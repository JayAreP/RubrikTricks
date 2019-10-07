Function Set-RubrikUserAuthorization {
    param(
        [parameter(Mandatory)]
        [string] $principalid,
        [parameter(Mandatory)]
        [array] $objectid,
        [parameter(Mandatory)]
        [ValidateSet('destructiveRestore','restore','onDemandSnapshot','restoreWithoutDownload','rovisionOnInfra','viewReport')]
        [array] $accessroles
    )
    # Create the payload here
    $privileges = New-Object -TypeName psobject
    foreach ($r in $accessroles) {
        $entry = @()
        $entry += $objectid
        $privileges | Add-Member -MemberType NoteProperty -Name $r -Value $entry
    }
    $o = New-Object -TypeName psobject
    $o | Add-Member -MemberType NoteProperty -Name "principals" -Value @($principalid)
    $o | Add-Member -MemberType NoteProperty -Name "privileges" -Value @($privileges)
    $o | ConvertTo-Json -Depth 10

    # Deliver the pizza
    $endpointURI = 'authorization/role/end_user'
    return Invoke-RubrikRESTCall -Endpoint $endpointURI -Method POST -api internal -Body $o
}