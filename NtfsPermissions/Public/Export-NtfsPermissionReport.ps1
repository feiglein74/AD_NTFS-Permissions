function Export-NtfsPermissionReport {
    <#
    .SYNOPSIS
        Erstellt einen eigenständigen HTML-Bericht (eine Datei, kein Internet nötig).

    .DESCRIPTION
        Der Bericht enthält eine Zusammenfassung, eine Filterleiste ("Nur Auffälligkeiten",
        "Geerbte Einträge ausblenden", Volltextsuche), eine Karte pro Objekt und die
        aufklappbare SDDL-Aufschlüsselung. Hell-/Dunkelmodus folgt dem Betriebssystem.

    .PARAMETER InputObject
        Pfad, FileSystemInfo oder NtfsPermissions.Item (z. B. aus Get-NtfsPermission).

    .PARAMETER OutFile
        Zieldatei, z. B. .\bericht.html

    .PARAMETER Open
        Den Bericht nach dem Erstellen im Standardbrowser öffnen.

    .EXAMPLE
        Export-NtfsPermissionReport D:\Daten -Recurse -Depth 3 -OutFile .\daten.html -Open

    .EXAMPLE
        Get-NtfsPermission \\server\freigabe -Recurse -ExplicitOnly | Export-NtfsPermissionReport -OutFile .\abweichungen.html
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$OutFile,

        [string]$Title = 'NTFS-Berechtigungen',

        [switch]$Recurse,
        [ValidateRange(0, [int]::MaxValue)]
        [int]$Depth,
        [switch]$IncludeFiles,
        [switch]$ExplicitOnly,
        [switch]$IncludeAudit,

        [switch]$Open,
        [switch]$PassThru
    )

    begin {
        $items = [System.Collections.Generic.List[object]]::new()
    }

    process {
        Resolve-NtfsInput -InputObject $InputObject -Options $PSBoundParameters | ForEach-Object { $items.Add($_) }
    }

    end {
        $file = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($OutFile)
        $html = ConvertTo-NtfsHtml -Items $items.ToArray() -Title $Title
        [System.IO.File]::WriteAllText($file, $html, [System.Text.UTF8Encoding]::new($false))
        Write-Verbose "Bericht geschrieben: $file ($($items.Count) Objekte)"
        if ($Open) { Invoke-Item -LiteralPath $file }
        if ($PassThru) { Get-Item -LiteralPath $file }
    }
}
