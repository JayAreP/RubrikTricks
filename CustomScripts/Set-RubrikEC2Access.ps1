param(
    [parameter(Mandatory)]
    [array] $EC2List,
    [parameter(Mandatory)]
    [string] $adgroup,
    [parameter(Mandatory)]
    [string] $sla
)

# Functions

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

Function Get-RubrikEC2Instance {
    param (
        [string] $name
    )
    $endpointURI = 'aws/ec2_instance?name=' + $name
    return (Invoke-RubrikRESTCall -Endpoint $endpointURI -Method GET -api internal).data
}

Function Get-RubrikUserAuthorization {
    param(
        [string] $id
    )
    $endpointURI = 'authorization/role/end_user?principals=' + $id
    return (Invoke-RubrikRESTCall -Endpoint $endpointURI -Method GET -api internal).data
}

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

# Check for adgroup in rubrik

try {
    $userinfo = Get-RubrikPrincipal -name $adgroup -type group
} catch {
    # expand on this later
    return $error[0]
}

# Assign acess for EC2 against group

foreach ($i in $EC2List) {
    try {
        Set-RubrikUserAuthorization -principalid $userinfo.id -objectid $i.id -accessroles destructiveRestore,restore,onDemandSnapshot
    } catch {
        # expand on this later
        return $error[0]
    }
}

# Assign SLAs to EC2 instances
## Check that the SLA is valid
Try {
    $slainfo = Get-RubrikSLA -Name $sla
} catch {
    # expand on this later
    return $error[0]
}

foreach ($i in $EC2List) {
    try {
        Protect-RubrikEC2Instance -id $i.id -slaid $slainfo.id
    } catch {
        # expand on this later
        return $error[0]
    }
}

# Report on any errors. 