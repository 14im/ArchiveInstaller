@{
    RootModule        = 'ArchiveInstaller.psm1'
    ModuleVersion     = '1.1.1'
    GUID              = 'b8a0f1f5-9a0b-4f8c-9f4f-3f7c6f9a3d81'
    Author            = 'TOUAHRIA Karim'
    CompanyName       = 'ArchiveInstaller'
    Copyright         = '(c) 2026 TOUAHRIA Karim. Tous droits reserves.'
    Description       = 'Telechargement et installation d"archives avec FastDownload (HttpClient/BITS), verification de checksum, Force, Verbose et WhatIf.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Get-PowerShellArchive','Expand-PowerShellArchive','Get-VSCodeArchive','Expand-VSCodeArchive','Get-WindowsTerminalArchive','Expand-WindowsTerminalArchive','Get-PowershellVSCodeExtension','Install-PowershellVSCodeExtension','Get-Git','Install-Git')
    CmdletsToExport   = @()
    AliasesToExport   = @()
    PrivateData       = @{ PSData = @{ Tags = @('Downloads','Archive','Installer','GitHub','PowerShell','VSCode','WindowsTerminal','BITS','FastDownload','Checksum') } }
}