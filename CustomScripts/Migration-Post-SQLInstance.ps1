function Protect-RSQLInstance {
    param(
        [parameter(Mandatory)]
        [string] $id,
        [parameter(Mandatory)]
        [string] $SLA,
        [parameter(Mandatory)]
        [int] $logRetentionHours,
        [parameter(Mandatory)]
        [int] $logBackupFrequencyInSeconds,
        [parameter()]
        [bool] $copyOnly = $false
    )

    $rsla = Get-RubrikSLA -Name $SLA -PrimaryClusterID local

    $o = New-Object -TypeName psobject
    $o | Add-Member -MemberType NoteProperty -Name "configuredSlaDomainId" -Value $rsla.id
    $o | Add-Member -MemberType NoteProperty -Name "logRetentionHours" -Value $logRetentionHours
    $o | Add-Member -MemberType NoteProperty -Name "logBackupFrequencyInSeconds" -Value $logBackupFrequencyInSeconds
    $o | Add-Member -MemberType NoteProperty -Name "copyOnly" -Value $copyOnly

    $endpointURI = 'mssql/instance/' + $id
    Invoke-RubrikRESTCall -Endpoint $endpointURI -Body $o -Method PATCH
}

$AllSQLInstances = get-content .\OldSQLInstances.json | ConvertFrom-Json
$AllSQLInstances = $AllSQLInstances | where-object {$_.configuredSlaDomainId -ne 'Inherit' -and $i_.configuredSlaDomainId -ne 'Unprotected'}
foreach ($i in $AllSQLInstances) {
    $instance = Get-RubrikSQLInstance -Name $i.name -Hostname $i.rootProperties.rootName
    Protect-RSQLInstance -SLA $i.configuredSlaDomainName -logRetentionHours $i.LogRetentionHours -logBackupFrequencyInSeconds $i.logBackupFrequencyInSeconds -id $instance.id
}