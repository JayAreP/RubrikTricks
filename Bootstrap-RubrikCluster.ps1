param(
    [parameter(mandatory)]
    [string] $hostaddress,
    [parameter(mandatory)]
    [string] $jsonfile,
    [parameter()]
    [switch] $validate
)

<#  
    .SYNOPSIS
    Connect to a rubrik endpoint and bootstrap it using the provided .json file.

    .EXAMPLE
    Bootstrap-RubrikCluster.ps1 -hostaddress RVM16CS013917 -jsonfile cluster-settings.json

#>

function fixcert {

    if ([System.Net.ServicePointManager]::CertificatePolicy.ToString() -ne "TrustAllCertsPolicy") {
    add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
    write-host -ForegroundColor yellow "Updating local certificate policy"
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

    }
}

$settings = get-content $jsonfile | ConvertFrom-Json
[array]$nlfromjson = ($settings.nodeConfigs | format-list | out-string).trim().replace(' : @{ipmiIpConfig=; managementIpConfig=}',$null).Split() | where-object {$_} | Sort-Object

if ($hostaddress -notlike "*.local") {
    write-host -ForegroundColor yellow "Adding .local to $hostaddress"
    $hostaddress = $hostaddress + '.local'
}

$jsondata = Get-Content $jsonfile

Write-Host -ForegroundColor green `n"Performing discovery on $hostaddress to compare to input JSON file"`n

#  --- 

Write-Host '==========================='

$json = get-content $jsonfile | ConvertFrom-Json

$nodeinfo = (Get-Content $jsonfile | Where-Object {$_ -match "RVM"}).replace(': {',$null).replace('"',$null).TrimStart() 
$firstnode = $nodeinfo[0]

$o = New-Object PSObject
$o | Add-Member -Name 'Cluster Name' -type noteproperty -Value $json.name
$o | Add-Member -Name 'NTP' -type noteproperty -Value $json.ntpservers
$o | Add-Member -Name 'DNS' -type noteproperty -Value $json.dnsNameservers
$o | Add-Member -Name 'Management Netmask' -type noteproperty -Value $json.nodeConfigs.$firstnode.managementIpConfig.netmask 
$o | Add-Member -Name 'Management Gateway' -type noteproperty -Value $json.nodeConfigs.$firstnode.managementIpConfig.gateway
$o | Add-Member -Name 'IPMI Netmask' -type noteproperty -Value $json.nodeConfigs.$firstnode.ipmiIpConfig.netmask 
$o | Add-Member -Name 'IPMI Gateway' -type noteproperty -Value $json.nodeConfigs.$firstnode.ipmiIpConfig.gateway
$o | Add-Member -Name 'Data Netmask' -type noteproperty -Value $json.nodeConfigs.$firstnode.dataIpConfig.netmask
$o | Add-Member -Name 'Data Gateway' -type noteproperty -Value $json.nodeConfigs.$firstnode.dataIpConfig.gateway
$o | Add-Member -Name 'Admin Password' -type noteproperty -Value $json.adminUserInfo.password

$o

$nodeconfigs = @()
foreach ($i in $nodeinfo) {
    $n = New-Object PSObject
    $n | Add-Member -Name 'Serial' -Type NoteProperty -Value $i
    $n | Add-Member -Name 'Management' -Type NoteProperty -Value $json.nodeConfigs.$i.managementIpConfig.address
    $n | Add-Member -Name 'IPMI' -Type NoteProperty -Value $json.nodeConfigs.$i.ipmiIpConfig.address
    $n | Add-Member -Name 'Data' -Type NoteProperty -Value $json.nodeConfigs.$i.dataIpConfig.address
    $nodeconfigs += $n
}

$nodetally = $nodeconfigs.count
if (($nodeconfigs | select-object management -unique).count -lt $nodetally) {
    Write-Host -ForegroundColor Red "IP Conflict in Management IPs"
}
if (($nodeconfigs | select-object IPMI -unique).count -lt $nodetally) {
    Write-Host -ForegroundColor Red "IP Conflict in IPMI IPs"
}
if (($nodeconfigs | select-object Data -unique).count -lt $nodetally) {
    Write-Host -ForegroundColor Red "IP Conflict in Data IPs"
}
$nodeconfigs | Format-Table

# --

$confirm = Read-Host 'Does the above list look correct? [Y,n]'
$confirm = $confirm.tolower()
while("y","n" -notcontains $confirm)
{
    if (!$confirm) {$confirm = 'y'}
    else {
        $confirm = Read-Host 'Does the above list look correct? [Y,n]'
    }
}

if ($confirm -eq "n") {
    Write-Host Configuration rejected, exiting...
    exit}

if ($validate) {

    if ($PSVersionTable.os -match 'darwin') {
        $discover = Invoke-RestMethod -Method get -Uri ("https://HOSTADDRESS/api/internal/cluster/me/discover").replace('HOSTADDRESS',$hostaddress) -SkipCertificateCheck
    } else {
        fixcert
        $discover = Invoke-RestMethod -Method get -Uri ("https://HOSTADDRESS/api/internal/cluster/me/discover").replace('HOSTADDRESS',$hostaddress) 
    }
    if ($discover.data.hostname) {
        [array]$nlfromdisc = $discover.data.hostname | Sort-Object
    } else {
        [array]$nlfromdisc = $discover.data | Sort-Object
    }
    
    Compare-Object -ReferenceObject $nlfromjson -DifferenceObject $nlfromdisc -IncludeEqual

    if  (Compare-Object -ReferenceObject $nlfromjson -DifferenceObject $nlfromdisc) {
        Write-Host -ForegroundColor Yellow "--- JSON file and node discovery do not match, please double check the input file. ---"
        Exit 
    } 
} 

Write-Host -ForegroundColor yellow '---- Starting Bootstrap -----'

if ($PSVersionTable.os -match 'darwin') {
    $data = Invoke-RestMethod -Method POST -Uri ("https://HOSTADDRESS/api/internal/cluster/me/bootstrap").replace('HOSTADDRESS',$hostaddress) -body $jsondata -SkipCertificateCheck -verbose
} else {
    fixcert
    $data = Invoke-RestMethod -Method POST -Uri ("https://HOSTADDRESS/api/internal/cluster/me/bootstrap").replace('HOSTADDRESS',$hostaddress) -body $jsondata -verbose
}
$data | Convertto-Json
$data 

start-sleep 3

write-host -ForegroundColor yellow Check bootstrap progress using the command `n`n ./Check-RubrikBootstrapProgress.ps1 -hostaddress $hostaddress -id $data.id