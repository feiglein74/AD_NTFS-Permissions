<#
    Beispieldaten für README-Bilder (docs/demo.gif, docs/report.png).
    Alle Pfade sind ausgedacht, die SDDL-Strings werden ohne Dateisystemzugriff ausgewertet.
    Die Domänen-SIDs stammen aus der Microsoft-Dokumentation und sind absichtlich nicht auflösbar.

    Aufruf aus dem Repo-Stamm:
        . .\docs\demo-data.ps1
        $demo | Show-NtfsPermission
        Export-DemoReport -OutFile .\docs\report.html
#>

Import-Module (Join-Path $PSScriptRoot '..\NtfsPermissions\NtfsPermissions.psd1') -Force

$orphan = 'S-1-5-21-3623811015-3361044348-30300820'

$demoSddl = [ordered]@{
    'D:\Shares'                = "O:BAG:SYD:PAI(A;OICI;FA;;;BA)(A;OICI;FA;;;SY)(A;OICI;FA;;;$orphan-512)(A;;0x1200a9;;;AU)(A;OICIIO;GA;;;CO)"
    'D:\Shares\Sales'          = "O:BAG:SYD:AI(A;OICI;0x1301bf;;;$orphan-1104)(A;OICI;0x1200a9;;;AU)(A;OICIID;FA;;;BA)(A;OICIID;FA;;;SY)(A;OICIIOID;GA;;;CO)"
    'D:\Shares\Sales\Archive'  = 'O:BAG:SYD:PAI(D;OICI;0x10040;;;WD)(A;OICI;FA;;;BA)(A;OICI;FA;;;SY)(A;OICI;0x1200a9;;;AU)'
    'D:\Shares\HR'             = "O:${orphan}-1105G:SYD:PAI(A;OICI;FA;;;BA)(D;OICI;FA;;;$orphan-1106)(A;OICI;FA;;;SY)"
    'D:\Shares\Public'         = 'O:BAG:SYD:AI(A;OICIID;FA;;;BA)(A;OICIID;FA;;;SY)(A;ID;0x1200a9;;;AU)(A;OICIIOID;GA;;;CO)'
}

$demo = foreach ($entry in $demoSddl.GetEnumerator()) {
    ConvertFrom-NtfsSddl -Sddl $entry.Value -Path $entry.Key
}

function Export-DemoReport {
    param([Parameter(Mandatory)][string]$OutFile)
    $demo | Export-NtfsPermissionReport -OutFile $OutFile -Title 'NTFS-Berechtigungen – Beispiel'
    # Rechnername und Konto des erzeugenden Systems durch neutrale Werte ersetzen
    $html = [System.IO.File]::ReadAllText($OutFile)
    $html = $html -replace 'auf [^<]+ von [^<]+</p>', 'auf FS01 von CONTOSO\admin</p>'
    [System.IO.File]::WriteAllText($OutFile, $html, [System.Text.UTF8Encoding]::new($false))
}
