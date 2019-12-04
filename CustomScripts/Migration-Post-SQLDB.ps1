$AllSQLDatabases = get-content .\OldSQLDatabases.json | ConvertFrom-Json
$AllSQLDatabases = $AllSQLDatabases | where-object {$_.configuredSlaDomainId -ne 'Inherit' -and $_.configuredSlaDomainId -ne 'Unprotected'}
foreach ($i in $AllSQLDatabases) {
    $rdb = Get-RubrikDatabase -Name $i.name -Instance $i.instanceName -Hostname $i.rootProperties.rootName -PrimaryClusterID local
    Protect-RubrikDatabase -id $rdb.id -SLA $i.configuredSlaDomainName
    # create new function
    # Set-RubrikDatabase -id $rdb.id -LogBackupFrequencyInSeconds $i.logBackupFrequencyInSeconds -LogRetentionHours $i.LogRetentionHours
}