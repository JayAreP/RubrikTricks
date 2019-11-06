param(
    [parameter(Mandatory)]
    [string] $inputfile,
    [parameter(Mandatory)]
    [string] $NASHost,
    [parameter(Mandatory)]
    [string] $SLA,
    [parameter(Mandatory)]
    [Alias("Export")]
    [string] $share,
    [parameter()]
    [ValidateSet('NFS','SMB')]
    [string] $ShareType = "NFS"
)

    <#
        .SYNOPSIS
        Automates the creation of NAS fileset templates and fileset enrollment, keyed off of a simple input file of folder lists. 
        
        .DESCRIPTION
        Generate a list of folders from the root of the desired NAS host share, store that file as a plain text file. 
        Then feed the file as an argument to this script so it can be keyed from and auto-generate the appropriate filesets. 

        .EXAMPLE
        Enroll-NassEnMasse.ps1 -inputfile folderlist.txt -NAShost isln01 -SLA "Production Azure Archive" -export '/ifs/isilon_nfs' -sharetype NFS
        
        This will loop through the folderlist.txt and create fileset templates, filesets, and enroll isln01:/operations/{folder} 
        into the SLA "Production Azure Archive" 
    #>

# Create NAS Fileset Templates

$inputfile = Get-Content $inputfile
foreach ($i in $inputfile) {
    if ($ShareType = "NFS") {$includes = '/' + $i + '/*'}
    if ($ShareType = "SMB") {$includes = '\\' + $i + '\**'}
    if (!(Get-RubrikFilesetTemplate -Name $i)) {
        New-RubrikFilesetTemplate -Name $i -ShareType $ShareType -Includes $includes
    } else {
        Write-Host Fileset Template $i already exists. Skipping.
    }
}

# Generate Host context

try {
    $rubrikhost = Get-RubrikHost -name $NASHost
} catch {
    return $error[0]
}

try {
    # Suss out a better way to specifcy the precise share
    $rubriknas = Get-RubrikNASShare -HostName $rubrikhost.name -exportPoint $share
} catch {
    return $error[0]
}

# Enroll Host in SLA
foreach ($i in $inputfile) {
    $template = Get-RubrikFilesetTemplate -Name $i
    $rubrikfileset = New-RubrikFileset -TemplateID $template.id -hostID $rubriknas.id
    $rubrikfileset | Protect-RubrikFileset -SLA $SLA -Confirm:0
}
