param (
    [parameter(mandatory)]
    [string] $Datacenter,
    [parameter(mandatory)]
    [string] $namePrefix,
    [parameter(mandatory)]
    [string] $vCenterRoleName,
    [parameter(mandatory)]
    [string] $ADGroupName
)
<#
    .SYNOPSIS
    Powershell scripts to create and harden a service account for use with a specific vCenter datacenter object and tie that access to a specific vCenter role. 
    Use this script after, and in cunjunction with the one-time use script RubrikRBACWorkflow-stage1.ps1 to populate an appropriate Rubrik access role and AD group. 
     
    .EXAMPLE
    ./RubrikRBACWorkflow-stage2.ps1 -Datacenter Labs -vCenterRoleName RubrikVcenter -ADGroupName RubrikAccessGroup-DLG -namePrefix rbksvc

    This will:
        - Assign this user the role of RubrikVcenter to the Labs datacenter. 
        - Check to see if the RubrikAccessGroup-DLG has NoAccess already assigned to the datacenter Labs, and if not, assign NoAccess to the datacenter Labs.
#>

# create datacenter object 
$vcdc = Get-Datacenter -Name $datacenter

# assign user to rubrik role on datacenter
$filter = ($namePrefix + '*')
$aduser = Get-ADUser -filter {name -like $filter} -properties * | Where-Object {$_.name -match $Datacenter} 
$role = Get-VIRole -Name $vCenterRoleName
$principleName = $ADDomain.NetBIOSName + '\' + $aduser.Name
Write-Host -ForegroundColor Green Adding $principleName to NoAccess for $vcdc.name
New-VIPermission -Principal $principleName -Role $role -Entity $vcdc

# Check to see if group role deny permissions already exist, add if needed. 
$ADDomain = Get-ADDomain $aduser.CanonicalName.split('/')[0]
$ADGroupPrincipleName = $ADDomain.NetBIOSName + '\' + $ADGroupName

if (!(Get-VIPermission -Entity $vcdc -Principal $ADGroupPrincipleName)) {
    Write-Host -ForegroundColor Green Adding $ADGroupName to NoAccess for $vcdc.name
    $role = Get-VIRole NoAccess
    New-VIPermission -Principal $ADGroupPrincipleName -Role $role -Entity $vcdc
} else {
    Write-Host -ForegroundColor Yellow $ADGroupPrincipleName already has NoAccess role for $vcdc.name
}