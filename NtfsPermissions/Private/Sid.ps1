if (-not ('NtfsPermissions.SidLookup' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace NtfsPermissions
{
    public class SidLookupResult
    {
        public string Domain;
        public string Name;
        public int Use;   // SID_NAME_USE
    }

    public static class SidLookup
    {
        const int ERROR_INSUFFICIENT_BUFFER = 122;

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern bool LookupAccountSid(string systemName, byte[] sid, StringBuilder name, ref int cchName,
                                            StringBuilder domain, ref int cchDomain, out int use);

        // null = SID ist keinem Konto zugeordnet (verwaist) oder die Domäne ist nicht erreichbar
        public static SidLookupResult Lookup(byte[] sid)
        {
            int cchName = 256, cchDomain = 256, use;
            StringBuilder name = new StringBuilder(cchName);
            StringBuilder domain = new StringBuilder(cchDomain);
            if (!LookupAccountSid(null, sid, name, ref cchName, domain, ref cchDomain, out use))
            {
                if (Marshal.GetLastWin32Error() != ERROR_INSUFFICIENT_BUFFER) return null;
                name = new StringBuilder(cchName);
                domain = new StringBuilder(cchDomain);
                if (!LookupAccountSid(null, sid, name, ref cchName, domain, ref cchDomain, out use)) return null;
            }
            SidLookupResult r = new SidLookupResult();
            r.Domain = domain.ToString();
            r.Name = name.ToString();
            r.Use = use;
            return r;
        }
    }
}
'@
}

$script:SidCache = @{}

# SID_NAME_USE -> Kontotyp
$script:SidUseNames = @{
    1  = 'Benutzer'
    2  = 'Gruppe'
    3  = 'Domäne'
    4  = 'Gruppe (lokal)'
    5  = 'Bekannte Gruppe'
    6  = 'Gelöschtes Konto'
    7  = 'Ungültig'
    8  = 'Unbekannt'
    9  = 'Computer'
    10 = 'Integritätsstufe'
    11 = 'Anmeldesitzung'
}

# Statische, überall gleiche SIDs (Name = Rückfall, falls die Übersetzung scheitert)
$script:WellKnownSids = @{
    'S-1-0-0'      = @{ Name = 'NULL-SID'; Type = 'Bekannte Gruppe'; Description = 'Keine Sicherheitsprinzipal' }
    'S-1-1-0'      = @{ Name = 'Jeder'; Type = 'Bekannte Gruppe'; Description = 'Alle Benutzer inkl. Gast und anonym (je nach Richtlinie)' }
    'S-1-2-0'      = @{ Name = 'LOKAL'; Type = 'Bekannte Gruppe'; Description = 'Lokal angemeldete Benutzer' }
    'S-1-2-1'      = @{ Name = 'KONSOLENANMELDUNG'; Type = 'Bekannte Gruppe'; Description = 'An der physischen Konsole angemeldet' }
    'S-1-3-0'      = @{ Name = 'ERSTELLER-BESITZER'; Type = 'Bekannte Gruppe'; Description = 'Platzhalter: wird beim Vererben durch den Ersteller des Objekts ersetzt' }
    'S-1-3-1'      = @{ Name = 'ERSTELLERGRUPPE'; Type = 'Bekannte Gruppe'; Description = 'Platzhalter: wird beim Vererben durch die primäre Gruppe des Erstellers ersetzt' }
    'S-1-3-4'      = @{ Name = 'BESITZERRECHTE'; Type = 'Bekannte Gruppe'; Description = 'Begrenzt die impliziten Rechte des Besitzers' }
    'S-1-5-1'      = @{ Name = 'NT-AUTORITÄT\DIALUP'; Type = 'Bekannte Gruppe'; Description = 'Über DFÜ angemeldet' }
    'S-1-5-2'      = @{ Name = 'NT-AUTORITÄT\NETZWERK'; Type = 'Bekannte Gruppe'; Description = 'Über das Netzwerk angemeldet' }
    'S-1-5-3'      = @{ Name = 'NT-AUTORITÄT\BATCH'; Type = 'Bekannte Gruppe'; Description = 'Als Batchauftrag angemeldet' }
    'S-1-5-4'      = @{ Name = 'NT-AUTORITÄT\INTERAKTIV'; Type = 'Bekannte Gruppe'; Description = 'Interaktiv angemeldet' }
    'S-1-5-6'      = @{ Name = 'NT-AUTORITÄT\DIENST'; Type = 'Bekannte Gruppe'; Description = 'Als Dienst angemeldet' }
    'S-1-5-7'      = @{ Name = 'NT-AUTORITÄT\ANONYMOUS-ANMELDUNG'; Type = 'Bekannte Gruppe'; Description = 'Anonyme Anmeldung' }
    'S-1-5-9'      = @{ Name = 'NT-AUTORITÄT\DOMÄNENCONTROLLER DER ORGANISATION'; Type = 'Bekannte Gruppe'; Description = 'Alle DCs der Gesamtstruktur' }
    'S-1-5-10'     = @{ Name = 'NT-AUTORITÄT\SELBST'; Type = 'Bekannte Gruppe'; Description = 'Platzhalter für das Objekt selbst' }
    'S-1-5-11'     = @{ Name = 'NT-AUTORITÄT\Authentifizierte Benutzer'; Type = 'Bekannte Gruppe'; Description = 'Alle authentifizierten Konten (ohne Gast/anonym)' }
    'S-1-5-12'     = @{ Name = 'NT-AUTORITÄT\EINGESCHRÄNKTER ZUGRIFF'; Type = 'Bekannte Gruppe'; Description = 'Eingeschränkte Token' }
    'S-1-5-13'     = @{ Name = 'NT-AUTORITÄT\TERMINALSERVERBENUTZER'; Type = 'Bekannte Gruppe'; Description = 'Über Terminaldienste angemeldet' }
    'S-1-5-14'     = @{ Name = 'NT-AUTORITÄT\REMOTE INTERAKTIVE ANMELDUNG'; Type = 'Bekannte Gruppe'; Description = 'Über RDP angemeldet' }
    'S-1-5-15'     = @{ Name = 'NT-AUTORITÄT\Diese Organisation'; Type = 'Bekannte Gruppe'; Description = 'Konten derselben Organisation (Gesamtstrukturvertrauen)' }
    'S-1-5-17'     = @{ Name = 'NT-AUTORITÄT\IUSR'; Type = 'Bekannte Gruppe'; Description = 'Anonymer IIS-Zugriff' }
    'S-1-5-18'     = @{ Name = 'NT-AUTORITÄT\SYSTEM'; Type = 'Bekannte Gruppe'; Description = 'Lokales Systemkonto (Betriebssystem)' }
    'S-1-5-19'     = @{ Name = 'NT-AUTORITÄT\LOKALER DIENST'; Type = 'Bekannte Gruppe'; Description = 'Dienstkonto mit minimalen Rechten' }
    'S-1-5-20'     = @{ Name = 'NT-AUTORITÄT\NETZWERKDIENST'; Type = 'Bekannte Gruppe'; Description = 'Dienstkonto, tritt im Netz als Computerkonto auf' }
    'S-1-5-32-544' = @{ Name = 'VORDEFINIERT\Administratoren'; Type = 'Gruppe (lokal)'; Description = 'Lokale Administratoren' }
    'S-1-5-32-545' = @{ Name = 'VORDEFINIERT\Benutzer'; Type = 'Gruppe (lokal)'; Description = 'Lokale Benutzer (enthält meist Domänen-Benutzer)' }
    'S-1-5-32-546' = @{ Name = 'VORDEFINIERT\Gäste'; Type = 'Gruppe (lokal)'; Description = 'Lokale Gäste' }
    'S-1-5-32-547' = @{ Name = 'VORDEFINIERT\Hauptbenutzer'; Type = 'Gruppe (lokal)'; Description = 'Veraltete Hauptbenutzer-Gruppe' }
    'S-1-5-32-548' = @{ Name = 'VORDEFINIERT\Konten-Operatoren'; Type = 'Gruppe (lokal)'; Description = 'Nur auf DCs' }
    'S-1-5-32-549' = @{ Name = 'VORDEFINIERT\Server-Operatoren'; Type = 'Gruppe (lokal)'; Description = 'Nur auf DCs' }
    'S-1-5-32-550' = @{ Name = 'VORDEFINIERT\Druck-Operatoren'; Type = 'Gruppe (lokal)'; Description = 'Nur auf DCs' }
    'S-1-5-32-551' = @{ Name = 'VORDEFINIERT\Sicherungs-Operatoren'; Type = 'Gruppe (lokal)'; Description = 'Dürfen Dateien unabhängig von Berechtigungen sichern/wiederherstellen' }
    'S-1-5-32-552' = @{ Name = 'VORDEFINIERT\Replikations-Operator'; Type = 'Gruppe (lokal)'; Description = 'Dateireplikation' }
    'S-1-5-32-554' = @{ Name = 'VORDEFINIERT\Prä-Windows 2000 kompatibler Zugriff'; Type = 'Gruppe (lokal)'; Description = 'Lesezugriff für Altsysteme' }
    'S-1-5-32-555' = @{ Name = 'VORDEFINIERT\Remotedesktopbenutzer'; Type = 'Gruppe (lokal)'; Description = 'RDP-Anmeldung erlaubt' }
    'S-1-5-32-556' = @{ Name = 'VORDEFINIERT\Netzwerkkonfigurations-Operatoren'; Type = 'Gruppe (lokal)'; Description = 'Netzwerkeinstellungen ändern' }
    'S-1-5-32-558' = @{ Name = 'VORDEFINIERT\Leistungsüberwachungsbenutzer'; Type = 'Gruppe (lokal)'; Description = '' }
    'S-1-5-32-559' = @{ Name = 'VORDEFINIERT\Leistungsprotokollbenutzer'; Type = 'Gruppe (lokal)'; Description = '' }
    'S-1-5-32-562' = @{ Name = 'VORDEFINIERT\Distributed COM-Benutzer'; Type = 'Gruppe (lokal)'; Description = '' }
    'S-1-5-32-568' = @{ Name = 'VORDEFINIERT\IIS_IUSRS'; Type = 'Gruppe (lokal)'; Description = 'IIS-Anwendungspools' }
    'S-1-5-32-569' = @{ Name = 'VORDEFINIERT\Kryptografie-Operatoren'; Type = 'Gruppe (lokal)'; Description = '' }
    'S-1-5-32-573' = @{ Name = 'VORDEFINIERT\Ereignisprotokollleser'; Type = 'Gruppe (lokal)'; Description = '' }
    'S-1-5-32-574' = @{ Name = 'VORDEFINIERT\Zertifikatdienst-DCOM-Zugriff'; Type = 'Gruppe (lokal)'; Description = '' }
    'S-1-5-32-578' = @{ Name = 'VORDEFINIERT\Hyper-V-Administratoren'; Type = 'Gruppe (lokal)'; Description = '' }
    'S-1-5-32-579' = @{ Name = 'VORDEFINIERT\Zugriffssteuerungs-Unterstützungsoperatoren'; Type = 'Gruppe (lokal)'; Description = '' }
    'S-1-5-32-580' = @{ Name = 'VORDEFINIERT\Remoteverwaltungsbenutzer'; Type = 'Gruppe (lokal)'; Description = 'WinRM-Zugriff' }
    'S-1-5-32-583' = @{ Name = 'VORDEFINIERT\Gerätebesitzer'; Type = 'Gruppe (lokal)'; Description = '' }
    'S-1-5-64-10'  = @{ Name = 'NT-AUTORITÄT\NTLM-Authentifizierung'; Type = 'Bekannte Gruppe'; Description = 'Per NTLM authentifiziert' }
    'S-1-5-64-14'  = @{ Name = 'NT-AUTORITÄT\SChannel-Authentifizierung'; Type = 'Bekannte Gruppe'; Description = 'Per SChannel authentifiziert' }
    'S-1-5-64-21'  = @{ Name = 'NT-AUTORITÄT\Digestauthentifizierung'; Type = 'Bekannte Gruppe'; Description = 'Per Digest authentifiziert' }
    'S-1-5-80-0'   = @{ Name = 'NT SERVICE\ALL SERVICES'; Type = 'Bekannte Gruppe'; Description = 'Alle Dienste' }
    'S-1-5-113'    = @{ Name = 'NT-AUTORITÄT\Lokales Konto'; Type = 'Bekannte Gruppe'; Description = 'Lokale (nicht Domänen-)Konten' }
    'S-1-5-114'    = @{ Name = 'NT-AUTORITÄT\Lokales Konto und Mitglied der Gruppe "Administratoren"'; Type = 'Bekannte Gruppe'; Description = '' }
    'S-1-15-2-1'   = @{ Name = 'ZERTIFIZIERUNGSSTELLE FÜR ANWENDUNGSPAKETE\ALLE ANWENDUNGSPAKETE'; Type = 'Bekannte Gruppe'; Description = 'Alle UWP-/App-Container' }
    'S-1-15-2-2'   = @{ Name = 'ZERTIFIZIERUNGSSTELLE FÜR ANWENDUNGSPAKETE\ALLE EINGESCHRÄNKTEN ANWENDUNGSPAKETE'; Type = 'Bekannte Gruppe'; Description = '' }
    'S-1-16-0'     = @{ Name = 'Verbindlich\Nicht vertrauenswürdige Verbindlichkeitsstufe'; Type = 'Integritätsstufe'; Description = 'Untrusted' }
    'S-1-16-4096'  = @{ Name = 'Verbindlich\Niedrige Verbindlichkeitsstufe'; Type = 'Integritätsstufe'; Description = 'Low' }
    'S-1-16-8192'  = @{ Name = 'Verbindlich\Mittlere Verbindlichkeitsstufe'; Type = 'Integritätsstufe'; Description = 'Medium' }
    'S-1-16-8448'  = @{ Name = 'Verbindlich\Mittlere Plus-Verbindlichkeitsstufe'; Type = 'Integritätsstufe'; Description = 'Medium Plus' }
    'S-1-16-12288' = @{ Name = 'Verbindlich\Hohe Verbindlichkeitsstufe'; Type = 'Integritätsstufe'; Description = 'High' }
    'S-1-16-16384' = @{ Name = 'Verbindlich\Systemverbindlichkeitsstufe'; Type = 'Integritätsstufe'; Description = 'System' }
}

# Bekannte RIDs in Domänen-SIDs (S-1-5-21-<Domäne>-<RID>)
$script:WellKnownRids = @{
    500 = @{ Name = 'Administrator'; Type = 'Benutzer'; Description = 'Integriertes Administratorkonto' }
    501 = @{ Name = 'Gast'; Type = 'Benutzer'; Description = 'Integriertes Gastkonto' }
    502 = @{ Name = 'krbtgt'; Type = 'Benutzer'; Description = 'Kerberos-Dienstkonto der Domäne' }
    512 = @{ Name = 'Domänen-Admins'; Type = 'Gruppe'; Description = 'Administratoren der Domäne' }
    513 = @{ Name = 'Domänen-Benutzer'; Type = 'Gruppe'; Description = 'Alle Benutzerkonten der Domäne' }
    514 = @{ Name = 'Domänen-Gäste'; Type = 'Gruppe'; Description = 'Gastkonten der Domäne' }
    515 = @{ Name = 'Domänencomputer'; Type = 'Gruppe'; Description = 'Alle Computer der Domäne (ohne DCs)' }
    516 = @{ Name = 'Domänencontroller'; Type = 'Gruppe'; Description = 'Alle DCs der Domäne' }
    517 = @{ Name = 'Zertifikatherausgeber'; Type = 'Gruppe'; Description = '' }
    518 = @{ Name = 'Schema-Admins'; Type = 'Gruppe'; Description = 'Nur in der Stammdomäne' }
    519 = @{ Name = 'Organisations-Admins'; Type = 'Gruppe'; Description = 'Nur in der Stammdomäne' }
    520 = @{ Name = 'Richtlinien-Ersteller-Besitzer'; Type = 'Gruppe'; Description = '' }
    521 = @{ Name = 'Schreibgeschützte Domänencontroller'; Type = 'Gruppe'; Description = '' }
    522 = @{ Name = 'Klonbare Domänencontroller'; Type = 'Gruppe'; Description = '' }
    525 = @{ Name = 'Protected Users'; Type = 'Gruppe'; Description = '' }
    526 = @{ Name = 'Schlüsseladministratoren'; Type = 'Gruppe'; Description = '' }
    527 = @{ Name = 'Organisationsschlüsseladministratoren'; Type = 'Gruppe'; Description = '' }
    553 = @{ Name = 'RAS- und IAS-Server'; Type = 'Gruppe (lokal)'; Description = '' }
    571 = @{ Name = 'Zulässige RODC-Kennwortreplikationsgruppe'; Type = 'Gruppe (lokal)'; Description = '' }
    572 = @{ Name = 'Abgelehnte RODC-Kennwortreplikationsgruppe'; Type = 'Gruppe (lokal)'; Description = '' }
}

# SID-Bereiche ohne festen Namen
$script:SidPatterns = @(
    @{ Pattern = '^S-1-5-80-'; Type = 'Dienst'; Description = 'Dienst-SID (NT SERVICE\<Dienstname>)' }
    @{ Pattern = '^S-1-5-82-'; Type = 'IIS-AppPool'; Description = 'Identität eines IIS-Anwendungspools' }
    @{ Pattern = '^S-1-5-83-'; Type = 'Virtuelle Maschine'; Description = 'Hyper-V-VM (NT VIRTUAL MACHINE)' }
    @{ Pattern = '^S-1-5-5-'; Type = 'Anmeldesitzung'; Description = 'SID einer einzelnen Anmeldesitzung' }
    @{ Pattern = '^S-1-15-3-'; Type = 'App-Capability'; Description = 'Fähigkeit eines App-Containers, hat grundsätzlich keinen Kontonamen' }
    @{ Pattern = '^S-1-15-2-'; Type = 'App-Paket'; Description = 'App-Container-Paket' }
)

function Resolve-NtfsSid {
    # Löst eine SID in Kontonamen und Kontotyp auf (mit Cache).
    # Reihenfolge: LookupAccountSid (lokal/AD) -> Tabelle bekannter SIDs -> bekannte Domänen-RID -> SID-Bereich -> nicht auflösbar
    [CmdletBinding()]
    param([System.Security.Principal.SecurityIdentifier]$Sid)

    if ($null -eq $Sid) {
        return [pscustomobject]@{ Name = $null; Sid = $null; Resolved = $false; AccountType = $null; Description = $null; Source = $null }
    }

    $key = $Sid.Value
    if ($script:SidCache.ContainsKey($key)) { return $script:SidCache[$key] }

    $bytes = [byte[]]::new($Sid.BinaryLength)
    $Sid.GetBinaryForm($bytes, 0)
    $known = $script:WellKnownSids[$key]

    $result = $null
    $lookup = [NtfsPermissions.SidLookup]::Lookup($bytes)
    if ($null -ne $lookup -and $lookup.Use -ne 6 -and $lookup.Use -ne 7 -and $lookup.Use -ne 8) {
        $name = if ($lookup.Domain) { "$($lookup.Domain)\$($lookup.Name)" } else { $lookup.Name }
        $type = $script:SidUseNames[$lookup.Use]
        if (-not $type) { $type = "Typ $($lookup.Use)" }
        $result = @{ Name = $name; Resolved = $true; AccountType = $type; Description = $(if ($known) { $known.Description }); Source = 'Kontodatenbank' }
    }
    elseif ($known) {
        $result = @{ Name = $known.Name; Resolved = $true; AccountType = $known.Type; Description = $known.Description; Source = 'Tabelle bekannter SIDs' }
    }
    elseif ($key -match '^S-1-5-21-\d+-\d+-\d+-(\d+)$' -and $script:WellKnownRids.ContainsKey([int]$Matches[1])) {
        $rid = $script:WellKnownRids[[int]$Matches[1]]
        $result = @{ Name = "$($rid.Name) [Domäne unbekannt]"; Resolved = $true; AccountType = $rid.Type
            Description = "Bekannte RID $($Matches[1]) einer nicht auflösbaren Domäne. $($rid.Description)".Trim(); Source = 'Bekannte Domänen-RID' }
    }
    else {
        $pattern = $script:SidPatterns | Where-Object { $key -match $_.Pattern } | Select-Object -First 1
        if ($pattern) {
            $result = @{ Name = "$($pattern.Type) $key"; Resolved = $true; AccountType = $pattern.Type; Description = $pattern.Description; Source = 'SID-Bereich' }
        }
    }

    if (-not $result) {
        $type = if ($null -ne $lookup -and $lookup.Use -eq 6) { 'Gelöschtes Konto' } else { 'Unbekannt' }
        Write-Verbose "SID $key nicht auflösbar"
        $result = @{ Name = $key; Resolved = $false; AccountType = $type; Description = 'Nicht auflösbar: gelöschtes Konto (verwaiste SID) oder Domäne nicht erreichbar'; Source = $null }
    }

    $result.Sid = $key
    $obj = [pscustomobject]@{
        Name        = $result.Name
        Sid         = $result.Sid
        Resolved    = $result.Resolved
        AccountType = $result.AccountType
        Description = $result.Description
        Source      = $result.Source
    }
    $script:SidCache[$key] = $obj
    $obj
}
