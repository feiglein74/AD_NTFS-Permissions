# TODO

## Offen

- [ ] Lesen ohne eigenen Zugriff über SeBackupPrivilege in einer Admin-Sitzung verifizieren (bisher nur ohne Adminrechte getestet)
- [ ] AD-Gruppen auflösen: welche Benutzer haben über welche (verschachtelte) Gruppe Zugriff
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
