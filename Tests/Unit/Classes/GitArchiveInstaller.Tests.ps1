BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force

    # Explicitly load class files (base class first, then derived)
    $classPath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\Classes" -Resolve
    . (Join-Path $classPath "ArchiveInstaller.ps1")
    . (Join-Path $classPath "GitArchiveInstaller.ps1")

    # Load helpers
    . (Join-Path $PSScriptRoot "..\..\Fixtures\GitHubResponses.ps1" -Resolve)
}

Describe "GitArchiveInstaller Class" -Tag 'Unit', 'Classes' {

    Context "Constructor" {
        It "Should create instance with default constructor" {
            $installer = [GitArchiveInstaller]::new()

            $installer | Should -Not -BeNullOrEmpty
        }

        It "Should set GithubRepositoryOwner to 'git-for-windows'" {
            $installer = [GitArchiveInstaller]::new()

            $installer.GithubRepositoryOwner | Should -Be 'git-for-windows'
        }

        It "Should set GithubRepositoryName to 'git'" {
            $installer = [GitArchiveInstaller]::new()

            $installer.GithubRepositoryName | Should -Be 'git'
        }

        It "Should set ArchiveGlob to '*-64-bit.zip'" {
            $installer = [GitArchiveInstaller]::new()

            $installer.ArchiveGlob | Should -Be '*-64-bit.zip'
        }

        It "Should inherit from ArchiveInstaller" {
            $installer = [GitArchiveInstaller]::new()

            $installer -is [ArchiveInstaller] | Should -Be $true
        }

        It "Should have default DownloadDirectory from base class" {
            $installer = [GitArchiveInstaller]::new()

            $installer.DownloadDirectory | Should -Not -BeNullOrEmpty
        }
    }

    Context "GetGitHubDownloadUrl Method" {
        BeforeEach {
            $script:installer = [GitArchiveInstaller]::new()
        }

        It "Should query git-for-windows/git repository" {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -match "git-for-windows/git" } {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{ name = "Git-2.43.0-64-bit.zip"; browser_download_url = "https://github.com/git-for-windows/git/releases/download/v2.43.0/Git-2.43.0-64-bit.zip" }
                    )
                }
            }

            $url = $script:installer.GetGitHubDownloadUrl()

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Uri -match "git-for-windows/git" }
        }

        It "Should return download URL for matching asset" {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{ name = "Git-2.43.0-64-bit.zip"; browser_download_url = "https://github.com/git-for-windows/git/releases/download/v2.43.0/Git-2.43.0-64-bit.zip" }
                        [PSCustomObject]@{ name = "Git-2.43.0-32-bit.zip"; browser_download_url = "https://github.com/git-for-windows/git/releases/download/v2.43.0/Git-2.43.0-32-bit.zip" }
                    )
                }
            }

            $url = $script:installer.GetGitHubDownloadUrl()

            $url | Should -Match "Git-2.43.0-64-bit.zip"
            $url | Should -Not -Match "32-bit"
        }

        It "Should filter by 64-bit glob pattern" {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{ name = "Git-2.43.0-64-bit.zip"; browser_download_url = "https://example.com/64bit.zip" }
                        [PSCustomObject]@{ name = "Git-2.43.0-32-bit.zip"; browser_download_url = "https://example.com/32bit.zip" }
                        [PSCustomObject]@{ name = "PortableGit-2.43.0-64-bit.7z"; browser_download_url = "https://example.com/portable.7z" }
                    )
                }
            }

            $url = $script:installer.GetGitHubDownloadUrl()

            # Should match the glob pattern *-64-bit.zip
            $url | Should -Be "https://example.com/64bit.zip"
        }

        It "Should use User-Agent header" {
            Mock Invoke-RestMethod -ParameterFilter { $Headers['User-Agent'] -eq 'ArchiveInstaller' } {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{ name = "Git-2.43.0-64-bit.zip"; browser_download_url = "https://github.com/git-for-windows/git/releases/download/v2.43.0/Git-2.43.0-64-bit.zip" }
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
                        [PSCustomObject]@{ name = "Git-2.43.0-32-bit.zip"; browser_download_url = "https://example.com/32bit.zip" }
                    )
                }
            }

            { $script:installer.GetGitHubDownloadUrl() } | Should -Throw "*No matching asset*"
        }
    }

    Context "Inherited Functionality" {
        BeforeEach {
            $script:installer = [GitArchiveInstaller]::new()
            $script:installer.DownloadDirectory = $TestDrive
        }

        It "Should inherit GetDownloadArchive method" {
            $script:installer.DownloadUrl = "https://github.com/git-for-windows/git/releases/download/v2.43.0/Git-2.43.0-64-bit.zip"

            Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'HEAD' } {
                return [PSCustomObject]@{
                    Headers = @{ 'Content-Disposition' = 'filename="Git-2.43.0-64-bit.zip"' }
                    BaseResponse = [PSCustomObject]@{
                        ResponseUri = [PSCustomObject]@{
                            AbsolutePath = "/Git-2.43.0-64-bit.zip"
                        }
                    }
                }
            }

            $filename = $script:installer.GetDownloadArchive()

            $filename | Should -Be "Git-2.43.0-64-bit.zip"
        }

        It "Should inherit Download method" {
            $script:installer.DownloadUrl = "https://example.com/git.zip"

            Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'HEAD' } {
                return [PSCustomObject]@{
                    Headers = @{ 'Content-Disposition' = 'filename="git.zip"' }
                    BaseResponse = [PSCustomObject]@{
                        ResponseUri = [PSCustomObject]@{
                            AbsolutePath = "/git.zip"
                        }
                    }
                }
            }

            Mock Invoke-WebRequest -ParameterFilter { $Method -ne 'HEAD' } {
                "content" | Out-File (Join-Path $TestDrive "git.zip")
            }

            $result = $script:installer.Download()

            $result | Should -Match "git.zip"
            Test-Path $result | Should -Be $true
        }

        # NOTE: Test for automatic GitHub URL resolution moved to Integration tests
        # Unit testing this is complex due to PowerShell class method mocking limitations
        # and the interplay between Download() and GetGitHubDownloadUrl()
    }

    Context "DefaultDestination Static Method" {
        It "Should use inherited DefaultDestination" {
            $destination = [GitArchiveInstaller]::DefaultDestination()

            $destination | Should -Not -BeNullOrEmpty
            $destination | Should -Match 'Programs\\Microsoft'
        }
    }
}
