param(
    [parameter(mandatory)]
    [string]$managedVolumeName,
    [parameter(mandatory)]
    [string]$channels,
    [parameter()]
    [int64]$size,
    [parameter()]
    [string]$localpath,
    [parameter()]
    [string]$subnet,
    [ValidateSet('Oracle', 'OracleIncremental', 'MsSql', 'SapHana', 'SapHanaLog', 'MySql', 'PostgreSql', 'RecoverX', IgnoreCase = $false)]
    [parameter()]
    [string]$applicationTag = "Oracle",
    [parameter()]
    [string]$sla
)

<#
.SYNOPSIS

Creates the managed volume and generates the fstab entries for the linux host.  

.EXAMPLE

./Create-RubrikOracleBackups.ps1 -managedVolumeName ORMV01 -channels 2 -size 20gb -localpath '/mnt/ormv01' -sla 'Oracle SLA'

Creates file named fstab-additions.txt that contains a copy/paste set of fstab entries for the Linux Oracle host. 
Also creates a text file that includes the 'curl -k -X...' commands to post to the appropriate URI to open/close the MVs, should you 
require them.


#>
if ($localpath) {
    if ($localpath[-1] -eq '/') {
        Write-Host -ForegroundColor yellow Trailing `/ found in localpath paramter `($localpath`), removing... `n
        $localpath = $localpath.Substring(0,$localpath.Length-1)
    }
} else {
    $localpath = '/mnt/' + $managedVolumeName
}

if (Get-RubrikManagedVolume -Name $managedVolumeName) {
    Write-Host -ForegroundColor green $managedVolumeName already exists, no need to re-create... `n
} else {
    if ($subnet) {
        New-RubrikManagedVolume -Name $managedVolumeName -Channels $channels -VolumeSize $size -applicationTag $applicationTag -Subnet $subnet
    } else {
        New-RubrikManagedVolume -Name $managedVolumeName -Channels $channels -VolumeSize $size -applicationTag $applicationTag
    }
}

# put a wait here

$RMVs = Get-RubrikManagedVolume -Name $managedVolumeName
$patharray = $RMVs.mainExport.channels
$rmvid = $RMVs.id

while (!$patharray) {
    Write-Progress -Activity "Creating Managed Volume exports, please wait"
    sleep 1
    $RMVs = Get-RubrikManagedVolume -Name $managedVolumeName
    $patharray = $RMVs.mainExport.channels
}

$fstabname = 'fstab' + '-' + $managedVolumeName + '.txt'
$curlname = 'curl' + '-' + $managedVolumeName + '.txt'

$fstab = @()

Write-Host -ForegroundColor yellow `n'Copy and paste the following into the guest console to create the folders:'

foreach ($i in $patharray) {
    $rpath = $i.ipAddress + ':' + $i.mountPoint
    $lpath = $localpath + '-ch' + $i.mountPoint[-1]
    Write-Host "mkdir $lpath"
    $o = New-Object psobject
    $o | Add-Member -Type NoteProperty -Name 'RubrikPath' -Value $rpath
    $o | Add-Member -Type NoteProperty -Name 'LocalPath' -Value $lpath
    $o | Add-Member -Type NoteProperty -Name 'FSType' -Value 'nfs'
    $o | Add-Member -Type NoteProperty -Name 'Options' -Value 'rw,bg,hard,nointr,rsize=1048576,wsize=1048576,tcp,vers=3,timeo=600,actimeo=0,noatime 0 0'
    $fstab += $o
}


if ($sla) {
    if (Get-RubrikSLA -Name $sla -PrimaryClusterID local) {
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


Write-Host -ForegroundColor yellow `n"Copy and paste the following into /etc/fstab, or open $fstabname"
$fstab | Format-Table -hidetableheaders
$fstab | Format-Table -hidetableheaders | Out-File $fstabname 

$curlcmdURI = 'https://' + $Global:rubrikConnection.server + '/api/internal/managed_volume/' + $rmvid

$curlstart = 'curl -k -X POST -u ' + "'username:password' " + $curlcmdURI + '/begin_snapshot'
$curlend = 'curl -k -X POST -u ' + "'username:password' " + $curlcmdURI + '/end_snapshot'


Write-Host -ForegroundColor yellow "Use the following CURL URI for this volume or refer to $curlname"`n 
$curlstart
$curlend
Write-Host `n`n
$curlstart | Out-File $curlname
$curlend | Out-File $curlname -Append

