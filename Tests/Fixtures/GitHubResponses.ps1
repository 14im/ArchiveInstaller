function Get-MockGitHubRelease {
    param(
        [string]$RepoOwner = "PowerShell",
        [string]$RepoName = "PowerShell",
        [string]$Version = "7.4.0"
    )

    return @{
        tag_name = "v$Version"
        name = "v$Version Release"
        assets = @(
            @{
                name = "PowerShell-$Version-win-x64.zip"
                browser_download_url = "https://github.com/$RepoOwner/$RepoName/releases/download/v$Version/PowerShell-$Version-win-x64.zip"
                size = 104857600
            },
            @{
                name = "hashes.sha256"
                browser_download_url = "https://github.com/$RepoOwner/$RepoName/releases/download/v$Version/hashes.sha256"
                size = 2048
            },
            @{
                name = "PowerShell-$Version-linux-x64.tar.gz"
                browser_download_url = "https://github.com/$RepoOwner/$RepoName/releases/download/v$Version/PowerShell-$Version-linux-x64.tar.gz"
                size = 67108864
            }
        )
    }
}

function Get-MockGitRelease {
    param(
        [string]$Version = "2.43.0.windows.1"
    )

    return @{
        tag_name = "v$Version"
        name = "v$Version Release"
        assets = @(
            @{
                name = "Git-2.43.0-64-bit.zip"
                browser_download_url = "https://github.com/git-for-windows/git/releases/download/v$Version/Git-2.43.0-64-bit.zip"
                size = 52428800
            },
            @{
                name = "checksums.txt"
                browser_download_url = "https://github.com/git-for-windows/git/releases/download/v$Version/checksums.txt"
                size = 1024
            }
        )
    }
}

function Get-MockWindowsTerminalRelease {
    param(
        [string]$Version = "1.18.2822.0"
    )

    return @{
        tag_name = "v$Version"
        name = "v$Version Release"
        assets = @(
            @{
                name = "Microsoft.WindowsTerminal_Win10_$($Version)_8wekyb3d8bbwe_x64.zip"
                browser_download_url = "https://github.com/microsoft/terminal/releases/download/v$Version/Microsoft.WindowsTerminal_Win10_$($Version)_8wekyb3d8bbwe_x64.zip"
                size = 31457280
            },
            @{
                name = "SHA256SUMS"
                browser_download_url = "https://github.com/microsoft/terminal/releases/download/v$Version/SHA256SUMS"
                size = 512
            }
        )
    }
}

function Get-MockPowerShellVSCodeExtensionRelease {
    param(
        [string]$Version = "2023.8.0"
    )

    return @{
        tag_name = "v$Version"
        name = "v$Version Release"
        assets = @(
            @{
                name = "powershell-$Version.vsix"
                browser_download_url = "https://github.com/PowerShell/vscode-powershell/releases/download/v$Version/powershell-$Version.vsix"
                size = 10485760
            }
        )
    }
}
