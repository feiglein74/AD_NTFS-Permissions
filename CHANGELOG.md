# Changelog

Alle relevanten Änderungen an diesem Projekt werden hier dokumentiert.
Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionierung nach [SemVer](https://semver.org/lang/de/).

## [Unreleased]

## [0.1.0] - 2026-10-10

### Hinzugefügt
- `Get-NtfsPermission`: liest Berechtigungen von Ordnern und Dateien, optional rekursiv (`-Recurse`, `-Depth`, `-IncludeFiles`, `-ExplicitOnly`, `-IncludeAudit`)
- Aktivierung von `SeBackupPrivilege` (bzw. `SeSecurityPrivilege` für die SACL), um auch Objekte ohne eigenen Zugriff zu lesen
- `ConvertFrom-NtfsSddl`: schlüsselt beliebige SDDL-Strings ohne Dateisystemzugriff auf, nimmt auch `Get-Acl`-Ausgabe entgegen
- `Show-NtfsPermission`: farbige Konsolenansicht mit optionaler SDDL-Aufschlüsselung (`-Sddl`), Einzelrechten (`-Detail`) und transparenter Kürzung (`-Truncate`)
- `Export-NtfsPermissionReport`: eigenständiger HTML-Bericht mit Kennzahlen, Filter, Suche und Hell-/Dunkelmodus
- Rechte-Zusammenfassung wie im Explorer, Übersetzung generischer Rechte, Spalte „Gilt für“
- Erkennung von deaktivierter Vererbung, verwaisten SIDs, nicht-kanonischer Reihenfolge und NULL-DACL
- SID-Auflösung über `LookupAccountSid` mit Kontotyp (`AccountType`: Benutzer, Gruppe, Gruppe (lokal), Bekannte Gruppe, Computer …), Rückfall auf eine Tabelle bekannter SIDs, bekannte Domänen-RIDs (z. B. 512 = Domänen-Admins) und SID-Bereiche (Dienste, IIS-AppPools, VMs, App-Capabilities); Erläuterung in `AccountInfo`; `OwnerType`/`GroupType` am Objekt
- Englischer README-Kopf, Demo-GIF und Bericht-Screenshot aus Beispieldaten (`docs/`)
- Manifest-Metadaten für die PowerShell Gallery (`ProjectUri`, `LicenseUri`, `ReleaseNotes`, Tags)
- GitHub-Action: Pester unter PowerShell 7 und 5.1, PSScriptAnalyzer, `Test-ModuleManifest`
- Standardansichten (`Format.ps1xml`) für Objekte und Einträge
- Pester-Tests für Windows PowerShell 5.1 und PowerShell 7
