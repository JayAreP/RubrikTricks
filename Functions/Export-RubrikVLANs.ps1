function Export-RubrikVLANs {
    param(
        [parameter(Mandatory)]
        [string] $filename
    )

    $vlans = Invoke-RubrikRESTCall -Method GET -api internal -Endpoint 'cluster/me/vlan'
    $vlans.data | ConvertTo-Json -Depth 10 | Out-File $filename
}
