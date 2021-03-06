Function Export-RubrikSLA {
    param(
        [parameter(Mandatory)]
        [String] $sla,
        [parameter()]
        [String] $filename
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
    $json | Out-File $filename
}