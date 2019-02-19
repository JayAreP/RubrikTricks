param(
    [parameter()]
    [String] $sla,
    [parameter()]
    [String] $archive,
    [parameter()]
    [String] $rubrik = $global:RubrikConnection.server,
    [Parameter()]
    [switch] $UseScriptCredential,
    [parameter()]
    [String] $csv
)

if (!$sla -and !$archive) {
    Write-Host -ForegroundColor red "Please specify either -sla or -archive, but not both."
    Exit
}

if ($sla -and $archive) {
    Write-Host -ForegroundColor red "Please specify only either -sla or -archive, but not both."
    Exit
}

if ($UseScriptCredential -and !$rubrik) {
    Write-Host -ForegroundColor red "Please specify a -rubrik argument when using -UseScriptCredential"
    Exit
}

<#  
    .SYNOPSIS
    Connect to a rubrik endpoint and generate a storage report. 


    .EXAMPLE
    Export-SizeReport.ps1 -sla 'Compliance 3 year SLA' -csv 'report.csv'
    This will return a report for objects protected by the SLA "Compliance 3 year SLA" and name the report "report.csv"

    .EXAMPLE
    Export-SizeReport.ps1 -archive 'S3archive' -UseScriptCredential -rubrik RubrikCLS01.domain.local
    This will return a report for all SLA-bound objects configured to use with the Archive target named 'S3archive'. 
    It will also use the script configured username and password and connect to the specific -rubrik CDM cluster named "Compliance 3 year SLA".


#>

# Check if the UseScriptCredentials argument was supplied. 

if ($UseScriptCredential) {
    function runrubriklogin {
        param(
            [parameter(mandatory)]
            [String] $rbk
        )
            $rubuser = 'User'
            $password = 'Password' | ConvertTo-SecureString -force -AsPlainText
            $creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $rubuser, $password
            Connect-Rubrik -Server $rbk -Credential $creds 
        }
    Write-Host -ForegroundColor yellow Logging into $rubrik as Script-defined user.
    runrubriklogin -rbk $rubrik
}

# Store the argued SLA.

if ($sla) {
        $RSLA = Get-RubrikSLA -name $sla -PrimaryClusterID local
        if ($RSLA) {Write-Host -ForegroundColor green Using $RSLA.name}
        else {Write-Host -ForegroundColor Yellow "No SLA named $sla was discovered, please try again..."
        exit
    }
}

# Store the cluster archive targets.

$rarchives = (Invoke-RubrikRESTCall -Endpoint 'archive/location' -Method GET -api internal).data

if ($archive) {
    $archiveID = $rarchives | Where-Object {$_.name -eq $archive}
    if ($archiveID) {
        $RSLA = Get-RubrikSLA -PrimaryClusterID local | where-object {$_.archivalSpecs.locationId -eq $archiveID.id}
        Write-Host -ForegroundColor green "The following SLAs are using the archive $archive"
        $RSLA.name
    } else {
        write-host -ForegroundColor Red "-- No archive named $archive is configured, please supply one of the following:"
        $rarchives.name
        exit
    }   
}

# Gather all Rubrik objects within the argued SLA.
$ROBJs = @()
foreach ($r in $RSLA) {
    Write-Host -ForegroundColor green Gathering $r.name SLA VM information
    $ROBJs += Get-RubrikVM -SLA $r.name | Get-RubrikVM
    $ROBJs += Get-RubrikHyperVVM -SLA $r.name | Get-RubrikHyperVVM
    Write-Host -ForegroundColor green Gathering $r.name SLA Database information
    $ROBJs += Get-RubrikDatabase -SLA $r.name | Get-RubrikDatabase
    Write-Host -ForegroundColor green Gathering $r.name SLA Fileset information
    $ROBJs += Get-RubrikFileset -SLA $r.name | Get-RubrikFileset
}

# -- Build the report object -- This will take a while. 

$reportarray = @()
$absoluteSnapLB = 0
$absoluteSnapIB = 0
$absoluteSnapPB = 0

foreach ($i in $ROBJs) {
    $iname = $i.name
    Write-Host -ForegroundColor green "-- Grabbing snapshot info for $iname --"
    $otype = $i.id.Split(':')[0]
    if ($i.snapshots) {
        $snaps = $i.snapshots
    } else {
        $snaps = $i | Get-RubrikSnapshot 
    }

    $snaptotals = @()
    if ($snaps) {
        foreach ($sn in $snaps) {
           if ($sn.cloudstate -ne 2) {
                if ($sn.databaseName) {
                    $snapidURI = "mssql/db/"+ $i.id +"/snappable_id"
                    $snapid = Invoke-RubrikRESTCall -Endpoint $snapidURI -Method GET -api internal
                    $endpointURI = 'snapshot/' + $sn.id + '/storage/stats?snappable_id=' + $snapid.snappableId
                } else {
                    $endpointURI = 'snapshot/' + $sn.id + '/storage/stats?snappable_id=' + $i.id
                }
                try {
                    $snapstats = Invoke-RubrikRESTCall -Endpoint $endpointURI -Method GET -api internal -ErrorAction silentlycontinue
                    write-host -ForegroundColor green Adding snapshot $iname `/ $sn.id on $rubrik
                    $snaptotals += $snapstats
                }
                catch {
                    write-host -ForegroundColor yellow No local snapshot $iname `/ $sn.id on $rubrik
                }
                
           }
        }
        $archivename = ($rarchives | where-object {$_.id -eq ($snaps.archivalLocationIds | sort -Unique)}).name -join ","
        $snapLB = 0
        $snapIB = 0
        $snapPB = 0

        foreach ($sb in $snaptotals) {
            $snapLB = $snapLB + $sb.logicalBytes
            $snapIB = $snapIB + $sb.ingestedBytes
            $snapPB = $snapPB + $sb.physicalBytes
        }
        $cloudonly = ($snaps | Where-Object {$_.cloudstate -eq 2}).count
        $localonly = ($snaps | Where-Object {$_.cloudstate -ne 2}).count
    }
    $ro = new-object psobject
    $ro | Add-Member -Name 'Name' -Type NoteProperty -Value $i.name
    $ro | Add-Member -Name 'Type' -Type NoteProperty -Value $otype
    $ro | Add-Member -Name 'Local Snapshots' -type NoteProperty -Value $localonly
    $ro | Add-Member -Name 'Cloud-Only Snapshots' -type NoteProperty -Value $cloudonly 
#    $ro | Add-Member -Name 'Archive' -type NoteProperty -Value $archivename
    $ro | Add-Member -Name 'SLA' -type NoteProperty -Value $i.effectiveSlaDomainName
    $ro | add-member -name 'logicalBytes (GB)' -type noteproperty -value ([math]::Round(($snapLB / 1gb),2))
    $ro | add-member -name 'ingestedBytes (GB)' -type noteproperty -value ([math]::Round(($snapIB / 1gb),2))
    $ro | add-member -name 'physicalBytes (GB)' -type noteproperty -value ([math]::Round(($snapPB / 1gb),2))

    $absoluteSnapLB = $absoluteSnapLB + $snapLB
    $absoluteSnapIB = $absoluteSnapIB + $snapIB 
    $absoluteSnapPB = $absoluteSnapPB + $snapPB 
    $reportarray += $ro

}

# Append grand totals at the end of the CSV report

$ro = new-object psobject
$ro | Add-Member -Name 'Name' -Type NoteProperty -Value '-- Total --'
$ro | add-member -name 'logicalBytes (GB)' -type noteproperty -value ([math]::Round(($absoluteSnapLB / 1gb),2))
$ro | add-member -name 'ingestedBytes (GB)' -type noteproperty -value ([math]::Round(($absoluteSnapIB / 1gb),2))
$ro | add-member -name 'physicalBytes (GB)' -type noteproperty -value ([math]::Round(($absoluteSnapPB  / 1gb),2))

$reportarray += $ro

# Generate report name and export the CSV

if (!$csv) {
    $date = (get-date).ToString("MM-dd-yyyy-hh-mm-ss")
    $filename = $sla + $archive + "-" + $date + ".csv"
} else {
    $filename = $csv
}
$filename = $filename.replace(':',$null)
$reportarray | export-csv -NoTypeInformation $filename
$reportarray | Format-Table -AutoSize

write-host -ForegroundColor yellow Exporting report to $filename
