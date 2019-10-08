param(
    [parameter(Mandatory)]
    [array] $EC2List,
    [parameter(Mandatory)]
    [string] $adgroup,
    [parameter(Mandatory)]
    [string] $sla
)

# Functions

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
    return Invoke-RubrikRESTCall -Endpoint $endpointURI -Method POST -Body $o 
}

# Check for adgroup in rubrik

try {
    $userinfo = Get-RubrikUser -Username $adgroup
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
    return[0]
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