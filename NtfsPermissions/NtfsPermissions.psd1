@{
    RootModule           = 'NtfsPermissions.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'ad500fb5-e88f-46fb-85c4-a49dac09f955'
    Author               = 'Sascha Feig'
    Copyright            = '(c) Sascha Feig'
    Description          = 'NTFS-Berechtigungen lesen (dank SeBackupPrivilege auch ohne eigenen Zugriff), SDDL aufschlüsseln, übersichtlich anzeigen und als HTML-Bericht exportieren.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FormatsToProcess     = @('NtfsPermissions.Format.ps1xml')
    FunctionsToExport    = @(
        'Get-NtfsPermission'
        'ConvertFrom-NtfsSddl'
        'Show-NtfsPermission'
        'Export-NtfsPermissionReport'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags = @('NTFS', 'ACL', 'SDDL', 'Permissions', 'Security', 'Windows')
        }
    }
}
