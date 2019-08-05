param (
    [parameter(mandatory)]
    [string]$vcDatacenter,
    [parameter()]
    [string]$password = 'Rubrik123!@#',
    [parameter()]
    [string]$namePrefix = 'rbksvc-',
    [parameter(mandatory)]
    [string]$rubrikRoleName,
    [parameter(mandatory)]
    [string]$ADDomainName,
    [parameter(mandatory)]
    [string]$ADGroupName
    )
<#
    .SYNOPSIS
    Powershell scripts to create and harden a service account for use with a specific vCenter datacenter object and tie that access to a specificvCenter role. 
    Use this script after, and in cunjunction with the one-time use script RubrikRBACWorkflow-stage1.ps1 to populate an appropriate Rubrik access role and AD group. 
     
    .EXAMPLE
    ./RubrikRBACWorkflow-stage2.ps1 -vcDatacenter Labs -rubrikRoleName RubrikVcenter -ADDomainName Americas -ADGroupName RubrikAccessGroup-DLG 

    This will:
        - Create an AD User named rbksvc-Labs with a default password of 'Rubrik123!@#' (specify another password with the -password paramter) 
        - Add the user to an AD group named RubrikAccessGroup-DLG
        - Assign this user the role of RubrikVcenter to the Labs datacenter. 
        - Check to see if the RubrikAccessGroup-DLG has NoAccess already assigned to the datacenter Labs, and if not, assign NoAccess to the datacenter Labs.
#>

# create datacenter object 
$vcdc = Get-Datacenter -Name $datacenter

# create service account
$ADDomain = Get-ADDomain $ADDomainName
$namestring = $namePrefix + $vcdc.name
if (!(Get-ADUser -Filter 'name -eq $namestring')) {
    $suffix = $ADDomain.forest
    $upn = $namestring + '@' + $suffix
    $pw = $password | ConvertTo-SecureString -Force -AsPlainText
    Write-Host -ForegroundColor Green Creating AD User $namestring
    New-ADUser -AccountPassword $pw -Name $namestring -Enabled $true -UserPrincipalName $upn
} else {
    write-host -ForegroundColor yellow User $namestring already exists.
}
    
# add account to adgroup
Write-Host -ForegroundColor Green Adding AD User $namestring to group $ADGroupName
Get-ADGroup $ADGroupName | Add-ADGroupMember -Members $namestring


# assign user to rubrik role on datacenter
$aduser = Get-ADUser $namestring -Properties *
$role = Get-VIRole -Name $rubrikRoleName
$principleName = $ADDomain.NetBIOSName + '\' + $aduser.Name
Write-Host -ForegroundColor Green Adding $principleName to NoAccess for $vcdc.name
New-VIPermission -Principal $principleName -Role $role -Entity $vcdc

# Check to see if group role deny permissions already exist, add if needed. 
$ADGroupPrincipleName = $ADDomain.NetBIOSName + '\' + $ADGroupName

if (!(Get-VIPermission -Entity $vcdc -Principal $ADGroupPrincipleName)) {
    Write-Host -ForegroundColor Green Adding $ADGroupName to NoAccess for $vcdc.name
    $role = Get-VIRole NoAccess
    New-VIPermission -Principal $ADGroupPrincipleName -Role $role -Entity $vcdc
} else {
    Write-Host -ForegroundColor Yellow $ADGroupPrincipleName already has NoAccess role for $vcdc.name
}