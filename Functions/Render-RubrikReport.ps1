function Render-RubrikReport {
    param (
        [parameter(mandatory)]
        [string] $reportname
    )
    $rnd = get-random
    $filename = $rnd.ToString() + '.csv'
    $filename | Write-Verbose
    function Get-RubrikReportCSV {
        param (
            [parameter(mandatory)]
            [string] $id,
            [parameter(mandatory)]
            [string] $filename
        )

        $URIendpoint = 'report/' + $id + '/refresh'
        $request = Invoke-RubrikRESTCall -api internal -Endpoint $URIendpoint -Method POST 
        $URIendpointreq = 'report/request/' + $request.id 
        $reqrequest = Invoke-RubrikRESTCall -api internal -Endpoint $URIendpointreq -Method GET
        while ($reqrequest.status -ne "SUCCEEDED") {
            Write-Progress -Activity "Preparing Report"
            Start-Sleep -Seconds 1
            $URIendpointreq = 'report/request/' + $request.id 
            $reqrequest = Invoke-RubrikRESTCall -api internal -Endpoint $URIendpointreq -Method GET
        }
        $URIendpointCSV = 'report/' + $id + '/csv_link'
        $csvrequest = Invoke-RubrikRESTCall -api internal -Endpoint $URIendpointCSV -Method GET
        $csvrequest | Write-Verbose
        Invoke-WebRequest -Uri $csvrequest -OutFile $filename
        Get-Item $filename
    }
    $reportname | Write-Verbose 
    $rrpt = get-rubrikreport -name $reportname | Get-RubrikReport
    $rrpt | Write-Verbose
    $rtable = Get-RubrikReportCSV -id $rrpt.id -filename $filename
    
    $array = Import-Csv $filename
    $array 
    Remove-Item $filename
}