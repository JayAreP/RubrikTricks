function Invoke-RubrikRESTCallAsJSON {
    param (
        [Parameter()]
        [string]$api = 'v1',
        [Parameter(Mandatory)]
        [string]$endpoint,
        [Parameter(Mandatory)]
        [string]$method,
        [Parameter()]
        [string]$body
    )

    $endpointURIprefix = 'https://' + $Global:RubrikConnection.server + '/api/'
    $endpointAPI = $endpointURIprefix + $api + '/'
    $endpointURI = $endpointAPI + $endpoint
    $endpointURI | Write-Verbose 
    if ($body) {
        Invoke-RestMethod -Uri $endpointURI -Method $method -Body $body -headers $Global:rubrikConnection.header 
    } else {
        Invoke-RestMethod -Uri $endpointURI -Method $method -headers $Global:rubrikConnection.header
    }
}