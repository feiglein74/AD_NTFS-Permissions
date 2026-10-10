function Get-NtfsPermission {
    <#
    .SYNOPSIS
        Liest NTFS-Berechtigungen von Ordnern und Dateien und liefert aufgeschlüsselte Objekte.

    .DESCRIPTION
        Aktiviert (wenn möglich) SeBackupPrivilege, damit auch Objekte gelesen werden können,
        auf die das eigene Konto keinen Zugriff hat - dafür muss PowerShell als Administrator laufen.
        Ohne Adminrechte werden nur Objekte gelesen, auf die man selbst Zugriff hat.

        Jedes Ergebnis (NtfsPermissions.Item) enthält Besitzer, Vererbungsstatus, die SDDL und in
        .Aces jeden Berechtigungseintrag mit aufgelöstem Konto, zusammengefassten Rechten und "Gilt für".

    .PARAMETER Path
        Ordner oder Datei. Nimmt auch Get-ChildItem-Ausgabe über die Pipeline entgegen.

    .PARAMETER Recurse
        Unterordner einbeziehen.

    .PARAMETER Depth
        Maximale Rekursionstiefe (nur mit -Recurse). 1 = nur die direkten Unterordner.

    .PARAMETER IncludeFiles
        Bei -Recurse auch Dateien auswerten (Standard: nur Ordner).

    .PARAMETER ExplicitOnly
        Bei -Recurse nur Objekte ausgeben, die vom Normalfall abweichen: deaktivierte Vererbung,
        explizite Einträge, nicht-kanonische Reihenfolge, Lesefehler. Der Startordner wird immer ausgegeben.

    .PARAMETER IncludeAudit
        Zusätzlich die Überwachungseinträge (SACL) lesen. Benötigt SeSecurityPrivilege (Administrator).

    .EXAMPLE
        Get-NtfsPermission D:\Daten

    .EXAMPLE
        Get-NtfsPermission D:\Daten -Recurse -ExplicitOnly | Show-NtfsPermission

    .EXAMPLE
        (Get-NtfsPermission D:\Daten -Recurse).Aces | Export-Csv rechte.csv -NoTypeInformation -Delimiter ';' -Encoding UTF8
    #>
    [CmdletBinding()]
    [OutputType('NtfsPermissions.Item')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'LiteralPath')]
        [string[]]$Path,

        [switch]$Recurse,

        [ValidateRange(0, [int]::MaxValue)]
        [int]$Depth = [int]::MaxValue,

        [switch]$IncludeFiles,

        [switch]$ExplicitOnly,

        [switch]$IncludeAudit
    )

    begin {
        if (-not (Enable-NtfsPrivilege 'SeBackupPrivilege') -and -not $script:BackupWarned) {
            Write-Warning 'SeBackupPrivilege nicht verfügbar (PowerShell nicht als Administrator gestartet?) - es werden nur Objekte gelesen, auf die du selbst Zugriff hast.'
            $script:BackupWarned = $true
        }
        $audit = $false
        if ($IncludeAudit) {
            if (Enable-NtfsPrivilege 'SeSecurityPrivilege') { $audit = $true }
            else { Write-Warning 'SeSecurityPrivilege nicht verfügbar - Überwachungseinträge (SACL) werden übersprungen.' }
        }
        $maxDepth = if ($Recurse) { $Depth } else { 0 }
    }

    process {
        foreach ($p in $Path) {
            try {
                $resolved = Resolve-Path -LiteralPath $p -ErrorAction Stop
            }
            catch {
                Write-Error -Message "Pfad nicht gefunden: $p" -TargetObject $p -Category ObjectNotFound
                continue
            }
            foreach ($r in $resolved) {
                if ($r.Provider.Name -ne 'FileSystem') {
                    Write-Error -Message "Kein Dateisystempfad: $p" -TargetObject $p -Category InvalidArgument
                    continue
                }
                $full = $r.ProviderPath
                $isDir = [System.IO.Directory]::Exists($full)
                Read-NtfsTree -Path $full -IsContainer $isDir -Depth $maxDepth -IncludeFiles $IncludeFiles.IsPresent `
                    -ExplicitOnly $ExplicitOnly.IsPresent -Audit $audit -IsRoot $true
            }
        }
    }
}
