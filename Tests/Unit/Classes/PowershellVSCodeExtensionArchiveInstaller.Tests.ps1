BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force

    # Explicitly load class files (base class first, then derived)
    $classPath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\Classes" -Resolve
    . (Join-Path $classPath "ArchiveInstaller.ps1")
    . (Join-Path $classPath "PowershellVSCodeExtensionArchiveInstaller.ps1")
}

Describe "PowershellVSCodeExtensionArchiveInstaller Class" -Tag 'Unit', 'Classes' {

    Context "Constructor" {
        It "Should create instance with default constructor" {
            $installer = [PowershellVSCodeExtensionArchiveInstaller]::new()

            $installer | Should -Not -BeNullOrEmpty
        }

        It "Should set GithubRepositoryOwner to 'PowerShell'" {
            $installer = [PowershellVSCodeExtensionArchiveInstaller]::new()

            $installer.GithubRepositoryOwner | Should -Be 'PowerShell'
        }

        It "Should set GithubRepositoryName to 'vscode-powershell'" {
            $installer = [PowershellVSCodeExtensionArchiveInstaller]::new()

            $installer.GithubRepositoryName | Should -Be 'vscode-powershell'
        }

        It "Should set ArchiveGlob to 'powershell-*.vsix'" {
            $installer = [PowershellVSCodeExtensionArchiveInstaller]::new()

            $installer.ArchiveGlob | Should -Be 'powershell-*.vsix'
        }

        It "Should inherit from ArchiveInstaller" {
            $installer = [PowershellVSCodeExtensionArchiveInstaller]::new()

            $installer -is [ArchiveInstaller] | Should -Be $true
        }

        It "Should have default DownloadDirectory from base class" {
            $installer = [PowershellVSCodeExtensionArchiveInstaller]::new()

            $installer.DownloadDirectory | Should -Not -BeNullOrEmpty
        }
    }

    Context "GetGitHubDownloadUrl Method" {
        BeforeEach {
            $script:installer = [PowershellVSCodeExtensionArchiveInstaller]::new()
        }

        It "Should query PowerShell/vscode-powershell repository" {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -match "PowerShell/vscode-powershell" } {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{ name = "powershell-2024.2.2.vsix"; browser_download_url = "https://github.com/PowerShell/vscode-powershell/releases/download/v2024.2.2/powershell-2024.2.2.vsix" }
                    )
                }
            }

            $url = $script:installer.GetGitHubDownloadUrl()

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Uri -match "PowerShell/vscode-powershell" }
        }

        It "Should return download URL for matching asset" {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{ name = "powershell-2024.2.2.vsix"; browser_download_url = "https://github.com/PowerShell/vscode-powershell/releases/download/v2024.2.2/powershell-2024.2.2.vsix" }
                        [PSCustomObject]@{ name = "powershell-preview-2024.3.0.vsix"; browser_download_url = "https://github.com/PowerShell/vscode-powershell/releases/download/v2024.3.0/powershell-preview-2024.3.0.vsix" }
                    )
                }
            }

            $url = $script:installer.GetGitHubDownloadUrl()

            $url | Should -Match "powershell-.*\.vsix"
            # Should match the first one due to glob pattern
            $url | Should -Match "powershell-2024.2.2.vsix"
        }

        It "Should filter by vsix glob pattern" {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{ name = "powershell-2024.2.2.vsix"; browser_download_url = "https://example.com/powershell.vsix" }
                        [PSCustomObject]@{ name = "powershell-2024.2.2.zip"; browser_download_url = "https://example.com/powershell.zip" }
                        [PSCustomObject]@{ name = "powershell-source.tar.gz"; browser_download_url = "https://example.com/source.tar.gz" }
                    )
                }
            }

            $url = $script:installer.GetGitHubDownloadUrl()

            # Should match the glob pattern powershell-*.vsix
            $url | Should -Be "https://example.com/powershell.vsix"
        }

        It "Should use User-Agent header" {
            Mock Invoke-RestMethod -ParameterFilter { $Headers['User-Agent'] -eq 'ArchiveInstaller' } {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{ name = "powershell-2024.2.2.vsix"; browser_download_url = "https://github.com/PowerShell/vscode-powershell/releases/download/v2024.2.2/powershell-2024.2.2.vsix" }
                    )
                }
            }

            $script:installer.GetGitHubDownloadUrl()

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Headers['User-Agent'] -eq 'ArchiveInstaller' }
        }

        It "Should throw when no matching asset found" {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{ name = "powershell-source.tar.gz"; browser_download_url = "https://example.com/source.tar.gz" }
                    )
                }
            }

            { $script:installer.GetGitHubDownloadUrl() } | Should -Throw "*No matching asset*"
        }
    }

    Context "VSIX File Support" {
        BeforeEach {
            $script:installer = [PowershellVSCodeExtensionArchiveInstaller]::new()
        }

        It "Should handle VSIX file extension" {
            $script:installer.ArchiveGlob | Should -Match "\.vsix$"
        }

        It "Should target PowerShell extension specifically" {
            $script:installer.GithubRepositoryName | Should -Be 'vscode-powershell'
        }
    }

    Context "Inherited Functionality" {
        BeforeEach {
            $script:installer = [PowershellVSCodeExtensionArchiveInstaller]::new()
            $script:installer.DownloadDirectory = $TestDrive
        }

        It "Should inherit GetDownloadArchive method" {
            $script:installer.DownloadUrl = "https://github.com/PowerShell/vscode-powershell/releases/download/v2024.2.2/powershell-2024.2.2.vsix"

            Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'HEAD' } {
                return [PSCustomObject]@{
                    Headers = @{ 'Content-Disposition' = 'filename="powershell-2024.2.2.vsix"' }
                    BaseResponse = [PSCustomObject]@{
                        ResponseUri = [PSCustomObject]@{
                            AbsolutePath = "/powershell-2024.2.2.vsix"
                        }
                    }
                }
            }

            $filename = $script:installer.GetDownloadArchive()

            $filename | Should -Be "powershell-2024.2.2.vsix"
        }

        It "Should inherit Download method" {
            $script:installer.DownloadUrl = "https://example.com/powershell.vsix"

            Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'HEAD' } {
                return [PSCustomObject]@{
                    Headers = @{ 'Content-Disposition' = 'filename="powershell.vsix"' }
                    BaseResponse = [PSCustomObject]@{
                        ResponseUri = [PSCustomObject]@{
                            AbsolutePath = "/powershell.vsix"
                        }
                    }
                }
            }

            Mock Invoke-WebRequest -ParameterFilter { $Method -ne 'HEAD' } {
                "content" | Out-File (Join-Path $TestDrive "powershell.vsix")
            }

            $result = $script:installer.Download()

            $result | Should -Match "powershell.vsix"
            Test-Path $result | Should -Be $true
        }
    }

    Context "DefaultDestination Static Method" {
        It "Should use inherited DefaultDestination" {
            $destination = [PowershellVSCodeExtensionArchiveInstaller]::DefaultDestination()

            $destination | Should -Not -BeNullOrEmpty
            $destination | Should -Match 'Programs\\Microsoft'
        }
    }
}
