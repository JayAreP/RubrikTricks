function Add-RubrikVLAN {
    param(
        [int] $vlan,
        [string] $netmask,
        [array] $nodeList
    )
    <#
     .EXAMPLE
    Generate a nodelist array like so:

    $nodelist = @()

    $o = New-Object PSObject
    $o | Add-Member -MemberType NoteProperty -Name 'node' -Value 'RVM9999999'
    $o | Add-Member -MemberType NoteProperty -Name 'ip' -Value '10.10.10.11'

    Add-RubrikVLAN -vlan 202 -subnet 255.255.255.0 -nodeList $nodelist
    
    #>

    $o = New-Object psobject
    $o | Add-Member -MemberType NoteProperty -Name 'vlan' -Value $vlan
    $o | Add-Member -MemberType NoteProperty -Name 'netmask' -Value $netmask
    $o | Add-Member -MemberType NoteProperty -Name 'interfaces' -Value $nodeList

    Invoke-RubrikRESTCall -Method POST -api internal -Endpoint 'cluster/me/vlan' -Body $o
}

