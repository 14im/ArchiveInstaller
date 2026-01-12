BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force

    # Explicitly load class files (base class first, then derived)
    $classPath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\Classes" -Resolve
    . (Join-Path $classPath "ArchiveInstaller.ps1")
    . (Join-Path $classPath "PowershellArchiveInstaller.ps1")
}

Describe "PowershellArchiveInstaller Class" -Tag 'Unit', 'Classes' {

    Context "Constructor" {
        It "Should create instance with default constructor" {
            $installer = [PowershellArchiveInstaller]::new()

            $installer | Should -Not -BeNullOrEmpty
        }

        It "Should set GithubRepositoryOwner to 'PowerShell'" {
            $installer = [PowershellArchiveInstaller]::new()

            $installer.GithubRepositoryOwner | Should -Be 'PowerShell'
        }

        It "Should set GithubRepositoryName to 'PowerShell'" {
            $installer = [PowershellArchiveInstaller]::new()

            $installer.GithubRepositoryName | Should -Be 'PowerShell'
        }

        It "Should set ArchiveGlob to 'PowerShell-*-x64.zip'" {
            $installer = [PowershellArchiveInstaller]::new()

            $installer.ArchiveGlob | Should -Be 'PowerShell-*-x64.zip'
        }

        It "Should inherit from ArchiveInstaller" {
            $installer = [PowershellArchiveInstaller]::new()

            $installer -is [ArchiveInstaller] | Should -Be $true
        }

        It "Should have default DownloadDirectory from base class" {
            $installer = [PowershellArchiveInstaller]::new()

            $installer.DownloadDirectory | Should -Not -BeNullOrEmpty
        }
    }

    Context "GetGitHubDownloadUrl Method" {
        BeforeEach {
            $script:installer = [PowershellArchiveInstaller]::new()
        }

        It "Should query PowerShell/PowerShell repository" {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -match "PowerShell/PowerShell" } {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{ name = "PowerShell-7.4.0-x64.zip"; browser_download_url = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/PowerShell-7.4.0-x64.zip" }
                    )
                }
            }

            $url = $script:installer.GetGitHubDownloadUrl()

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Uri -match "PowerShell/PowerShell" }
        }

        It "Should return download URL for matching asset" {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{ name = "PowerShell-7.4.0-x64.zip"; browser_download_url = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/PowerShell-7.4.0-x64.zip" }
                        [PSCustomObject]@{ name = "PowerShell-7.4.0-arm64.zip"; browser_download_url = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/PowerShell-7.4.0-arm64.zip" }
                    )
                }
            }

            $url = $script:installer.GetGitHubDownloadUrl()

            $url | Should -Match "PowerShell-7.4.0-x64.zip"
            $url | Should -Not -Match "arm64"
        }

        It "Should filter by x64 glob pattern" {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{ name = "PowerShell-7.4.0-x64.zip"; browser_download_url = "https://example.com/x64.zip" }
                        [PSCustomObject]@{ name = "PowerShell-7.4.0-arm64.zip"; browser_download_url = "https://example.com/arm64.zip" }
                        [PSCustomObject]@{ name = "PowerShell-7.4.0-win-x86.zip"; browser_download_url = "https://example.com/x86.zip" }
                    )
                }
            }

            $url = $script:installer.GetGitHubDownloadUrl()

            # Should match the glob pattern PowerShell-*-x64.zip
            $url | Should -Be "https://example.com/x64.zip"
        }

        It "Should use User-Agent header" {
            Mock Invoke-RestMethod -ParameterFilter { $Headers['User-Agent'] -eq 'ArchiveInstaller' } {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{ name = "PowerShell-7.4.0-x64.zip"; browser_download_url = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/PowerShell-7.4.0-x64.zip" }
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
                        [PSCustomObject]@{ name = "PowerShell-7.4.0-arm64.zip"; browser_download_url = "https://example.com/arm64.zip" }
                    )
                }
            }

            { $script:installer.GetGitHubDownloadUrl() } | Should -Throw "*No matching asset*"
        }
    }

    Context "Inherited Functionality" {
        BeforeEach {
            $script:installer = [PowershellArchiveInstaller]::new()
            $script:installer.DownloadDirectory = $TestDrive
        }

        It "Should inherit GetDownloadArchive method" {
            $script:installer.DownloadUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/PowerShell-7.4.0-x64.zip"

            Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'HEAD' } {
                return [PSCustomObject]@{
                    Headers = @{ 'Content-Disposition' = 'filename="PowerShell-7.4.0-x64.zip"' }
                    BaseResponse = [PSCustomObject]@{
                        ResponseUri = [PSCustomObject]@{
                            AbsolutePath = "/PowerShell-7.4.0-x64.zip"
                        }
                    }
                }
            }

            $filename = $script:installer.GetDownloadArchive()

            $filename | Should -Be "PowerShell-7.4.0-x64.zip"
        }

        It "Should inherit Download method" {
            $script:installer.DownloadUrl = "https://example.com/powershell.zip"

            Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'HEAD' } {
                return [PSCustomObject]@{
                    Headers = @{ 'Content-Disposition' = 'filename="powershell.zip"' }
                    BaseResponse = [PSCustomObject]@{
                        ResponseUri = [PSCustomObject]@{
                            AbsolutePath = "/powershell.zip"
                        }
                    }
                }
            }

            Mock Invoke-WebRequest -ParameterFilter { $Method -ne 'HEAD' } {
                "content" | Out-File (Join-Path $TestDrive "powershell.zip")
            }

            $result = $script:installer.Download()

            $result | Should -Match "powershell.zip"
            Test-Path $result | Should -Be $true
        }
    }

    Context "DefaultDestination Static Method" {
        It "Should use inherited DefaultDestination" {
            $destination = [PowershellArchiveInstaller]::DefaultDestination()

            $destination | Should -Not -BeNullOrEmpty
            $destination | Should -Match 'Programs\\Microsoft'
        }
    }
}
