if (!(Get-Module PSReadLine)) { Import-Module PSReadLine }

Set-PSReadLineKeyHandler -Chord "Ctrl+u" -Function BackwardDeleteLine
Set-PSReadLineKeyHandler -Chord "Ctrl+k" -Function ForwardDeleteLine

Set-PSReadLineKeyHandler -Chord "Ctrl+b" -Function BackwardChar
Set-PSReadLineKeyHandler -Chord "Ctrl+e" -Function EndOfLine
Set-PSReadLineKeyHandler -Chord "Alt+b" -Function BackwardWord

Set-PSReadLineKeyHandler -Chord "Alt+d" -Function DeleteWord

Function get_all_child_item ($path) { @(Get-ChildItem -Hidden $path) + @(Get-ChildItem $path) }
Set-Alias -Name la -Value get_all_child_item
Set-Alias -Name ll -Value Get-ChildItem

Set-Alias -Name touch -Value New-Item
Set-Alias -Name ifconfig -Value ipconfig.exe
Set-Alias -Name ip -Value ipconfig.exe

$SEP = [IO.Path]::DirectorySeparatorChar

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
        # PointAt
        [string]$Target, 
        [Parameter(Position = 1)]
        # LinkName
        [string]$Name, 
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
        [Alias("P")]
        [switch]$physical, #TODO
        
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
        [switch]${no-target-directory}, #TODO
        [switch]$help, #TODO
        [switch]$version #TODO
    )

    <# Creates a symbolic link.
    MKLINK [[/D] | [/H] | [/J]] Link Target
        /D      Creates a directory symbolic link. Default is a file symbolic link.
        /H      Creates a hard link instead of a symbolic link.
        /J      Creates a Directory Junction.
        Link    Specifies the new symbolic link name.
        Target  Specifies the path (relative or absolute) that the new link refers to. #>

    # Valid/Preprocess/Generate Target/Name
    if ($Target) { $PointAt = $Target }
    else {
        Write-Error "Argument Target is required"
        return
    }
    if ($Name.Length -eq 0) {
        if ($Target -match '^([^\\/]+)$') {
            $LinkName = $Matches[1]
        }
        elseif ($Target -match '^.*[\\/](.+?)$') {
            $LinkName = $Matches[1]
        }

    }
    else { $LinkName = $Name }


    if (Test-Path $Target) {
        $FileObject = Get-Item $Target
        $IsDir = $FileObject -is [System.IO.DirectoryInfo] #$object.PSIsContainer
    }
    else {
        $FileObject = $null
        Write-Warning "Target:$Target not exists"
    }


    $o_arg_target = $PointAt
    if ($relative) {
        if ($FileObject) {
            $o_arg_target = Resolve-Path $Target -Relative 
            Write-Debug "Resolved relative: $o_arg_target"
        }
        else {
            Write-Error "Target:$Target not exists, unable to resolve relative path"
        }
    }

    if (${target-directory}) { $o_arg_link_loc = "${target-directory}$SEP$LinkName" }
    else { $o_arg_link_loc = $LinkName }

    # Powershell wrapper
    $o_arg_type = 'SymbolicLink'
    if ($IsDir -or $directory) {
        $o_arg_type = $symbolic ? 'Junction' : 'SymbolicLink'
    }

    # Check target path
    if ((Test-Path $o_arg_link_loc) -and $backup) {
        $new_loc = $o_arg_link_loc
        while ($true) {
            $new_loc += $suffix
            if (-not (Test-Path $new_loc)) { break }
        }
        Move-Item $o_arg_link_loc $new_loc
    }
    New-Item -ItemType $o_arg_type -Target $o_arg_target -Path $o_arg_link_loc -Force:$force -Confirm:$interactive
    
}

function Get-DirectorySize() {
    [CmdletBinding()]
    [Alias("du")]
    param (
        [string]$directory = ".",
        [switch]$NoRecurse,
        [Parameter(Mandatory = $false)]
        [bool]$HumanReadAble = $true
    )
    $DirObj = Get-Item $directory
    if ($DirObj -isnot [System.IO.DirectoryInfo]) { Write-Error "a directory is required"; return }
    Get-ChildItem $DirObj -Recurse:(!$NoRecurse) |
    Measure-Object -Sum Length |
    Select-Object `
    @{
        Name       = ”Path”
        Expression = { $DirObj } 
    },
    @{
        Name       = ”Files”
        Expression = { $_.Count } 
    },
    @{
        Name       = ”Size”
        Expression = { $HumanReadAble ? $_.Sum / 1000000 : $_.Sum } 
    }
}
