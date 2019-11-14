param(
    [parameter(mandatory)]
    [string]$server,
    [parameter()]
    [string]$instance = "MSSQLServer",
    [parameter()]
    [array]$databases,
    [parameter(mandatory)]
    [string]$SLA,
    [parameter()]
    [bool]$IsAlwaysOn = $false,
    [parameter()]
    [switch]$generateJSONTemplate,
    [parameter()]
    [switch]$includeSysDBs,
    [parameter()]
    [switch]$logOnly

)

if ($generateJSONTemplate) {
    $array = @()
    $o = New-Object psobject
    $o | Add-Member -MemberType NoteProperty -Name 'server' -Value $server
    $o | Add-Member -MemberType NoteProperty -Name 'instance' -Value $instance
    $o | Add-Member -MemberType NoteProperty -Name 'database' -Value $databases
    $o | Add-Member -MemberType NoteProperty -Name 'SLA' -Value $SLA
    $o | Add-Member -MemberType NoteProperty -Name 'IsAlwaysOn' -Value $IsAlwaysOn 
    $array += $o
    $array += $o
    return $array | ConvertTo-Json -Depth 10
}

<#
    .SYNOPSIS
    Keys off of an optional input JSON and invokes an on-demand backup of the desired databases on the existing SLA

    .EXAMPLE
    -- Single instance run ---
    ./Start-RubrikDatabaseOnDemand.ps1 -server SQLServer1 -instance Instance1 -databases db1,db2,db3 -SLA Gold
    This would grab the databases db1, db2, and db3 on SQLServer1\Instance1 and perform an on-demand backup against the SLA 'Gold'

    --- JSON template generation ---
    ./Start-RubrikDatabaseOnDemand.ps1 -server SQLServer1 -instance Instance1 -databases db1 -SLA Gold -generateJSONTemplate
    This will not perform an actual backup, but will generate a JSON template to use to key off of for operational ease. 

    --- JSON multi-database and multi-instance operations ---
    Get-Content databases.json | foreach-object {
        ./Start-RubrikDatabaseOnDemand.ps1 -server $_.server -instance $_.instance -databases $_.database -SLA $_.SLA
    }
#>

# System databases to ignore
$sysdbs = @(
    'msdb',
    'master',
    'model',
    'tempdb'
)

# declare the instance
if ($IsAlwaysOn -eq $true) {
    $rbSQLInstance = Get-RubrikAvailabilityGroup -GroupName $server 
} else {
    $rbSQLInstance = Get-RubrikSQLInstance -Hostname $server -ServerInstance $instance
}

# declare the databases. If no -databases list was provided we'll grab all of them
if (!$databases) {
    $rbDBs = Get-RubrikDatabase -InstanceID $rbSQLInstance.id
} else {
    $rbDBs = @()
    foreach ($db in $databases) {
        $rbDBs += Get-RubrikDatabase -InstanceID $rbSQLInstance.id -Name $db
    }
}

# Check for the -logOnly switch and perform log backups on all desired user databases, then exit the script. 
if ($logOnly) {
    foreach ($rdb in $rbDBs) {
        if (!($sysdbs -contains $rdb.name)) {
            New-RubrikLogBackup -id $rdb.id 
        }
    }
    Exit
}

# Check that the databases are not part of the $sysdbs and if so, perform backup against the desired SLA
if (!$includeSysDBs) {
    foreach ($rdb in $rbDBs) {
        if (!($sysdbs -contains $rdb.name)) {
            New-RubrikSnapshot -id $rdb.id -SLA $SLA
        }
    }
} else {
    foreach ($rdb in $rbDBs) {
        New-RubrikSnapshot -id $rdb.id -SLA $SLA
    }
}
