Import-Module PSReadLine

Set-PSReadLineKeyHandler -Chord "Ctrl+u" -Function BackwardDeleteLine
Set-PSReadLineKeyHandler -Chord "Ctrl+k" -Function ForwardDeleteLine
Set-PSReadLineKeyHandler -Chord "Ctrl+b" -Function BackwardChar
Set-PSReadLineKeyHandler -Chord "Alt+d" -Function DeleteWord
Set-PSReadLineKeyHandler -Chord "Alt+b" -Function BackwardWord

Update-TypeData -AppendPath $PSScriptRoot\man_types.format.ps1xml
Function get_child_item_size { Get-ChildItem | Format-Table -Property Mode, FileSize, Name }
Set-Alias -Name ll -Value get_child_item_size
Function get_all_child_item ($path) { (Get-ChildItem -Hidden $path) + (Get-ChildItem $path) }
Set-Alias -Name la -Value get_all_child_item

Set-Alias -Name touch -Value New-Item
Set-Alias -Name ifconfig -Value ipconfig.exe
Set-Alias -Name ip -Value ipconfig.exe

$SEP = [IO.Path]::DirectorySeparatorChar
function p_u2w($path) {
    return $path -replace '/', $SEP
}

# Simlate to gnu ln
# https://www.gnu.org/software/coreutils/manual/html_node/ln-invocation.html
function ln {
    [CmdletBinding()]
    Param(
        <# ln [option]… [-T] target linkname
        ln [option]… target
        ln [option]… target… directory
        ln [option]… -t directory target… #>
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Target, # PointAt
        [Parameter(Position = 1)]
        [string]$Name, # LinkName
        <# Mandatory arguments to long options are mandatory for short options too.
            --backup[=CONTROL]      make a backup of each existing destination file
        -b                          like --backup but does not accept an argument
        -d, -F, --directory         allow the superuser to attempt to hard link directories 
                (note: will probably fail due to system restrictions, even for the superuser)
        -f, --force                 remove existing destination files
        -i, --interactive           prompt whether to remove destinations
        -L, --logical               dereference TARGETs that are symbolic links
        -n, --no-dereference        treat LINK_NAME as a normal file if it is a symbolic link to a directory
        -P, --physical              make hard links directly to symbolic links
        -r, --relative              create symbolic links relative to link location
        -s, --symbolic              make symbolic links instead of hard links
        -S, --suffix=SUFFIX         override the usual backup suffix
        -t, --target-directory=     specify the DIRECTORY in which to create the links
        -T, --no-target-directory   treat LINK_NAME as a normal file always
        -v, --verbose               print name of each linked file
            --help                  display this help and exit
            --version               output version information and exit #>
        # -a_ -> -A
        [Alias("b")]
        [switch]$backup,
        [Alias("d", "f_")]
        [switch]$directory,
        
        [Alias("f")]
        [switch]$force,
        [Alias("i")]
        [switch]$interactive,
        
        [Alias("L", "l_")]
        [switch]$logical, #TODO
        [Alias("n")]
        [switch]${no-dereference}, #TODO
        
        [Alias("r")]
        [switch]$relative,
        [Parameter()]
        [Alias("s")]
        [switch]$symbolic,
        [Alias("s_")]
        [string]$suffix = "~",
        
        [Alias("t")]
        [string]${target-directory},
        [Alias("t_")]
        [switch]${no-target-directory},
        [switch]$help #TODO
    )

    <# Creates a symbolic link.
    MKLINK [[/D] | [/H] | [/J]] Link Target
        /D      Creates a directory symbolic link. Default is a file symbolic link.
        /H      Creates a hard link instead of a symbolic link.
        /J      Creates a Directory Junction.
        Link    Specifies the new symbolic link name.
        Target  Specifies the path (relative or absolute) that the new link refers to. #>

    # Valid/Preprocess/Generate Target/Name
    if ($Target) { $PointAt = p_u2w($Target) ; $path = $Target }
    if ($Name) { $LinkName = p_u2w($Name) }
    else {
        $LinkName = $Target.Substring($Target.LastIndexOf($SEP) + 1)
    }

    if (Test-Path $Target) {
        $FileObject = Get-Item $Target
        $IsDir = $FileObject -is [System.IO.DirectoryInfo] #$object.PSIsContainer
    }
    else {
        Write-Warning "Target:$Target not exists"
    }

    #
    if (!$relative) {}
    elseif (-not $FileObject) {
        Write-Error "File $Target not exists, unable to resolve relative path"
    }
    else { 
        $path = Resolve-Path $Target -Relative 
        Write-Debug "Resolved relative: $path"
        if (${target-directory}) { $PointAt = "${target-directory}$SEP$path" }
        else { $PointAt = $path }
    }

    # Powershell wrapper
    $type = 'SymbolicLink'
    if ($IsDir -or $directory) {
        $type = $symbolic ? 'Junction' : 'SymbolicLink'
    }
    elseif (!$symbolic) {
        $type = 'HardLink'
    }

    # Handle Link Location
    $LinkNameExist = Test-Path $Name
    if ($LinkNameExist -and $backup) {
        Move-Item $Name $Name.FullName + $suffix
    }
    New-Item -ItemType $type -Target $PointAt -Path $LinkName -Force:$Force -Confirm:$interactive
    <# mklink wrapper
    # Modes
    [System.Collections.Generic.HashSet[string]]$Modes = @()
    if ($IsDir -or $directory) {
        $Modes.Add(!$symbolic ? "/J" : "/D") > $null
    }
    elseif (!$symbolic) {
        $Modes.Add("/H")
    }
    Write-Verbose "[Mode of mklink]: $Modes"

    # Handle Link Location
    $LinkNameExist = Test-Path $Name
    if (!$LinkNameExist) {}
    else {
        if ($backup) { Move-Item $Name $Name.FullName + $suffix }
        elseif ($force) { Remove-Item $Name -Force:$Force -Confirm:$Interactive } 
        else { Write-Error "$Name already existed, unable to create link"; return }
    }

    Write-Verbose "cmd /c mklink $(Join-String -InputObject $Modes -Separator ' ') $Name $path"
    $arguments = ("/c", "mklink") + $Modes + ($Name, $path)
    Write-Verbose "$arguments"
    Start-Process -FilePath cmd -ArgumentList $arguments `
        -NoNewWindow -WorkingDirectory (Get-Location) -Wait #>
}

# Update-FormatData -PrependPath $Env:USERPROFILE\Documents\PowerShell\man_format.format.ps1xml

function Get-DirectorySize() {
    [CmdletBinding()]
    [Alias("du")]
    param (
        [string]$directory = ".",
        [switch]$NoRecurse,
        [bool]$HumanReadAble = $true
    )
    $DirObj = Get-Item $directory
    if ($DirObj -isnot [System.IO.DirectoryInfo]) { Write-Error "a directory is required"; return }
    Get-ChildItem $DirObj -Recurse:(!$NoRecurse) |
    Measure-Object -Sum Length |
    Select-Object `
    @{Name         = ”Path”
        Expression = { $DirObj }
    }, @{Name      = ”Files”
        Expression = { $_.Count }
    }, @{Name      = ”Size”
        Expression = { $HumanReadAble ? $_.Sum / 1000000 : $_.Sum }
    }
}
