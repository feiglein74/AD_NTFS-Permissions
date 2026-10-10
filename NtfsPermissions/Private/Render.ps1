function Limit-NtfsText {
    # Kürzt nur auf ausdrücklichen Wunsch (Truncate > 0) und macht die Kürzung sichtbar
    param([string]$Text, [int]$Truncate = -1)
    if ($null -eq $Text) { return '' }
    if ($Truncate -le 0 -or $Text.Length -le $Truncate) { return $Text }
    '{0}… [+{1} Zeichen]' -f $Text.Substring(0, $Truncate), ($Text.Length - $Truncate)
}

function Write-NtfsLabel {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Bewusste farbige Konsolenausgabe von Show-NtfsPermission; Daten liefert Get-NtfsPermission')]
    param([string]$Label, [string]$Text, [System.ConsoleColor]$Color = 'Gray')
    Write-Host ('   {0,-10} ' -f $Label) -ForegroundColor DarkGray -NoNewline
    Write-Host $Text -ForegroundColor $Color
}

function Write-NtfsAceTable {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Bewusste farbige Konsolenausgabe von Show-NtfsPermission; Daten liefert Get-NtfsPermission')]
    param([object[]]$Aces, [switch]$Detail, [int]$Truncate = -1)

    if (-not $Aces) {
        Write-Host '   (keine Einträge)' -ForegroundColor DarkGray
        return
    }

    $headers = 'Typ', 'Konto', 'Kontotyp', 'Rechte', 'Gilt für', 'Herkunft'
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($ace in $Aces) {
        $who = if ($ace.Resolved) { $ace.Principal } else { "$($ace.Principal) (?)" }
        $origin = if ($ace.Inherited) { 'geerbt' } else { 'explizit' }
        $cells = @($ace.Type, $who, $ace.AccountType, $ace.Rights, $ace.AppliesTo, $origin) | ForEach-Object { Limit-NtfsText $_ $Truncate }
        $rows.Add(@($cells))
    }

    # Spaltenbreite = längster Wert der Spalte, ohne Obergrenze
    $widths = for ($c = 0; $c -lt $headers.Count; $c++) {
        $w = $headers[$c].Length
        foreach ($row in $rows) { if ($row[$c].Length -gt $w) { $w = $row[$c].Length } }
        $w
    }

    $line = { param($cells) '   ' + ((0..($cells.Count - 1) | ForEach-Object { ([string]$cells[$_]).PadRight($widths[$_]) }) -join '  ') }

    Write-Host (& $line $headers) -ForegroundColor DarkCyan
    Write-Host ('   ' + (($widths | ForEach-Object { '─' * $_ }) -join '  ')) -ForegroundColor DarkGray

    for ($i = 0; $i -lt $rows.Count; $i++) {
        $ace = $Aces[$i]
        $color = if ($ace.IsDeny) { 'Red' } elseif (-not $ace.Resolved) { 'Yellow' } elseif ($ace.Inherited) { 'Gray' } else { 'White' }
        Write-Host (& $line $rows[$i]) -ForegroundColor $color
        if ($Detail -or $ace.Rights -like '*Spezial*') {
            Write-Host ('   ' + (' ' * ($widths[0] + 2)) + '└ ' + $ace.RightsDetail) -ForegroundColor DarkGray
        }
    }
}

function Write-NtfsSddlHost {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Bewusste farbige Konsolenausgabe von Show-NtfsPermission; Daten liefert Get-NtfsPermission')]
    param($Item)

    $b = Get-NtfsSddlBreakdown $Item
    Write-Host ''
    Write-Host '   SDDL ' -ForegroundColor DarkCyan -NoNewline
    Write-Host $Item.Sddl -ForegroundColor DarkGray

    # Ausrichtungsbreite: überlange Tokens werden nicht gekürzt, sondern ragen in die nächste Spalte
    $tw = [Math]::Min(24, (@($b.Header | ForEach-Object { $_.Token.Length }) + 4 | Measure-Object -Maximum).Maximum)
    foreach ($h in $b.Header) {
        Write-Host ('     {0}  ' -f $h.Token.PadRight($tw)) -ForegroundColor Cyan -NoNewline
        Write-Host ('{0,-9}' -f $h.Label) -ForegroundColor DarkGray -NoNewline
        Write-Host $h.Meaning
    }

    foreach ($a in $b.Aces) {
        Write-Host ''
        Write-Host ('     #{0} {1}' -f $a.Index, $a.Raw) -ForegroundColor Cyan
        $pw = [Math]::Min(20, (@($a.Parts | ForEach-Object { $_.Token.Length }) + 2 | Measure-Object -Maximum).Maximum)
        foreach ($p in $a.Parts) {
            Write-Host ('        {0}  ' -f $p.Token.PadRight($pw)) -ForegroundColor DarkCyan -NoNewline
            Write-Host ('{0,-9}' -f $p.Label) -ForegroundColor DarkGray -NoNewline
            Write-Host $p.Meaning
        }
    }
}

function Write-NtfsItemHost {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Bewusste farbige Konsolenausgabe von Show-NtfsPermission; Daten liefert Get-NtfsPermission')]
    param($Item, [switch]$Sddl, [switch]$Detail, [int]$Truncate = -1)

    Write-Host ''
    Write-Host ' ■ ' -ForegroundColor Cyan -NoNewline
    Write-Host $(if ($Item.Path) { $Item.Path } else { '(SDDL)' }) -ForegroundColor White -NoNewline
    if ($Item.ItemType) { Write-Host "  [$($Item.ItemType)]" -ForegroundColor DarkGray } else { Write-Host '' }

    if ($Item.Error) {
        Write-NtfsLabel -Label 'Fehler' -Text $Item.Error -Color Red
        return
    }

    if ($Item.OwnerResolved) {
        Write-NtfsLabel -Label 'Besitzer' -Text "$($Item.Owner)  ($($Item.OwnerType))" -Color White
    }
    else {
        Write-NtfsLabel -Label 'Besitzer' -Text "$($Item.Owner)  ($($Item.OwnerType), nicht auflösbar)" -Color Yellow
    }
    if ($Item.InheritanceEnabled) {
        Write-NtfsLabel -Label 'Vererbung' -Text 'aktiv' -Color Green
    }
    else {
        Write-NtfsLabel -Label 'Vererbung' -Text 'DEAKTIVIERT - erbt nichts vom übergeordneten Ordner' -Color Yellow
    }
    if ($Item.NullDacl) { Write-NtfsLabel -Label 'Achtung' -Text 'NULL-DACL - jeder hat Vollzugriff!' -Color Red }
    if ($Item.IsCanonical -eq $false) { Write-NtfsLabel -Label 'Achtung' -Text 'Einträge stehen nicht in kanonischer Reihenfolge' -Color Yellow }
    if ($Item.Note) { Write-NtfsLabel -Label 'Hinweis' -Text $Item.Note -Color DarkYellow }
    Write-Host ''

    Write-NtfsAceTable -Aces $Item.Aces -Detail:$Detail -Truncate $Truncate

    if ($Item.AuditAces) {
        Write-Host ''
        Write-Host '   Überwachung (SACL)' -ForegroundColor DarkCyan
        Write-NtfsAceTable -Aces $Item.AuditAces -Detail:$Detail -Truncate $Truncate
    }

    if ($Sddl) { Write-NtfsSddlHost $Item }
}
