param(
    [parameter(Mandatory)]
    [string] $resourceGroupName,
    [parameter(Mandatory)]
    [string] $storageAccountName,
    [parameter(Mandatory)]
    [string] $rubrikArchiveName,
    [parameter()]
    [ValidateSet('key1','key2')]
    [string] $keyName = "key2"
)

<#
    .SYNOPSIS 
    Script to automatically update an Azure Storage account key against an existing Rubrik Archive.

    .EXAMPLE
    Update-RubrikAzureArchiveKey.ps1 -rubrikArchiveName 'Azure:Rubrik' -resourceGroupName RG01 -storageAccountName rubrikstorageaccount -keyName key2

    The above will:
     - Display the current key2 for the storage account rubrikstorageaccount.
     - Reqest an update for key2 for the storage account rubrikstorageaccount.
     - Display the updated key2 for the storage account rubrikstorageaccount.
     - Update the Rubrik Archive Azure:Rubrik with the updated key.
     

#>

# functions

function Get-RubrikAzureArchiveId {
    param (
        [string] $archiveName
    )
    $archives = (Invoke-RubrikRESTCall -api internal -Endpoint 'archive/object_store' -Method GET).data
    $archiveId = ($archives | where-object {$_.definition.name -eq $archiveName}).id
    return $archiveId
}

function Set-RubrikAzureArchiveKey {
    param (
        [string] $id,
        [string] $key
    )
    $o = New-Object psobject
    $o | Add-Member -MemberType NoteProperty -Name secretKey -Value $key
    $endpointURI = 'archive/object_store/' + $id
    Invoke-RubrikRESTCall -Endpoint $endpointURI -Method PATCH -Body $o -api internal -Verbose
}

# get current rubrik key
$archiveId = Get-RubrikAzureArchiveId -archiveName $rubrikArchiveName

# collect storage account info
$storageAccount = Get-AzureRmStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName
$currentStorageAccountKey = $storageAccount | Get-AzureRmStorageAccountKey | where-object {$_.KeyName -eq $keyName}
Write-Host Current Storage account key for $keyName
$currentStorageAccountKey


# create new key (must be key1 or key2)
$storageAccount | New-AzureRmStorageAccountKey -keyName $keyName 
$newStorageAccountKey = $storageAccount | Get-AzureRmStorageAccountKey | where-object {$_.KeyName -eq $keyName}

Write-Host New Storage account key for $keyName
$newStorageAccountkey

# Submit new key to rubrik
$rubrikKeySet = Set-RubrikAzureArchiveKey -id $archiveId -key $newStorageAccountkey.value -Verbose
$rubrikKeySet.definition
