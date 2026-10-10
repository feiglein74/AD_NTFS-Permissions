function Show-NtfsPermission {
    <#
    .SYNOPSIS
        Zeigt NTFS-Berechtigungen farbig und übersichtlich in der Konsole an.

    .DESCRIPTION
        Nimmt Pfade, Get-ChildItem-Ausgabe oder Ergebnisse von Get-NtfsPermission / ConvertFrom-NtfsSddl entgegen.
        Farben: Rot = Verweigern, Gelb = nicht auflösbare SID, Weiß = expliziter Eintrag, Grau = geerbt.

    .PARAMETER InputObject
        Pfad, FileSystemInfo oder NtfsPermissions.Item.

    .PARAMETER Sddl
        Zusätzlich den SDDL-String Token für Token aufschlüsseln.

    .PARAMETER Detail
        Bei jedem Eintrag die Einzelrechte anzeigen (bei "Spezial" passiert das immer).

    .PARAMETER Truncate
        Tabellenzellen auf diese Anzahl Zeichen kürzen, damit die Tabelle in schmale Konsolen passt.
        Gekürzte Zellen werden mit "… [+N Zeichen]" markiert. Standard: -1 = nichts kürzen.

    .EXAMPLE
        Show-NtfsPermission D:\Daten -Sddl

    .EXAMPLE
        Show-NtfsPermission D:\Daten -Truncate 30

    .EXAMPLE
        Show-NtfsPermission D:\Daten -Recurse -Depth 2 -ExplicitOnly
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$InputObject,

        [switch]$Sddl,
        [switch]$Detail,
        [int]$Truncate = -1,

        [switch]$Recurse,
        [ValidateRange(0, [int]::MaxValue)]
        [int]$Depth,
        [switch]$IncludeFiles,
        [switch]$ExplicitOnly,
        [switch]$IncludeAudit
    )

    process {
        Resolve-NtfsInput -InputObject $InputObject -Options $PSBoundParameters | ForEach-Object {
            Write-NtfsItemHost -Item $_ -Sddl:$Sddl -Detail:$Detail -Truncate $Truncate
        }
    }

    end {
        Write-Host ''
    }
}
