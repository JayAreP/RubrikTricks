Function Get-RubrikUserAuthorization {
    param(
        [string] $id
    )
    $endpointURI = 'authorization/role/end_user?principals=' + $id
    return (Invoke-RubrikRESTCall -Endpoint $endpointURI -Method GET -api internal).data
}