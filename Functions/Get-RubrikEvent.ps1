function Get-RubrikEvent {

    param(
        [parameter()]
        [int]$limit = 50,
        [parameter()]
        [string]$after_id,
        [parameter()]
        [string]$event_series_id,
        [parameter()]
        [string]$status,
        [parameter()]
        [string]$event_type,
        [Parameter()]
        [string]$object_ids,
        [parameter()]
        [string]$object_name,
        [parameter()]
        [string]$before_date,
        [parameter()]
        [string]$after_date,
        [parameter()]
        [string]$object_type,
        [parameter()]
        [bool]$show_only_latest = $true
    )
    <#
    .SYNOPSIS
    Powershell Function to search for rubrik events. 
     
    .EXAMPLE
    Get-RubrikEvent -event_type Failure -object_name SQL01 -after_date (get-date).adddays(-1)
    #>

    if ($before_date) {$before_date = get-date $before_date -UFormat "%a %b %d %T %Y"}
    if ($after_date) {$after_date = get-date $after_date -UFormat "%a %b %d %T %Y"}

    $endpointURI = 'event?'
    $plist = $PSBoundParameters
    if ($PSBoundParameters) {
        foreach ($i in $plist.keys) {
            $par = $i
            $val = $plist[$i]
            $endpointURI = $endpointURI + $par + '=' + $val + '&'
        }
    }

    $endpointURI = $endpointURI.Replace(' ','%20')
    $endpointURI = $endpointURI.Replace(',','%2C')
    $endpointURI = $endpointURI.Replace(':','%3A')

    if ($endpointURI[-1] -eq '&') {$endpointURI = $endpointURI.Substring(0,$endpointURI.Length-1)}
    $endpointURI | write-verbose
    $jobdata = Invoke-RubrikRESTCall -Endpoint $endpointURI -Method GET -api internal -verbose
    $jobdata.data
}



