function Get-MockChecksumFileContent {
    param(
        [ValidateSet("standard", "git", "mixed_spacing", "invalid", "windows_terminal")]
        [string]$Format = "standard"
    )

    switch ($Format) {
        "standard" {
            return @"
a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  PowerShell-7.4.0-win-x64.zip
b234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef  PowerShell-7.4.0-linux-x64.tar.gz
c345678901bcdef2345678901bcdef2345678901bcdef2345678901bcdef234  PowerShell-7.4.0-osx-x64.tar.gz
"@
        }
        "git" {
            return @"
d456789012cdef3456789012cdef3456789012cdef3456789012cdef3456789  Git-2.43.0-64-bit.zip
e567890123def4567890123def4567890123def4567890123def4567890123d  PortableGit-2.43.0-64-bit.7z.exe
f678901234ef5678901234ef5678901234ef5678901234ef5678901234ef567  Git-2.43.0-32-bit.zip
"@
        }
        "mixed_spacing" {
            return @"
a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e    PowerShell-7.4.0-win-x64.zip
b234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef PowerShell-7.4.0-linux-x64.tar.gz
c345678901bcdef2345678901bcdef2345678901bcdef2345678901bcdef234		PowerShell-7.4.0-osx-x64.tar.gz
"@
        }
        "invalid" {
            return @"
invalidhash  file1.zip
abc  file2.zip
a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  correct-file.zip
"@
        }
        "windows_terminal" {
            return @"
g789012345f6789012345f6789012345f6789012345f6789012345f6789012  Microsoft.WindowsTerminal_Win10_1.18.2822.0_8wekyb3d8bbwe_x64.zip
h890123456g7890123456g7890123456g7890123456g7890123456g78901234  Microsoft.WindowsTerminal_Win11_1.18.2822.0_8wekyb3d8bbwe_x64.zip
"@
        }
    }
}

function New-MockArchiveWithChecksum {
    <#
    .SYNOPSIS
        Creates a mock archive file and returns its hash
    .DESCRIPTION
        Creates a test file with specified content and computes its SHA256 hash
    .PARAMETER Path
        Path where to create the mock file
    .PARAMETER Content
        Content to write to the file (default: "Mock archive content")
    .OUTPUTS
        Hashtable with Path, Hash, and Content properties
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Content = "Mock archive content"
    )

    $Content | Out-File -FilePath $Path -Encoding ascii -NoNewline
    $hash = (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLower()

    return @{
        Path = $Path
        Hash = $hash
        Content = $Content
    }
}

function Get-MockChecksumForFile {
    <#
    .SYNOPSIS
        Generates a checksum file entry for a given filename
    .DESCRIPTION
        Creates a properly formatted checksum line with a mock hash
    .PARAMETER FileName
        Name of the file to create checksum for
    .PARAMETER Hash
        Optional specific hash to use (generates a valid-looking hash if not provided)
    .OUTPUTS
        String in format "hash  filename"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FileName,

        [string]$Hash
    )

    if (-not $Hash) {
        # Generate a deterministic but unique-looking hash based on filename
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($FileName)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha256.ComputeHash($bytes)
        $Hash = ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ''
    }

    return "$Hash  $FileName"
}
