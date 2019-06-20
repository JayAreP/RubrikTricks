function Update-RubrikVLANNetmask {
    <#
    .DESCRIPTION
    Update the requested VLAN to use a new subnet mask. It has to remove and re-add the vlan due to no PATCH method for this API. 

    .EXAMPLE
    Update-RubrikVLANNetmask -vlan 5 -netmask 255.255.252.0
    This will remove vlan 5, and re-add it using the same interface assignments, but with an updated netmask. 
    #>
    
    param (
        [Parameter(Mandatory)]
        [string] $vlan,
        [Parameter(Mandatory)]
        [string] $netmask
    )

    $rvlan = (Invoke-RubrikRESTCall -Method get -api internal -Endpoint 'cluster/me/vlan').data | Where-Object {$_.vlan -eq $vlan}
    $rvlan.netmask = $netmask
    
    $endpoint = 'cluster/me/vlan?vlan_id=' + $vlan
    Invoke-RubrikRESTCall -Method delete -api internal -Endpoint $endpoint
    $vlancheck = (Invoke-RubrikRESTCall -Method get -api internal -Endpoint 'cluster/me/vlan').data | Where-Object {$_.vlan -eq $vlan}

    while ($vlancheck) {
        Write-Progress -Activity "Updating vlan $vlan"
        sleep 5
        $vlancheck = (Invoke-RubrikRESTCall -Method get -api internal -Endpoint 'cluster/me/vlan').data | Where-Object {$_.vlan -eq $vlan}
    }

    Invoke-RubrikRESTCall -Method post -api internal -Endpoint 'cluster/me/vlan' -Body $rvlan
    $rvlan | ConvertTo-Json -Depth 10
}