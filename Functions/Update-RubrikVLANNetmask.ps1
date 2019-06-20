function Update-RubrikVLANNetmask {
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