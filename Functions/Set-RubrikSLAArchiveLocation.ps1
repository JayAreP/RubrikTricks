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