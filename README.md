# NtfsPermissions

PowerShell-Modul, um NTFS-Berechtigungen **lesbar** zu machen:

- liest Berechtigungen auch von Ordnern, auf die man selbst keinen Zugriff hat (über `SeBackupPrivilege`, als Administrator)
- fasst Rechte so zusammen wie der Explorer („Ändern“, „Lesen, Ausführen“, „Spezial“ …) und übersetzt generische Rechte (`GA`, `GR` …)
- übersetzt die Vererbungsflags in die Explorer-Spalte „Gilt für“
- **schlüsselt SDDL Token für Token auf**, z. B. `(A;OICI;0x1200a9;;;BU)`
- markiert Auffälligkeiten: deaktivierte Vererbung, Verweigern-Einträge, verwaiste SIDs, nicht-kanonische Reihenfolge, NULL-DACL
- farbige Konsolenansicht, eigenständiger HTML-Bericht, CSV-Export über die Pipeline
- läuft unter Windows PowerShell 5.1 und PowerShell 7

## Installation

```powershell
# einmalig für die Sitzung
Import-Module .\NtfsPermissions\NtfsPermissions.psd1

# dauerhaft: Ordner NtfsPermissions in einen Pfad aus $env:PSModulePath kopieren, z. B.
Copy-Item .\NtfsPermissions "$HOME\Documents\PowerShell\Modules\" -Recurse
```

Für Ordner ohne eigenen Zugriff PowerShell **als Administrator** starten. Ohne Adminrechte funktioniert alles, was man selbst lesen darf. Das Modul gibt dann einmal eine Warnung aus.

## Befehle

| Befehl | Zweck |
|---|---|
| `Show-NtfsPermission` | farbige Konsolenansicht, optional mit `-Sddl`-Aufschlüsselung |
| `Get-NtfsPermission` | liefert Objekte zum Weiterverarbeiten (Filtern, CSV …) |
| `ConvertFrom-NtfsSddl` | schlüsselt einen beliebigen SDDL-String auf, ohne Dateisystemzugriff |
| `Export-NtfsPermissionReport` | HTML-Bericht mit Filter, Suche und Hell-/Dunkelmodus |

Alle Befehle haben eine Hilfe: `Get-Help Show-NtfsPermission -Full`.

## Beispiele

```powershell
# Ein Ordner, mit SDDL-Aufschlüsselung
Show-NtfsPermission D:\Daten\Projekte -Sddl

# Nur Abweichungen in den ersten 3 Ebenen (Vererbung aus, explizite Einträge, Fehler)
Show-NtfsPermission D:\Daten -Recurse -Depth 3 -ExplicitOnly

# Schmale Konsole: Zellen auf 30 Zeichen kürzen (gekürzte Zellen zeigen "… [+N Zeichen]")
Show-NtfsPermission D:\Daten -Truncate 30

# HTML-Bericht einer Freigabe
Export-NtfsPermissionReport \\fs01\abteilungen -Recurse -ExplicitOnly -OutFile .\abteilungen.html -Open

# Flache Liste aller Einträge als CSV (für Excel: Semikolon)
(Get-NtfsPermission D:\Daten -Recurse).Aces |
    Export-Csv .\rechte.csv -NoTypeInformation -Delimiter ';' -Encoding UTF8

# Wo hat ein bestimmtes Konto explizite Rechte?
(Get-NtfsPermission D:\Daten -Recurse -ExplicitOnly).Aces |
    Where-Object { -not $_.Inherited -and $_.Principal -like '*\GG_Vertrieb*' } |
    Select-Object Path, Rights, AppliesTo

# Verwaiste SIDs finden
(Get-NtfsPermission D:\Daten -Recurse -ExplicitOnly).Aces |
    Where-Object { -not $_.Resolved } | Select-Object Path, Sid -Unique

# SDDL aus einem Ticket / Log verstehen
ConvertFrom-NtfsSddl 'O:BAG:SYD:PAI(A;OICI;FA;;;BA)(A;CI;DCLCRPCR;;;BU)' | Show-NtfsPermission -Sddl
```

## Beispielausgabe

```
 ■ C:\ProgramData  [Ordner]
   Besitzer   NT-AUTORITÄT\SYSTEM
   Vererbung  DEAKTIVIERT - erbt nichts vom übergeordneten Ordner

   Typ       Konto                         Rechte                   Gilt für                                Herkunft
   ────────  ────────────────────────────  ───────────────────────  ──────────────────────────────────────  ────────
   Zulassen  ERSTELLER-BESITZER            Vollzugriff (generisch)  Nur Unterordner und Dateien             explizit
   Zulassen  NT-AUTORITÄT\SYSTEM           Vollzugriff              Dieser Ordner, Unterordner und Dateien  explizit
   Zulassen  VORDEFINIERT\Administratoren  Vollzugriff              Dieser Ordner, Unterordner und Dateien  explizit
   Zulassen  VORDEFINIERT\Benutzer         Lesen, Ausführen         Dieser Ordner, Unterordner und Dateien  explizit
   Zulassen  VORDEFINIERT\Benutzer         Schreiben                Dieser Ordner und Unterordner           explizit

   SDDL O:SYG:SYD:PAI(A;OICIIO;GA;;;CO)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;0x1200a9;;;BU)(A;CI;DCLCRPCR;;;BU)
     O:SY   Besitzer NT-AUTORITÄT\SYSTEM
     G:SY   Gruppe   NT-AUTORITÄT\SYSTEM
     D:PAI  DACL     Geschützt (Vererbung deaktiviert), Automatisch vererbt

     #5 (A;CI;DCLCRPCR;;;BU)
        A         Typ      Zulassen
        CI        Flags    Unterordner erben -> Dieser Ordner und Unterordner
        DCLCRPCR  Rechte   Schreiben  [0x00000116]
        BU        Konto    VORDEFINIERT\Benutzer  [S-1-5-32-545]
```

Farben: **rot** = Verweigern, **gelb** = nicht auflösbare SID, **weiß** = expliziter Eintrag, **grau** = geerbt.

## Die Objekte

`Get-NtfsPermission` und `ConvertFrom-NtfsSddl` liefern pro Ordner/Datei ein `NtfsPermissions.Item`:

| Eigenschaft | Bedeutung |
|---|---|
| `Path`, `ItemType` | Pfad, `Ordner` oder `Datei` |
| `Owner`, `OwnerSid`, `OwnerResolved` | Besitzer |
| `InheritanceEnabled` | `$false` = Vererbung deaktiviert (SDDL-Flag `P`) |
| `IsCanonical`, `NullDacl` | Prüfungen auf fehlerhafte DACLs |
| `AceCount`, `ExplicitCount`, `DenyCount` | Zähler |
| `Aces`, `AuditAces` | die Einträge (siehe unten) |
| `Sddl` | Original-SDDL |
| `Error`, `Note` | ACL nicht lesbar / Hinweis (z. B. Inhalt nicht auflistbar, Junction) |

Jeder Eintrag in `.Aces` (`NtfsPermissions.Ace`) enthält `Path`, `Type`, `Principal`, `Sid`, `Resolved`, `Rights`, `RightsDetail`, `AccessMask`, `AppliesTo`, `Inherited`, `IsDeny` und `AceSddl`. Weil `Path` in jedem Eintrag steht, lässt sich `.Aces` direkt als flache Tabelle exportieren.

## SDDL-Spickzettel

| Teil | Bedeutung |
|---|---|
| `O:` / `G:` | Besitzer / primäre Gruppe |
| `D:` / `S:` | DACL (Berechtigungen) / SACL (Überwachung) |
| `P` · `AI` · `AR` | geschützt (Vererbung aus) · automatisch vererbt · Vererbung angefordert |
| `(Typ;Flags;Rechte;;;Konto)` | ein Eintrag (ACE) |
| `A` · `D` · `AU` | Zulassen · Verweigern · Überwachung |
| `OI` · `CI` · `IO` · `NP` · `ID` | Dateien erben · Unterordner erben · nur Unterobjekte · nur eine Ebene · geerbt |
| `FA` · `FR` · `FW` · `FX` | Vollzugriff · Lesen · Schreiben · Ausführen |
| `GA` · `GR` · `GW` · `GX` | generische Rechte (typisch bei `CO` = Ersteller-Besitzer) |
| `BA` · `BU` · `SY` · `CO` · `AU` · `WD` | Administratoren · Benutzer · SYSTEM · Ersteller-Besitzer · Authentifizierte Benutzer · Jeder |

## Hinweise

- **SeBackupPrivilege** wird nur für den eigenen PowerShell-Prozess aktiviert und gilt bis zu dessen Ende. Am System wird nichts verändert, das Modul liest nur.
- **Überwachung (SACL)** gibt es nur mit `-IncludeAudit`; dafür braucht es zusätzlich `SeSecurityPrivilege` (Administrator).
- **Junctions/Symlinks** (z. B. `C:\Users\All Users`) werden aufgeführt, aber nicht durchlaufen.
- **Verwaiste SIDs**: Wenn ein Domain Controller nicht erreichbar ist, erscheinen auch gültige Domänenkonten als „nicht auflösbar“.
- **Lange Pfade (> 260 Zeichen)** funktionieren unter PowerShell 7 problemlos. Unter Windows PowerShell 5.1 nur, wenn `LongPathsEnabled` im System aktiviert ist.

## Entwicklung

```powershell
Invoke-Pester .\Tests                    # Tests (PS 7 und powershell.exe für 5.1)
Invoke-ScriptAnalyzer -Path . -Recurse   # Linting, muss 0 Findings liefern
```

Skriptdateien als **UTF-8 mit BOM** speichern, sonst zeigt Windows PowerShell 5.1 die Umlaute falsch an.
Design-Entscheidungen stehen in [DESIGN-PRINCIPLES.md](DESIGN-PRINCIPLES.md), Änderungen in [CHANGELOG.md](CHANGELOG.md) und offene Punkte in [TODO.md](TODO.md).

## Lizenz

[MIT](LICENSE)
