function Search-RubrikFilesetFile {
    param(
        [Parameter(Mandatory)]
        [array]$filename,
        [Parameter(Mandatory)]
        [array]$filesetname,
        [Parameter()]
        [switch] $download
    )

<#  
    .SYNOPSIS
    Powershell Function to search and acquire a file from a fileset. 
    Simple syntax, use the -download switch for a menu-driven file and date select download. 

    .EXAMPLE
    Search-RubrikFilesetFile -filename "notepad.exe" -fileset "D Drive" -download

#>

    $endpointURI = 'fileset?name=' + $filesetname.replace(' ','%20')
    $filesets = (Invoke-RubrikRESTCall -Method get -Endpoint $endpointURI)
    $endpointURI | write-verbose
    $search = $filesets.data.id | foreach-object {
        Invoke-RubrikRESTCall -Method get -Endpoint ('fileset/' + $_ + '/search?path=' + $filename)}
    if ($download) {
        $filenames = $search.data.path | sort -Unique
        clear
        # setup menu for file select
        $menuarray = @()
        foreach ($i in $filenames) {
            $o = New-Object psobject
            $o | Add-Member -MemberType NoteProperty -Name 'File' -Value $i
            $menuarray += $o
        }
    
        $menu = @{}
        for (
            $i=1
            $i -le $menuarray.count
            $i++
        ) { Write-Host "$i. $($menuarray[$i-1].file)" 
            $menu.Add($i,($menuarray[$i-1].file))
        }
        [int]$mntselect = Read-Host 'Enter the file that you would like to recover'
        $fileselect = $menu.Item($mntselect)

        
        $searchlist = $search.data | where-object {$_.path -eq $fileselect}

        $fileselectmenu = $searchlist.fileVersions | sort lastModified -Unique
        clear
        $fmenuarray = @()
        foreach ($i in $fileselectmenu) {
            $o = New-Object psobject
            $o | Add-Member -MemberType NoteProperty -Name 'lastModified' -Value $i.lastModified
            $fmenuarray += $o
        }
    
        $fmenu = @{}
        for (
            $i=1
            $i -le $fmenuarray.count
            $i++
        ) { Write-Host "$i. $($fmenuarray[$i-1].lastModified)" 
            $fmenu.Add($i,($fmenuarray[$i-1].lastModified))
        }
        [int]$mntselect = Read-Host 'Enter the file date that you would like to recover'
        $filedateselect = $fmenu.Item($mntselect)

        $restorefinal = $fileselectmenu | where-object {$_.lastModified -eq $filedateselect}

        $o = New-Object PSobject
        $o | Add-Member -Name 'sourceDir' -Value $fileselect -type noteproperty
        $endpointURI = 'fileset/snapshot/' + $restorefinal.snapshotid + '/download_file'
        $filedownload = Invoke-RubrikRESTCall -Endpoint $endpointURI -Method POST -Body $o
        $endpointURI = 'fileset/request/' + $filedownload.id
        while ((Invoke-RubrikRESTCall -Method get -Endpoint $endpointURI).status -ne "SUCCEEDED") {
            Write-Progress -Activity "Preparing File"
            start-sleep -seconds 1
        }
        $endpointURI = 'fileset/request/' + $filedownload.id
        $request = Invoke-RubrikRESTCall -Method get -Endpoint $endpointURI
        $request.links.href -like "download*"
        $downloadURI = 'https://' + $Global:RubrikConnections[-1].server + '/' + ($request.links.href -like "download*")
        $outfile = (Get-Location).path + '\' + $filename
        $outfile
        Invoke-WebRequest -Uri $downloadURI -OutFile $outfile
        get-item $filename
    } else {
        $search.data.path | sort -Unique
    }
}    