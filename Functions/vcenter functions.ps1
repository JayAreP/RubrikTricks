function rbkvcuser {
    param(
        [string] $user,
        [string] $dc
    )
    
    $vcdc = get-datacenter -Name $dc

    $principle  = $user
    $role = Get-VIRole -Name RubrikVcenter
    New-VIPermission -Principal $principle -Role $role -Entity $vcdc
}

function Add-RubrikVcenter {
    param(
        [parameter(mandatory)]
        [System.Management.Automation.PSCredential] $credential,
        [parameter()]
        [switch] $updateOnly
    )
    $vcserver = (Get-VIAccount)[0].server.name
    $o = New-Object psobject
    $o | Add-Member -MemberType NoteProperty -Name 'hostname' -Value $vcserver
    $o | Add-Member -MemberType NoteProperty -Name 'username' -Value $credential.username
    $o | Add-Member -MemberType NoteProperty -Name 'password' -Value $credential.GetNetworkCredential().password
    $o | Add-Member -MemberType NoteProperty -Name 'conflictResolutionAuthz' -Value "AllowAutoConflictResolution"

    if ($updateOnly) {
        $currentvc = (Invoke-RubrikRESTCall -Endpoint 'vmware/vcenter' -Method GET).data | where-object {$_.hostname -eq $vcserver}
        $endpoint = 'vmware/vcenter/' + $currentvc.id
        Invoke-RubrikRESTCall -Endpoint $endpoint -Method PUT -Body $o
        sleep 3
        $endpoint = 'vmware/vcenter/' + $currentvc.id + '/refresh'
        $jobrun = Invoke-RubrikRESTCall -Endpoint $endpoint -Method POST
        while ($jobrun.status -eq "RUNNING" -or $jobrun.status -eq "QUEUED") {
            Write-Progress -Activity "Refreshing vCenter..." -PercentComplete $jobrun.progress
            start-sleep -seconds 1
            $endpoint = 'vmware/vcenter/request/' + $jobrun.id
            $jobrun = Invoke-RubrikRESTCall -Endpoint $endpoint -Method get
        }
    } else {
        $endpoint = 'vmware/vcenter'
        Invoke-RubrikRESTCall -Endpoint $endpoint -Method POST -Body $o
    }
}

function createrbkrole {
    $Rubrik_Privileges = @(
        'Datastore.AllocateSpace'
        'Datastore.Browse'
        'Datastore.Config'
        'Datastore.Delete'
        'Datastore.FileManagement'
        'Datastore.Move'
        'Global.DisableMethods'
        'Global.EnableMethods'
        'Global.Licenses'
        'Host.Config.Storage'
        'Network.Assign'
        'Resource.AssignVMToPool'
        'Sessions.TerminateSession'
        'Sessions.ValidateSession'
        'System.Anonymous'
        'System.Read'
        'System.View'
        'VirtualMachine.Config.AddExistingDisk'
        'VirtualMachine.Config.AddNewDisk'
        'VirtualMachine.Config.AdvancedConfig'
        'VirtualMachine.Config.ChangeTracking'
        'VirtualMachine.Config.DiskLease'
        'VirtualMachine.Config.Rename'
        'VirtualMachine.Config.Resource'
        'VirtualMachine.Config.Settings'
        'VirtualMachine.Config.SwapPlacement'
        'VirtualMachine.GuestOperations.Execute'
        'VirtualMachine.GuestOperations.Modify'
        'VirtualMachine.GuestOperations.Query'
        'VirtualMachine.Interact.AnswerQuestion'
        'VirtualMachine.Interact.Backup'
        'VirtualMachine.Interact.DeviceConnection'
        'VirtualMachine.Interact.GuestControl'
        'VirtualMachine.Interact.PowerOff'
        'VirtualMachine.Interact.PowerOn'
        'VirtualMachine.Interact.Reset'
        'VirtualMachine.Interact.Suspend'
        'VirtualMachine.Interact.ToolsInstall'
        'VirtualMachine.Inventory.Create'
        'VirtualMachine.Inventory.Delete'
        'VirtualMachine.Inventory.Move'
        'VirtualMachine.Inventory.Register'
        'VirtualMachine.Inventory.Unregister'
        'VirtualMachine.Provisioning.DiskRandomAccess'
        'VirtualMachine.Provisioning.DiskRandomRead'
        'VirtualMachine.Provisioning.GetVmFiles'
        'VirtualMachine.Provisioning.PutVmFiles'
        'VirtualMachine.State.CreateSnapshot'
        'VirtualMachine.State.RemoveSnapshot'
        'VirtualMachine.State.RenameSnapshot'
        'VirtualMachine.State.RevertToSnapshot'
    )
    $access = Get-VIPrivilege -id $Rubrik_Privileges
    if (!(Get-VIRole -Name 'RubrikVcenter')) {
        New-VIRole -Name RubrikVcenter -Privilege $access}
}