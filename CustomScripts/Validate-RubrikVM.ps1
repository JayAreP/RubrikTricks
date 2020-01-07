param(
    [parameter()]
    [string] $vm,
    [parameter()]
    [string] $esxhost,
    [parameter()]
    [datetime] $date,
    [parameter()]
    [string] $snapshotID
)

if ($snapshotID) {
    Try {
        Write-Output "Gathering snapshot information..."
        $snapshot = Get-RubrikVMSnapshot -id $snapshotID
    } catch {
        Write-host No snapshot with id $snapshotID is available
        exit
    }
    $vm = $snapshot.vmName
}

if (!$esxhost) {
    $bareVM = Get-RubrikVM -id $snapshot.virtualMachine.id      
    $esxhost = $bareVM.currentHost.name
    Write-Output "Setting $esxhost as the destination vmware host..."
}


try {
    Write-Output "Gathering VMWare host details..."
    $vmhost = Get-RubrikVMwarehost -Name $esxhost -PrimaryClusterID local
} catch {
    Write-host No ESX host named $esxhost available
    exit
}

if (!$vmhost) {
    $vmhost = Get-RubrikVMwarehost -PrimaryClusterID local | get-random
}

# build the rubrik VM
try {
    Write-Output "Gathering Rubrik VM details..."
    $rvm = get-rubrikvm -Name $vm | Get-RubrikVM
} catch {
    Write-Host No VM named $vm could be found on the Rubrik
}
Write-Output $rvm
# Get the snapshots and pre/post the dates
if (!$snapshotID) {
    if (!$date) {$date = get-date}
    $allsnaps = $rvm | Get-RubrikSnapshot

    $predate = @()
    $postdate = @()

    foreach ($i in $allsnaps) {
        $idate = get-date $i.date
        if ($idate -le $date) {
            $predate += $i 
        } else {
            $postdate += $i
        }
    }

    $snap = ($predate | Sort-Object date -Descending)[0]
} else {
    $snap = $snapshot
}

write-output $snap 

# Live mount the VM

$mountName = $vm + "-Validation" + "-" + (get-random -Maximum 9999 -Minimum 1000)
Write-Output "Live Mounting $mountName"
$livemount = $snap | New-RubrikMount -MountName $mountName -HostID $vmhost.id -DisableNetwork:$true -PowerOn:$true
$lmstatus = $livemount

while ($lmstatus.status -ne "SUCCEEDED") {
    $lmstatus.status
    Write-Progress -Activity "Mounting VM" -PercentComplete $lmstatus.progress
    start-sleep -seconds 2
    $lmstatus = Get-RubrikRequest -id $lmstatus.id -Type 'vmware/vm' -Verbose
    $lmstatus
}

Start-Sleep -Seconds 10
# Wait for tools heartbeat (PowerCLI operation)

try {
    Write-Output "Gathering VMWare validation VM information..."
    $vm = get-vmguest -vm $mountName 
} catch {
    Write-Output "No VM named $mountName could be found in vcenter."
    exit
}
$waitdate = (get-date).addminutes(5)

$o = New-Object psobject
$o | Add-Member -MemberType NoteProperty -Name 'VM name' -Value $rvm.name
$o | Add-Member -MemberType NoteProperty -Name 'Target ESXi Host' -Value $vmhost.name
$o | Add-Member -MemberType NoteProperty -Name 'Snapshot ID' -Value $snap.id
$o | Add-Member -MemberType NoteProperty -Name 'Snapshot Date' -Value $snap.date.ToShortDateString()
$o | Add-Member -MemberType NoteProperty -Name 'Mounted VM Name' -Value $mountName

# $vm | format-list
while (!(Get-VMGuest -VM $mountName | Select-Object ToolsVersion).ToolsVersion) {
    $date = get-date
    if ($date -le $waitdate) {
        get-vmguest -vm $mountName | Format-List
        Write-Output $vm | Format-List
        Write-Output $vm.VM | Format-List
    } else {
        $o | Add-Member -MemberType NoteProperty -Name 'Validation' -Value "Failed"
        return "failed to validate VM after 5 minutes... giving up."
        Get-RubrikMount -VMID $rvm.id | Remove-RubrikMount
    }
}

$o | Add-Member -MemberType NoteProperty -Name 'Validation' -Value "Passed"

# Once validated, discard the VM mount
Write-Output "$mountName validated, cleaning up..."
Get-RubrikMount -VMID $rvm.id | Remove-RubrikMount

$filename = $mountName + '.csv'
$o | Export-Csv -notype -Path $filename

Write-Output "Writing report to $filename"
Return $o