BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force

    # Explicitly load class files (base class first, then derived)
    $classPath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\Classes" -Resolve
    . (Join-Path $classPath "ArchiveInstaller.ps1")
    . (Join-Path $classPath "WindowsTerminalArchiveInstaller.ps1")
}

Describe "WindowsTerminalArchiveInstaller Class" -Tag 'Unit', 'Classes' {

    Context "Constructor" {
        It "Should create instance with default constructor" {
            $installer = [WindowsTerminalArchiveInstaller]::new()

            $installer | Should -Not -BeNullOrEmpty
        }

        It "Should set GithubRepositoryOwner to 'microsoft'" {
            $installer = [WindowsTerminalArchiveInstaller]::new()

            $installer.GithubRepositoryOwner | Should -Be 'microsoft'
        }

        It "Should set GithubRepositoryName to 'terminal'" {
            $installer = [WindowsTerminalArchiveInstaller]::new()

            $installer.GithubRepositoryName | Should -Be 'terminal'
        }

        It "Should set ArchiveGlob to 'Microsoft.WindowsTerminal_*x64.zip'" {
            $installer = [WindowsTerminalArchiveInstaller]::new()

            $installer.ArchiveGlob | Should -Be 'Microsoft.WindowsTerminal_*x64.zip'
        }

        It "Should inherit from ArchiveInstaller" {
            $installer = [WindowsTerminalArchiveInstaller]::new()

            $installer -is [ArchiveInstaller] | Should -Be $true
        }

        It "Should have default DownloadDirectory from base class" {
            $installer = [WindowsTerminalArchiveInstaller]::new()

            $installer.DownloadDirectory | Should -Not -BeNullOrEmpty
        }
    }

    Context "GetGitHubDownloadUrl Method" {
        BeforeEach {
            $script:installer = [WindowsTerminalArchiveInstaller]::new()
        }

        It "Should query microsoft/terminal repository" {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -match "microsoft/terminal" } {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{ name = "Microsoft.WindowsTerminal_1.18.10301.0_x64.zip"; browser_download_url = "https://github.com/microsoft/terminal/releases/download/v1.18.10301.0/Microsoft.WindowsTerminal_1.18.10301.0_x64.zip" }
                    )
                }
            }

            $url = $script:installer.GetGitHubDownloadUrl()

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Uri -match "microsoft/terminal" }
        }

        It "Should return download URL for matching asset" {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{ name = "Microsoft.WindowsTerminal_1.18.10301.0_x64.zip"; browser_download_url = "https://github.com/microsoft/terminal/releases/download/v1.18.10301.0/Microsoft.WindowsTerminal_1.18.10301.0_x64.zip" }
                        [PSCustomObject]@{ name = "Microsoft.WindowsTerminal_1.18.10301.0_arm64.zip"; browser_download_url = "https://github.com/microsoft/terminal/releases/download/v1.18.10301.0/Microsoft.WindowsTerminal_1.18.10301.0_arm64.zip" }
                    )
                }
            }

            $url = $script:installer.GetGitHubDownloadUrl()

            $url | Should -Match "Microsoft.WindowsTerminal_.*_x64.zip"
            $url | Should -Not -Match "arm64"
        }

        It "Should filter by x64 glob pattern" {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{ name = "Microsoft.WindowsTerminal_1.18.10301.0_x64.zip"; browser_download_url = "https://example.com/x64.zip" }
                        [PSCustomObject]@{ name = "Microsoft.WindowsTerminal_1.18.10301.0_arm64.zip"; browser_download_url = "https://example.com/arm64.zip" }
                        [PSCustomObject]@{ name = "Microsoft.WindowsTerminal_1.18.10301.0_x86.zip"; browser_download_url = "https://example.com/x86.zip" }
                    )
                }
            }

            $url = $script:installer.GetGitHubDownloadUrl()

            # Should match the glob pattern Microsoft.WindowsTerminal_*x64.zip
            $url | Should -Be "https://example.com/x64.zip"
        }

        It "Should throw when no matching asset found" {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{ name = "Microsoft.WindowsTerminal_1.18.10301.0_arm64.zip"; browser_download_url = "https://example.com/arm64.zip" }
                    )
                }
            }

            { $script:installer.GetGitHubDownloadUrl() } | Should -Throw "*No matching asset*"
        }
    }

    Context "ExtractLastLocalArchive Override - No Parameters" {
        BeforeEach {
            $script:installer = [WindowsTerminalArchiveInstaller]::new()
            $script:installer.DownloadDirectory = $TestDrive

            # Create test archive structure
            $archiveName = "Microsoft.WindowsTerminal_1.18.10301.0_x64.zip"
            $archivePath = Join-Path $TestDrive $archiveName
            "dummy" | Out-File $archivePath

            # Create extraction directory with subdirectory
            $extractionDir = Join-Path $TestDrive "Microsoft.WindowsTerminal_1.18.10301.0_x64"
            $subDir = Join-Path $extractionDir "terminal-1.18.10301.0"
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null
            "content" | Out-File (Join-Path $subDir "wt.exe")
            "content" | Out-File (Join-Path $subDir "profiles.json")
        }

        It "Should call base ExtractLastLocalArchive with default destination" {
            Mock Expand-Archive {}
            Mock Get-ChildItem -ParameterFilter { $Directory } {
                $subDir = Join-Path $TestDrive "Microsoft.WindowsTerminal_1.18.10301.0_x64\terminal-1.18.10301.0"
                return @([PSCustomObject]@{ FullName = $subDir })
            }
            Mock Move-Item {}
            Mock Remove-Item {}

            $result = $script:installer.ExtractLastLocalArchive()

            $result | Should -Match "Programs\\Microsoft"
        }

        It "Should flatten subdirectory structure" {
            $extractionDir = Join-Path $TestDrive "Microsoft.WindowsTerminal_1.18.10301.0_x64"
            $subDir = Join-Path $extractionDir "terminal-1.18.10301.0"

            Mock Expand-Archive {}
            Mock Get-ChildItem -ParameterFilter { $Directory } {
                return @([PSCustomObject]@{ FullName = $subDir })
            }

            $movedItems = @()
            Mock Move-Item {
                $movedItems += $Source
            }

            Mock Remove-Item {}

            # Test that files are moved from subdirectory
            $result = $script:installer.ExtractLastLocalArchive()

            Should -Invoke Move-Item -Times 1
        }

        It "Should remove subdirectory after moving contents" {
            $extractionDir = Join-Path $TestDrive "Microsoft.WindowsTerminal_1.18.10301.0_x64"
            $subDir = Join-Path $extractionDir "terminal-1.18.10301.0"

            Mock Expand-Archive {}
            Mock Get-ChildItem -ParameterFilter { $Directory } {
                return @([PSCustomObject]@{ FullName = $subDir })
            }
            Mock Move-Item {}
            Mock Remove-Item {}

            $result = $script:installer.ExtractLastLocalArchive()

            Should -Invoke Remove-Item -Times 1 -ParameterFilter { $Recurse -and $Force }
        }
    }

    Context "ExtractLastLocalArchive Override - With Destination" {
        BeforeEach {
            $script:installer = [WindowsTerminalArchiveInstaller]::new()
            $script:installer.DownloadDirectory = $TestDrive
            $script:destination = Join-Path $TestDrive "CustomDestination"

            # Create test archive
            $archiveName = "Microsoft.WindowsTerminal_1.18.10301.0_x64.zip"
            $archivePath = Join-Path $TestDrive $archiveName
            "dummy" | Out-File $archivePath
        }

        It "Should accept custom destination parameter" {
            Mock Expand-Archive {}
            Mock Get-ChildItem -ParameterFilter { $Directory } {
                return $null  # No subdirectories
            }

            $result = $script:installer.ExtractLastLocalArchive($script:destination)

            $result | Should -Match "CustomDestination"
        }

        It "Should handle case with no subdirectories" {
            Mock Expand-Archive {}
            Mock Get-ChildItem -ParameterFilter { $Directory } {
                return $null  # No subdirectories
            }

            # Should not throw
            { $script:installer.ExtractLastLocalArchive($script:destination) } | Should -Not -Throw
        }

        It "Should select first subdirectory when multiple exist" {
            $extractionDir = Join-Path $script:destination "Microsoft.WindowsTerminal_1.18.10301.0_x64"
            $subDir1 = Join-Path $extractionDir "terminal-1"
            $subDir2 = Join-Path $extractionDir "terminal-2"

            Mock Expand-Archive {}
            Mock Get-ChildItem -ParameterFilter { $Directory } {
                return @(
                    [PSCustomObject]@{ FullName = $subDir1 }
                    [PSCustomObject]@{ FullName = $subDir2 }
                )
            }
            Mock Move-Item {}
            Mock Remove-Item {}

            $result = $script:installer.ExtractLastLocalArchive($script:destination)

            # Should only process first subdirectory
            Should -Invoke Move-Item -Times 1
            Should -Invoke Remove-Item -Times 1
        }
    }

    Context "Inherited Functionality" {
        BeforeEach {
            $script:installer = [WindowsTerminalArchiveInstaller]::new()
            $script:installer.DownloadDirectory = $TestDrive
        }

        It "Should inherit GetDownloadArchive method" {
            $script:installer.DownloadUrl = "https://github.com/microsoft/terminal/releases/download/v1.18.10301.0/Microsoft.WindowsTerminal_1.18.10301.0_x64.zip"

            Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'HEAD' } {
                return [PSCustomObject]@{
                    Headers = @{ 'Content-Disposition' = 'filename="Microsoft.WindowsTerminal_1.18.10301.0_x64.zip"' }
                    BaseResponse = [PSCustomObject]@{
                        ResponseUri = [PSCustomObject]@{
                            AbsolutePath = "/Microsoft.WindowsTerminal_1.18.10301.0_x64.zip"
                        }
                    }
                }
            }

            $filename = $script:installer.GetDownloadArchive()

            $filename | Should -Be "Microsoft.WindowsTerminal_1.18.10301.0_x64.zip"
        }

        It "Should inherit Download method" {
            $script:installer.DownloadUrl = "https://example.com/terminal.zip"

            Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'HEAD' } {
                return [PSCustomObject]@{
                    Headers = @{ 'Content-Disposition' = 'filename="terminal.zip"' }
                    BaseResponse = [PSCustomObject]@{
                        ResponseUri = [PSCustomObject]@{
                            AbsolutePath = "/terminal.zip"
                        }
                    }
                }
            }

            Mock Invoke-WebRequest -ParameterFilter { $Method -ne 'HEAD' } {
                "content" | Out-File (Join-Path $TestDrive "terminal.zip")
            }

            $result = $script:installer.Download()

            $result | Should -Match "terminal.zip"
            Test-Path $result | Should -Be $true
        }
    }

    Context "DefaultDestination Static Method" {
        It "Should use inherited DefaultDestination" {
            $destination = [WindowsTerminalArchiveInstaller]::DefaultDestination()

            $destination | Should -Not -BeNullOrEmpty
            $destination | Should -Match 'Programs\\Microsoft'
        }
    }
}
