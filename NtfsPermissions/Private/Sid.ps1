$script:SidCache = @{}

function Resolve-NtfsSid {
    # Übersetzt eine SID in einen Kontonamen (mit Cache). Nicht auflösbare SIDs bleiben als SID-String stehen.
    [CmdletBinding()]
    param([System.Security.Principal.SecurityIdentifier]$Sid)

    if ($null -eq $Sid) {
        return [pscustomobject]@{ Name = $null; Sid = $null; Resolved = $false }
    }

    $key = $Sid.Value
    if (-not $script:SidCache.ContainsKey($key)) {
        $name = $key
        $ok = $false
        try {
            $name = $Sid.Translate([System.Security.Principal.NTAccount]).Value
            $ok = $true
        }
        catch {
            # verwaiste SID (gelöschtes Konto) oder Domäne nicht erreichbar
            Write-Verbose "SID $key nicht auflösbar: $($_.Exception.Message)"
        }
        if (-not $ok -and $key -like 'S-1-15-3-*') {
            # App-Capability-SIDs haben grundsätzlich keinen Kontonamen - nicht als verwaist melden
            $name = "App-Capability $key"
            $ok = $true
        }
        $script:SidCache[$key] = [pscustomobject]@{ Name = $name; Sid = $key; Resolved = $ok }
    }
    $script:SidCache[$key]
}
