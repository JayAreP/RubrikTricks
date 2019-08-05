param(
    [parameter(mandatory)]
    [string] $ADGroupName,
    [parameter(mandatory)]
    [string] $vCenterRoleName,
    [parameter(mandatory)]
    [string]$ADDomainName
    )

 <#
    .SYNOPSIS
    Powershell scripts to create and harden a service account for use with a specific vCenter datacenter object and tie that access to a specificvCenter role. 
    Use this script in cunjunction with the operational script RubrikRBACWorkflow-stage2.ps1 to complete per-datacenter access and account creation. 
     
    .EXAMPLE
    ./RubrikRBACWorkflow-stage1.ps1 -ADGroupName RubrikAccessGroup-DLG -vCenterRoleName RubrikVcenter -ADDomainName Americas

    This will:
        - Create an AD Group named RubrikAccessGroup-DLG.
        - Create a vCenter role named RubrikVcenter with all appropriate vCenter permissions for the Rubrik Appliance. 
        - Assign the AD Group RubrikAccessGroup-DLG to the RubrikVcenter role at the vCenter root. 
        - Assign the AD Group RubrikAccessGroup-DLG to the NoAccess role for all datacenters.
#>

function createrbkrole {
    param(
        [parameter(mandatory)]
        [string] $roleName
    )
        
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
    if (!(Get-VIRole -Name $roleName)) {
        New-VIRole -Name $roleName -Privilege $access}
}

# Create vcenter role
createrbkrole -roleName $vCenterRoleName

# Create AD Group
New-ADGroup $ADGroupname -GroupScope DomainLocal

# Add allow RBAC to root
$role = Get-VIRole -Name $vCenterRoleName
$ADDomain = Get-ADDomain $ADDomainName
$ADGroupPrincipleName = $ADDomain.NetBIOSName + '\' + $ADGroupName
New-VIPermission -Principal $ADGroupPrincipleName -Role $role

# Add deny RBAC to each vcenter datacenter
$vcdcs = get-datacenter
foreach ($i in $vcdcs) {
    $role = Get-VIRole NoAccess
    Write-Host -ForegroundColor Green Adding $ADGroupName to NoAccess for $i.name
    New-VIPermission -Principal $ADGroupPrincipleName -Role $role -Entity $i
}