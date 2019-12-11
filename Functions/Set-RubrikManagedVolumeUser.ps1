function Set-RubrikManagedVolumeUser {
    param(
        [parameter(mandatory)]
        [string] $principleID
    )

    $privileges = New-Object psobject
    $privileges | Add-Member -MemberType NoteProperty -Name 'basic' -Value @('Global:::All')

    $o = New-Object psobject
    $o | Add-Member -MemberType NoteProperty -Name 'principals' -Value @($principleID)
    $o | Add-Member -MemberType NoteProperty -Name 'privileges' -Value $privileges

    $o | ConvertTo-Json | Write-Verbose
    
    $endpointURI = 'authorization/role/managed_volume_user'
    $result = Invoke-RubrikRESTCall -Method POST -api internal -Body $o -Endpoint $endpointURI
    return $result
}
