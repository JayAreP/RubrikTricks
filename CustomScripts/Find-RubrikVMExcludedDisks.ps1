param(
    [string] $sla
)

$rvms = Get-RubrikVM -SLA $sla 

function Get-RubrikVMDisks {
    (Invoke-RubrikRESTCall -Endpoint 'vmware/vm/virtual_disk' -Method get -api internal).data
}
function Get-RubrikVMDiskInfo {
    param (
        [string] $id
    )
    $endpointURI = 'vmware/vm/virtual_disk/' + $id
    Invoke-RubrikRESTCall -Endpoint $endpointURI -Method get 
}

function Get-RubrikVMDiskStats {
    param (
        [string] $vmname,
        [string] $diskid
    )
    $o = New-Object psobject
    $o | Add-Member -MemberType NoteProperty -Name VMName -Value $vmname

    $dsk = Get-RubrikVMDiskInfo -id $diskid 
    
    $o | Add-Member -MemberType NoteProperty -Name ("FileName") -Value $dsk.fileName.Split('/')[-1]
    $o | Add-Member -MemberType NoteProperty -Name ("size") -Value $dsk.size
    $o | Add-Member -MemberType NoteProperty -Name ("Excluded") -Value $dsk.excludeFromSnapshots
    $o
}

$disks = Get-RubrikVMDisks

$masterlist = @()

foreach ($i in $rvms) {
    $rvmdisks = $disks | Where-Object {$_.vmname -eq $i.name}
    foreach ($d in $rvmdisks) {
        Get-RubrikVMDiskStats -vmname $i.name -diskid $d.id
    }
}

