Function Get-RubrikEC2Instance {
    param (
        [string] $name
    )
    $endpointURI = 'aws/ec2_instance?name=' + $name
    return (Invoke-RubrikRESTCall -Endpoint $endpointURI -Method GET -api internal).data
}