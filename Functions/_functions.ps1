
function New-APIHeader {
    param(
        [parameter(mandatory)]
        [System.Management.Automation.PSCredential]$Credential
    )
    $username = $Credential.username
    $password = $Credential.GetNetworkCredential().password
    @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($username+":"+$password ))}
}

function new-apicall {
    param(
        [parameter(mandatory)]
        [string] $URI,
        [parameter(mandatory)]
        [string] $method,
        [parameter(mandatory)]
        [string] $headers
    )
    (Invoke-RestMethod -Method $method -uri $URI -Headers $header).data
}
function invoke-slaexcusion {
    param(
        [parameter()]
        [string]$sla,
        [parameter()]
        [string]$exclude
    )
    $rvms = Get-RubrikVM | where-object {$_.effectiveSlaDomainName -eq $sla -and $_.effectiveSlaSourceObjectName -notmatch $exclude}
    foreach ($i in $rvms) {Protect-RubrikVM -id $i.id -SLA $sla -confirm:0}
}

function quickmount {
    param(
        [parameter(mandatory)]
        [string] $vm
    )
    $rvmsnap = (get-rubrikvm $vm | Get-RubrikSnapshot)[-1]
    $mntname = $vm + "-" + (get-date $rvmsnap.date -Format s).Replace(':','-')
    New-RubrikMount -id $rvmsnap.id -MountName $mntname -DisableNetwork:1 -Confirm:0
}

function get-rubrikvmsnapshotstats {
    param(
        [parameter(mandatory)]
        [string] $vm
    )
    $total = 0
    $rvm = get-rubrikvm -name $vm | get-rubrikvm
    foreach ($i in $rvm.snapshots) {
        $endpointURI = 'snapshot/' + $i.id + '/storage/stats?snappable_id=' + $rvm.id
        $stats = Invoke-RubrikRESTCall -Endpoint $endpointURI -Method GET -api internal
        $total = $total + $stats.physicalBytes
        
    }
    $o = new-object psobject
    $o | add-member -type noteproperty -name "Total snapshot GB" -value ($total / 1gb)
    $o
}


function Get-RubrikArchiveJobConnect {

    <#
          .SYNOPSIS
          Retrieve the following information about job: ID of job, job status, error details, start time of job, end time of job, job type, ID of the node, job progress and location id.
  
          .EXAMPLE
          Get-RubrikArchiveJobConnect -JobID
          This will return all
    #>
      
      param(
          [parameter(mandatory)]
          [string] $JobID
      )
      $endpointURI = 'archive/location/job/connect/' + $jobid
      $jobstats = Invoke-RubrikRESTCall -Endpoint $endpointURI -Method GET -api internal
      $jobstats
}

function Get-RubrikArchiveLocation {
    <#
        .SYNOPSIS
        .EXAMPLE
    #>    
  param(
        [parameter()]
        [string] $status,
        [parameter()]
        [string] $name,
        [parameter()]
        [string] $sort_by,
        [parameter()]
        [string] $sort_order,
        [parameter()]
        [string] $location
    )
    $endpointURI = 'archive/location'
    $plist = $PSBoundParameters
    foreach ($i in $plist.keys) {
        Write-Host ---
        $par = $i
        $val = $plist[$i]
        $endpointURI = $endpointURI + '?' + $par + '=' + $val
    }
    # $endpointURI 
    $jobstats = Invoke-RubrikRESTCall -Endpoint $endpointURI -Method GET -api internal
    $jobstats.data
}

function Get-RubrikStatsSLADomain {
    param(
        [parameter(Mandatory)]
        [string]$sla
    )
    $rsla = get-rubriksla -name $sla
    $endpointURI = 'stats/sla_domain_storage/' + $rsla.id
    $jobstats = (Invoke-RubrikRESTCall -Endpoint $endpointURI -Method GET -api internal)
    (([math]::Round(($jobstats.value / 1gb),2))).ToString() + "GB"
}

function Find-RubrikVMFile {
    param(
        [Parameter(Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
        [String]$Id,
        [parameter(Mandatory)]
        [string]$searchstring
    )
    Write-Host -ForegroundColor green Searching for $searchstring in $Id...
    $endpointURI = 'vmware/vm/' + $Id + '/search?path=' + $SearchString
    $jobstats = (Invoke-RubrikRESTCall -Endpoint $endpointURI -Method GET)
    if ($jobstats.data) {
        $jobstats.data | Select-Object filename,path
    }
}

function Export-RubrikReportCriteria {
    param(
        [parameter(Mandatory)]
        [string]$name,
        [parameter(Mandatory)]
        [string]$outputfile
    )
    $rrpt = Get-RubrikReport -Name $name | Get-RubrikReport -verbose
    $rrpt | select-object reportTemplate,chart0,chart1,table | ConvertTo-Json | out-file $outputfile
    $rrpt | select-object reportTemplate,chart0,chart1,table | ConvertTo-Json 
}

function Import-RubrikReportCriteria {
    param(
        [parameter(Mandatory)]
        [string]$json,
        [parameter(Mandatory)]
        [string]$name
    )
    $jsondata = Get-Content $json
    $o = $jsondata | convertfrom-json
    $o | Add-Member -MemberType NoteProperty -name "name" -Value $name
    $endpointURIprefix = 'https://' + $Global:RubrikConnection.server + '/api/'
    $endpointAPI = $endpointURIprefix + 'internal' + '/'
    $endpointURI = $endpointAPI + 'report'
    $body = $o | ConvertTo-Json
    Invoke-RestMethod -Uri $endpointURI -Method POST -Body $body -headers $Global:rubrikConnection.header
    $body | write-verbose   
}

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

    $rsla = get-rubriksla -Name $sla
    [array]$allowedBackupWindows = @()

    $startTimeAttributes = new-object psobject
    $startTimeAttributes | Add-Member -type noteproperty  -Name 'minutes' -Value $minutes
    $startTimeAttributes | Add-Member -type noteproperty  -Name 'hour' -Value $hour
  
    $ao = @{durationInHours=$duration;startTimeAttributes=$startTimeAttributes}
    # if ($clear) {$ao = @()}
    $allowedBackupWindows += $ao

    $o = new-object psobject
    $o | Add-Member -Type NoteProperty -Name 'allowedBackupWindows' -Value $allowedBackupWindows
    $jsondata = $o | ConvertTo-Json -Depth 10
    $jsondata

    $endpointURI =  'https://' + $Global:RubrikConnection.server + '/api/v1/sla_domain/' + $rsla.id 
    Invoke-RestMethod -Uri $endpointURI -Method PATCH -Body $jsondata -headers $Global:rubrikConnection.header
}

function Set-RubrikSLAFirstWindow {
    param(
        [parameter(Mandatory)]
        [String] $sla,
        [parameter()]
        [int] $DayofWeek = 0,
        [parameter()]
        [int] $hour = 0,
        [parameter()]
        [int] $minutes = $null,
        [parameter()]
        [int] $duration = 0,
        [parameter()]
        [switch] $clear

    )

    $rsla = get-rubriksla -Name $sla
    [array]$firstFullAllowedBackupWindows = @()

    $startTimeAttributes = new-object psobject
    $startTimeAttributes | Add-Member -type noteproperty  -Name 'minutes' -Value $minutes
    $startTimeAttributes | Add-Member -type noteproperty  -Name 'hour' -Value $hour
    $startTimeAttributes | Add-Member -type noteproperty  -Name 'dayofWeek' -Value $dayofWeek
  
    $ao = @{durationInHours=$duration;startTimeAttributes=$startTimeAttributes}
    if ($clear) {$ao = @()}
    $firstFullAllowedBackupWindows += $ao

    $o = new-object psobject
    $o | Add-Member -Type NoteProperty -Name 'firstFullAllowedBackupWindows' -Value $firstFullAllowedBackupWindows
    $jsondata = $o | ConvertTo-Json -Depth 10
    $jsondata

    $endpointURI =  'https://' + $Global:RubrikConnection.server + '/api/v1/sla_domain/' + $rsla.id 
    Invoke-RestMethod -Uri $endpointURI -Method PATCH -Body $jsondata -headers $Global:rubrikConnection.header
}

function Add-RubrikSLAFirstWindow {
    # Experimental - does not work
    param(
        [parameter(Mandatory)]
        [String] $sla,
        [parameter()]
        [int] $DayofWeek,
        [parameter()]
        [int] $hour,
        [parameter()]
        [int] $minutes,
        [parameter()]
        [int] $duration,
        [parameter()]
        [switch] $clear

    )

    $rsla = get-rubriksla -Name $sla
    [array]$firstFullAllowedBackupWindows = $rsla.firstFullAllowedBackupWindows

    $startTimeAttributes = new-object psobject
    $startTimeAttributes | Add-Member -type noteproperty  -Name 'minutes' -Value $minutes
    $startTimeAttributes | Add-Member -type noteproperty  -Name 'hour' -Value $hour
    $startTimeAttributes | Add-Member -type noteproperty  -Name 'dayofWeek' -Value $dayofWeek
  
    $ao = @{durationInHours=$duration;startTimeAttributes=$startTimeAttributes}
    if ($clear) {$ao = @()}
    $firstFullAllowedBackupWindows += $ao

    $o = new-object psobject
    $o | Add-Member -Type NoteProperty -Name 'firstFullAllowedBackupWindows' -Value $firstFullAllowedBackupWindows
    $jsondata = $o | ConvertTo-Json -Depth 10
    $jsondata = $jsondata.replace('null','0')
    $jsondata.replace('null','0')

    $endpointURI =  'https://' + $Global:RubrikConnection.server + '/api/v1/sla_domain/' + $rsla.id 
    Invoke-RestMethod -Uri $endpointURI -Method PATCH -Body $jsondata -headers $Global:rubrikConnection.header
}


function Export-RubrikReportHTML {
    param(
        [parameter(Mandatory)]
        [string]$name,
        [parameter(Mandatory)]
        [string]$outputfile
    )
    $report = Get-RubrikReport -Name $name
    $endpointURI = 'report/' + $report.id + '/chart'
    $call = Invoke-RubrikRESTCall -Endpoint $endpointURI -Method get -api internal

    foreach ($i in $call) {

        foreach ($d in $i.dataColumns) {

        }


    }

}

function Search-RubrikFilesetFile {
    param(
        [Parameter(Mandatory)]
        [array]$filename,
        [Parameter(Mandatory)]
        [array]$filesetname,
        [Parameter()]
        [switch] $download
    )
    $endpointURI = 'fileset?name=' + $filesetname.replace(' ','%20')
    $filesets = (Invoke-RubrikRESTCall -Method get -Endpoint $endpointURI)
    $endpointURI | write-verbose
    $search = $filesets.data.id | foreach-object {
        Invoke-RubrikRESTCall -Method get -Endpoint ('fileset/' + $_ + '/search?path=' + $filename)}
    if ($download) {
        $filenames = $search.data.path | sort -Unique
        clear
        # setup menu for file select
        $menuarray = @()
        foreach ($i in $filenames) {
            $o = New-Object psobject
            $o | Add-Member -MemberType NoteProperty -Name 'File' -Value $i
            $menuarray += $o
        }
    
        $menu = @{}
        for (
            $i=1
            $i -le $menuarray.count
            $i++
        ) { Write-Host "$i. $($menuarray[$i-1].file)" 
            $menu.Add($i,($menuarray[$i-1].file))
        }
        [int]$mntselect = Read-Host 'Enter the file that you would like to recover'
        $fileselect = $menu.Item($mntselect)

        
        $searchlist = $search.data | where-object {$_.path -eq $fileselect}

        $fileselectmenu = $searchlist.fileVersions | sort lastModified -Unique
        clear
        $fmenuarray = @()
        foreach ($i in $fileselectmenu) {
            $o = New-Object psobject
            $o | Add-Member -MemberType NoteProperty -Name 'lastModified' -Value $i.lastModified
            $fmenuarray += $o
        }
    
        $fmenu = @{}
        for (
            $i=1
            $i -le $fmenuarray.count
            $i++
        ) { Write-Host "$i. $($fmenuarray[$i-1].lastModified)" 
            $fmenu.Add($i,($fmenuarray[$i-1].lastModified))
        }
        [int]$mntselect = Read-Host 'Enter the file date that you would like to recover'
        $filedateselect = $fmenu.Item($mntselect)

        $restorefinal = $fileselectmenu | where-object {$_.lastModified -eq $filedateselect}

        $o = New-Object PSobject
        $o | Add-Member -Name 'sourceDir' -Value $fileselect -type noteproperty
        $endpointURI = 'fileset/snapshot/' + $restorefinal.snapshotid + '/download_file'
        $filedownload = Invoke-RubrikRESTCall -Endpoint $endpointURI -Method POST -Body $o
        $endpointURI = 'fileset/request/' + $filedownload.id
        while ((Invoke-RubrikRESTCall -Method get -Endpoint $endpointURI).status -ne "SUCCEEDED") {
            Write-Progress -Activity "Preparing File"
            start-sleep -seconds 1
        }
        $endpointURI = 'fileset/request/' + $filedownload.id
        $request = Invoke-RubrikRESTCall -Method get -Endpoint $endpointURI
        $request.links.href -like "download*"
        $downloadURI = 'https://' + $Global:RubrikConnections[-1].server + '/' + ($request.links.href -like "download*")
        $outfile = (Get-Location).path + '\' + $filename
        $outfile
        Invoke-WebRequest -Uri $downloadURI -OutFile $outfile
        get-item $filename
    } else {
        $search.data.path | sort -Unique
    }
}    

function Refresh-RubrikDatabaseServer {
    param (
        [Parameter(Mandatory)]
        [array]$DatabaseServer
    )
    $targetdbserverid = (Get-RubrikHost -name $DatabaseServer | where-object {$_.hostname -eq $DatabaseServer}).id
    $endpointURI = 'host/' + $targetdbserverid + '/refresh'
    Invoke-RubrikRESTCall -Endpoint $endpointURI -Method POST
}

Function Set-ServiceAccount {
    param(
        [Parameter()]
        [string] $ComputerName,
        [Parameter(Mandatory)]
        [string] $Service,
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential] $Credential
    )
    if (!$ComputerName) {$ComputerName = $env:computername}
    $username = $Credential.username
    $password = $credential.GetNetworkCredential().password
	$ServiceName = Get-WmiObject -ComputerName $ComputerName -Query "SELECT * FROM Win32_Service WHERE Name = '$Service'"
	$ServiceName.Change($null,$null,$null,$null,$null,$null,"$username",$password) 
	Get-Service -ComputerName $computername -Name $service | Restart-Service
}

function parmtest {
    param(
        [parameter(mandatory)]
        [string] $database,
        [parameter()]
        [string] $instance = "MSSQLSERVER",
        [parameter()]
        [string] $targetdbname = $database
    )
    #if (!$targetdbname) {$targetdbname = $database}
    $database
    $instance
    $targetdbname
}

function Get-RubrikReportTable {
    param (
        [parameter(mandatory)]
        [string] $id,
        [parameter(mandatory)]
        [string] $number = 25
    )

    $o = New-Object PSOBject
    $o | Add-Member -MemberType NoteProperty -Name 'sortBy' -Value 'ObjectName'
    $o | Add-Member -MemberType NoteProperty -Name 'sortOrder' -Value 'asc'
    $o | Add-Member -MemberType NoteProperty -Name 'requestFilters' -Value $null
    $o | Add-Member -MemberType NoteProperty -Name 'limit' -Value $number
    $jsonbody = $o | ConvertTo-Json

    $URIendpoint = 'report/' + $id + '/table'
    Invoke-RubrikRESTCall -api internal -Endpoint $URIendpoint -Method POST -Body $jsonbody
}


function Tally-ByField {
    param (
        [parameter(mandatory)]
        [array] $var,
        [parameter(mandatory)]
        [string] $field
    )
    $fieldlist = ($var | Select-Object $field -Unique).$field
    [array]$outarray = @{}
    foreach ($i in $fieldlist) {
        $i
        $num = ($var | ? {$_.$field -eq $i}).count
        $num
        $o = New-Object psobject
        $o | Add-Member -MemberType NoteProperty -Name $i -Value $num
        $o
        $outarray += $o
    }
}

Function Compare-ObjectProperties {
    Param(
        [PSObject]$ReferenceObject,
        [PSObject]$DifferenceObject 
    )
    $objprops = $ReferenceObject | Get-Member -MemberType Property,NoteProperty | % Name
    $objprops += $DifferenceObject | Get-Member -MemberType Property,NoteProperty | % Name
    $objprops = $objprops | Sort | Select -Unique
    $diffs = @()
    foreach ($objprop in $objprops) {
        $diff = Compare-Object $ReferenceObject $DifferenceObject -Property $objprop
        if ($diff) {            
            $diffprops = @{
                PropertyName=$objprop
                RefValue=($diff | ? {$_.SideIndicator -eq '<='} | % $($objprop))
                DiffValue=($diff | ? {$_.SideIndicator -eq '=>'} | % $($objprop))
            }
            $diffs += New-Object PSObject -Property $diffprops
        }        
    }
    if ($diffs) {return ($diffs | Select PropertyName,RefValue,DiffValue)}     
}

function addVMToConfig {
    param (
        [parameter()]
        [array] $jsonfile,
        [parameter(mandatory)]
        [string] $name,
        [parameter(mandatory)]
        [string] $mountName,
        [parameter(mandatory)]
        [string] $guestcred,
        [parameter(mandatory)]
        [ipaddress] $testIP,
        [parameter(mandatory)]
        [string] $testNetwork,
        [parameter(mandatory)]
        [ipaddress] $testGateway
    )
    $configArray = @()
    if ($jsonfile) {
        $json = get-content $jsonfile | ConvertFrom-Json
        foreach ($j in $json) {
            $configArray += $j
        } 
    } 

    $tasks = @("Ping","Netlogon")

    $o = New-Object psobject
    $o | Add-Member -MemberType NoteProperty "name" -Value $name
    $o | Add-Member -MemberType NoteProperty "mountName" -Value $mountname
    $o | Add-Member -MemberType NoteProperty "guestcred" -Value $guestcred
    $o | Add-Member -MemberType NoteProperty "testIP" -Value $testIP.IPAddressToString
    $o | Add-Member -MemberType NoteProperty "testNetwork" -Value $testNetwork
    $o | Add-Member -MemberType NoteProperty "testGateway" -Value $testGateway.IPAddressToString
    $o | Add-Member -MemberType NoteProperty "tasks" -Value $tasks

    $configArray += $o
    $configArray | ConvertTo-Json
}

function Get-RUbrikReportChartTable {
    param(
        [string]$id,
        [string]$chart
    )
    $endpointURI = 'report/' + $id + '/chart'
}
function Invoke-RubrikRESTCall-json {
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