param (
    [parameter(mandatory)]
    [datetime] $start,
    [parameter(mandatory)]
    [datetime] $end,
    [parameter(mandatory)]
    [string] $clustername,
    [parameter(mandatory)]
    [string] $vmname
)

<#  
    .SYNOPSIS
    Generate CSV files for VMMS events from all nodes in the specified cluster

    .EXAMPLE
    Find-VMMSEvents.ps1 -start "3/11/2019 3:00 AM" -end "3/14/2019 5:00 PM" -cluster amer2-hvc
    This will return a report for each node name as a CSV with the VMMS events inside the specified date range. 

#>

$clusternodes = (get-clusternode -Cluster $clustername).name
$options = @{LogName ="Microsoft-Windows-Hyper-V-VMMS*"; StartTime = (get-date $start); EndTime = (get-date $end)}

if ($clusternodes) {
    foreach ($i in $clusternodes) {
        $events = Get-WinEvent -FilterHashTable $options -ComputerName $i
        $filename = $i + '.csv'
        if ($vmname) {$events = $events | where-object {$_.message -match $vmname}}
        $events | Export-Csv -NoTypeInformation -Path $filename
    }
} else {
    Write-Host "Cluster node names for $clustername could not be found, please check name and access."
}