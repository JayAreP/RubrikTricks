
# helper functions
function getEventSeries {
    param(
        [string] $objectID
    )
    $endpointURI = "event_series?limit=99&status=Success&event_type=Backup&object_ids=" + $objectID
    return (Invoke-RubrikRESTCall -Endpoint $endpointURI -Method GET -api internal).data
}

function filterObject {
    param(
        [string] $snapID,
        [string] $snapable,
        [DateTime] $snapDate,
        [string] $objectName,
        [string] $slaID,
        [string] $cloudState
    )
    $class = $snapable.Split(':::')[0]
    $o = new-object PSObject
    $o | Add-Member -MemberType NoteProperty -Name 'snapID' -value $snapID
    $o | Add-Member -MemberType NoteProperty -Name 'snapable' -Value $snapable
    $o | Add-Member -MemberType NoteProperty -Name 'snapDate' -Value $snapDate
    $o | Add-Member -MemberType NoteProperty -Name 'objectName' -Value $objectName
    $o | Add-Member -MemberType NoteProperty -Name 'class' -Value $class
    $o | Add-Member -MemberType NoteProperty -Name 'slaID' -Value $slaID
    $o | Add-Member -MemberType NoteProperty -Name 'cloudState' -Value $cloudState

    return $o
}

function getSnapStorage {
    param (
        [string] $snapID,
        [string] $snapableID
    )
    $endpoiubtURI = 'snapshot/' + $snapID + '/storage/stats?snappable_id=' + $snapableID
    $storageStats = Invoke-RubrikRESTCall -Endpoint $endpoiubtURI -Method GET -api internal
    return $storageStats
}

# create initial vars and SLA index.

$date = get-date
$allsnaps = @()
$AllSLAs = Get-RubrikSLA -PrimaryClusterID local

# Gather VM snaps
$Objects = Get-RubrikVM -PrimaryClusterID local
foreach ($o in $Objects) {
    $snaps = $o | Get-RubrikSnapshot -OnDemandSnapshot -Range 1 -Date $date.ToShortDateString() -ExactMatch
    if ($snaps) {
        $snaps | foreach-object {
            $allsnaps += filterObject -snapID $_.id -snapable $o.id -snapDate $_.date -objectName $o.name -slaID $_.slaid -cloudState $_.cloudState
        }
    }
}

# Gather Hyper-V snaps
$Objects = Get-RubrikHyperVVM -PrimaryClusterID local
foreach ($o in $Objects) {
    $snaps = $o | Get-RubrikSnapshot -OnDemandSnapshot -Range 1 -Date $date.ToShortDateString() -ExactMatch
    if ($snaps) {
        $snaps | foreach-object {
            $allsnaps += filterObject -snapID $_.id -snapable $o.id -snapDate $_.date -objectName $o.name -slaID $_.slaid -cloudState $_.cloudState
        }
    }
}

# Gather SQL snaps
$Objects = Get-RubrikDatabase -PrimaryClusterID local
foreach ($o in $Objects) {
    $snaps = $o | Get-RubrikSnapshot -OnDemandSnapshot -Range 1 -Date $date.ToShortDateString() -ExactMatch
    if ($snaps) {
        $snaps | foreach-object {
            $allsnaps += filterObject -snapID $_.id -snapable $o.id -snapDate $_.date -objectName $o.name -slaID $_.slaid -cloudState $_.cloudState
        }
    }
}

# Gather FileSet snaps
$Objects = Get-RubrikFileSet -PrimaryClusterID local
foreach ($o in $Objects) {
    $snaps = $o | Get-RubrikSnapshot -OnDemandSnapshot -Range 1 -Date $date.ToShortDateString() -ExactMatch
    if ($snaps) {
        $snaps | foreach-object {
            $allsnaps += filterObject -snapID $_.id -snapable $o.id -snapDate $_.date -objectName $o.name -slaID $_.slaid -cloudState $_.cloudState
        }
    }
}

# Gather MV snaps
$Objects = Get-RubrikManagedVolume -PrimaryClusterID local
foreach ($o in $Objects) {
    $snaps = $o | Get-RubrikSnapshot -OnDemandSnapshot -Range 1 -Date $date.ToShortDateString() -ExactMatch
    if ($snaps) {
        $snaps | foreach-object {
            $allsnaps += filterObject -snapID $_.id -snapable $o.id -snapDate $_.date -objectName $o.name -slaID $_.slaid -cloudState $_.cloudState
        }
    }
}

# Gather VG snaps
$Objects = Get-RubrikVolumeGroup -PrimaryClusterID local
foreach ($o in $Objects) {
    $snaps = $o | Get-RubrikSnapshot -OnDemandSnapshot -Range 1 -Date $date.ToShortDateString() -ExactMatch
    if ($snaps) {
        $snaps | foreach-object {
            $allsnaps += filterObject -snapID $_.id -snapable $o.id -snapDate $_.date -objectName $o.name -slaID $_.slaid -cloudState $_.cloudState
        }
    } else {
    }
}

# gather storage for snaps
foreach ($snap in $allsnaps) {
    try {
        $stats = getSnapStorage -snapID $snap.snapID -snapableID $snap.snapable
    } catch {
        continue
    }
    
    $slastats = $AllSLAs | Where-Object {$_.id -eq $snap.slaID}

    $events = getEventSeries -objectID $snap.snapable
    $currentevent = ($events | where-object {$_.eventdate -ge $snap.snapDate})[-1]

    $o = New-Object psobject
    $o | Add-Member -MemberType NoteProperty -Name 'Name' -Value $snap.objectName
    $o | Add-Member -MemberType NoteProperty -Name 'Location' -Value $Global:rubrikConnection.server
    $o | Add-Member -MemberType NoteProperty -Name 'Object Class' -Value $snap.class
    $o | Add-Member -MemberType NoteProperty -Name 'Retention SLA' -Value $slastats.name
    $o | Add-Member -MemberType NoteProperty -Name 'Local Storage (in bytes)' -Value $stats.physicalBytes
    $o | Add-Member -MemberType NoteProperty -Name 'Start Time' -Value $currentevent.startTime
    $o | Add-Member -MemberType NoteProperty -Name 'End Time' -Value $currentevent.endTime
    $o | Add-Member -MemberType NoteProperty -Name 'Duration' -Value $currentevent.duration
    $o
    $o | export-csv .\output.csv -notype
}