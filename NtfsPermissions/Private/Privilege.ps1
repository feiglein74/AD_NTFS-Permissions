if (-not ('NtfsPermissions.TokenPrivilege' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace NtfsPermissions
{
    public static class TokenPrivilege
    {
        [StructLayout(LayoutKind.Sequential, Pack = 4)]
        struct TOKEN_PRIVILEGES
        {
            public int PrivilegeCount;
            public long Luid;
            public int Attributes;
        }

        const int TOKEN_ADJUST_PRIVILEGES = 0x20;
        const int TOKEN_QUERY = 0x08;
        const int SE_PRIVILEGE_ENABLED = 0x02;
        const int ERROR_NOT_ALL_ASSIGNED = 1300;

        [DllImport("advapi32.dll", SetLastError = true)]
        static extern bool OpenProcessToken(IntPtr process, int access, out IntPtr token);

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        static extern bool LookupPrivilegeValue(string system, string name, out long luid);

        [DllImport("advapi32.dll", SetLastError = true)]
        static extern bool AdjustTokenPrivileges(IntPtr token, bool disableAll, ref TOKEN_PRIVILEGES newState,
                                                 int bufferLength, IntPtr previousState, IntPtr returnLength);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool CloseHandle(IntPtr handle);

        [DllImport("kernel32.dll")]
        static extern IntPtr GetCurrentProcess();

        // true = Privileg ist aktiv; false = das Token besitzt das Privileg nicht (z. B. nicht elevated)
        public static bool Enable(string privilege)
        {
            IntPtr token;
            if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, out token))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            try
            {
                TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
                tp.PrivilegeCount = 1;
                tp.Attributes = SE_PRIVILEGE_ENABLED;
                if (!LookupPrivilegeValue(null, privilege, out tp.Luid))
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                if (!AdjustTokenPrivileges(token, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero))
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                return Marshal.GetLastWin32Error() != ERROR_NOT_ALL_ASSIGNED;
            }
            finally
            {
                CloseHandle(token);
            }
        }
    }
}
'@
}

$script:PrivilegeState = @{}
$script:BackupWarned = $false

function Enable-NtfsPrivilege {
    # Aktiviert ein Token-Privileg für den aktuellen Prozess (einmal pro Sitzung) und meldet, ob es aktiv ist.
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string]$Name)

    if (-not $script:PrivilegeState.ContainsKey($Name)) {
        try {
            $script:PrivilegeState[$Name] = [NtfsPermissions.TokenPrivilege]::Enable($Name)
        }
        catch {
            Write-Verbose "Privileg ${Name}: $($_.Exception.Message)"
            $script:PrivilegeState[$Name] = $false
        }
    }
    $script:PrivilegeState[$Name]
}
