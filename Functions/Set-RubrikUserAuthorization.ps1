Function Set-RubrikUserAuthorization {
    param(
        [parameter(Mandatory)]
        [string] $principalid,
        [parameter(Mandatory)]
        [array] $objectid,
        [parameter(Mandatory)]
        [ValidateSet('destructiveRestore','restore','onDemandSnapshot','restoreWithoutDownload','provisionOnInfra','viewReport')]
        [array] $accessroles
    )

    # Query existing permissioms
    $endpointURI = 'authorization/role/end_user?principals=' + $principalid
    $userset = Invoke-RubrikRESTCall -Endpoint $endpointURI -Method GET -api internal 

    # Create the payload here
    foreach ($r in $accessroles) {
        $userset.data.privileges.$r += $objectid
    }

    $o = New-Object -TypeName psobject
    $o | Add-Member -MemberType NoteProperty -Name "principals" -Value @($principalid)
    $o | Add-Member -MemberType NoteProperty -Name "privileges" -Value $userset.data.privileges

    $classes = ($o.privileges | get-member | Where-Object {$_.membertype -eq "NoteProperty"}).name

    foreach ($c in $classes) {
        if ($o.privileges.$c -and ($o.privileges.$c | measure-object).count -lt 2) {
            $o.privileges.$c = @($o.privileges.$c)
        }
    }

    $o | ConvertTo-Json -Depth 10 | Write-Verbose

    # Deliver the pizza
    $endpointURI = 'authorization/role/end_user'
    return (Invoke-RubrikRESTCall -Endpoint $endpointURI -Method POST -api internal -Body $o).data | ConvertTo-Json -Depth 10
}