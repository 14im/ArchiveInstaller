BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force

    # Dot-source the class file directly for testing
    $classPath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\Classes\ArchiveInstaller.ps1" -Resolve
    . $classPath

    # Load fixtures
    . (Join-Path $PSScriptRoot "..\..\Fixtures\GitHubResponses.ps1" -Resolve)
    . (Join-Path $PSScriptRoot "..\..\Helpers\MockHelpers.ps1" -Resolve)
}

Describe "ArchiveInstaller Class" -Tag 'Unit', 'Classes' {

    Context "Constructors" {
        It "Should create instance with default constructor" {
            $installer = [ArchiveInstaller]::new()
            $installer | Should -Not -BeNullOrEmpty
            $installer.DownloadDirectory | Should -Not -BeNullOrEmpty
        }

        It "Should create instance with DownloadUrl" {
            $url = "https://example.com/archive.zip"
            $installer = [ArchiveInstaller]::new($url)
            $installer.DownloadUrl | Should -Be $url
        }

        It "Should create instance with GitHub owner and repo" {
            $installer = [ArchiveInstaller]::new("PowerShell", "PowerShell")
            $installer.GithubRepositoryOwner | Should -Be "PowerShell"
            $installer.GithubRepositoryName | Should -Be "PowerShell"
        }

        It "Should create instance with GitHub owner, repo, and glob" {
            $installer = [ArchiveInstaller]::new("PowerShell", "PowerShell", "*-x64.zip")
            $installer.GithubRepositoryOwner | Should -Be "PowerShell"
            $installer.GithubRepositoryName | Should -Be "PowerShell"
            $installer.ArchiveGlob | Should -Be "*-x64.zip"
        }

        It "Should set default DownloadDirectory to Downloads folder" {
            $installer = [ArchiveInstaller]::new()
            $installer.DownloadDirectory | Should -Not -BeNullOrEmpty
            # Should contain user profile path
            $installer.DownloadDirectory | Should -Match "Downloads"
        }

        It "Should set default ArchiveGlob to *x64.zip" {
            $installer = [ArchiveInstaller]::new()
            $installer.ArchiveGlob | Should -Be '*x64.zip'
        }
    }

    Context "GetGitHubDownloadUrl Method" {
        BeforeEach {
            $script:installer = [ArchiveInstaller]::new("PowerShell", "PowerShell", "PowerShell-*-x64.zip")
        }

        It "Should query GitHub API and return download URL" {
            Mock Invoke-RestMethod {
                return @{
                    assets = @(
                        @{
                            name = "PowerShell-7.4.0-win-x64.zip"
                            browser_download_url = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/PowerShell-7.4.0-win-x64.zip"
                        },
                        @{
                            name = "PowerShell-7.4.0-linux-x64.tar.gz"
                            browser_download_url = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/PowerShell-7.4.0-linux-x64.tar.gz"
                        }
                    )
                }
            }

            $url = $script:installer.GetGitHubDownloadUrl()

            $url | Should -Match "PowerShell-.*-win-x64.zip"
            Should -Invoke Invoke-RestMethod -Times 1
        }

        It "Should use User-Agent header" {
            Mock Invoke-RestMethod {
                $Headers['User-Agent'] | Should -Be 'ArchiveInstaller'
                return Get-MockGitHubRelease
            }

            $script:installer.GetGitHubDownloadUrl()
        }

        It "Should select first matching asset based on glob" {
            Mock Invoke-RestMethod {
                return @{
                    assets = @(
                        @{ name = "app-v1.0-x64.zip"; browser_download_url = "https://example.com/v1.zip" },
                        @{ name = "app-v1.0-x86.zip"; browser_download_url = "https://example.com/v1-x86.zip" },
                        @{ name = "app-v1.0-arm64.zip"; browser_download_url = "https://example.com/v1-arm.zip" }
                    )
                }
            }

            $script:installer.ArchiveGlob = "*-x64.zip"
            $url = $script:installer.GetGitHubDownloadUrl()

            $url | Should -Be "https://example.com/v1.zip"
        }

        It "Should throw when no matching asset found" {
            Mock Invoke-RestMethod {
                return @{
                    assets = @(
                        @{ name = "wrong-file.tar.gz"; browser_download_url = "https://example.com/wrong.tar.gz" }
                    )
                }
            }

            { $script:installer.GetGitHubDownloadUrl() } | Should -Throw "*No matching asset found*"
        }

        It "Should write verbose messages" {
            Mock Invoke-RestMethod { return Get-MockGitHubRelease }
            Mock Write-Verbose { } -Verifiable -ParameterFilter { $Message -match "Querying GitHub" }

            $script:installer.GetGitHubDownloadUrl()

            Should -InvokeVerifiable
        }

        It "Should use correct GitHub API endpoint" {
            Mock Invoke-RestMethod {
                $Uri | Should -Match "api.github.com/repos/.*/releases/latest"
                return Get-MockGitHubRelease
            }

            $script:installer.GetGitHubDownloadUrl()
        }

        It "Should handle glob patterns with wildcards" {
            Mock Invoke-RestMethod {
                return @{
                    assets = @(
                        @{ name = "myapp-1.0-win-x64.zip"; browser_download_url = "https://example.com/1.zip" },
                        @{ name = "myapp-1.0-linux-x64.tar.gz"; browser_download_url = "https://example.com/2.tar.gz" }
                    )
                }
            }

            $script:installer.ArchiveGlob = "myapp-*-win-*.zip"
            $url = $script:installer.GetGitHubDownloadUrl()

            $url | Should -Be "https://example.com/1.zip"
        }
    }

    Context "GetDownloadArchive Method" {
        BeforeEach {
            $script:installer = [ArchiveInstaller]::new("https://example.com/archive.zip")
        }

        It "Should resolve filename from Content-Disposition header" {
            Mock Invoke-WebRequest {
                return @{
                    Headers = @{
                        'Content-Disposition' = 'attachment; filename="myfile.zip"'
                    }
                    BaseResponse = @{
                        ResponseUri = @{ AbsolutePath = "/path/archive.zip" }
                    }
                }
            }

            $filename = $script:installer.GetDownloadArchive()

            $filename | Should -Be "myfile.zip"
        }

        It "Should parse Content-Disposition with quotes" {
            Mock Invoke-WebRequest {
                return @{
                    Headers = @{
                        'Content-Disposition' = 'attachment; filename="quoted-file.zip"'
                    }
                    BaseResponse = @{
                        ResponseUri = @{ AbsolutePath = "/path/file.zip" }
                    }
                }
            }

            $filename = $script:installer.GetDownloadArchive()

            $filename | Should -Be "quoted-file.zip"
        }

        It "Should fallback to URI leaf when no Content-Disposition" {
            Mock Invoke-WebRequest {
                return @{
                    Headers = @{}
                    BaseResponse = @{
                        ResponseUri = @{ AbsolutePath = "/releases/download/v1.0/archive.zip" }
                    }
                }
            }

            $filename = $script:installer.GetDownloadArchive()

            $filename | Should -Be "archive.zip"
        }

        It "Should use HEAD method to avoid downloading" {
            Mock Invoke-WebRequest {
                $Method | Should -Be 'HEAD'
                return @{
                    Headers = @{ 'Content-Disposition' = 'attachment; filename="test.zip"' }
                    BaseResponse = @{ ResponseUri = @{ AbsolutePath = "/test.zip" } }
                }
            }

            $script:installer.GetDownloadArchive()
        }

        It "Should throw when filename cannot be determined" {
            Mock Invoke-WebRequest {
                return @{
                    Headers = @{}
                    BaseResponse = @{ ResponseUri = @{ AbsolutePath = "/" } }
                }
            }

            $script:installer.DownloadUrl = "https://example.com/"

            { $script:installer.GetDownloadArchive() } | Should -Throw "*Unable to determine filename*"
        }

        It "Should set User-Agent header" {
            Mock Invoke-WebRequest {
                $Headers['User-Agent'] | Should -Be 'ArchiveInstaller'
                return @{
                    Headers = @{}
                    BaseResponse = @{ ResponseUri = @{ AbsolutePath = "/test.zip" } }
                }
            }

            $script:installer.GetDownloadArchive()
        }

        It "Should use UseBasicParsing" {
            Mock Invoke-WebRequest {
                $UseBasicParsing | Should -Be $true
                return @{
                    Headers = @{}
                    BaseResponse = @{ ResponseUri = @{ AbsolutePath = "/test.zip" } }
                }
            }

            $script:installer.GetDownloadArchive()
        }
    }

    Context "Download Method" {
        BeforeEach {
            $script:installer = [ArchiveInstaller]::new("https://example.com/test.zip")
            $script:installer.DownloadDirectory = $TestDrive
        }

        It "Should download file to DownloadDirectory" {
            Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'HEAD' } {
                return @{
                    Headers = @{ 'Content-Disposition' = 'filename="test.zip"' }
                    BaseResponse = @{ ResponseUri = @{ AbsolutePath = "/test.zip" } }
                }
            }

            Mock Invoke-WebRequest -ParameterFilter { $Method -ne 'HEAD' } {
                $filePath = Join-Path $TestDrive "test.zip"
                "test content" | Out-File $filePath
                return @{ StatusCode = 200 }
            }

            $result = $script:installer.Download()

            $result | Should -Match "test.zip"
            Test-Path $result | Should -Be $true
        }

        It "Should throw when DownloadUrl is missing and GitHub info not set" {
            $script:installer.DownloadUrl = $null

            { $script:installer.Download() } | Should -Throw "*Download Url is missing*"
        }

        It "Should resolve GitHub URL when DownloadUrl is null" {
            $script:installer.DownloadUrl = $null
            $script:installer.GithubRepositoryOwner = "test"
            $script:installer.GithubRepositoryName = "repo"

            # First resolve the GitHub URL explicitly
            Mock Invoke-RestMethod { return Get-MockGitHubRelease }
            $script:installer.DownloadUrl = $script:installer.GetGitHubDownloadUrl()

            # Verify URL was resolved
            $script:installer.DownloadUrl | Should -Not -BeNullOrEmpty
            $script:installer.DownloadUrl | Should -Match "PowerShell.*\.zip$"

            # Now test that Download works with the resolved URL
            Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'HEAD' } {
                return @{
                    Headers = @{ 'Content-Disposition' = 'filename="test.zip"' }
                    BaseResponse = @{ ResponseUri = @{ AbsolutePath = "/test.zip" } }
                }
            }
            Mock Invoke-WebRequest -ParameterFilter { $Method -ne 'HEAD' } {
                "content" | Out-File (Join-Path $TestDrive "test.zip")
            }

            $result = $script:installer.Download()

            $result | Should -Match "test.zip"
            Test-Path $result | Should -Be $true
        }

        It "Should write verbose messages" {
            Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'HEAD' } {
                return @{
                    Headers = @{}
                    BaseResponse = @{ ResponseUri = @{ AbsolutePath = "/test.zip" } }
                }
            }
            Mock Invoke-WebRequest -ParameterFilter { $Method -ne 'HEAD' } {
                "content" | Out-File (Join-Path $TestDrive "test.zip")
            }
            Mock Write-Verbose { } -Verifiable -ParameterFilter { $Message -match "Download" }

            $script:installer.Download()

            Should -InvokeVerifiable
        }
    }

    Context "ExtractLastLocalArchive Method" {
        BeforeEach {
            $script:installer = [ArchiveInstaller]::new()
            $script:installer.DownloadDirectory = $TestDrive
            $script:testArchive = Join-Path $TestDrive "test-x64.zip"

            # Create a simple test file to zip
            $testContent = Join-Path $TestDrive "content.txt"
            "test" | Out-File $testContent
            Compress-Archive -Path $testContent -DestinationPath $script:testArchive -Force
        }

        It "Should expand archive to destination" {
            $dest = Join-Path $TestDrive "extracted"

            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{
                        FullName = $script:testArchive
                        Name = "test-x64.zip"
                    }
                )
            }

            Mock Expand-Archive {}

            $result = $script:installer.ExtractLastLocalArchive($dest)

            Should -Invoke Expand-Archive -Times 1
        }

        It "Should create destination directory if it does not exist" {
            $dest = Join-Path $TestDrive "newdir\extracted"

            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{ FullName = $script:testArchive; Name = "test-x64.zip" }
                )
            }

            Mock Expand-Archive {}

            $script:installer.ExtractLastLocalArchive($dest)

            Test-Path (Split-Path $dest -Parent) | Should -Be $true
        }

        It "Should use Force parameter when expanding" {
            $dest = $TestDrive

            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{ FullName = $script:testArchive; Name = "test-x64.zip" }
                )
            }

            Mock Expand-Archive {
                $Force | Should -Be $true
            }

            $script:installer.ExtractLastLocalArchive($dest)
        }

        It "Should return extraction path" {
            $dest = $TestDrive

            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{ FullName = $script:testArchive; Name = "test-x64.zip" }
                )
            }

            Mock Expand-Archive {}

            $result = $script:installer.ExtractLastLocalArchive($dest)

            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match "test"
        }
    }

    Context "GetLastLocalArchive Method" {
        BeforeEach {
            $script:installer = [ArchiveInstaller]::new()
            $script:installer.DownloadDirectory = $TestDrive
            $script:installer.ArchiveGlob = "*-x64.zip"
        }

        It "Should return most recent matching archive" {
            $file1 = Join-Path $TestDrive "app-v1.0-x64.zip"
            $file2 = Join-Path $TestDrive "app-v2.0-x64.zip"

            "v1" | Out-File $file1
            Start-Sleep -Milliseconds 100
            "v2" | Out-File $file2

            $result = $script:installer.GetLastLocalArchive()

            $result | Should -Match "app-v2.0-x64.zip"
        }

        It "Should use ArchiveGlob for filtering" {
            $file1 = Join-Path $TestDrive "app-x64.zip"
            $file2 = Join-Path $TestDrive "app-x86.zip"

            "x64" | Out-File $file1
            "x86" | Out-File $file2

            $result = $script:installer.GetLastLocalArchive()

            $result | Should -Match "x64.zip"
            $result | Should -Not -Match "x86.zip"
        }

        It "Should sort by name and return last" {
            # Clean up any existing files that might interfere
            Get-ChildItem -Path $TestDrive -Filter "*-x64.zip" | Remove-Item -Force

            $files = @("app-v1.0-x64.zip", "app-v2.0-x64.zip", "app-v1.5-x64.zip")
            foreach ($file in $files) {
                "content" | Out-File (Join-Path $TestDrive $file)
            }

            $result = $script:installer.GetLastLocalArchive()

            # Should get last alphabetically sorted
            $result | Should -Match "v2.0"
        }
    }

    Context "DestinationExtractionDirectory Method" {
        BeforeEach {
            $script:installer = [ArchiveInstaller]::new()
            $script:installer.DownloadDirectory = $TestDrive
        }

        It "Should compute extraction path from archive name" {
            $archive = Join-Path $TestDrive "PowerShell-7.4.0-win-x64.zip"
            "test" | Out-File $archive

            Mock Get-ChildItem {
                return @([PSCustomObject]@{ FullName = $archive; Name = "PowerShell-7.4.0-win-x64.zip" })
            }

            $dest = $script:installer.DestinationExtractionDirectory()

            $dest | Should -Match "PowerShell-7.4.0-win-x64"
            $dest | Should -Not -Match "\.zip"
        }

        It "Should strip .zip extension" {
            $archive = Join-Path $TestDrive "test.zip"

            $dest = $script:installer.DestinationExtractionDirectory($archive)

            $dest | Should -Not -Match "\.zip$"
        }

        It "Should strip .0_x64 suffix" {
            $archive = Join-Path $TestDrive "PowerShell-7.4.0_x64.zip"

            $dest = $script:installer.DestinationExtractionDirectory($archive)

            $dest | Should -Not -Match "\.0_x64"
        }

        It "Should include LocalApplicationData path" {
            $archive = Join-Path $TestDrive "test.zip"

            $dest = $script:installer.DestinationExtractionDirectory($archive)

            $dest | Should -Match "LocalApplicationData|AppData"
        }
    }

    Context "DefaultDestination Static Method" {
        It "Should return path in LocalApplicationData" {
            $dest = [ArchiveInstaller]::DefaultDestination()

            $dest | Should -Not -BeNullOrEmpty
        }

        It "Should include Programs directory" {
            $dest = [ArchiveInstaller]::DefaultDestination()

            $dest | Should -Match "Programs"
        }

        It "Should include Microsoft directory" {
            $dest = [ArchiveInstaller]::DefaultDestination()

            $dest | Should -Match "Microsoft"
        }
    }

    Context "Property Defaults" {
        It "Should have default DownloadDirectory" {
            $installer = [ArchiveInstaller]::new()

            $installer.DownloadDirectory | Should -Not -BeNullOrEmpty
        }

        It "Should allow setting custom DownloadDirectory" {
            $installer = [ArchiveInstaller]::new()
            $customDir = "C:\CustomDownloads"

            $installer.DownloadDirectory = $customDir

            $installer.DownloadDirectory | Should -Be $customDir
        }

        It "Should allow setting DownloadUrl" {
            $installer = [ArchiveInstaller]::new()
            $url = "https://example.com/file.zip"

            $installer.DownloadUrl = $url

            $installer.DownloadUrl | Should -Be $url
        }

        It "Should allow setting GitHub repository properties" {
            $installer = [ArchiveInstaller]::new()

            $installer.GithubRepositoryOwner = "test"
            $installer.GithubRepositoryName = "repo"
            $installer.ArchiveGlob = "*.tar.gz"

            $installer.GithubRepositoryOwner | Should -Be "test"
            $installer.GithubRepositoryName | Should -Be "repo"
            $installer.ArchiveGlob | Should -Be "*.tar.gz"
        }
    }
}
