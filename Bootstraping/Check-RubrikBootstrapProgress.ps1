param(
    [parameter(mandatory)]
    [string] $hostaddress,
    [parameter()]
    [string] $id = "1"
)

if ($hostaddress -notlike "*.local") {
    write-host -ForegroundColor yellow "Adding .local to $hostaddress"
    $hostaddress = $hostaddress + '.local'
}

$statcounter = 0

function bootstat {
    if ($PSVersionTable.os -match 'darwin') {
        $bootstatus = Invoke-RestMethod -Method get -Uri ("https://HOSTADDRESS/api/internal/cluster/me/bootstrap?request_id=" + $id).replace('HOSTADDRESS',$hostaddress) -SkipCertificateCheck -verbose -TimeoutSec 15
    } else {
        fixcert
        $bootstatus = Invoke-RestMethod -Method get -Uri ("https://HOSTADDRESS/api/internal/cluster/me/bootstrap?request_id=" + $id).replace('HOSTADDRESS',$hostaddress) -verbose -TimeoutSec 15
    }
    $bootstatus
}

$bootstat = bootstat

while($bootstat -notmatch 'FAILURE')
{
    Clear-Host
    Write-Host -ForegroundColor yellow "Bootstrap has been running for"  $statcounter.ToString()  "seconds"
    $bootstat = bootstat
    if ($bootstat) {
        $bootstat
    }
    Start-Sleep -Seconds 15
    $statcounter = $statcounter + 15
}