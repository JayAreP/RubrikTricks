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
        
        This will loop through the folderlist.txt and create fileset templates, filesets, and enroll isln01:/ifs/isilon_nfs/{folder} 
        into the SLA "Production Azure Archive" 
    #>

# Create NAS Fileset Templates

$inputlist = Get-Content $inputfile
foreach ($i in $inputlist) {
    $tmplatename = $NASHost + "-" + $i
    if ($ShareType = "NFS") {$includes = '/' + $i + '/*'}
    if ($ShareType = "SMB") {$includes = '\' + $i + '\**'}
    if (!(Get-RubrikFilesetTemplate -Name $tmplatename)) {
        New-RubrikFilesetTemplate -Name $tmplatename -ShareType $ShareType -Includes $includes
    } else {
        Write-Host Fileset Template $tmplatename already exists. Skipping.
    }
}

# Generate Host context

try {
    $rubrikhost = Get-RubrikHost -name $NASHost
} catch {
    return $error[0]
}

try {
    $rubriknas = New-RubrikNASShare -HostID $rubrikhost.id -ShareType $ShareType -ExportPoint $share
    # Suss out a better way to specifcy the precise share
} catch {
    $rubriknas = Get-RubrikNASShare -HostName $rubrikhost.name -exportPoint $share
}


# Enroll Host in SLA
foreach ($i in $inputlist) {
    $tmplatename = $NASHost + "-" + $i
    $template = Get-RubrikFilesetTemplate -Name $tmplatename
    try {
        $rubrikfileset = New-RubrikFileset -TemplateID $template.id -ShareID $rubriknas.id   
    } catch {
        $rubrikfileset = Get-RubrikFileset -TemplateID $template.id -ShareID $rubriknas.id 
    }
    $rubrikfileset | Protect-RubrikFileset -SLA $SLA -Confirm:0
}
