param(
    [parameter(mandatory)]
    [string] $Datacenter,
    [parameter(mandatory)]
    [System.Management.Automation.PSCredential] $Credential,
    [parameter(mandatory)]
    [string] $serviceUser,
    [parameter()]
    [string] $servicePass,
    [parameter()]
    [string] $IncludeInName = 'rubrik'
)
<#
    .SYNOPSIS
    Powershell scripts to create and harden a service account for use with a specific vCenter datacenter object and tie that access to a specific vCenter role. 
    Use this script after, and in cunjunction with the one-time use script RubrikRBACWorkflow-stage1.ps1 and the operational script RubrikRBACWorkflow-stage2.ps1 
    to populate an appropriate Rubrik access role and AD group. 
     
    .EXAMPLE
    ./RubrikRBACWorkflow-stage3.ps1 -Datacenter Labs -Credential $rubrikAdmin -serviceUser rbksvc-USEast -servicePass 'Rubrik123!@#'

    This will:
        - Acquire the Edge appliance IPv4 address and connect to that rubrik using the specified -Credential
        - Update the Rubrik with serviceUser and servicePass specified.
        - Refresh the Rubrik Edge appliance's vcenter. 
#>

function Add-RubrikVcenter {
    param(
        [parameter(mandatory)]
        [System.Management.Automation.PSCredential] $credential,
        [parameter()]
        [switch] $updateOnly
    )
    $vcserver = (Get-VIAccount)[0].server.name
    $o = New-Object psobject
    $o | Add-Member -MemberType NoteProperty -Name 'hostname' -Value $vcserver
    $o | Add-Member -MemberType NoteProperty -Name 'username' -Value $credential.username
    $o | Add-Member -MemberType NoteProperty -Name 'password' -Value $credential.GetNetworkCredential().password
    $o | Add-Member -MemberType NoteProperty -Name 'conflictResolutionAuthz' -Value "AllowAutoConflictResolution"

    if ($updateOnly) {
        $currentvc = (Invoke-RubrikRESTCall -Endpoint 'vmware/vcenter' -Method GET).data | where-object {$_.hostname -eq $vcserver}
        $endpoint = 'vmware/vcenter/' + $currentvc.id
        Invoke-RubrikRESTCall -Endpoint $endpoint -Method PUT -Body $o
        start-sleep -seconds 3
        $endpoint = 'vmware/vcenter/' + $currentvc.id + '/refresh'
        $jobrun = Invoke-RubrikRESTCall -Endpoint $endpoint -Method POST
        while ($jobrun.status -eq "RUNNING" -or $jobrun.status -eq "QUEUED") {
            Write-Progress -Activity "Refreshing vCenter..." -PercentComplete $jobrun.progress
            start-sleep -seconds 1
            $endpoint = 'vmware/vcenter/request/' + $jobrun.id
            $jobrun = Invoke-RubrikRESTCall -Endpoint $endpoint -Method get
        }
    } else {
        $endpoint = 'vmware/vcenter'
        try {
        Invoke-RubrikRESTCall -Endpoint $endpoint -Method POST -Body $o
        } catch {
            Write-Host -ForegroundColor red 
        }
    }
}

if (!$servicePass) {
<#
$servicePass = << Put aim client command to grab password here >>
#>
}

$edgevm = Get-Datacenter $Datacenter | Get-VM | Where-Object {$_.name -match $IncludeInName}   
$edgeip = $edgevm.Guest.IPAddress
$iplists = $edgeip | ForEach-Object {[ipaddress]$_}
$edgeip = ($iplists | Where-Object {$_.AddressFamily -eq 'InterNetwork'}).IPAddressToString

foreach ($ip in $edgeip) {

Connect-Rubrik -Server $ip -Credential $Credential

    # $updatecreds = Import-Clixml $credfile.Name
    $pw = $servicepass | ConvertTo-SecureString -Force -AsPlainText
    $updatecreds = New-Object System.Management.Automation.PSCredential($serviceUser,$pw)
    Add-RubrikVcenter -credential $updatecreds -updateOnly
    $vmcount = (Get-RubrikVM).count
    return $vmcount
}