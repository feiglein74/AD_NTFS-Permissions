# Design-Prinzipien für NtfsPermissions

## Leitprinzipien

### 1. Vollständigkeit vor Kürze

Die Konsolenansicht kürzt standardmäßig nichts. Spaltenbreiten richten sich nach dem längsten Wert, auch wenn die Tabelle dadurch breiter als das Fenster wird.

```powershell
# ❌ FALSCH - Spalten mit fester Obergrenze, Rest wird abgeschnitten
$caps = 24, 44, 30, 48, 8
'VORDEFINIERT\Adminis…'          # Wie heißt das Konto wirklich?

# ✅ RICHTIG - Breite = längster Wert der Spalte
'VORDEFINIERT\Administratoren'
```

**Warum?** Bei Berechtigungen entscheidet oft der Teil, der abgeschnitten würde. Ein Beispiel ist `DOMÄNE\GG_Vertrieb_Lesen` gegenüber `DOMÄNE\GG_Vertrieb_Ändern`.

### 2. Opt-in statt Opt-out für Einschränkungen

Jede Einschränkung muss ausdrücklich eingeschaltet werden:

| Einschränkung | Parameter | Default |
|---|---|---|
| Kürzung von Tabellenzellen | `Show-NtfsPermission -Truncate 30` | `-1` = nichts kürzen |
| Nur abweichende Objekte | `-ExplicitOnly` | alle Objekte |
| Rekursionstiefe | `-Depth 2` | unbegrenzt (mit `-Recurse`) |
| Dateien einbeziehen | `-IncludeFiles` | nur Ordner, weil Dateien fast immer nur erben (*siehe unten*) |

### 3. Transparenz bei Modifikationen

Wird gekürzt, steht dabei, wie viel fehlt:

```
❌ FALSCH:  VORDEFINIERT\Adminis…
✅ RICHTIG: VORDEFINIERT\Adminis… [+8 Zeichen]
```

Auch nicht gelesene Inhalte bleiben nie stillschweigend weg:
- Junctions/Symlinks werden aufgeführt, mit `Note = 'Verknüpfung (Junction/Symlink) - Inhalt wird nicht verfolgt'`
- Nicht auflistbare Ordner erhalten `Note = 'Inhalt nicht auflistbar: …'`
- Nicht lesbare ACLs erscheinen als Objekt mit `Error`. Sie werden nicht übersprungen.
- Fehlendes SeBackupPrivilege wird einmal pro Sitzung als Warnung gemeldet.

### 4. Explizit vor Implizit

Kein Befehl verändert das System. Das Modul liest nur. Die einzige Nebenwirkung ist das Aktivieren von `SeBackupPrivilege` bzw. `SeSecurityPrivilege` im **eigenen** Prozess-Token. Das wird in der Hilfe und der README beschrieben.

### 5. Sichere Defaults

Fehlerdetails werden vollständig durchgereicht (`$_.Exception.Message`). Ein Lesefehler bei einem Ordner bricht den Durchlauf nicht ab, sondern wird als Objekt mit `Error` ausgegeben.

## Projekt-spezifische Entscheidungen

### Rechte-Zusammenfassung ist verlustfrei

`Rights` fasst die Zugriffsmaske wie der Explorer zusammen. Das ist eine Transformation, aber keine verlustbehaftete:

- Namen wie „Vollzugriff“, „Ändern“ oder „Lesen, Ausführen“ werden nur vergeben, wenn die Maske **exakt** abgedeckt ist.
- Bleiben Bits übrig, steht `Spezial` im Text, und die Konsole zeigt die Einzelrechte **immer** darunter an.
- `AccessMask` (hex) und `RightsDetail` stehen in jedem Objekt.

```powershell
# ❌ FALSCH - "Schreiben" für FILE_GENERIC_WRITE (0x120116), obwohl zusätzlich "Berechtigungen lesen" enthalten ist
# ✅ RICHTIG - "Schreiben + Spezial", darunter: ... Berechtigungen lesen
```

### Generische Rechte werden gekennzeichnet

`GA`/`GR`/`GW`/`GX` werden auf Dateirechte abgebildet, damit sie vergleichbar sind. Die Herkunft bleibt sichtbar: `Vollzugriff (generisch)`.

### Ein Objektmodell für alle Ausgaben

`Get-NtfsPermission` und `ConvertFrom-NtfsSddl` liefern dasselbe `NtfsPermissions.Item`. `Show-` und `Export-` sind reine Darstellungen davon. Neue Ausgabeformate setzen auf dem Objekt auf, nicht auf eigener Logik.

### SDDL wird zusätzlich selbst zerlegt

Die Rechte werden aus dem Binärformat (`RawSecurityDescriptor`) berechnet, weil das zuverlässig ist. Für die Aufschlüsselung wird der SDDL-String aber zusätzlich selbst zerlegt, damit Original-Tokens wie `BU` oder `DCLCRPCR` sichtbar bleiben. Der Parser zählt Klammern, damit bedingte ACEs mit verschachtelten Klammern korrekt bleiben. Stimmt die Anzahl nicht mit der Binär-ACL überein, bleibt `AceSddl` leer, statt falsch zugeordnet zu werden.

### Ordner standardmäßig, Dateien per Opt-in

Bei `-Recurse` werden nur Ordner gelesen, Dateien nur mit `-IncludeFiles`. Das ist eine Einschränkung des Umfangs, keine versteckte: Der Parameter ist dokumentiert, und Dateien erben in der Praxis fast immer. Auf Freigaben mit hunderttausenden Dateien wäre der vollständige Lauf sonst unbrauchbar langsam.

**Test-Kriterium:** Wird ein Entwickler überrascht sein? Ein Admin, der `-Recurse` aufruft, erwartet eine Ordnerstruktur, wie im Explorer-Dialog „Erweiterte Sicherheit“.

### Kompatibilität PowerShell 5.1 und 7

- Skriptdateien sind **UTF-8 mit BOM**, sonst liest 5.1 die Umlaute falsch.
- Flags werden als `[int]` verglichen, nicht als Enum. `-band` auf dem Byte-Enum `AceFlags` wirft unter 5.1 `InvalidCastException`.
- Keine PS7-Syntax (`??`, `?:`, `&&` im Modulcode).

### Write-Host nur in der Darstellungsschicht

`Write-Host` steht ausschließlich in `Private/Render.ps1` und wird dort pro Funktion mit Begründung für PSScriptAnalyzer freigegeben. Alle anderen Funktionen liefern Objekte.

## Merksatz

> **"Der Default ist die Wahrheit, Einschränkungen sind explizit."**
