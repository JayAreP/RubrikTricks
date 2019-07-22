function Import-RubrikVLANs {
    param(
        [parameter(Mandatory)]
        [string] $filename
    )

    $vlansdata = Get-Content $filename | ConvertFrom-Json
    Invoke-RubrikRESTCall -Method POST -api internal -Endpoint 'cluster/me/vlan' -Body $vlansdata
}

