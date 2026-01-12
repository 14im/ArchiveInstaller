BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force

    # Explicitly load class files
    $classPath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\Classes" -Resolve
    . (Join-Path $classPath "ArchiveInstaller.ps1")
    . (Join-Path $classPath "VSCodeArchiveInstaller.ps1")
}

Describe "Get-VSCodeArchive" -Tag 'Unit', 'Public' {

    Context "Download Operations" {
        BeforeEach {
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

            Mock Download-File -ModuleName ArchiveInstaller {
                $targetFile = $OutFile
                "dummy content" | Out-File -LiteralPath $targetFile
            }
        }

        It "Should download from VSCode direct URL" {
            $result = Get-VSCodeArchive -DownloadDirectory $TestDrive

            Should -Invoke Download-File -ModuleName ArchiveInstaller -Times 1
            $result | Should -Match "VSCode-win32-x64.*\.zip"
            Test-Path $result | Should -Be $true
        }

        It "Should skip if file exists without -Force" {
            $existingFile = Join-Path $TestDrive "VSCode-win32-x64-1.85.0.zip"
            "existing content" | Out-File -LiteralPath $existingFile

            $result = Get-VSCodeArchive -DownloadDirectory $TestDrive

            Should -Invoke Download-File -ModuleName ArchiveInstaller -Times 0
            $result | Should -Be $existingFile
        }

        It "Should re-download with -Force" {
            $existingFile = Join-Path $TestDrive "VSCode-win32-x64-1.85.0.zip"
            "existing content" | Out-File -LiteralPath $existingFile

            $result = Get-VSCodeArchive -DownloadDirectory $TestDrive -Force

            Should -Invoke Download-File -ModuleName ArchiveInstaller -Times 1
            $result | Should -Be $existingFile
        }

        It "Should create DownloadDirectory if missing" {
            $newDir = Join-Path $TestDrive "NewDownloadDir"

            Get-VSCodeArchive -DownloadDirectory $newDir

            Test-Path $newDir | Should -Be $true
        }

        It "Should use custom DownloadDirectory when specified" {
            $customDir = Join-Path $TestDrive "CustomDir"

            $result = Get-VSCodeArchive -DownloadDirectory $customDir

            $result | Should -Match ([Regex]::Escape($customDir))
        }

        It "Should use direct download URL (not GitHub API)" {
            # Mock GitHub API to ensure it's not called
            Mock Invoke-RestMethod {
                throw "GitHub API should not be called for VSCode"
            }

            # This should succeed without calling GitHub API
            { Get-VSCodeArchive -DownloadDirectory $TestDrive } | Should -Not -Throw
        }
    }

    Context "Checksum Verification" {
        BeforeEach {
            # Clean up any existing files
            Get-ChildItem -Path $TestDrive -Filter "*.zip" -ErrorAction SilentlyContinue | Remove-Item -Force

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

            # Mock for checksum file downloads
            Mock Invoke-WebRequest -ParameterFilter { $Uri -like "*checksums.txt*" } {
                $checksumContent = "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  VSCode-win32-x64-1.85.0.zip"
                $checksumContent | Out-File -LiteralPath $OutFile
            }

            Mock Download-File -ModuleName ArchiveInstaller {
                "dummy content" | Out-File -LiteralPath $OutFile
            }
        }

        It "Should warn when checksum verification requested (no GitHub repo)" {
            Mock Get-GitHubAssetChecksum -ModuleName ArchiveInstaller { return $null }
            Mock Test-Checksum -ModuleName ArchiveInstaller { return $true }

            $warnings = @()
            $result = Get-VSCodeArchive -DownloadDirectory $TestDrive -VerifyChecksum -WarningVariable +warnings 3>&1

            # VSCode doesn't have GitHub repo info, so checksum won't be found
            $warnings -match "Checksum not found" | Should -Not -BeNullOrEmpty
            Should -Invoke Test-Checksum -ModuleName ArchiveInstaller -Times 0
        }

        It "Should throw when checksum not found with -Strict" {
            Mock Get-GitHubAssetChecksum -ModuleName ArchiveInstaller { return $null }

            { Get-VSCodeArchive -DownloadDirectory $TestDrive -VerifyChecksum -Strict } | Should -Throw "*Checksum not found*"
        }

        It "Should use ChecksumFile parameter if provided (local file)" {
            $checksumFile = Join-Path $TestDrive "checksums.txt"
            "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  VSCode-win32-x64-1.85.0.zip" | Out-File -LiteralPath $checksumFile

            Mock Get-GitHubAssetChecksum -ModuleName ArchiveInstaller { return $null }
            Mock Test-Checksum -ModuleName ArchiveInstaller { return $true }

            Get-VSCodeArchive -DownloadDirectory $TestDrive -VerifyChecksum -ChecksumFile $checksumFile

            Should -Invoke Get-GitHubAssetChecksum -ModuleName ArchiveInstaller -Times 0
            Should -Invoke Test-Checksum -ModuleName ArchiveInstaller -Times 1
        }

        It "Should verify checksum when ChecksumFile provided" {
            $checksumFile = Join-Path $TestDrive "checksums.txt"
            "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  VSCode-win32-x64-1.85.0.zip" | Out-File -LiteralPath $checksumFile

            Mock Get-GitHubAssetChecksum -ModuleName ArchiveInstaller { return $null }
            Mock Test-Checksum -ModuleName ArchiveInstaller { return $true }

            $result = Get-VSCodeArchive -DownloadDirectory $TestDrive -VerifyChecksum -ChecksumFile $checksumFile

            Should -Invoke Test-Checksum -ModuleName ArchiveInstaller -Times 1
        }

        It "Should throw when checksum mismatch" {
            $checksumFile = Join-Path $TestDrive "checksums.txt"
            "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  VSCode-win32-x64-1.85.0.zip" | Out-File -LiteralPath $checksumFile

            Mock Get-GitHubAssetChecksum -ModuleName ArchiveInstaller { return $null }
            Mock Test-Checksum -ModuleName ArchiveInstaller { return $false }

            { Get-VSCodeArchive -DownloadDirectory $TestDrive -VerifyChecksum -ChecksumFile $checksumFile } | Should -Throw "*Checksum mismatch*"
        }
    }

    Context "Download Methods" {
        BeforeEach {
            # Clean up any existing files
            Get-ChildItem -Path $TestDrive -Filter "*.zip" -ErrorAction SilentlyContinue | Remove-Item -Force

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

            Mock Download-File -ModuleName ArchiveInstaller {
                "dummy content" | Out-File -LiteralPath $OutFile
            }
        }

        It "Should use FastDownload when specified" {
            Get-VSCodeArchive -DownloadDirectory $TestDrive -FastDownload

            Should -Invoke Download-File -ModuleName ArchiveInstaller -Times 1 -ParameterFilter { $FastDownload -eq $true }
        }

        It "Should use standard download without FastDownload" {
            Get-VSCodeArchive -DownloadDirectory $TestDrive

            Should -Invoke Download-File -ModuleName ArchiveInstaller -Times 1 -ParameterFilter { -not $FastDownload }
        }
    }

    Context "Parameter Validation" {
        BeforeEach {
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

            Mock Download-File -ModuleName ArchiveInstaller {
                "dummy content" | Out-File -LiteralPath $OutFile
            }
        }

        It "Should accept valid DownloadDirectory" {
            { Get-VSCodeArchive -DownloadDirectory $TestDrive } | Should -Not -Throw
        }

        It "Should work without any optional parameters" {
            { Get-VSCodeArchive -DownloadDirectory $TestDrive } | Should -Not -Throw
        }
    }

    Context "Integration with Class" {
        BeforeEach {
            # Clean up any existing files
            Get-ChildItem -Path $TestDrive -Filter "*.zip" -ErrorAction SilentlyContinue | Remove-Item -Force

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

            Mock Download-File -ModuleName ArchiveInstaller {
                "dummy content" | Out-File -LiteralPath $OutFile
            }
        }

        It "Should create VSCodeArchiveInstaller instance internally" {
            # Mock GitHub API to ensure it's not called
            Mock Invoke-RestMethod {
                throw "GitHub API should not be called for VSCode"
            }

            # This test verifies the function uses the class correctly
            # Should succeed without calling GitHub API
            { Get-VSCodeArchive -DownloadDirectory $TestDrive } | Should -Not -Throw
        }

        It "Should call Download-File internally" {
            Get-VSCodeArchive -DownloadDirectory $TestDrive

            Should -Invoke Download-File -ModuleName ArchiveInstaller -Times 1
        }

        It "Should return file path" {
            $result = Get-VSCodeArchive -DownloadDirectory $TestDrive

            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match "VSCode-win32-x64.*\.zip"
            Test-Path $result | Should -Be $true
        }
    }
}
