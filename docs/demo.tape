# Aufnahme von docs/demo.gif mit charmbracelet/vhs
# Aufruf aus dem Repo-Stamm:  vhs docs/demo.tape

Output docs/demo.gif

Set Shell "pwsh"
Set FontSize 14
Set Width 1800
Set Height 700
Set Padding 24
Set Theme "Dracula"
Set TypingSpeed 25ms

# Neutraler Prompt (kein lokaler Pfad/Benutzername im Bild), Farben erzwingen (vhs-Umgebung meldet sonst "keine Farben"), Modul laden
Hide
Type "function prompt { 'PS> ' }; $PSStyle.OutputRendering = 'Ansi'; Import-Module ./NtfsPermissions/NtfsPermissions.psd1; Clear-Host"
Enter
Sleep 2s
Show

Type "ConvertFrom-NtfsSddl 'O:BAG:SYD:PAI(A;OICI;FA;;;BA)(D;OICI;FA;;;S-1-5-21-3623811015-3361044348-30300820-1106)(A;CI;0x1200a9;;;AU)' | Show-NtfsPermission -Sddl"
Sleep 500ms
Enter
Sleep 9s
