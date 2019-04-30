param(
    [string]$nameprefix,
    [ipaddress]$dns = 8.8.8.8,
    [string]$ntp = "pool.ntp.org"
)

$vmlist = Get-AzureRmVM | where-object {$_.name -match $nameprefix}

foreach ($i in $vmlist) {
    $vmnic = Get-AzureRmNetworkInterface -Name $i.NetworkProfile.NetworkInterfaces.id.split('/')[-1] -ResourceGroupName $i. -ResourceGroupName
    $vsubnetname = ($vmnic.IpConfigurationsText | ConvertFrom-Json).subnet.id.split('/')[-1]
    $vnetworkname = ($vmnic.IpConfigurationsText | ConvertFrom-Json).subnet.id.split('/')[-3]
    $vsubnet = Get-AzureRmVirtualNetwork -Name $vnetworkname -ResourceGroupName $vmnic.ResourceGroupName | Get-AzureRmVirtualNetworkSubnetConfig -Name $vsubnetname


    $NodeIP = $vmnic.IpConfigurations.PrivateIpAddress

}


$nodata = new-object psobject
$nodata | add-member -name 'managementIpConfig' -type noteproperty -value @{address=$NodeIP.IPAddressToString  ; netmask=$script:MGMTSN.IPAddressToString; gateway=$script:MGMTGW.IPAddressToString}

$o = new-object psobject

# $o | add-member -name 'dnsSearchDomains' -type noteproperty -value $null
$o | add-member -name 'enableSoftwareEncryptionAtRest' -type noteproperty -value $script:enc
$o | add-member -name 'name' -type noteproperty -value $script:clsname
$o | add-member -name 'nodeConfigs' -type noteproperty -value $script:nodeconfigs
$o | add-member -name 'ntpServers' -type noteproperty -value $script:ntpsrv
$o | add-member -name 'dnsNameservers' -type noteproperty -value $script:dnssrv
$o | add-member -name 'adminUserInfo' -type noteproperty -value @{id="admin"; emailAddress=$script:email; password=$script:admpass}
