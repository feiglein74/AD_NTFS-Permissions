$script:SddlAceTypes = @{
    A  = 'Zulassen'
    D  = 'Verweigern'
    AU = 'Überwachung'
    AL = 'Alarm'
    OA = 'Zulassen (Objekt)'
    OD = 'Verweigern (Objekt)'
    OU = 'Überwachung (Objekt)'
    OL = 'Alarm (Objekt)'
    XA = 'Zulassen (bedingt)'
    XD = 'Verweigern (bedingt)'
    XU = 'Überwachung (bedingt)'
    ZA = 'Zulassen (Objekt, bedingt)'
    ML = 'Integritätsstufe'
    RA = 'Ressourcenattribut'
    SP = 'Zentrale Zugriffsrichtlinie'
}

$script:SddlAceFlags = @{
    OI = 'Dateien erben'
    CI = 'Unterordner erben'
    NP = 'Nicht weitervererben'
    IO = 'Nur für Unterobjekte'
    ID = 'Geerbt'
    SA = 'Erfolg überwachen'
    FA = 'Fehler überwachen'
    TP = 'Vertrauensschutz'
    CR = 'Kritisch'
}

$script:SddlAclFlags = @{
    P                 = 'Geschützt (Vererbung deaktiviert)'
    AI                = 'Automatisch vererbt'
    AR                = 'Vererbung angefordert'
    NO_ACCESS_CONTROL = 'NULL-DACL - jeder hat Vollzugriff!'
}

function Split-NtfsSddl {
    # Zerlegt einen SDDL-String in Besitzer, Gruppe, ACL-Flags und die einzelnen ACE-Strings.
    # Klammertiefe wird mitgezählt, damit auch bedingte ACEs "(XA;;FR;;;WD;(...))" korrekt bleiben.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Sddl)

    $text = @{ O = ''; G = ''; D = ''; S = '' }
    $seen = @{}
    $aces = @{
        D = [System.Collections.Generic.List[string]]::new()
        S = [System.Collections.Generic.List[string]]::new()
    }
    $section = $null
    $depth = 0
    $start = 0

    for ($i = 0; $i -lt $Sddl.Length; $i++) {
        $c = $Sddl[$i]
        if ($depth -eq 0 -and $i + 1 -lt $Sddl.Length -and $Sddl[$i + 1] -eq ':' -and 'OGDS'.Contains([string]$c)) {
            $section = [string]$c
            $seen[$section] = $true
            $i++
            continue
        }
        if ($c -eq '(') {
            if ($depth -eq 0) { $start = $i }
            $depth++
        }
        elseif ($c -eq ')') {
            $depth--
            if ($depth -eq 0 -and $section -and $aces.ContainsKey($section)) {
                $aces[$section].Add($Sddl.Substring($start, $i - $start + 1))
            }
        }
        elseif ($depth -eq 0 -and $section) {
            $text[$section] += $c
        }
    }

    [pscustomobject]@{
        Owner     = $text.O
        Group     = $text.G
        HasDacl   = $seen.ContainsKey('D')
        DaclFlags = $text.D
        DaclAces  = $aces.D.ToArray()
        HasSacl   = $seen.ContainsKey('S')
        SaclFlags = $text.S
        SaclAces  = $aces.S.ToArray()
    }
}

function Split-NtfsSddlAce {
    # "(A;OICI;FA;;;BA)" -> Typ, Flags, Rechte, Objekt-GUID, geerbte Objekt-GUID, SID, Bedingung
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Ace)

    $p = $Ace.Substring(1, $Ace.Length - 2) -split ';', 7
    [pscustomobject]@{
        Type                = $p[0]
        Flags               = $p[1]
        Rights              = $p[2]
        ObjectGuid          = $p[3]
        InheritedObjectGuid = $p[4]
        Sid                 = $p[5]
        Condition           = if ($p.Count -gt 6) { $p[6] } else { $null }
    }
}

function ConvertFrom-NtfsAclFlag {
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$Flags, [switch]$Dacl)

    $tokens = @([regex]::Matches($Flags, 'NO_ACCESS_CONTROL|AI|AR|P') | ForEach-Object { $script:SddlAclFlags[$_.Value] })
    if ($Dacl -and $Flags -notmatch 'P|NO_ACCESS_CONTROL') { $tokens = @('Vererbung aktiv') + $tokens }
    if (-not $tokens) { return 'keine Flags' }
    $tokens -join ', '
}

function Get-NtfsSddlBreakdown {
    # Liefert eine Token-für-Token-Erklärung des SDDL-Strings eines NtfsPermissions.Item
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Item)

    $sp = Split-NtfsSddl $Item.Sddl

    $header = [System.Collections.Generic.List[object]]::new()
    if ($sp.Owner) { $header.Add([pscustomobject]@{ Token = "O:$($sp.Owner)"; Label = 'Besitzer'; Meaning = "$($Item.Owner)  ($($Item.OwnerType))" }) }
    if ($sp.Group) { $header.Add([pscustomobject]@{ Token = "G:$($sp.Group)"; Label = 'Gruppe'; Meaning = "$($Item.Group)  ($($Item.GroupType))" }) }
    if ($sp.HasDacl) {
        $header.Add([pscustomobject]@{ Token = "D:$($sp.DaclFlags)"; Label = 'DACL'; Meaning = (ConvertFrom-NtfsAclFlag $sp.DaclFlags -Dacl) })
    }
    if ($sp.HasSacl) {
        $header.Add([pscustomobject]@{ Token = "S:$($sp.SaclFlags)"; Label = 'SACL'; Meaning = (ConvertFrom-NtfsAclFlag $sp.SaclFlags) })
    }

    $aces = foreach ($ace in @($Item.Aces) + @($Item.AuditAces)) {
        if (-not $ace.AceSddl) { continue }
        $s = Split-NtfsSddlAce $ace.AceSddl
        $parts = [System.Collections.Generic.List[object]]::new()

        $typeText = $script:SddlAceTypes[$s.Type]
        if (-not $typeText) { $typeText = $ace.Type }
        $parts.Add([pscustomobject]@{ Token = $s.Type; Label = 'Typ'; Meaning = $typeText })

        if ($s.Flags) {
            $flagText = @([regex]::Matches($s.Flags, '..') | ForEach-Object {
                    $t = $script:SddlAceFlags[$_.Value]
                    if ($t) { $t } else { $_.Value }
                }) -join ', '
            $parts.Add([pscustomobject]@{ Token = $s.Flags; Label = 'Flags'; Meaning = "$flagText -> $($ace.AppliesTo)" })
        }
        else {
            $parts.Add([pscustomobject]@{ Token = '-'; Label = 'Flags'; Meaning = "keine -> $($ace.AppliesTo)" })
        }

        $rightsText = "$($ace.Rights)  [$($ace.AccessMask)]"
        if ($ace.Rights -like '*Spezial*') { $rightsText += ": $($ace.RightsDetail)" }
        $parts.Add([pscustomobject]@{ Token = $s.Rights; Label = 'Rechte'; Meaning = $rightsText })

        if ($s.ObjectGuid) { $parts.Add([pscustomobject]@{ Token = $s.ObjectGuid; Label = 'Objekt'; Meaning = 'Objekttyp-GUID' }) }
        if ($s.InheritedObjectGuid) { $parts.Add([pscustomobject]@{ Token = $s.InheritedObjectGuid; Label = 'Erbt an'; Meaning = 'Geerbter Objekttyp-GUID' }) }

        $who = $ace.Principal
        if ($s.Sid -notlike 'S-*') { $who += "  [$($ace.Sid)]" }
        $who += "  · $($ace.AccountType)"
        if ($ace.AccountInfo) { $who += " - $($ace.AccountInfo)" }
        $parts.Add([pscustomobject]@{ Token = $s.Sid; Label = 'Konto'; Meaning = $who })

        if ($s.Condition) { $parts.Add([pscustomobject]@{ Token = $s.Condition; Label = 'Bedingung'; Meaning = 'Bedingter Ausdruck (Dynamic Access Control)' }) }

        [pscustomobject]@{ Raw = $ace.AceSddl; Index = $ace.Index; Ace = $ace; Parts = $parts.ToArray() }
    }

    [pscustomobject]@{ Sddl = $Item.Sddl; Header = $header.ToArray(); Aces = @($aces) }
}
