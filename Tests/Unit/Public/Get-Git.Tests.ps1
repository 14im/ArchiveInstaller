BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force

    # Explicitly load class files
    $classPath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\Classes" -Resolve
    . (Join-Path $classPath "ArchiveInstaller.ps1")
    . (Join-Path $classPath "GitArchiveInstaller.ps1")
}

Describe "Get-Git" -Tag 'Unit', 'Public' {

    Context "Download Operations" {
        BeforeEach {
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

            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{
                            name = "Git-2.43.0-64-bit.zip"
                            browser_download_url = "https://github.com/git-for-windows/git/releases/download/v2.43.0/Git-2.43.0-64-bit.zip"
                        }
                    )
                }
            }

            Mock Download-File -ModuleName ArchiveInstaller {
                $targetFile = $OutFile
                "dummy content" | Out-File -LiteralPath $targetFile
            }
        }

        It "Should download from GitHub releases" {
            $result = Get-Git -DownloadDirectory $TestDrive

            Should -Invoke Download-File -ModuleName ArchiveInstaller -Times 1
            $result | Should -Match "Git.*64-bit.zip"
            Test-Path $result | Should -Be $true
        }

        It "Should skip if file exists without -Force" {
            $existingFile = Join-Path $TestDrive "Git-2.43.0-64-bit.zip"
            "existing content" | Out-File -LiteralPath $existingFile

            $result = Get-Git -DownloadDirectory $TestDrive

            Should -Invoke Download-File -ModuleName ArchiveInstaller -Times 0
            $result | Should -Be $existingFile
        }

        It "Should re-download with -Force" {
            $existingFile = Join-Path $TestDrive "Git-2.43.0-64-bit.zip"
            "existing content" | Out-File -LiteralPath $existingFile

            $result = Get-Git -DownloadDirectory $TestDrive -Force

            Should -Invoke Download-File -ModuleName ArchiveInstaller -Times 1
            $result | Should -Be $existingFile
        }

        It "Should create DownloadDirectory if missing" {
            $newDir = Join-Path $TestDrive "NewDownloadDir"

            Get-Git -DownloadDirectory $newDir

            Test-Path $newDir | Should -Be $true
        }

        It "Should use custom DownloadDirectory when specified" {
            $customDir = Join-Path $TestDrive "CustomDir"

            $result = Get-Git -DownloadDirectory $customDir

            $result | Should -Match ([Regex]::Escape($customDir))
        }
    }

    Context "Checksum Verification" {
        BeforeEach {
            # Clean up any existing files
            Get-ChildItem -Path $TestDrive -Filter "*.zip" -ErrorAction SilentlyContinue | Remove-Item -Force

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

            # Mock for checksum file downloads
            Mock Invoke-WebRequest -ParameterFilter { $Uri -like "*checksums.txt*" } {
                $checksumContent = "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  Git-2.43.0-64-bit.zip"
                $checksumContent | Out-File -LiteralPath $OutFile
            }

            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{
                            name = "Git-2.43.0-64-bit.zip"
                            browser_download_url = "https://github.com/git-for-windows/git/releases/download/v2.43.0/Git-2.43.0-64-bit.zip"
                        }
                    )
                }
            }

            Mock Download-File -ModuleName ArchiveInstaller {
                "dummy content" | Out-File -LiteralPath $OutFile
            }
        }

        It "Should verify checksum when -VerifyChecksum specified" {
            Mock Get-GitHubAssetChecksum -ModuleName ArchiveInstaller {
                return "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e"
            }

            Mock Test-Checksum -ModuleName ArchiveInstaller { return $true }

            $result = Get-Git -DownloadDirectory $TestDrive -VerifyChecksum

            Should -Invoke Get-GitHubAssetChecksum -ModuleName ArchiveInstaller -Times 1
            Should -Invoke Test-Checksum -ModuleName ArchiveInstaller -Times 1
        }

        It "Should throw when checksum mismatch" {
            Mock Get-GitHubAssetChecksum -ModuleName ArchiveInstaller {
                return "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e"
            }

            Mock Test-Checksum -ModuleName ArchiveInstaller { return $false }

            { Get-Git -DownloadDirectory $TestDrive -VerifyChecksum } | Should -Throw "*Checksum mismatch*"
        }

        It "Should warn when checksum not found without -Strict" {
            Mock Get-GitHubAssetChecksum -ModuleName ArchiveInstaller { return $null }
            Mock Test-Checksum -ModuleName ArchiveInstaller { return $true }

            $warnings = @()
            $result = Get-Git -DownloadDirectory $TestDrive -VerifyChecksum -WarningVariable +warnings 3>&1

            $warnings -match "Checksum not found" | Should -Not -BeNullOrEmpty
            Should -Invoke Test-Checksum -ModuleName ArchiveInstaller -Times 0
        }

        It "Should throw when checksum not found with -Strict" {
            Mock Get-GitHubAssetChecksum -ModuleName ArchiveInstaller { return $null }

            { Get-Git -DownloadDirectory $TestDrive -VerifyChecksum -Strict } | Should -Throw "*Checksum not found*"
        }

        It "Should use ChecksumFile parameter if provided (local file)" {
            $checksumFile = Join-Path $TestDrive "checksums.txt"
            "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  Git-2.43.0-64-bit.zip" | Out-File -LiteralPath $checksumFile

            Mock Get-GitHubAssetChecksum -ModuleName ArchiveInstaller { return $null }
            Mock Test-Checksum -ModuleName ArchiveInstaller { return $true }

            Get-Git -DownloadDirectory $TestDrive -VerifyChecksum -ChecksumFile $checksumFile

            Should -Invoke Get-GitHubAssetChecksum -ModuleName ArchiveInstaller -Times 0
            Should -Invoke Test-Checksum -ModuleName ArchiveInstaller -Times 1
        }

        It "Should download remote ChecksumFile if URL provided" -Skip {
            # SKIP: This test has mocking issues with multiple Invoke-WebRequest calls
            # TODO: Rewrite as integration test or use more sophisticated mocking
            $remoteChecksumUrl = "https://example.com/checksums.txt"

            Mock Get-GitHubAssetChecksum -ModuleName ArchiveInstaller { return $null }
            Mock Test-Checksum -ModuleName ArchiveInstaller { return $true }

            Get-Git -DownloadDirectory $TestDrive -VerifyChecksum -ChecksumFile $remoteChecksumUrl

            Should -Invoke Invoke-WebRequest -Times 1 -ParameterFilter { $Uri -like "*checksums.txt*" }
            Should -Invoke Test-Checksum -ModuleName ArchiveInstaller -Times 1
        }
    }

    Context "Download Methods" {
        BeforeEach {
            # Clean up any existing files
            Get-ChildItem -Path $TestDrive -Filter "*.zip" -ErrorAction SilentlyContinue | Remove-Item -Force

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

            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{
                            name = "Git-2.43.0-64-bit.zip"
                            browser_download_url = "https://github.com/git-for-windows/git/releases/download/v2.43.0/Git-2.43.0-64-bit.zip"
                        }
                    )
                }
            }

            Mock Download-File -ModuleName ArchiveInstaller {
                "dummy content" | Out-File -LiteralPath $OutFile
            }
        }

        It "Should use FastDownload when specified" {
            Get-Git -DownloadDirectory $TestDrive -FastDownload

            Should -Invoke Download-File -ModuleName ArchiveInstaller -Times 1 -ParameterFilter { $FastDownload -eq $true }
        }

        It "Should use standard download without FastDownload" {
            Get-Git -DownloadDirectory $TestDrive

            Should -Invoke Download-File -ModuleName ArchiveInstaller -Times 1 -ParameterFilter { -not $FastDownload }
        }
    }

    Context "Parameter Validation" {
        BeforeEach {
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

            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{
                            name = "Git-2.43.0-64-bit.zip"
                            browser_download_url = "https://github.com/git-for-windows/git/releases/download/v2.43.0/Git-2.43.0-64-bit.zip"
                        }
                    )
                }
            }

            Mock Download-File -ModuleName ArchiveInstaller {
                "dummy content" | Out-File -LiteralPath $OutFile
            }
        }

        It "Should accept valid DownloadDirectory" {
            { Get-Git -DownloadDirectory $TestDrive } | Should -Not -Throw
        }

        It "Should work without any optional parameters" {
            { Get-Git -DownloadDirectory $TestDrive } | Should -Not -Throw
        }
    }

    Context "Integration with Class" {
        BeforeEach {
            # Clean up any existing files
            Get-ChildItem -Path $TestDrive -Filter "*.zip" -ErrorAction SilentlyContinue | Remove-Item -Force

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

            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{
                            name = "Git-2.43.0-64-bit.zip"
                            browser_download_url = "https://github.com/git-for-windows/git/releases/download/v2.43.0/Git-2.43.0-64-bit.zip"
                        }
                    )
                }
            }

            Mock Download-File -ModuleName ArchiveInstaller {
                "dummy content" | Out-File -LiteralPath $OutFile
            }
        }

        It "Should create GitArchiveInstaller instance internally" {
            # This test verifies the function uses the class correctly
            $result = Get-Git -DownloadDirectory $TestDrive

            # Verify GitHub API was called (class method)
            Should -Invoke Invoke-RestMethod -Times 1
        }

        It "Should call Download-File internally" {
            Get-Git -DownloadDirectory $TestDrive

            Should -Invoke Download-File -ModuleName ArchiveInstaller -Times 1
        }

        It "Should return file path" {
            $result = Get-Git -DownloadDirectory $TestDrive

            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match "Git.*64-bit.zip"
            Test-Path $result | Should -Be $true
        }
    }
}
