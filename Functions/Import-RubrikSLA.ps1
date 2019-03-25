Function Import-RubrikSLA {
    param(
        [parameter()]
        [String] $slaname,
        [parameter(Mandatory)]
        [String] $filename
    )

    $dsla = Get-Content $filename | ConvertFrom-Json
    $rsla = $dsla | Select-Object name,frequencies,allowedBackupWindows,firstFullAllowedBackupWindows,localRetentionLimit,archivalSpecs,replicationSpecs

    if ($slaname) {$rsla.name = $slaname}

    Invoke-RubrikRESTCall -Endpoint 'sla_domain' -Method POST -Body $rsla
}