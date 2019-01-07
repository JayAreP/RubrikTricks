# Quick Build menu function. 
function Build-MenuFromArray {
    param(
        [Parameter(Mandatory)]
        [array]$array,
        [Parameter(Mandatory)]
        [string]$property,
        [Parameter()]
        [string]$message = "Select item"
    )
    Write-Host '------'
    $menuarray = @()
        foreach ($i in $array) {
            $o = New-Object psobject
            $o | Add-Member -MemberType NoteProperty -Name $property -Value $i.$property
            $menuarray += $o
        }
    $menu = @{}
    for (
        $i=1
        $i -le $menuarray.count
        $i++
    ) { Write-Host "$i. $($menuarray[$i-1].$property)" 
        $menu.Add($i,($menuarray[$i-1].$property))
    }
    Write-Host '------'
    [int]$mntselect = Read-Host $message
    $menu.Item($mntselect)
    Write-Host `n`n
}

# Test to see if we're logged in:
if (Get-AzureRmSubscription -ErrorAction SilentlyContinue) {
    Write-Host Azure connected.
    } else {
    Write-Host Please first connet to Azure via `(Connect-AzureRMAccount`)
    exit
}

# Use menus to select ResourceGroup, Network, and Subnet. 

$rgarray = Get-AzureRmResourceGroup
$rgselect = Build-MenuFromArray -array $rgarray -property ResourceGroupName -message "Select Resource Group"

$vnarray = Get-AzureRmVirtualNetwork -ResourceGroupName $rgselect -WarningAction silentlyContinue
$vnselect = Build-MenuFromArray -array $vnarray -property Name -message "Select Virtual Network"

$snarray =  Get-AzureRmVirtualNetwork -name $vnselect -ResourceGroupName $rgselect -WarningAction silentlyContinue| Get-AzureRmVirtualNetworkSubnetConfig -WarningAction silentlyContinue
$snselect = Build-MenuFromArray -array $snarray -property Name -message "Select Subnet"

# Select the number of interfaces and a name prefix to be used. 

[int]$niccount = Read-Host `n'Enter number of network interfaces [4]' 
if (!$niccount) {[int]$niccount = 4}
[string]$nicprefix = Read-Host `n'Enter network interface name prefix' 
while (!$nicprefix) {
    Read-Host `n'Enter network interface name prefix [RubrikCC]' 
}

$rvnet = Get-AzureRmVirtualNetwork -Name $vnselect -ResourceGroupName $rgselect -WarningAction SilentlyContinue
$rsubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $snselect -VirtualNetwork $rvnet -WarningAction SilentlyContinue

for (
    $i=1
    $i -le $niccount
    $i++
) { 
    $nicname = $nicprefix + '-' + $i
    if (Get-AzureRmNetworkInterface -Name $nicname -ResourceGroupName $rgselect -ErrorAction SilentlyContinue) {
        Write-Host -ForegroundColor Yellow Network interface $nicname already exists in $vnselect`, using existing.
    } else {
        New-AzureRmNetworkInterface -Name $nicname -ResourceGroupName $rgselect -SubnetId $rsubnet.Id -Location $rvnet.location
    }
}

$storageaccounts = Get-AzureRMStorageAccount -ResourceGroupName $rgselect | Where-Object {$_.Location -eq $rvnet.location -and $_.Sku.Name -match "LRS"}

Write-Host -ForegroundColor green `n`n'The following Storage acounts qualify for this deployment:'
$storageaccounts | select StorageAccountName,Location
$sacreate = Read-Host `n'Would you like to create a new Storage Account? [y,N]' 
$sacreate = $sacreate.tolower()
while("y","n" -notcontains $sacreate)
{
    if (!$sacreate) {$sacreate = 'y'}
    else {
        $sacreate = Read-Host `n'Would you like to create a new Storage Account? [y,N]' 
    }
}
if ($sacreate -eq "y") {
    $saname = Read-Host `n'Please type in the name for the new Storage Account'
    try {
        $saname = $saname.tolower()
        Write-Host -ForegroundColor yellow  New-AzureRmStorageAccount -ResourceGroupName $rgselect -Name $saname -Location $rvnet.location -SkuName Standard_LRS -Kind Storage 
        New-AzureRmStorageAccount -ResourceGroupName $rgselect -Name $saname -Location $rvnet.location -SkuName Standard_LRS -Kind Storage 
    } catch {
        Write-Host "Cannot create storage account" 
        Write-Host "Use this syntax to manually create:" `n
        Write-Host -ForegroundColor yellow  New-AzureRmStorageAccount -ResourceGroupName $rgselect -Name $saname -Location $rvnet.location -SkuName Standard_LRS -Kind Storage 
    }
}


