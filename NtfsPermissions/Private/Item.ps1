function ConvertFrom-NtfsRawAcl {
    # Wandelt eine RawAcl in NtfsPermissions.Ace-Objekte um. $AceSddl liefert die Original-ACE-Strings in gleicher Reihenfolge.
    [CmdletBinding()]
    param(
        [System.Security.AccessControl.RawAcl]$Acl,
        [string[]]$AceSddl,
        [string]$Path,
        [bool]$IsContainer
    )

    if ($null -eq $Acl) { return }
    $withSddl = $null -ne $AceSddl -and $AceSddl.Count -eq $Acl.Count

    for ($i = 0; $i -lt $Acl.Count; $i++) {
        $ace = $Acl[$i]
        $sid = $null
        $mask = 0L
        if ($ace -is [System.Security.AccessControl.KnownAce]) {
            $sid = $ace.SecurityIdentifier
            $mask = [long]$ace.AccessMask -band 0xFFFFFFFFL
        }
        $who = Resolve-NtfsSid $sid
        $rights = Get-NtfsRightsInfo $mask

        [pscustomobject]@{
            PSTypeName   = 'NtfsPermissions.Ace'
            Path         = $Path
            Index        = $i + 1
            Type         = Get-NtfsAceTypeName $ace
            Principal    = $who.Name
            Sid          = $who.Sid
            Resolved     = $who.Resolved
            AccountType  = $who.AccountType
            AccountInfo  = $who.Description
            Rights       = $rights.Summary
            RightsDetail = $rights.Detail -join ', '
            AccessMask   = '0x{0:X8}' -f $mask
            AppliesTo    = Get-NtfsAppliesTo $ace.AceFlags $IsContainer
            Inherited    = ([int]$ace.AceFlags -band 0x10) -ne 0   # AceFlags.Inherited
            IsDeny       = ([string]$ace.AceType) -like 'AccessDenied*'
            AceSddl      = if ($withSddl) { $AceSddl[$i] } else { $null }
        }
    }
}

function Test-NtfsCanonical {
    # Kanonisch = explizit Verweigern, dann explizit Zulassen, dann geerbte Einträge
    [CmdletBinding()]
    [OutputType([bool])]
    param([object[]]$Aces)

    $phase = 0
    foreach ($ace in $Aces) {
        $p = if ($ace.Inherited) { 2 } elseif ($ace.IsDeny) { 0 } else { 1 }
        if ($p -lt $phase) { return $false }
        $phase = $p
    }
    $true
}

function Test-NtfsNotable {
    # Weicht das Objekt vom "einfach geerbt"-Normalfall ab?
    [CmdletBinding()]
    [OutputType([bool])]
    param($Item)

    [bool]($Item.Error -or $Item.Note -or $Item.InheritanceEnabled -eq $false -or
        $Item.ExplicitCount -gt 0 -or $Item.IsCanonical -eq $false -or $Item.NullDacl)
}

function Test-NtfsItemObject {
    param($InputObject)
    $null -ne $InputObject -and $InputObject.PSObject.TypeNames -contains 'NtfsPermissions.Item'
}

function ConvertTo-NtfsPermissionItem {
    [CmdletBinding()]
    param(
        [string]$Sddl,
        [string]$Path,
        [bool]$IsContainer = $true,
        [string]$ErrorMessage
    )

    $item = [ordered]@{
        PSTypeName         = 'NtfsPermissions.Item'
        Path               = $Path
        ItemType           = if (-not $Path) { $null } elseif ($IsContainer) { 'Ordner' } else { 'Datei' }
        Owner              = $null
        OwnerSid           = $null
        OwnerResolved      = $false
        OwnerType          = $null
        Group              = $null
        GroupSid           = $null
        GroupType          = $null
        InheritanceEnabled = $null
        NullDacl           = $false
        IsCanonical        = $null
        AceCount           = 0
        ExplicitCount      = 0
        DenyCount          = 0
        Aces               = @()
        AuditAces          = @()
        Sddl               = $Sddl
        Error              = $ErrorMessage
        Note               = $null
    }

    if (-not $ErrorMessage) {
        $sd = [System.Security.AccessControl.RawSecurityDescriptor]::new($Sddl)
        $sp = Split-NtfsSddl $Sddl
        $ctl = [int]$sd.ControlFlags

        $owner = Resolve-NtfsSid $sd.Owner
        $group = Resolve-NtfsSid $sd.Group
        $aces = @(ConvertFrom-NtfsRawAcl -Acl $sd.DiscretionaryAcl -AceSddl $sp.DaclAces -Path $Path -IsContainer $IsContainer)
        $audit = @(ConvertFrom-NtfsRawAcl -Acl $sd.SystemAcl -AceSddl $sp.SaclAces -Path $Path -IsContainer $IsContainer)

        $item.Owner = $owner.Name
        $item.OwnerSid = $owner.Sid
        $item.OwnerResolved = $owner.Resolved
        $item.OwnerType = $owner.AccountType
        $item.Group = $group.Name
        $item.GroupSid = $group.Sid
        $item.GroupType = $group.AccountType
        $item.InheritanceEnabled = ($ctl -band 0x1000) -eq 0                        # DiscretionaryAclProtected
        $item.NullDacl = (($ctl -band 0x0004) -ne 0) -and $null -eq $sd.DiscretionaryAcl   # DiscretionaryAclPresent
        $item.IsCanonical = Test-NtfsCanonical $aces
        $item.AceCount = $aces.Count
        $item.ExplicitCount = @($aces | Where-Object { -not $_.Inherited }).Count
        $item.DenyCount = @($aces | Where-Object { $_.IsDeny }).Count
        $item.Aces = $aces
        $item.AuditAces = $audit
    }

    [pscustomobject]$item
}
