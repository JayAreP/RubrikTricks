function Get-RubrikUser {
    param(
        [Parameter()]
        [string] $Username,
        [Parameter()]
        [string] $Domain,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [String]$id
    )
    if ($Username) {
        $endpoint = 'user?username=' + $Username
    } elseif ($id) {
        $endpoint = 'user/' + $id
    } else {
        $endpoint = 'user'
    }
    if ($domain) {
        $ldaplist = Invoke-RubrikRESTCall -Endpoint 'ldap_service' -Method GET 
        $ldapdomain = $ldaplist.data | where-object {$_.name -eq $Domain}
        $endpoint = $endpoint + '&auth_domain_id=' + $ldapdomain.id
    }
    Write-Verbose $endpoint
    Invoke-RubrikRESTCall -Endpoint $endpoint -api internal -Method Get
}