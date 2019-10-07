function Get-RubrikUser {
    param(
        [Parameter()]
        [string] $Username,
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
    Invoke-RubrikRESTCall -Endpoint $endpoint -api internal -Method Get
}