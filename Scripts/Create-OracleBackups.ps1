param(
    [parameter(mandatory)]
    [string]$managedvolume,
    [int]$channels,
    [int64]$size,
    [parameter(mandatory)]
    [string]$localpath,
    [string]$sla
)
if (!(Get-RubrikManagedVolume -Name $managedvolume)) {
    Write-Host -ForegroundColor green $managedvolume already exists, no need to re-create... `n
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
    Write-Host `n `n Adding $managedvolume to SLA $sla
    $rsla = get-rubriksla -Name $sla
    $rid = $rsla.id
    $jsonstring = "{`"managedIds`": [`"$rmvid`"]}"
    $r = $jsonstring | ConvertFrom-Json
    $endpointURI = 'sla_domain/' + $rid + '/assign'
    Invoke-RubrikRESTCall -Method POST -Endpoint $endpointURI -Body $r -api internal
}

Write-Host -ForegroundColor yellow 'Copy and paste the following into /etc/fstab' `n 'or open .\fstab-aditions.txt'`n "---------------------------------------"

$fstab | Format-Table -hidetableheaders
$fstab | Format-Table -hidetableheaders | Out-File .\fstab-additions.txt

