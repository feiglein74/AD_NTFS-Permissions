# TODO

## Offen

- [ ] Lesen ohne eigenen Zugriff über SeBackupPrivilege in einer Admin-Sitzung verifizieren (bisher nur ohne Adminrechte getestet)
- [ ] AD-Gruppen expandieren: welche Benutzer haben über welche (verschachtelte) Gruppe Zugriff
- [ ] PowerShell Gallery: `Publish-Module -Path .\NtfsPermissions -NuGetApiKey <key>` (Nutzer), danach README-Quickstart auf `Install-Module NtfsPermissions` umstellen und Gallery-Badge ergänzen
- [ ] Social Preview (1280×640) unter Settings → General hochladen (Nutzer)
- [ ] Vergleich zweier Stände (Export als JSON/CLIXML, Diff: was hat sich geändert)
- [ ] Effektive Rechte eines bestimmten Kontos auf einem Ordner berechnen
- [ ] Freigabeberechtigungen (SMB-Share-ACL) zusätzlich zu NTFS anzeigen
- [ ] Integritätsstufe (Mandatory Label) aus der SACL auslesen
- [ ] Performance bei sehr großen Freigaben messen (Get-Acl ggf. durch direkten API-Aufruf ersetzen)
- [ ] Veröffentlichung in internem Repository / PowerShell Gallery prüfen

## Erledigt

- [x] Modulstruktur, Manifest, Format-Ansichten (0.1.0)
- [x] SDDL-Aufschlüsselung inkl. bedingter ACEs (0.1.0)
- [x] HTML-Bericht (0.1.0)
- [x] Kompatibilität Windows PowerShell 5.1 und PowerShell 7 (0.1.0)
- [x] SID-Auflösung mit Kontotyp, bekannten SIDs und Domänen-RIDs (0.1.0)
- [x] README-Kopf (englisch), Demo-GIF, Bericht-Screenshot, CI (0.1.0)
