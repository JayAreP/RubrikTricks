param(
    [parameter(mandatory)]
    [string] $dbserver,
    [parameter(mandatory)]
    [string] $database,
    [parameter(mandatory)]
    [string] $targetdbserver,
    [parameter()]
    [string] $instance = "MSSQLSERVER",
    [parameter()]
    [string] $targetdbname = $database,
    [parameter(mandatory)]
    [string] $rubrik,
    [parameter()]
    [string] $dbfilepath,
    [parameter()]
    [string] $logfilepath,
    [Parameter()]
    [switch] $uselatestsnapshot,
    [Parameter()]
    [switch] $usescriptcredentials
)

if ($dbfilepath -and !$logfilepath) { 
    write-host -ForegroundColor yellow Please spcify both -dbfilepath and -logfilepath
    exit}

<# 
A function here for adding a login to the script. You can actually construct the credential opbject however you like. 
1. Log into the system that is running this script as the service account that execute the script.  
2. Create the rubrik credential object by typing: 
    $creds = get-credential 
    and then enter the rubrik username and password.
3. Store that credential as a secure XML by typing: 
    $creds | Export-CliXML -path .\credential.xml -force
#>

function runrubriklogin {
    param(
        [parameter(mandatory)]
        [String] $rbk
    )
        $creds = Import-Clixml -Path .\credential.xml 
        Connect-Rubrik -Server $rbk -Credential $creds 
}

if ($usescriptcredentials) {
    runrubriklogin -rbk $rubrik
}

# Validate SQL server and refresh metadata

$targetdbserver = (Get-RubrikHost -name $targetdbserver | where-object {$_.hostname -eq $targetdbserver}).hostname

$targetdbserverid = (Get-RubrikHost -name $targetdbserver | where-object {$_.hostname -eq $targetdbserver}).id
$endpointURI = 'host/' + $targetdbserverid + '/refresh'
Invoke-RubrikRESTCall -Endpoint $endpointURI -Method POST

# Validate and grab the Database

try {
    $rdb = Get-RubrikDatabase -Hostname $dbserver -Instance $instance -Database $dbname | Get-RubrikDatabase -ErrorAction silentlycontinue}
catch {
    write-host -ForegroundColor Red Could not acquire $database on $dbserver
    Exit}

$SourceDBID = $rdb.id

if ($uselatestsnapshot) {
	$latestsnapdate = (Get-RubrikDatabase -Hostname $dbserver -Database $database | Get-RubrikSnapshot | Sort-Object date)[-1].date
	$recoverdate = Get-Date $latestsnapdate 
} else {
	$recoverdate = $rdb.latestRecoveryPoint | get-date
}

try {
    $TargetInstanceID = (Get-RubrikSQLInstance -Name $targetinstance -Hostname $targetdbserver).id}
catch {
    write-host -ForegroundColor red Could not acquire $targetdbserver information
    exit}

# -- All changes are below here --
# Build the databasefile array 

$sourcedbfiles = Get-RubrikDatabaseFiles -id $SourceDBID -RecoveryDateTime $recoverdate
$targetdbfiles = @()
foreach ($i in $sourcedbfiles) {
    $o = new-object psobject
    $o | add-member -name logicalName -type noteproperty -value $i.logicalName.Replace($dbname,$targetdbname)
    if ($dbfilepath) {
        if ($i.originalName -notlike "*.ldf") {$o | add-member -name exportPath -type noteproperty -value $dbfilepath}
        if ($i.originalName -like "*.ldf") {$o | add-member -name exportPath -type noteproperty -value $logfilepath}
    } else {
        $o | add-member -name exportPath -type noteproperty -value $i.originalPath
    }
    $targetdbfiles  += $o
}

$exportrequest = Export-RubrikDatabase -TargetFilePaths $targetdbfiles -id $SourceDBID -targetInstanceId $TargetInstanceID -targetDatabaseName $targetdbname -RecoveryDateTime $recoverdate -MaxDataStreams 4 -confirm:0 -finishrecovery

$exportrequest.id  | out-file .\export.log
# Get-RubrikRequest -id $exportrequest.id -type mssql
