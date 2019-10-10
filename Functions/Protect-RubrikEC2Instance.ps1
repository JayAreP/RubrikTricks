Function Protect-RubrikEC2Instance {
    param(
        [parameter(Mandatory)]
        [string] $id,
        [parameter(Mandatory)]
        [string] $slaid
    )
    $endpointURI = 'aws/ec2_instance/' + $id
    $o = New-Object -TypeName psobject
    $o | Add-Member -MemberType NoteProperty -TypeName "configuredSlaDomainId" -Value $slaid
    return Invoke-RubrikRESTCall -Endpoint $endpointURI -Method PATCH -Body $o -api internal
}