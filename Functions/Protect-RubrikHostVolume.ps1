function Protect-RubrikHostVolumes {
    param(
        [parameter(mandatory)]
        [string] $RubrikHost,
        [parameter(mandatory)]
        [string] $sla
    )
    <#  
    .SYNOPSIS
    Protect a hosts' volumes. 

    .EXAMPLE
    Protect-RubrikHostVolumes -RurbikHost Server01 -sla Gold

    #>
    $rhost = Get-RubrikHost -Name $RubrikHost
    $id = $rhost.id
    $slaid = Get-RubrikSLA -Name $sla -PrimaryClusterID local

    function Get-RubrikVolumeGroup {
        param(
        [string] $id
        )
        if ($id) {
            $endpoint = 'volume_group/' + $id 
            Invoke-RubrikRESTCall -Endpoint $endpoint -Method GET -api internal
        } else {
            $endpoint = 'volume_group'
            (Invoke-RubrikRESTCall -Endpoint $endpoint -Method GET -api internal).data
        }
    }

    $rhostvg = Get-RubrikVolumeGroup | Where-Object {$_.hostId -eq $id}
    # $rhostvols = Get-RubrikVolumeGroup -id $rhostvg.id
    $uri = 'host/' + $rhost.id + '/volume'
    $hostvols = Invoke-RubrikRESTCall -api internal -Method GET -Endpoint $uri

    $o = New-Object -TypeName psobject  
    $o | Add-Member -MemberType NoteProperty -Name configuredSlaDomainId -Value $slaid.id
    $o | Add-Member -MemberType NoteProperty -Name volumeIdsIncludedInSnapshots -Value @($hostvols.data.id)

    $endpoint = 'volume_group/' + $rhostvg.id
    Invoke-RubrikRESTCall -Endpoint $endpoint -Method PATCH -Body $o -api internal
}

