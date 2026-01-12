BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force

    # Dot-source the private function directly for testing
    $privatePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\Private\Get-GitHubAssetChecksum.ps1" -Resolve
    . $privatePath

    # Load fixtures
    . (Join-Path $PSScriptRoot "..\..\Fixtures\GitHubResponses.ps1" -Resolve)
    . (Join-Path $PSScriptRoot "..\..\Fixtures\ChecksumFiles.ps1" -Resolve)
}

Describe "Get-GitHubAssetChecksum" -Tag 'Unit', 'Private' {

    Context "GitHub API Interaction" {
        BeforeEach {
            Mock Invoke-RestMethod {
                return Get-MockGitHubRelease
            }

            Mock Invoke-WebRequest {
                $checksumFile = Join-Path $TestDrive "checksums.txt"
                Get-MockChecksumFileContent | Out-File $checksumFile
                return @{ StatusCode = 200 }
            }

            Mock Get-Content {
                return (Get-MockChecksumFileContent) -split "`n"
            }
        }

        It "Should query GitHub API for latest release" {
            Get-GitHubAssetChecksum -Owner "PowerShell" -Repo "PowerShell" -ArchiveName "PowerShell-7.4.0-win-x64.zip"

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -eq "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
            }
        }

        It "Should set User-Agent header" {
            Get-GitHubAssetChecksum -Owner "PowerShell" -Repo "PowerShell" -ArchiveName "test.zip"

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Headers['User-Agent'] -eq 'ArchiveInstaller'
            }
        }

        It "Should return null when API call fails" {
            Mock Invoke-RestMethod { throw "API Rate Limit Exceeded" }

            $result = Get-GitHubAssetChecksum -Owner "PowerShell" -Repo "PowerShell" -ArchiveName "test.zip"

            $result | Should -BeNullOrEmpty
        }

        It "Should write verbose message when API fails" {
            Mock Invoke-RestMethod { throw "Network error" }

            $verboseOutput = Get-GitHubAssetChecksum -Owner "PowerShell" -Repo "PowerShell" `
                -ArchiveName "test.zip" -Verbose 4>&1 -ErrorAction SilentlyContinue

            $verboseText = $verboseOutput -join " "
            $verboseText | Should -Match "(GitHub API failed|failed)"
        }

        It "Should construct correct API URL for different repos" {
            Get-GitHubAssetChecksum -Owner "microsoft" -Repo "terminal" -ArchiveName "terminal.zip"

            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Uri -eq "https://api.github.com/repos/microsoft/terminal/releases/latest"
            }
        }
    }

    Context "Checksum Asset Detection" {
        It "Should find asset with 'sha256' in name" {
            Mock Invoke-RestMethod {
                return @{
                    assets = @(
                        @{ name = "app.zip"; browser_download_url = "https://example.com/app.zip" },
                        @{ name = "checksums-sha256.txt"; browser_download_url = "https://example.com/checksums.txt" }
                    )
                }
            }

            Mock Invoke-WebRequest {
                $checksumFile = Join-Path $TestDrive "checksums.txt"
                "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  app.zip" | Out-File $checksumFile
            }

            Mock Get-Content {
                return @("a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  app.zip")
            }

            $result = Get-GitHubAssetChecksum -Owner "test" -Repo "repo" -ArchiveName "app.zip"

            Should -Invoke Invoke-WebRequest -Times 1 -ParameterFilter {
                $Uri -eq "https://example.com/checksums.txt"
            }
        }

        It "Should find asset with 'checksum' in name" {
            Mock Invoke-RestMethod {
                return @{
                    assets = @(
                        @{ name = "app.zip"; browser_download_url = "https://example.com/app.zip" },
                        @{ name = "checksums.txt"; browser_download_url = "https://example.com/checksums.txt" }
                    )
                }
            }

            Mock Invoke-WebRequest {}
            Mock Get-Content { return @("abc123def456abc123def456abc123def456abc123def456abc123def456abcd  app.zip") }

            Get-GitHubAssetChecksum -Owner "test" -Repo "repo" -ArchiveName "app.zip"

            Should -Invoke Invoke-WebRequest -Times 1
        }

        It "Should find asset with 'sha256sum' in name (case-insensitive)" {
            Mock Invoke-RestMethod {
                return @{
                    assets = @(
                        @{ name = "SHA256SUMS"; browser_download_url = "https://example.com/sums.txt" }
                    )
                }
            }

            Mock Invoke-WebRequest {}
            Mock Get-Content { return @("abc123def456abc123def456abc123def456abc123def456abc123def456abcd  app.zip") }

            Get-GitHubAssetChecksum -Owner "test" -Repo "repo" -ArchiveName "app.zip"

            Should -Invoke Invoke-WebRequest -Times 1
        }

        It "Should return null when no checksum asset found" {
            Mock Invoke-RestMethod {
                return @{
                    assets = @(
                        @{ name = "app.zip"; browser_download_url = "https://example.com/app.zip" },
                        @{ name = "README.md"; browser_download_url = "https://example.com/README.md" }
                    )
                }
            }

            $result = Get-GitHubAssetChecksum -Owner "test" -Repo "repo" -ArchiveName "app.zip"

            $result | Should -BeNullOrEmpty
        }

        It "Should prefer first matching checksum asset" {
            Mock Invoke-RestMethod {
                return @{
                    assets = @(
                        @{ name = "SHA256SUMS"; browser_download_url = "https://example.com/sha256sums" },
                        @{ name = "checksums.txt"; browser_download_url = "https://example.com/checksums.txt" }
                    )
                }
            }

            Mock Invoke-WebRequest {}
            Mock Get-Content { return @("abc123def456abc123def456abc123def456abc123def456abc123def456abcd  app.zip") }

            Get-GitHubAssetChecksum -Owner "test" -Repo "repo" -ArchiveName "app.zip"

            Should -Invoke Invoke-WebRequest -ParameterFilter {
                $Uri -eq "https://example.com/sha256sums"
            }
        }
    }

    Context "Checksum File Parsing" {
        BeforeEach {
            Mock Invoke-RestMethod { return Get-MockGitHubRelease }
            Mock Invoke-WebRequest {}
        }

        It "Should parse standard format: hash filename" {
            Mock Get-Content {
                return @(
                    "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  PowerShell-7.4.0-win-x64.zip",
                    "b234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef  PowerShell-7.4.0-linux-x64.tar.gz"
                )
            }

            $result = Get-GitHubAssetChecksum -Owner "PowerShell" -Repo "PowerShell" `
                -ArchiveName "PowerShell-7.4.0-win-x64.zip"

            $result | Should -Be "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e"
        }

        It "Should parse format with multiple spaces" {
            Mock Get-Content {
                return @("a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e    file.zip")
            }

            $result = Get-GitHubAssetChecksum -Owner "test" -Repo "repo" -ArchiveName "file.zip"

            $result | Should -Be "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e"
        }

        It "Should parse format with tabs" {
            Mock Get-Content {
                return @("a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e`tfile.zip")
            }

            $result = Get-GitHubAssetChecksum -Owner "test" -Repo "repo" -ArchiveName "file.zip"

            $result | Should -Be "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e"
        }

        It "Should validate hash is exactly 64 hex characters" {
            Mock Get-Content {
                return @(
                    "invalidhash  file.zip",  # Too short
                    "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  correct.zip"
                )
            }

            $result = Get-GitHubAssetChecksum -Owner "test" -Repo "repo" -ArchiveName "file.zip"

            $result | Should -BeNullOrEmpty
        }

        It "Should reject hash with non-hex characters" {
            Mock Get-Content {
                return @("g591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  file.zip")
            }

            $result = Get-GitHubAssetChecksum -Owner "test" -Repo "repo" -ArchiveName "file.zip"

            $result | Should -BeNullOrEmpty
        }

        It "Should handle files with special characters in name" {
            Mock Get-Content {
                return @("a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  file-v1.0.0_win-x64.zip")
            }

            $result = Get-GitHubAssetChecksum -Owner "test" -Repo "repo" `
                -ArchiveName "file-v1.0.0_win-x64.zip"

            $result | Should -Be "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e"
        }

        It "Should handle files with parentheses in name" {
            Mock Get-Content {
                return @("a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  file(x64).zip")
            }

            $result = Get-GitHubAssetChecksum -Owner "test" -Repo "repo" -ArchiveName "file(x64).zip"

            $result | Should -Be "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e"
        }

        It "Should return null when archive name not found in checksum file" {
            Mock Get-Content {
                return @(
                    "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  other-file.zip",
                    "b234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef  another-file.zip"
                )
            }

            $result = Get-GitHubAssetChecksum -Owner "test" -Repo "repo" -ArchiveName "my-file.zip"

            $result | Should -BeNullOrEmpty
        }

        It "Should be case-sensitive for filename matching" {
            Mock Get-Content {
                return @("a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  File.zip")
            }

            # Looking for "file.zip" but checksum has "File.zip"
            $result = Get-GitHubAssetChecksum -Owner "test" -Repo "repo" -ArchiveName "file.zip"

            $result | Should -BeNullOrEmpty
        }

        It "Should handle empty lines in checksum file" {
            Mock Get-Content {
                return @(
                    "",
                    "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  file.zip",
                    "",
                    "b234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef  other.zip"
                )
            }

            $result = Get-GitHubAssetChecksum -Owner "test" -Repo "repo" -ArchiveName "file.zip"

            $result | Should -Be "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e"
        }

        It "Should handle comments in checksum file" {
            Mock Get-Content {
                return @(
                    "# This is a comment",
                    "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  file.zip"
                )
            }

            $result = Get-GitHubAssetChecksum -Owner "test" -Repo "repo" -ArchiveName "file.zip"

            $result | Should -Be "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e"
        }
    }

    Context "Temporary File Handling" {
        It "Should download checksum file to temp directory" {
            $downloadedPath = $null

            Mock Invoke-RestMethod {
                return @{
                    assets = @(
                        @{ name = "sha256.txt"; browser_download_url = "https://example.com/sha256.txt" }
                    )
                }
            }

            Mock Invoke-WebRequest {
                $script:downloadedPath = $OutFile
                $OutFile | Should -Match ([regex]::Escape([System.IO.Path]::GetTempPath()))
            }

            Mock Get-Content { return @("a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  file.zip") }

            Get-GitHubAssetChecksum -Owner "test" -Repo "repo" -ArchiveName "file.zip"

            Should -Invoke Invoke-WebRequest -Times 1
        }

        It "Should use checksum filename in temp path" {
            Mock Invoke-RestMethod {
                return @{
                    assets = @(
                        @{ name = "SHA256SUMS"; browser_download_url = "https://example.com/SHA256SUMS" }
                    )
                }
            }

            Mock Invoke-WebRequest {
                $OutFile | Should -Match "SHA256SUMS"
            }

            Mock Get-Content { return @("a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e  file.zip") }

            Get-GitHubAssetChecksum -Owner "test" -Repo "repo" -ArchiveName "file.zip"
        }
    }

    Context "Parameter Validation" {
        It "Should require Owner parameter" {
            { Get-GitHubAssetChecksum -Repo "repo" -ArchiveName "file.zip" } | Should -Throw
        }

        It "Should require Repo parameter" {
            { Get-GitHubAssetChecksum -Owner "owner" -ArchiveName "file.zip" } | Should -Throw
        }

        It "Should require ArchiveName parameter" {
            { Get-GitHubAssetChecksum -Owner "owner" -Repo "repo" } | Should -Throw
        }

        It "Should accept all required parameters" {
            Mock Invoke-RestMethod { return @{ assets = @() } }

            { Get-GitHubAssetChecksum -Owner "owner" -Repo "repo" -ArchiveName "file.zip" } |
                Should -Not -Throw
        }
    }

    Context "Edge Cases" {
        It "Should return null when release has no assets" {
            Mock Invoke-RestMethod {
                return @{ assets = @() }
            }

            $result = Get-GitHubAssetChecksum -Owner "test" -Repo "repo" -ArchiveName "file.zip"

            $result | Should -BeNullOrEmpty
        }

        It "Should handle checksum file download failure" {
            Mock Invoke-RestMethod {
                return @{
                    assets = @(
                        @{ name = "checksums.txt"; browser_download_url = "https://example.com/checksums.txt" }
                    )
                }
            }

            Mock Invoke-WebRequest { throw "404 Not Found" }

            $result = Get-GitHubAssetChecksum -Owner "test" -Repo "repo" -ArchiveName "file.zip" -ErrorAction SilentlyContinue

            $result | Should -BeNullOrEmpty
        }

        It "Should handle empty checksum file" {
            Mock Invoke-RestMethod { return Get-MockGitHubRelease }
            Mock Invoke-WebRequest {}
            Mock Get-Content { return @() }

            $result = Get-GitHubAssetChecksum -Owner "test" -Repo "repo" -ArchiveName "file.zip"

            $result | Should -BeNullOrEmpty
        }
    }
}
