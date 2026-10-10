function Read-NtfsItem {
    [CmdletBinding()]
    param([string]$Path, [bool]$IsContainer, [bool]$Audit)

    try {
        $acl = if ($Audit) { Get-Acl -LiteralPath $Path -Audit -ErrorAction Stop } else { Get-Acl -LiteralPath $Path -ErrorAction Stop }
        ConvertTo-NtfsPermissionItem -Sddl $acl.Sddl -Path $Path -IsContainer $IsContainer
    }
    catch {
        ConvertTo-NtfsPermissionItem -Path $Path -IsContainer $IsContainer -ErrorMessage $_.Exception.Message
    }
}

function Read-NtfsTree {
    # Liest ein Objekt und (bei Depth > 0) rekursiv dessen Inhalt. Junctions/Symlinks werden nicht verfolgt.
    [CmdletBinding()]
    param(
        [string]$Path,
        [bool]$IsContainer,
        [int]$Depth,
        [bool]$IncludeFiles,
        [bool]$ExplicitOnly,
        [bool]$Audit,
        [bool]$IsRoot
    )

    $item = Read-NtfsItem -Path $Path -IsContainer $IsContainer -Audit $Audit
    $children = @()

    if ($IsContainer -and $Depth -gt 0) {
        $info = [System.IO.DirectoryInfo]::new($Path)
        if (-not $IsRoot -and ($info.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            $item.Note = 'Verknüpfung (Junction/Symlink) - Inhalt wird nicht verfolgt'
        }
        else {
            try {
                $children = @($info.GetFileSystemInfos() | Sort-Object -Property Name)
            }
            catch {
                $msg = $_.Exception.Message
                if ($_.Exception.InnerException) { $msg = $_.Exception.InnerException.Message }
                $item.Note = "Inhalt nicht auflistbar: $msg"
            }
        }
    }

    if ($IsRoot -or -not $ExplicitOnly -or (Test-NtfsNotable $item)) { $item }

    foreach ($child in $children) {
        $isDir = $child -is [System.IO.DirectoryInfo]
        if (-not $isDir -and -not $IncludeFiles) { continue }
        Read-NtfsTree -Path $child.FullName -IsContainer $isDir -Depth ($Depth - 1) `
            -IncludeFiles $IncludeFiles -ExplicitOnly $ExplicitOnly -Audit $Audit -IsRoot $false
    }
}

function Resolve-NtfsInput {
    # Gemeinsame Eingabelogik für Show-/Export-: fertige Items durchreichen, Pfade frisch einlesen.
    [CmdletBinding()]
    param($InputObject, [System.Collections.IDictionary]$Options)

    if (Test-NtfsItemObject $InputObject) { return $InputObject }

    $path = if ($InputObject -is [System.IO.FileSystemInfo]) { $InputObject.FullName } else { [string]$InputObject }
    $forward = @{ Path = $path }
    foreach ($key in 'Recurse', 'Depth', 'IncludeFiles', 'ExplicitOnly', 'IncludeAudit') {
        if ($Options.Keys -contains $key) { $forward[$key] = $Options[$key] }
    }
    Get-NtfsPermission @forward
}
