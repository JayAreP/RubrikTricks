param (
    [string] $path
)

function Render-RubrikReport {
    param (
        [parameter(mandatory)]
        [string] $reportname,
        [parameter()]
        [int] $total = 9999
    )
    $script:total = $total
    $rnd = get-random
    $filename = $rnd.ToString() + '.csv'

    function Invoke-RubrikRESTCall-json {
        param (
            [string]$api = 'v1',
            [string]$endpoint,
            [string]$method,
            [string]$body
        )
    
        $endpointURIprefix = 'https://' + $Global:RubrikConnection.server + '/api/'
        $endpointAPI = $endpointURIprefix + $api + '/'
        $endpointURI = $endpointAPI + $endpoint
        $endpointURI | Write-Verbose 
        if ($body) {
            Invoke-RestMethod -Uri $endpointURI -Method $method -Body $body -headers $Global:rubrikConnection.header -verbose
        } else {
            Invoke-RestMethod -Uri $endpointURI -Method $method -headers $Global:rubrikConnection.header -verbose
        }
    
    }
    function Get-RubrikReportTable {
        param (
            [parameter(mandatory)]
            [string] $id,
            [parameter(mandatory)]
            [int] $limit,
            [parameter(mandatory)]
            [string] $SortBy
        )

        $o = New-Object PSOBject
        $o | Add-Member -MemberType NoteProperty -Name 'sortBy' -Value $SortBy
        $o | Add-Member -MemberType NoteProperty -Name 'sortOrder' -Value 'asc'
        $o | Add-Member -MemberType NoteProperty -Name 'requestFilters' -Value $null
        $o | Add-Member -MemberType NoteProperty -Name 'limit' -Value $limit
        $jsonbody = $o | ConvertTo-Json
        $jsonbody 

        $URIendpoint = 'report/' + $id + '/table'
        Invoke-RubrikRESTCall-json -api internal -Endpoint $URIendpoint -Method POST -Body $jsonbody
    }

    $rrpt = get-rubrikreport -name $reportname | Get-RubrikReport
    $rrpt | Write-Verbose
    $rtable = Get-RubrikReportTable -id $rrpt.id -SortBy $rrpt.table.columns[0] -limit $script:total
    Write-Verbose "Sorting by $rrpt.table.columns[0]"

    $header = $rtable.columns

    $header -join ',' | Out-File $filename

    foreach ($i in $rtable.dataGrid) {
        $i -join ',' | Out-File $filename -Append
    }

    $array = Import-Csv $filename
    $array 
    Remove-Item $filename
}

$Header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #6495ED;font-size: 12px;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;font-size: 10px;}
</style>
"@
$reportlist = Get-RubrikReport | Where-Object {$_.name -match "HTMLR"}
foreach ($r in $reportlist) {
    $reportname = $r.name
    $htmlfile = $reportname + ".html"
    $fullpath = $path + $htmlfile
    Render-RubrikReport -reportname $reportname -Verbose | ConvertTo-Html -Head $header -Title $reportname | Out-File -FilePath $fullpath
}