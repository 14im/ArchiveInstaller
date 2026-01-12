BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force

    # Explicitly load class files (base class first, then derived)
    $classPath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\Classes" -Resolve
    . (Join-Path $classPath "ArchiveInstaller.ps1")
    . (Join-Path $classPath "VSCodeArchiveInstaller.ps1")
}

Describe "VSCodeArchiveInstaller Class" -Tag 'Unit', 'Classes' {

    Context "Constructor" {
        It "Should create instance with default constructor" {
            $installer = [VSCodeArchiveInstaller]::new()

            $installer | Should -Not -BeNullOrEmpty
        }

        It "Should set DownloadUrl to VSCode direct download URL" {
            $installer = [VSCodeArchiveInstaller]::new()

            $installer.DownloadUrl | Should -Be 'https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-archive'
        }

        It "Should set ArchiveGlob to 'VSCode-win32-x64-*.zip'" {
            $installer = [VSCodeArchiveInstaller]::new()

            $installer.ArchiveGlob | Should -Be 'VSCode-win32-x64-*.zip'
        }

        It "Should not set GithubRepositoryOwner" {
            $installer = [VSCodeArchiveInstaller]::new()

            $installer.GithubRepositoryOwner | Should -BeNullOrEmpty
        }

        It "Should not set GithubRepositoryName" {
            $installer = [VSCodeArchiveInstaller]::new()

            $installer.GithubRepositoryName | Should -BeNullOrEmpty
        }

        It "Should inherit from ArchiveInstaller" {
            $installer = [VSCodeArchiveInstaller]::new()

            $installer -is [ArchiveInstaller] | Should -Be $true
        }

        It "Should have default DownloadDirectory from base class" {
            $installer = [VSCodeArchiveInstaller]::new()

            $installer.DownloadDirectory | Should -Not -BeNullOrEmpty
        }
    }

    Context "Download Configuration" {
        BeforeEach {
            $script:installer = [VSCodeArchiveInstaller]::new()
        }

        It "Should have DownloadUrl pre-configured" {
            $script:installer.DownloadUrl | Should -Not -BeNullOrEmpty
            $script:installer.DownloadUrl | Should -Match "code.visualstudio.com"
        }

        It "Should not require GitHub API calls" {
            # VSCode uses direct download URL, no GitHub API needed
            $script:installer.GithubRepositoryOwner | Should -BeNullOrEmpty
            $script:installer.GithubRepositoryName | Should -BeNullOrEmpty
        }

        It "Should use stable build in URL" {
            $script:installer.DownloadUrl | Should -Match "build=stable"
        }

        It "Should target win32-x64 architecture in URL" {
            $script:installer.DownloadUrl | Should -Match "os=win32-x64-archive"
        }
    }

    Context "Inherited Functionality" {
        BeforeEach {
            $script:installer = [VSCodeArchiveInstaller]::new()
            $script:installer.DownloadDirectory = $TestDrive
        }

        It "Should inherit GetDownloadArchive method" {
            Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'HEAD' } {
                return [PSCustomObject]@{
                    Headers = @{ 'Content-Disposition' = 'filename="VSCode-win32-x64-1.85.0.zip"' }
                    BaseResponse = [PSCustomObject]@{
                        ResponseUri = [PSCustomObject]@{
                            AbsolutePath = "/VSCode-win32-x64-1.85.0.zip"
                        }
                    }
                }
            }

            $filename = $script:installer.GetDownloadArchive()

            $filename | Should -Be "VSCode-win32-x64-1.85.0.zip"
        }

        It "Should inherit Download method" {
            Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'HEAD' } {
                return [PSCustomObject]@{
                    Headers = @{ 'Content-Disposition' = 'filename="vscode.zip"' }
                    BaseResponse = [PSCustomObject]@{
                        ResponseUri = [PSCustomObject]@{
                            AbsolutePath = "/vscode.zip"
                        }
                    }
                }
            }

            Mock Invoke-WebRequest -ParameterFilter { $Method -ne 'HEAD' } {
                "content" | Out-File (Join-Path $TestDrive "vscode.zip")
            }

            $result = $script:installer.Download()

            $result | Should -Match "vscode.zip"
            Test-Path $result | Should -Be $true
        }
    }

    Context "DefaultDestination Static Method" {
        It "Should use inherited DefaultDestination" {
            $destination = [VSCodeArchiveInstaller]::DefaultDestination()

            $destination | Should -Not -BeNullOrEmpty
            $destination | Should -Match 'Programs\\Microsoft'
        }
    }
}
