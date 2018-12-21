param(
    [parameter(mandatory)]
    [string]$managedvolume,
    [parameter()]
    [int]$channels,
    [parameter()]
    [int64]$size,
    [parameter(mandatory)]
    [string]$localpath,
    [parameter()]
    [string]$sla
)

<#
.SYNOPSIS

Creates the managed volume and generates the fstab entries for the linux host. 

.EXAMPLE

./Create-RubrikOracleBackups.ps1 -managedvolume ORMV01 -channels 2 -size 20gb -localpath '/mnt/ormv01' -sla 'Oracle SLA'

Creates file named fstab-additions.txt that contains a copy/paste set of fstab entries for the Linux Oracle host

#>

if ($localpath[-1] -eq '/') {
    Write-Host -ForegroundColor yellow Trailing `/ found in localpath paramter `($localpath`), removing... `n
    $localpath = $localpath.Substring(0,$localpath.Length-1)
}

if (Get-RubrikManagedVolume -Name $managedvolume) {
    Write-Host -ForegroundColor green $managedvolume already exists, no need to re-create... `n
} else {
    New-RubrikManagedVolume -Name $managedvolume -Channels $channels -VolumeSize $size
}

function Get-RubrikFloatingIPAddress {
    Invoke-RubrikRESTCall -api internal -endpoint 'node_management/cluster_ip' -Method GET
}

$rfips = Get-RubrikFloatingIPAddress
if ($rfips.count -lt $channels) {
    write-host -ForegroundColor Yellow Not enough floating IPs are available to service the number of Channels. 
    exit
}

$RMVs = Get-RubrikManagedVolume -Name $managedvolume
$patharray = $RMVs.mainExport.channels
$rmvid = $RMVs.id

Remove-Item .\fstab-additions.txt -ErrorAction SilentlyContinue

$fstab = @()

Write-Host -ForegroundColor yellow `n 'Copy and paste the following into the guest console to create the folders.'`n "---------------------------------------"

foreach ($i in $patharray) {
    $rpath = $i.ipAddress + ':' + $i.mountPoint
    $lpath = $localpath + '-ch' + $i.mountPoint[-1]
    Write-Host "mkdir $lpath"
    $o = New-Object psobject
    $o | Add-Member -Type NoteProperty -Name 'RubrikPath' -Value $rpath
    $o | Add-Member -Type NoteProperty -Name 'LocalPath' -Value $lpath
    $o | Add-Member -Type NoteProperty -Name 'FSType' -Value 'nfs'
    $o | Add-Member -Type NoteProperty -Name 'Options' -Value 'rw,bg,hard,nointr,rsize=32768,wsize=32768,tcp,vers=3,timeo=600 0 0'
    $fstab += $o
}

if ($sla) {
    if (Get-RubrikSLA -Name $sla) {
        Write-Host `n `n Adding $managedvolume to SLA $sla
        $rsla = get-rubriksla -Name $sla
        $rid = $rsla.id
        $jsonstring = "{`"managedIds`": [`"$rmvid`"]}"
        $r = $jsonstring | ConvertFrom-Json
        $endpointURI = 'sla_domain/' + $rid + '/assign'
        Invoke-RubrikRESTCall -Method POST -Endpoint $endpointURI -Body $r -api internal
    } else {
        Write-Host -ForegroundColor yellow $sla is not the name of a valid SLA`, skipping... `n 
    }
}

Write-Host -ForegroundColor yellow 'Copy and paste the following into /etc/fstab' `n 'or open .\fstab-aditions.txt'`n "---------------------------------------"

$fstab | Format-Table -hidetableheaders
$fstab | Format-Table -hidetableheaders | Out-File .\fstab-additions.txt

