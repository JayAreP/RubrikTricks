param(
    [Parameter(Mandatory)]
    [string] $prefix,
    [Parameter(Mandatory)]
    [string] $rubrik,
    [Parameter()]
    [int] $NumMonths = 12
)
# Functions for later
function Build-MenuFromArray {
    param(
        [Parameter(Mandatory)]
        [array]$array,
        [Parameter(Mandatory)]
        [string]$property,
        [Parameter()]
        [string]$message = "Select item"
    )
    Write-Host '------'
    $menuarray = @()
        foreach ($i in $array) {
            $o = New-Object psobject
            $o | Add-Member -MemberType NoteProperty -Name $property -Value $i.$property
            $menuarray += $o
        }
    $menu = @{}
    for (
        $i=1
        $i -le $menuarray.count
        $i++
    ) { Write-Host "$i. $($menuarray[$i-1].$property)" 
        $menu.Add($i,($menuarray[$i-1].$property))
    }
    Write-Host '------'
    [int]$mntselect = Read-Host $message
    $menu.Item($mntselect)
    Write-Host `n`n
}

if (!(Get-RubrikSLA -ea SilentlyContinue)) {
    $creds = Get-Credential -Message "Enter Rubrik username and password."
    Connect-Rubrik -Server $rubrik -Credential $creds
}

function Set-RubrikSLAArchiveLocation {
    param(
        [Parameter(Mandatory)]
        [string] $SLA,
        [Parameter(Mandatory)]
        [string] $ArchiveName,
        [Parameter()]
        [switch] $InstantArchive,
        [Parameter()]
        [int] $DaysOnBrik
    )

    $jobstats = Invoke-RubrikRESTCall -Endpoint 'archive/location' -Method GET -api internal
    $archives = $jobstats.data
    $archive = $archives | Where-Object {$_.name -eq $ArchiveName}

    $RSLA = Get-RubrikSLA -Name $SLA -PrimaryClusterID local
    if ($InstantArchive) {$threshold = 1}
    else {$threshold = 0}

    $o = New-Object psobject
    $o | Add-Member -MemberType NoteProperty -Name 'locationId' -Value $archive.id
    $o | Add-Member -MemberType NoteProperty -Name 'archivalThreshold' -Value $threshold
    $a = New-Object psobject
    $a | Add-Member -MemberType NoteProperty -Name 'archivalSpecs' -Value @($o)

    if ($DaysOnBrik) {
        $localRetentionLimit = $DaysOnBrik * 60 * 60 * 24
        $a | Add-Member -MemberType NoteProperty -Name 'localRetentionLimit' -Value $localRetentionLimit
    }

    $endpointURI = 'sla_domain/' + $RSLA.id
    Invoke-RubrikRESTCall -Endpoint $endpointURI -Method PATCH -Body $a -verbose
}

#Archive Select Menu

$jobstats = Invoke-RubrikRESTCall -Endpoint 'archive/location' -Method GET -api internal
$archives = $jobstats.data
$archivelocal = Build-MenuFromArray -array $archives -property name -message "Select Archive Location"
# $archivestats = $archives | Where-Object {$_.name -eq $archivelocal}

$start = 1
$NumMonths = $NumMonths + 1
while ($start -lt $NumMonths){
    $date = get-date "Dec 2018"
    $date = $date.AddMonths($start)
    $SLAName = $prefix + '-' + 'Exp' + '-' + (Get-Culture).DateTimeFormat.GetAbbreviatedMonthName($date.month) + '-' + $date.Year
    Write-Host -ForegroundColor Green ---- Creating SLA $SLAName ---- `n
    New-RubrikSLA -Name $SLAName -MonthlyFrequency 1 -MonthlyRetention $start -Confirm:0
    Set-RubrikSLAArchiveLocation -SLA $SLAName -ArchiveName $archivelocal -InstantArchive -DaysOnBrik 3
    $start++
}

