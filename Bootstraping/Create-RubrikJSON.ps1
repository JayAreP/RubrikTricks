param(
    [parameter()]
    [string] $jsonfile,
    [parameter()]
    [string] $nodeCSV,
    [parameter()]
    [string] $clusterCSV
)

<#  
    .SYNOPSIS
    Create a Rubrik Bootstrap JSON

    .EXAMPLE
    ./Create-RubrikJSON.ps1 -jsonfile RVM16CS013917.local.json

    or

    ./Create-RubrikJSON.ps1 (without any paramters)


#>

if ($nodeCSV) {
    [bool]$inputfile = $true
    $jsdata = import-csv $nodeCSV
    $nodenames = $jsdata.nodename
    [int]$totalnodes = $jsdata.count
}


if ($jsonfile) {
    [bool]$inputfile = $true
    $jsdata = Get-Content $jsonfile | ConvertFrom-Json
    $nodenames = $jsdata.data.hostname
    [int]$totalnodes = $jsdata.data.hostname.count
    if ($nodenames -eq $null) {
        write-verbose "older style JSON supplied..."
        $nodenames = $jsdata.data
        [int]$totalnodes = $jsdata.data.count}
}

Clear-Host

<# --- Cluster Build --- #>

function rbkcluster {

    Write-Host -ForegroundColor green `n"--Rubrik json creation script --"`n`n

    if ($inputfile) {
        # $script:jsondata = Get-Content $jsonfile | ConvertFrom-Json
        write-host -ForegroundColor green `n"Using input file to set cluster tally and names:"`n

        [int]$script:nodetally = $totalnodes
        [array]$nodelist = @()
        [int]$nnumber = 1

        foreach ($n in $nodenames) {
            $o = new-object psobject
            $o | add-member -name "Order" -type noteproperty -value $nnumber
            $o | add-member -name "Node" -type noteproperty -value $n
            $nnumber++
            $nodelist += $o
        }
        
        $nlstring = $nodelist | Format-Table -wrap | out-string
        write-host `n"Discovered node order, please specify correct numerical order:"`n
        write-host $nlstring

        [array]$script:newnodelist = @()
    
        foreach ($i in $nodelist) {
            [int]$on = $script:nodetally+1
            while ($on -gt $script:nodetally) {
                $nn = $i.Node
                [int]$on = Read-Host "enter order number for $nn"
                $o = new-object psobject
                $o | add-member -name "Order" -type noteproperty -value $on
                $o | add-member -name "Node" -type noteproperty -value $nn
                if ($on -gt $script:nodetally) {
                    write-host -ForegroundColor red `n"`[$on`] is too high an order number, please re-enter a number less than $script:nodetally"
                } else {$script:newnodelist += $o}
            }
        }
        $script:newnodelist = $script:newnodelist | Sort-Object Order
        $nnlstring = $script:newnodelist | sort-object order | Format-Table -wrap | out-string
        write-host $nnlstring

        $noconfirm = Read-Host 'Does the above list look correct? [Y,n]'
        $noconfirm = $noconfirm.tolower()
        while("y","n" -notcontains $noconfirm)
        {
            if (!$noconfirm) {$noconfirm = 'y'}
            else {
                $noconfirm = Read-Host 'Does the above list look correct? [Y,n]'`n`n
            }
        }


    }


    write-host -ForegroundColor green "--- Cluster configuration ---"

    # Gather cluster-specific information. 

    $script:email = Read-Host 'E-mail address'
    $script:clsname = Read-Host 'Cluster name'

    [string]$script:encryption = Read-Host 'Encryption? [y,N]'
    [string]$script:encryption = [string]$script:encryption.tolower()
    while("y","n" -notcontains [string]$script:encryption)
    {
        if (![string]$script:encryption) {
            write-host No answer provided, setting Encryption to N
            [string]$script:encryption = 'n'}
        else {
        $script:encryption = Read-Host 'Encryption? [y,N]'
        }
    }

    if ([string]$script:encryption -eq "y") {
        [bool]$script:enc = $true} 
    if ([string]$script:encryption -eq "n") {
        [bool]$script:enc = $false} 

        write-verbose $script:enc

    $dnscnt = 1
    [array]$script:dnssrv = @()
    $dns = Read-Host "DNS server $dnscnt"
    $script:dnssrv += $dns
    do {
        $dnscnt++
        $dns = Read-Host "DNS server $dnscnt [EOL]"
        $script:dnssrv += $dns
    } while ($dnscnt -lt 2)
    $script:dnssrv = $script:dnssrv | where-object {$_}

    $ntpcnt = 1
    [array]$script:ntpsrv = @()
    $ntp = Read-Host "NTP server $ntpcnt"
    $script:ntpsrv += $ntp
    do {
        $ntpcnt++
        $ntp = Read-Host "NTP server $ntpcnt [EOL]"
        $script:ntpsrv += $ntp
    } while ($ntpcnt -lt 2)
    $script:ntpsrv = $script:ntpsrv | where-object {$_}

    $script:admpass = 'Rubrik123!@#'

    Write-Host -ForegroundColor green `n"Configure the Data `/ Management network:"`n
  
    [ipaddress]$script:MGMTGW = Read-Host -Prompt "Management Gateway"
    try {[ipaddress]$script:MGMTSN = Read-Host -Prompt "Mangement Subnet Mask [255.255.255.0]" -ErrorAction silentlycontinue }
    catch {[ipaddress]$script:MGMTSN = "255.255.255.0"}
    write-verbose $script:MGMTSN.IPAddressToString 

    Write-Host -ForegroundColor green `n"Configure the IPMI network:"`n

    [ipaddress]$script:IPMIGW = Read-Host -Prompt "IPMI Gateway"
    try {[ipaddress]$script:IPMISN = Read-Host -Prompt "IPMI Subnet Mask [255.255.255.0]" -ErrorAction silentlycontinue }
    catch {[ipaddress]$script:IPMISN = "255.255.255.0"}
    write-verbose $script:IPMISN.IPAddressToString

    Write-Host -ForegroundColor green `n"Configure the Management-Only network (optional):"`n
# -- fix the below mess
    [ipaddress]$script:MGTOGW = Read-Host -Prompt "Management-Only Gateway (optional)" 
    if ($script:MGTOGW) {
        [ipaddress]$script:MGTOSN = Read-Host -Prompt "Management-Only Subnet Mask [255.255.255.0]" -ErrorAction silentlycontinue | out-null
        if (!$script:MGTOSN) {[ipaddress]$script:MGTOSN= "255.255.255.0"}
            write-verbose $script:MGTOSN
    }

   

}

<# --- Node CSV import --- #>
function rbknodecsv {

    $nodecsv = import-csv $nodecsv

}


<# --- Node Build Function --- #>


function rbknodebuild {

    Write-Host -ForegroundColor green `n"Node configuration:"`n
    [array]$script:nodearray = @()

    Clear-Host 

    if (!$script:nodetally) {
        [int]$script:nodetally = Read-Host 'number of nodes?'
    }

    $script:nodeconfigs = new-object psobject
    $nodeloop = 1

    if ($inputfile) {
        $nodeptr = $nodeloop
        $nodeptr--
    }
    write-host -ForegroundColor green `n"--- Node configuration ---"`n
    Do {
        
        if ($startnodeip) {
            $startnodeip.Address = ($startnodeip.Address + 16777216)
        }
        if ($startipmiip) {
            $startipmiip.Address = ($startipmiip.Address + 16777216)
        }
        if ($startmgtoip) {
            $startmgtoip.Address = ($startmgtoip.Address + 16777216)
        }
        
        if ($inputfile) {
            # $jsonnname = $script:newnodelist[$nodeptr].Node
            $nodename = $script:newnodelist[$nodeptr].Node
            $nodeptr++
        } else {$nodename = Read-Host "Name for node $nodeloop"}

        $nextmip = $startnodeip.IPAddressToString

    Try {
        [ipaddress]$NodeIP = Read-Host -Prompt "$nodename Magement IP Address `[$nextmip`]" -ErrorAction silentlycontinue }
    Catch {
        write-verbose "No IP specified, using $nextmip"
        $NodeIP = $startnodeip  }
    Finally {
        write-verbose "IP Set to $NodeIP"}

        $nextiip = $startipmiip.IPAddressToString

    Try {
        [ipaddress]$IpmiIP = Read-Host -Prompt "$nodename IPMI IP Address `[$nextiip`]" -ErrorAction silentlycontinue}
    Catch {
        write-verbose "No IP specified, using $nextiip"
        $IpmiIP = $startipmiip}
    Finally {
        write-verbose "IP Set to $NodeIP"}

if ($script:MGTOGW) {

        $nextoip = $startmgtoip.IPAddressToString

        Try {
            [ipaddress]$MgtoIP = Read-Host -Prompt "$nodename Management-Only IP Address `[$nextoip`]" -ErrorAction silentlycontinue}
        Catch {
            write-verbose "No IP specified, using $nextoip"
            $MgtoIP = $startmgtoip}
        Finally {
            write-verbose "IP Set to $NodeIP"}
    }

        if (!$startnodeip) {$startnodeip = $NodeIP}
        if (!$startipmiip) {$startipmiip = $IpmiIP}

        $nodata = new-object psobject
        $nodata | add-member -name 'ipmiIpConfig' -type noteproperty -value @{address=$IpmiIP.IPAddressToString  ; netmask=$script:IPMISN.IPAddressToString; gateway=$script:IPMIGW.IPAddressToString}
        $nodata | add-member -name 'managementIpConfig' -type noteproperty -value @{address=$NodeIP.IPAddressToString  ; netmask=$script:MGMTSN.IPAddressToString; gateway=$script:MGMTGW.IPAddressToString}
        if ($script:MGTOGW) {
            $nodata | add-member -name 'dataIpConfig' -type noteproperty -value @{address=$MgtoIP.IPAddressToString  ; netmask=$script:MGTOSN.IPAddressToString; gateway=$script:MGTOGW.IPAddressToString}
        }

        write-host -ForegroundColor yellow `n"Node Data"`n
        $nodata | ConvertTo-Json -Depth 10
        write-host -ForegroundColor yellow `n"---------"`n
        $nname = $nodename

        $script:nodeconfigs | Add-Member -Name $nname -MemberType noteproperty -Value $nodata
        $nodeloop++

        $vnode = new-object psobject 
        $vnode | Add-Member -Name "Node Name" -Type noteproperty -value $nodename
        $vnode | Add-Member -Name "Management IP"  -Type noteproperty -value $NodeIP.IPAddressToString
        $vnode | Add-Member -Name "IPMI IP" -Type noteproperty -value $IpmiIP.IPAddressToString
        if ($script:MGTOGW) {
            $vnode | Add-Member -Name "MGTO IP" -Type noteproperty -value $MgtoIP.IPAddressToString
        }

        [array]$script:nodearray += $vnode

    } While ($nodeloop -le $script:nodetally) 

    Clear-Host




}

function rbkjsoncreate {

    Write-Host -ForegroundColor green "Node configuration configured as so:"

    $script:nodearray | format-table -a

    $confirm = Read-Host 'Does the above list look correct? [Y,n]'
    $confirm = $confirm.tolower()
    while("y","n" -notcontains $confirm)
    {
        if (!$confirm) {$confirm = 'y'}
        else {
            $confirm = Read-Host 'Does the above list look correct? [Y,n]'
        }
    }


    
    if ($confirm -eq 'y') {


        $o = new-object psobject

        # $o | add-member -name 'dnsSearchDomains' -type noteproperty -value $null
        $o | add-member -name 'enableSoftwareEncryptionAtRest' -type noteproperty -value $script:enc
        $o | add-member -name 'name' -type noteproperty -value $script:clsname
        $o | add-member -name 'nodeConfigs' -type noteproperty -value $script:nodeconfigs
        $o | add-member -name 'ntpServers' -type noteproperty -value $script:ntpsrv
        $o | add-member -name 'dnsNameservers' -type noteproperty -value $script:dnssrv
        $o | add-member -name 'adminUserInfo' -type noteproperty -value @{id="admin"; emailAddress=$script:email; password=$script:admpass}

        $filename = $script:clsname + '.json'

        write-host -ForegroundColor yellow `n"-------   JSON output   -------"

        $o | ConvertTo-Json -Depth 10
        $o | ConvertTo-Json -Depth 10 | Out-File $filename

        write-host -ForegroundColor yellow `n"Final json output saved to file $filename"

        } else {
            write-host -ForegroundColor yellow `n "Aborting json creation"`n
            break  
        }
    

}



    rbkcluster


$vcluster = new-object psobject 
$vcluster | Add-Member -Name "Cluster name" -Type noteproperty -value $script:clsname
$vcluster | Add-Member -Name "E-mail address"  -Type noteproperty -value $script:email
$vcluster | Add-Member -Name "Management Gateway" -Type noteproperty -value $script:MGMTGW.IPAddressToString
$vcluster | Add-Member -Name "Management Netmast" -Type noteproperty -value $script:MGMTSN.IPAddressToString
$vcluster | Add-Member -Name "IPMI Gateway" -Type noteproperty -value $script:IPMIGW.IPAddressToString
$vcluster | Add-Member -Name "IPMI Netmask" -Type noteproperty -value $script:IPMISN.IPAddressToString
$vcluster | Add-Member -Name "DNS Server" -Type noteproperty -value $script:dnssrv
$vcluster | Add-Member -Name "NTP Server" -Type noteproperty -value $script:ntpsrv
$vcluster | Add-Member -Name "Encryption" -Type noteproperty -value $script:enc

Clear-Host

write-host -ForegroundColor yellow `n "Cluster configuration:"`n

$vcluster | Format-List

$clsconfirm = Read-Host 'Does the above list look correct? [Y,n]'
$clsconfirm = $clsconfirm.tolower()
while("y","n" -notcontains $clsconfirm)
{
    if (!$clsconfirm) {$clsconfirm = 'y'}
    else {
        $clsconfirm = Read-Host 'Does the above list look correct? [Y,n]'
    }
}

if ($clsconfirm -eq 'y') {
    
    rbknodebuild
    rbkjsoncreate
    } else {
        write-host -ForegroundColor yellow `n "Aborting cluster configuration"`n
        break  
    }
