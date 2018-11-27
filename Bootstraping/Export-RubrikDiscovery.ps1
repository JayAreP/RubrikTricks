param(
    [parameter(mandatory)]
    [string] $hostaddress,    
    [parameter()]
    [switch] $exportCSV
)

<#  
    .SYNOPSIS
    Connect to a rubrik endpoint and generate a discovery JSON. 

    .EXAMPLE
    Export-RubrikDiscovery.ps1 -hostaddress RVM16CS013917

    or

    Export-RubrikDiscovery.ps1 -hostaddress RVM16CS013917.local

#>

if ($hostaddress -notlike "*.local") {
    write-host -ForegroundColor yellow "Adding .local to $hostaddress"
    $hostaddress = $hostaddress + '.local'
}

if ($PSVersionTable.os -match 'darwin') {
    $data = Invoke-RestMethod -Method get -Uri ("https://HOSTADDRESS/api/internal/cluster/me/discover").replace('HOSTADDRESS',$hostaddress) -SkipCertificateCheck
} else {
    if ([System.Net.ServicePointManager]::CertificatePolicy.ToString() -ne "TrustAllCertsPolicy") {
    add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
        write-host -ForegroundColor yellow "Updating local certificate policy"
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    }

    $data = Invoke-RestMethod -Method get -Uri ("https://HOSTADDRESS/api/internal/cluster/me/discover").replace('HOSTADDRESS',$hostaddress) 
}

$filename = $hostaddress + '.json'
$data | ConvertTo-Json
$data | ConvertTo-Json | Out-File $filename
write-host -ForegroundColor green `n"Saved json data to $filename"`n

write-host -ForegroundColor yellow "next, please run: `n`n`.`\create-rubrikjson.ps1 -jsonfile $filename"