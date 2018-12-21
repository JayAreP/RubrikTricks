function Set-RubrikSLAWindow {
    param(
        [parameter(Mandatory)]
        [String] $sla,
        [parameter()]
        [int] $hour = 0,
        [parameter()]
        [int] $minutes = 0,
        [parameter()]
        [int] $duration = 0,
        [parameter()]
        [switch] $clear 
    )

    $startTimeAttributes = new-object psobject
    $startTimeAttributes | Add-Member -type noteproperty  -Name 'minutes' -Value $minutes
    $startTimeAttributes | Add-Member -type noteproperty  -Name 'hour' -Value $hour
  
    [array]$allowedBackupWindows = @()
    $ao = @{durationInHours=$duration;startTimeAttributes=$startTimeAttributes}
    if ($clear) {$ao = @()}
    $allowedBackupWindows += $ao

    $cluster = Invoke-RubrikRESTCall -Endpoint 'cluster/me' -Method get

    $rsla = get-rubriksla -Name $sla -PrimaryClusterID $cluster.id
    $o = new-object psobject
    $o | Add-Member -Type NoteProperty -Name 'allowedBackupWindows' -Value $allowedBackupWindows
    $jsondata = $o | ConvertTo-Json -Depth 10
    $jsondata

    $endpointURI =  'https://' + $Global:RubrikConnection.server + '/api/v1/sla_domain/' + $rsla.id 
    $endpointURI
    Invoke-RestMethod -Uri $endpointURI -Method PATCH -Body $jsondata -headers $Global:rubrikConnection.header -verbose
}