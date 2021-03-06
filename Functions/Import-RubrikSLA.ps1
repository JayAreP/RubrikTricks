Function Import-RubrikSLA {
    param(
        [parameter()]
        [String] $slaname,
        [parameter(Mandatory)]
        [String] $filename,
        [parameter()]
        [Switch] $LocalOnly
    )

    $dsla = Get-Content $filename | ConvertFrom-Json
    $rsla = $dsla | Select-Object name,frequencies,allowedBackupWindows,firstFullAllowedBackupWindows,localRetentionLimit,showAdvancedUi,advancedUiConfig,archivalSpecs,replicationSpecs
    if ($LocalOnly) {
        $rsla.PSObject.Properties.Remove('archivalSpecs')
        $rsla.PSObject.Properties.Remove('replicationSpecs')
        $rsla.PSObject.Properties.Remove('localRetentionLimit')
    }
    if ($slaname) {$rsla.name = $slaname}

    Invoke-RubrikRESTCall -Endpoint 'sla_domain' -Method POST -api 2 -Body $rsla
}