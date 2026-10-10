function ConvertFrom-NtfsSddl {
    <#
    .SYNOPSIS
        Schlüsselt einen SDDL-String in lesbare Berechtigungen auf - ohne Dateisystemzugriff.

    .DESCRIPTION
        Liefert dasselbe Objekt wie Get-NtfsPermission. Praktisch für SDDL aus Logs, Tickets,
        icacls /save-Dateien oder von anderen Rechnern. Nimmt auch Get-Acl-Ausgabe entgegen.

    .PARAMETER Sddl
        Der SDDL-String, z. B. 'O:BAG:SYD:PAI(A;OICI;FA;;;BA)'.

    .PARAMETER Path
        Optionaler Pfad, der im Ergebnis mitgeführt wird (wird von Get-Acl automatisch übergeben).

    .PARAMETER File
        Den Descriptor als Datei statt als Ordner interpretieren (wirkt sich auf "Gilt für" aus).

    .EXAMPLE
        ConvertFrom-NtfsSddl 'O:BAG:SYD:PAI(A;OICI;FA;;;BA)(A;OICI;0x1200a9;;;BU)' | Show-NtfsPermission -Sddl

    .EXAMPLE
        Get-Acl \\server\freigabe | ConvertFrom-NtfsSddl
    #>
    [CmdletBinding()]
    [OutputType('NtfsPermissions.Item')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Sddl,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Path,

        [switch]$File
    )

    process {
        $cleanPath = if ($Path) { $Path -replace '^.*?::', '' } else { $null }
        try {
            ConvertTo-NtfsPermissionItem -Sddl $Sddl -Path $cleanPath -IsContainer (-not $File)
        }
        catch {
            Write-Error -Message "Ungültiger SDDL-String: $($_.Exception.Message)" -TargetObject $Sddl -Category InvalidArgument
        }
    }
}
