function Get-RubrikPrincipal {
    param(
        [Parameter(Mandatory)]
        [string] $name,
        [Parameter(Mandatory)]
        [ValidateSet('user','group',IgnoreCase = $false)]
        [String] $type
    )

    $o = New-Object psobject
    $o | Add-Member -MemberType NoteProperty -Name "principalType" -Value $type
    $o | Add-Member -MemberType NoteProperty -Name "searchAttr" -Value @('name')
    $o | Add-Member -MemberType NoteProperty -Name "searchValue" -Value @($name)

    $q = New-Object psobject
    $q | Add-Member -MemberType NoteProperty -Name "queries" -Value @($o)

    $endpointURI = 'principal_search'
    $results = (Invoke-RubrikRESTCall -Endpoint $endpointURI -api internal -Method POST -Body $q).data
    $result = $results | Where-Object {$_.name -eq $name}
    if ($result) {
        return $result
    } 
}