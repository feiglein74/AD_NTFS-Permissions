BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\NtfsPermissions\NtfsPermissions.psd1') -Force
}

Describe 'ConvertFrom-NtfsSddl' {

    It 'liest Besitzer, Vererbung und Gruppe' {
        $r = ConvertFrom-NtfsSddl 'O:BAG:SYD:PAI(A;OICI;FA;;;BA)'
        $r.OwnerSid | Should -Be 'S-1-5-32-544'
        $r.GroupSid | Should -Be 'S-1-5-18'
        $r.OwnerResolved | Should -BeTrue
        $r.InheritanceEnabled | Should -BeFalse
        $r.AceCount | Should -Be 1
        $r.ExplicitCount | Should -Be 1
    }

    It 'erkennt aktive Vererbung' {
        (ConvertFrom-NtfsSddl 'D:AI(A;OICIID;FA;;;SY)').InheritanceEnabled | Should -BeTrue
    }

    It 'fasst <Mask> als "<Expected>" zusammen' -TestCases @(
        @{ Mask = 'FA'; Expected = 'Vollzugriff' }
        @{ Mask = '0x1301bf'; Expected = 'Ändern' }
        @{ Mask = '0x1200a9'; Expected = 'Lesen, Ausführen' }
        @{ Mask = 'FR'; Expected = 'Lesen' }
        @{ Mask = '0x100116'; Expected = 'Schreiben' }
        @{ Mask = '0x116'; Expected = 'Schreiben' }
        @{ Mask = '0x12019f'; Expected = 'Lesen + Schreiben' }
        @{ Mask = 'FW'; Expected = 'Schreiben + Spezial' }
        @{ Mask = 'GA'; Expected = 'Vollzugriff (generisch)' }
        @{ Mask = 'GRGX'; Expected = 'Lesen, Ausführen (generisch)' }
        @{ Mask = '0x10000'; Expected = 'Spezial' }
    ) {
        param($Mask, $Expected)
        (ConvertFrom-NtfsSddl "D:(A;;$Mask;;;WD)").Aces[0].Rights | Should -BeExactly $Expected
    }

    It 'listet bei Spezial die Einzelrechte' {
        (ConvertFrom-NtfsSddl 'D:(A;;0x10000;;;WD)').Aces[0].RightsDetail | Should -Be 'Löschen'
    }

    It 'übersetzt Flags <Flags> in "<Expected>"' -TestCases @(
        @{ Flags = ''; Expected = 'Nur dieser Ordner' }
        @{ Flags = 'CI'; Expected = 'Dieser Ordner und Unterordner' }
        @{ Flags = 'OI'; Expected = 'Dieser Ordner und Dateien' }
        @{ Flags = 'OICI'; Expected = 'Dieser Ordner, Unterordner und Dateien' }
        @{ Flags = 'OICIIO'; Expected = 'Nur Unterordner und Dateien' }
        @{ Flags = 'CIIO'; Expected = 'Nur Unterordner' }
        @{ Flags = 'OIIO'; Expected = 'Nur Dateien' }
        @{ Flags = 'OICINP'; Expected = 'Dieser Ordner, Unterordner und Dateien (nur eine Ebene)' }
    ) {
        param($Flags, $Expected)
        (ConvertFrom-NtfsSddl "D:(A;$Flags;FA;;;WD)").Aces[0].AppliesTo | Should -BeExactly $Expected
    }

    It 'zeigt für Dateien "Nur diese Datei"' {
        (ConvertFrom-NtfsSddl 'D:(A;;FA;;;WD)' -File).Aces[0].AppliesTo | Should -Be 'Nur diese Datei'
    }

    It 'erkennt Verweigern und geerbte Einträge' {
        $r = ConvertFrom-NtfsSddl 'D:(D;;WD;;;WD)(A;ID;FA;;;SY)'
        $r.Aces[0].Type | Should -Be 'Verweigern'
        $r.Aces[0].IsDeny | Should -BeTrue
        $r.Aces[1].Inherited | Should -BeTrue
        $r.DenyCount | Should -Be 1
        $r.ExplicitCount | Should -Be 1
    }

    It 'erkennt nicht-kanonische Reihenfolge' {
        (ConvertFrom-NtfsSddl 'D:(A;;FA;;;BA)(D;;FA;;;WD)').IsCanonical | Should -BeFalse
        (ConvertFrom-NtfsSddl 'D:(A;ID;FA;;;SY)(A;;FA;;;BA)').IsCanonical | Should -BeFalse
        (ConvertFrom-NtfsSddl 'D:(D;;FA;;;WD)(A;;FA;;;BA)(A;ID;FA;;;SY)').IsCanonical | Should -BeTrue
    }

    It 'markiert nicht auflösbare SIDs' {
        $sid = 'S-1-5-21-1111111111-2222222222-3333333333-4444'
        $ace = (ConvertFrom-NtfsSddl "D:(A;;FA;;;$sid)").Aces[0]
        $ace.Resolved | Should -BeFalse
        $ace.Principal | Should -Be $sid
    }

    It 'erkennt eine NULL-DACL' {
        (ConvertFrom-NtfsSddl 'O:BAD:NO_ACCESS_CONTROL').NullDacl | Should -BeTrue
    }

    It 'ordnet jedem Eintrag seinen SDDL-Teil zu' {
        $r = ConvertFrom-NtfsSddl 'O:BAG:SYD:PAI(A;OICI;FA;;;BA)(A;OICIIO;GA;;;CO)'
        $r.Aces[0].AceSddl | Should -Be '(A;OICI;FA;;;BA)'
        $r.Aces[1].AceSddl | Should -Be '(A;OICIIO;GA;;;CO)'
    }

    It 'kommt mit bedingten ACEs (verschachtelte Klammern) zurecht' {
        $r = ConvertFrom-NtfsSddl 'D:(XA;;FR;;;WD;(Member_of {SID(BA)}))(A;;FA;;;BA)'
        $r.AceCount | Should -Be 2
        $r.Aces[0].Type | Should -Be 'Zulassen (bedingt)'
        $r.Aces[1].AceSddl | Should -Be '(A;;FA;;;BA)'
    }

    It 'nimmt Get-Acl-Ausgabe aus der Pipeline' {
        $r = Get-Acl -LiteralPath $TestDrive | ConvertFrom-NtfsSddl
        $r.Path | Should -Be $TestDrive
        $r.AceCount | Should -BeGreaterThan 0
    }

    It 'meldet ungültige SDDL als Fehler' {
        { ConvertFrom-NtfsSddl 'Unsinn' -ErrorAction Stop } | Should -Throw '*Ungültiger SDDL*'
    }
}

Describe 'Get-NtfsPermission' {

    BeforeAll {
        $root = Join-Path $TestDrive 'root'
        $null = New-Item -Path (Join-Path $root 'a\b') -ItemType Directory -Force
        $null = New-Item -Path (Join-Path $root 'c') -ItemType Directory -Force
        Set-Content -Path (Join-Path $root 'a\datei.txt') -Value 'x'

        $acl = Get-Acl -LiteralPath (Join-Path $root 'a')
        $everyone = [System.Security.Principal.SecurityIdentifier]'S-1-1-0'
        $rule = [System.Security.AccessControl.FileSystemAccessRule]::new($everyone, 'ReadAndExecute', 'ContainerInherit, ObjectInherit', 'None', 'Allow')
        $acl.AddAccessRule($rule)
        Set-Acl -LiteralPath (Join-Path $root 'a') -AclObject $acl
    }

    It 'liest einen einzelnen Ordner' {
        $r = @(Get-NtfsPermission $root -WarningAction SilentlyContinue)
        $r.Count | Should -Be 1
        $r[0].Path | Should -Be $root
        $r[0].ItemType | Should -Be 'Ordner'
        $r[0].Error | Should -BeNullOrEmpty
        $r[0].AceCount | Should -BeGreaterThan 0
    }

    It 'liest rekursiv nur Ordner' {
        $paths = (Get-NtfsPermission $root -Recurse -WarningAction SilentlyContinue).Path
        $paths | Should -Contain (Join-Path $root 'a\b')
        $paths | Should -Not -Contain (Join-Path $root 'a\datei.txt')
    }

    It 'bezieht mit -IncludeFiles Dateien ein' {
        $r = Get-NtfsPermission $root -Recurse -IncludeFiles -WarningAction SilentlyContinue
        ($r | Where-Object Path -EQ (Join-Path $root 'a\datei.txt')).ItemType | Should -Be 'Datei'
    }

    It 'beachtet -Depth' {
        $paths = (Get-NtfsPermission $root -Recurse -Depth 1 -WarningAction SilentlyContinue).Path
        $paths | Should -Contain (Join-Path $root 'a')
        $paths | Should -Not -Contain (Join-Path $root 'a\b')
    }

    It 'zeigt mit -ExplicitOnly nur Abweichungen (plus Startordner)' {
        $paths = (Get-NtfsPermission $root -Recurse -ExplicitOnly -WarningAction SilentlyContinue).Path
        $paths | Should -Contain $root
        $paths | Should -Contain (Join-Path $root 'a')
        $paths | Should -Not -Contain (Join-Path $root 'c')
        $paths | Should -Not -Contain (Join-Path $root 'a\b')
    }

    It 'findet den gesetzten expliziten Eintrag' {
        $ace = (Get-NtfsPermission (Join-Path $root 'a') -WarningAction SilentlyContinue).Aces |
            Where-Object { -not $_.Inherited -and $_.Sid -eq 'S-1-1-0' }
        $ace.Rights | Should -Be 'Lesen, Ausführen'
        $ace.AppliesTo | Should -Be 'Dieser Ordner, Unterordner und Dateien'
    }

    It 'nimmt Get-ChildItem-Ausgabe aus der Pipeline' {
        $r = Get-ChildItem -LiteralPath $root -Directory | Get-NtfsPermission -WarningAction SilentlyContinue
        @($r).Count | Should -Be 2
    }

    It 'gibt jedem ACE den Pfad mit (für CSV-Export)' {
        (Get-NtfsPermission $root -WarningAction SilentlyContinue).Aces[0].Path | Should -Be $root
    }

    It 'meldet fehlende Pfade als Fehler' {
        { Get-NtfsPermission (Join-Path $root 'gibtsnicht') -ErrorAction Stop -WarningAction SilentlyContinue } | Should -Throw '*nicht gefunden*'
    }
}

Describe 'Show-NtfsPermission' {
    It 'rendert ohne Fehler, auch mit SDDL-Aufschlüsselung' {
        { Show-NtfsPermission $TestDrive -Sddl -Detail -WarningAction SilentlyContinue 6>$null } | Should -Not -Throw
        { ConvertFrom-NtfsSddl 'O:BAD:PAI(D;;FA;;;S-1-5-21-1-2-3-4)(XA;;FR;;;WD;(Member_of {SID(BA)}))' | Show-NtfsPermission -Sddl 6>$null } | Should -Not -Throw
    }
}

Describe 'Export-NtfsPermissionReport' {
    It 'schreibt eine eigenständige HTML-Datei' {
        $out = Join-Path $TestDrive 'bericht.html'
        $file = Export-NtfsPermissionReport $TestDrive -Recurse -OutFile $out -PassThru -WarningAction SilentlyContinue
        $file.FullName | Should -Be $out
        $html = Get-Content -LiteralPath $out -Raw -Encoding UTF8
        $html | Should -Match '<!doctype html>'
        $html | Should -Match ([regex]::Escape([System.Net.WebUtility]::HtmlEncode($TestDrive)))
        $html | Should -Match 'SDDL aufschlüsseln'
    }
}
