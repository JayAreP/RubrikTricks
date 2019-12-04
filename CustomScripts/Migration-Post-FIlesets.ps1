$AllFileSets = get-content .\OldFileSets.json | ConvertFrom-Json
$AllFileSetTemplates = get-content .\OldFileSetTemplates.json | ConvertFrom-Json
foreach ($i in $AllFileSets) {
        $newHost = Get-RubrikHost -Name $i.hostName -PrimaryClusterID local
        $fsname = ($AllFileSetTemplates | where-object {$_.id -eq $i.templateId}).name 
        $fstemplate = Get-RubrikFilesetTemplate -Name $fsname | where-object {$_.name -eq $fsname -and $_.operatingSystemType -eq $i.operatingSystemType}
        try {
            $fileset = New-RubrikFileset -TemplateID $fstemplate.id -HostID $newHost.id
        } catch {
            $fileset = Get-RubrikFileset -TemplateID $fstemplate.id -HostName $newHost.name
        }
        $fileset | Protect-RubrikFileset -SLA $i.configuredSlaDomainName -confirm:0
}
