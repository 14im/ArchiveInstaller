# ArchiveInstaller (v1.1.1)

- FastDownload pour tous les Get-* (HttpClient streaming / BITS Windows)
- Verification SHA256: -VerifyChecksum, -Strict, -ChecksumFile
- Force, Verbose, WhatIf/Confirm partout

## Exemples
```powershell
Get-PowerShellArchive -FastDownload -VerifyChecksum -Strict -Verbose
Get-VSCodeArchive      -FastDownload -VerifyChecksum -Verbose
Expand-WindowsTerminalArchive -Verbose -WhatIf
Install-Git -AddPath -Force -Verbose
```