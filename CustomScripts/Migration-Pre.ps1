Function Export-RubrikSLA {
    param(
        [parameter(Mandatory)]
        [String] $sla,
        [parameter()]
        [String] $filename,
        [parameter()]
        [String] $path
    )
    $rsla = get-rubriksla -Name $sla -PrimaryClusterID local -ErrorAction silentlycontinue
    if (!$rsla) {
        Write-Host -ForegroundColor yellow $sla is not found on the cluster $Global:RubrikConnection.server 
        exit
    }
    if (!$filename) {
        $filename = $Global:RubrikConnection.server + '-' + $sla + '.json'
    }
    Write-Host -ForegroundColor Yellow Exporting $sla as $filename
    $rsla = get-rubriksla -Name $sla -PrimaryClusterID local
    $endpointURI =  'sla_domain/' + $rsla.id 
    $json = Invoke-RubrikRESTCall -Endpoint $endpointURI -Method get -api 2 | ConvertTo-Json -Depth 10
    if ($path) {
        $expath = $path + '\' + $filename
    } else {
        $expath = $filename
    }
    $json | Out-File -path $expath
}

New-Item -ItemType Directory -Name Migration

Get-RubrikSLA -PrimaryClusterID local | foreach-object {
    Export-RubrikSLA -sla $_.name -path .\Migration
}

$AllSQLInstances = Get-RubrikSQLInstance -PrimaryClusterID local
$AllSQLDatabases = Get-RubrikDatabase -PrimaryClusterID local
$AllHosts = Get-RubrikHost -PrimaryClusterID local
$AllFileSets = Get-RubrikFileset -PrimaryClusterID local
$AllFileSetTemplates = Get-RubrikFilesetTemplate -PrimaryClusterID local


$AllSQLInstances | ConvertTo-Json -Depth 10 | out-file .\Migration\OldSQLInstances.json
$AllSQLDatabases | ConvertTo-Json -Depth 10 | out-file .\Migration\OldSQLDatabases.json
$AllHosts | ConvertTo-Json -Depth 10 | out-file .\Migration\OldHosts.json
$AllFileSets | ConvertTo-Json -Depth 10 | out-file .\Migration\OldFileSets.json
$AllFileSetTemplates | ConvertTo-Json -Depth 10 | out-file .\Migration\OldFileSetTemplates.json