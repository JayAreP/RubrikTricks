param(
    [Parameter(Mandatory)]
    [array] $ObjectList,
    [Parameter(Mandatory)]
    [string] $ReportName
)
    
$currentReport = Get-RubrikReport -Name $ReportName | Get-RubrikReport

$objectlistitems = Get-Content $ObjectList
$objectsids = @()
foreach ($i in $objectlistitems) {
    $item = Get-RubrikVM -Name $i
    if (!$item) {
        $item = Get-RubrikFileset -Name $i
    }
    $item.id
    $objectsids += $item.id
}

$endpointURI = 'report/' + $currentReport.id
Invoke-RubrikRESTCall -Endpoint $endpointURI -Method PATCH -Body $currentReport -api internal