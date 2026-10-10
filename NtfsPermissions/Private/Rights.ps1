$script:Rights = @{
    Synchronize    = 0x00100000L
    FullControl    = 0x001F01FFL
    Modify         = 0x001301BFL
    ReadAndExecute = 0x001200A9L
    Read           = 0x00120089L
    Write          = 0x00100116L   # inkl. Synchronize, so wie der Explorer "Schreiben" setzt
    GenericAll     = 0x10000000L
    GenericExecute = 0x20000000L
    GenericWrite   = 0x40000000L
    GenericRead    = 0x80000000L
}

# Abbildung der generischen Rechte auf Dateirechte (FILE_GENERIC_*)
$script:GenericMapping = @{
    GenericAll     = 0x001F01FFL
    GenericRead    = 0x00120089L
    GenericWrite   = 0x00120116L
    GenericExecute = 0x001200A0L
}

# Einzelrechte in der Reihenfolge des Explorer-Dialogs "Erweiterte Berechtigungen"
$script:FileRights = @(
    @{ Bit = 0x00000020L; Name = 'Ordner durchsuchen / Datei ausführen' }
    @{ Bit = 0x00000001L; Name = 'Ordner auflisten / Daten lesen' }
    @{ Bit = 0x00000080L; Name = 'Attribute lesen' }
    @{ Bit = 0x00000008L; Name = 'Erweiterte Attribute lesen' }
    @{ Bit = 0x00000002L; Name = 'Dateien erstellen / Daten schreiben' }
    @{ Bit = 0x00000004L; Name = 'Ordner erstellen / Daten anhängen' }
    @{ Bit = 0x00000100L; Name = 'Attribute schreiben' }
    @{ Bit = 0x00000010L; Name = 'Erweiterte Attribute schreiben' }
    @{ Bit = 0x00000040L; Name = 'Unterordner und Dateien löschen' }
    @{ Bit = 0x00010000L; Name = 'Löschen' }
    @{ Bit = 0x00020000L; Name = 'Berechtigungen lesen' }
    @{ Bit = 0x00040000L; Name = 'Berechtigungen ändern' }
    @{ Bit = 0x00080000L; Name = 'Besitz übernehmen' }
    @{ Bit = 0x01000000L; Name = 'Überwachung (SACL) verwalten' }
    @{ Bit = 0x02000000L; Name = 'Maximal zulässig' }
)

function Get-NtfsRightsInfo {
    # Fasst eine Zugriffsmaske wie im Explorer zusammen ("Ändern", "Lesen + Schreiben", "Spezial" ...)
    [CmdletBinding()]
    param([long]$Mask)

    $r = $script:Rights
    $generic = ($Mask -band 0xF0000000L) -ne 0

    $m = $Mask -band 0x0FFFFFFFL
    foreach ($g in $script:GenericMapping.Keys) {
        if ($Mask -band $r[$g]) { $m = $m -bor $script:GenericMapping[$g] }
    }

    $n = $m -bor $r.Synchronize
    $covered = $r.Synchronize
    $names = [System.Collections.Generic.List[string]]::new()

    if (($n -band $r.FullControl) -eq $r.FullControl) {
        $names.Add('Vollzugriff'); $covered = $r.FullControl
    }
    elseif (($n -band $r.Modify) -eq $r.Modify) {
        $names.Add('Ändern'); $covered = $r.Modify
    }
    else {
        if (($n -band $r.ReadAndExecute) -eq $r.ReadAndExecute) {
            $names.Add('Lesen, Ausführen'); $covered = $covered -bor $r.ReadAndExecute
        }
        elseif (($n -band $r.Read) -eq $r.Read) {
            $names.Add('Lesen'); $covered = $covered -bor $r.Read
        }
        if (($n -band $r.Write) -eq $r.Write) {
            $names.Add('Schreiben'); $covered = $covered -bor $r.Write
        }
    }
    if (($n -band -bnot $covered) -ne 0) { $names.Add('Spezial') }

    $summary = if ($names.Count) { $names -join ' + ' } else { 'Keine' }
    if ($generic) { $summary += ' (generisch)' }

    $detail = foreach ($e in $script:FileRights) {
        if (($m -band $e.Bit) -ne 0) { $e.Name }
    }

    [pscustomobject]@{
        Summary       = $summary
        Detail        = @($detail)
        EffectiveMask = $m
    }
}

function Get-NtfsAppliesTo {
    # Übersetzt die Vererbungsflags in den Text der Explorer-Spalte "Gilt für"
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [System.Security.AccessControl.AceFlags]$Flags,
        [bool]$IsContainer
    )

    if (-not $IsContainer) { return 'Nur diese Datei' }

    # Rechnen mit [int]: -band auf dem Byte-Enum AceFlags wirft unter Windows PowerShell 5.1 InvalidCast
    $v = [int]$Flags
    $oi = ($v -band 0x01) -ne 0   # ObjectInherit
    $ci = ($v -band 0x02) -ne 0   # ContainerInherit
    $np = ($v -band 0x04) -ne 0   # NoPropagateInherit
    $io = ($v -band 0x08) -ne 0   # InheritOnly

    if (-not ($oi -or $ci)) {
        if ($io) { return 'Wirkungslos (IO ohne Vererbung)' }
        return 'Nur dieser Ordner'
    }

    $target = if ($io) {
        if ($oi -and $ci) { 'Nur Unterordner und Dateien' } elseif ($ci) { 'Nur Unterordner' } else { 'Nur Dateien' }
    }
    else {
        if ($oi -and $ci) { 'Dieser Ordner, Unterordner und Dateien' } elseif ($ci) { 'Dieser Ordner und Unterordner' } else { 'Dieser Ordner und Dateien' }
    }
    if ($np) { $target += ' (nur eine Ebene)' }
    $target
}

function Get-NtfsAceTypeName {
    [CmdletBinding()]
    param($Ace)

    $t = [string]$Ace.AceType
    $name = switch -Wildcard ($t) {
        'AccessAllowed*' { 'Zulassen' }
        'AccessDenied*'  { 'Verweigern' }
        'SystemAudit*'   { 'Überwachung' }
        'SystemAlarm*'   { 'Alarm' }
        default          { "Typ $t" }
    }
    if ($t -like '*Callback*') { $name += ' (bedingt)' }

    if ($t -like 'SystemAudit*') {
        $v = [int]$Ace.AceFlags
        $what = @()
        if ($v -band 0x40) { $what += 'Erfolg' }   # SuccessfulAccess
        if ($v -band 0x80) { $what += 'Fehler' }   # FailedAccess
        if ($what) { $name += " ($($what -join ', '))" }
    }
    $name
}
