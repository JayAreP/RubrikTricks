param(
    [parameter(mandatory)]
    [string] $Datacenter,
    [parameter(mandatory)]
    [string] $Credential,
    [parameter()]
    [string] $IncludeInName = 'rubrik'
)

$edgevm = Get-Datacenter $Datacenter | Get-VM | Where-Object {$_.name -match $IncludeInName}   
$edgeip = $edgevm.Guest.IPAddress[0]

Connect-Rubrik -Server $edgeip -Credential $Credential

function Add-RubrikVcenter {
    param(
        [parameter(mandatory)]
        [System.Management.Automation.PSCredential] $credential,
        [parameter()]
        [switch] $updateOnly
    )
    $vcserver = (Get-VIAccount)[0].server.name
    $o = New-Object psobject
    $o | Add-Member -MemberType NoteProperty -Name 'hostname' -Value $vcserver
    $o | Add-Member -MemberType NoteProperty -Name 'username' -Value $credential.username
    $o | Add-Member -MemberType NoteProperty -Name 'password' -Value $credential.GetNetworkCredential().password
    $o | Add-Member -MemberType NoteProperty -Name 'conflictResolutionAuthz' -Value "AllowAutoConflictResolution"

    if ($updateOnly) {
        $currentvc = (Invoke-RubrikRESTCall -Endpoint 'vmware/vcenter' -Method GET).data | where-object {$_.hostname -eq $vcserver}
        $endpoint = 'vmware/vcenter/' + $currentvc.id
        Invoke-RubrikRESTCall -Endpoint $endpoint -Method PUT -Body $o
        sleep 3
        $endpoint = 'vmware/vcenter/' + $currentvc.id + '/refresh'
        $jobrun = Invoke-RubrikRESTCall -Endpoint $endpoint -Method POST
        while ($jobrun.status -eq "RUNNING" -or $jobrun.status -eq "QUEUED") {
            Write-Progress -Activity "Refreshing vCenter..." -PercentComplete $jobrun.progress
            start-sleep -seconds 1
            $endpoint = 'vmware/vcenter/request/' + $jobrun.id
            $jobrun = Invoke-RubrikRESTCall -Endpoint $endpoint -Method get
        }
    } else {
        $endpoint = 'vmware/vcenter'
        Invoke-RubrikRESTCall -Endpoint $endpoint -Method POST -Body $o
    }
}

$filenamestring = $Datacenter + '-credfile.xml'
$credfile = Get-ChildItem | Where-Object {$_.name -match $filenamestring}
$updatecreds = Import-Clixml $credfile.Name
Add-RubrikVcenter -credential $updatecreds -updateOnly