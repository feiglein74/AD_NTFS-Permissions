@{
    RootModule           = 'NtfsPermissions.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'ad500fb5-e88f-46fb-85c4-a49dac09f955'
    Author               = 'Sascha Feig'
    Copyright            = '(c) Sascha Feig'
    Description          = 'Read and decode NTFS permissions: reads ACLs even without own access (SeBackupPrivilege), decodes SDDL token by token, resolves SIDs (users, groups, well-known SIDs, orphaned SIDs), shows Explorer-style rights in a colored console view and exports a standalone HTML audit report. Output labels are German.'
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
            Tags         = @('NTFS', 'ACL', 'SDDL', 'Permissions', 'Security', 'SID', 'Audit', 'ActiveDirectory', 'Windows', 'PSEdition_Desktop', 'PSEdition_Core')
            ProjectUri   = 'https://github.com/feiglein74/AD_NTFS-Permissions'
            LicenseUri   = 'https://github.com/feiglein74/AD_NTFS-Permissions/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/feiglein74/AD_NTFS-Permissions/blob/main/CHANGELOG.md'
        }
    }
}
