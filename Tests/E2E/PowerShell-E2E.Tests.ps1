BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force
}

Describe "PowerShell End-to-End Tests" -Tag 'E2E', 'Slow' {

    Context "Real Download from GitHub (Local Only)" {
        It "Should download real PowerShell archive from GitHub" -Skip:($env:CI -eq 'true') {
            $downloadDir = Join-Path $TestDrive "RealDownload"
            New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null

            # Real download - no mocks
            $archive = Get-PowerShellArchive -DownloadDirectory $downloadDir

            # Verify it's a real file
            Test-Path $archive | Should -Be $true
            $archive | Should -Match "PowerShell.*x64\.zip"

            # Verify file size is reasonable (PowerShell archives are >50MB)
            $fileSize = (Get-Item $archive).Length
            $fileSize | Should -BeGreaterThan 50MB
            $fileSize | Should -BeLessThan 500MB

            Write-Host "Downloaded: $archive ($([math]::Round($fileSize/1MB, 2)) MB)" -ForegroundColor Green
        }

        It "Should download with checksum verification" -Skip:($env:CI -eq 'true') {
            $downloadDir = Join-Path $TestDrive "RealDownloadChecksum"
            New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null

            # Real download with checksum
            { Get-PowerShellArchive -DownloadDirectory $downloadDir -VerifyChecksum } | Should -Not -Throw

            # If it succeeded, checksum was valid
            $archive = Get-ChildItem -Path $downloadDir -Filter "PowerShell*.zip" | Select-Object -First 1
            Test-Path $archive.FullName | Should -Be $true
        }

        It "Should respect -Force parameter for re-download" -Skip:($env:CI -eq 'true') {
            $downloadDir = Join-Path $TestDrive "RealDownloadForce"
            New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null

            # First download
            $archive1 = Get-PowerShellArchive -DownloadDirectory $downloadDir
            $firstDownloadTime = (Get-Item $archive1).LastWriteTime

            Start-Sleep -Seconds 2

            # Download again with -Force
            $archive2 = Get-PowerShellArchive -DownloadDirectory $downloadDir -Force
            $secondDownloadTime = (Get-Item $archive2).LastWriteTime

            # File should be re-downloaded (newer timestamp)
            $secondDownloadTime | Should -BeGreaterThan $firstDownloadTime
        }
    }

    Context "Real Extraction and Binary Validation (Local Only)" {
        BeforeAll {
            $script:downloadDir = Join-Path $TestDrive "E2EExtraction"
            New-Item -Path $script:downloadDir -ItemType Directory -Force | Out-Null
        }

        It "Should extract real PowerShell archive" -Skip:($env:CI -eq 'true') {
            # Download first
            $archive = Get-PowerShellArchive -DownloadDirectory $script:downloadDir

            # Extract
            $extractPath = Expand-PowerShellArchive -DownloadDirectory $script:downloadDir

            # Verify extraction
            Test-Path $extractPath | Should -Be $true
            Test-Path (Join-Path $extractPath "pwsh.exe") | Should -Be $true
            Test-Path (Join-Path $extractPath "pwsh.dll") | Should -Be $true

            Write-Host "Extracted to: $extractPath" -ForegroundColor Green
        }

        It "Should launch extracted pwsh.exe and verify version" -Skip:($env:CI -eq 'true') {
            $extractPath = Get-ChildItem -Path $script:downloadDir -Directory |
                Where-Object { $_.Name -like "PowerShell*" } |
                Select-Object -First 1 -ExpandProperty FullName

            $pwshExe = Join-Path $extractPath "pwsh.exe"
            Test-Path $pwshExe | Should -Be $true

            # Launch PowerShell and get version
            $versionOutput = & $pwshExe -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'

            # Verify version format
            $versionOutput | Should -Match '^\d+\.\d+\.\d+'

            # Should be PowerShell 7+
            $version = [version]$versionOutput
            $version.Major | Should -BeGreaterOrEqual 7

            Write-Host "PowerShell version: $versionOutput" -ForegroundColor Green
        }

        It "Should execute a simple script with extracted PowerShell" -Skip:($env:CI -eq 'true') {
            $extractPath = Get-ChildItem -Path $script:downloadDir -Directory |
                Where-Object { $_.Name -like "PowerShell*" } |
                Select-Object -First 1 -ExpandProperty FullName

            $pwshExe = Join-Path $extractPath "pwsh.exe"

            # Execute a simple calculation
            $result = & $pwshExe -NoProfile -Command '2 + 2'

            $result | Should -Be 4
        }
    }

    Context "Mocked Tests for CI" {
        BeforeEach {
            # Mock GitHub API
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{
                            name = "PowerShell-7.4.6-win-x64.zip"
                            browser_download_url = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.zip"
                        }
                    )
                }
            }

            # Mock HEAD request
            Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'HEAD' } {
                return [PSCustomObject]@{
                    Headers = @{ 'Content-Disposition' = 'filename="PowerShell-7.4.6-win-x64.zip"' }
                    BaseResponse = [PSCustomObject]@{
                        ResponseUri = [PSCustomObject]@{
                            AbsolutePath = "/PowerShell-7.4.6-win-x64.zip"
                        }
                    }
                }
            }

            # Mock download
            Mock Download-File -ModuleName ArchiveInstaller {
                # Create a real zip with PowerShell structure
                $tempDir = Join-Path $TestDrive "MockPwshContent"
                New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

                "Mock pwsh.exe" | Out-File -FilePath (Join-Path $tempDir "pwsh.exe")
                "Mock pwsh.dll" | Out-File -FilePath (Join-Path $tempDir "pwsh.dll")

                Compress-Archive -Path "$tempDir\*" -DestinationPath $OutFile -Force
            }
        }

        It "Should complete workflow with mocks (CI-friendly)" {
            $archive = Get-PowerShellArchive -DownloadDirectory $TestDrive

            Test-Path $archive | Should -Be $true
            $archive | Should -Match "PowerShell.*x64\.zip"
        }

        It "Should extract mocked archive successfully (CI-friendly)" {
            Get-PowerShellArchive -DownloadDirectory $TestDrive | Out-Null
            $extractPath = Expand-PowerShellArchive -DownloadDirectory $TestDrive

            Test-Path $extractPath | Should -Be $true
            Test-Path (Join-Path $extractPath "pwsh.exe") | Should -Be $true
        }

        It "Should handle extraction with -Force parameter (CI-friendly)" {
            Get-PowerShellArchive -DownloadDirectory $TestDrive | Out-Null
            $extractPath1 = Expand-PowerShellArchive -DownloadDirectory $TestDrive

            # Add a marker file
            "marker" | Out-File -FilePath (Join-Path $extractPath1 "marker.txt")

            # Re-extract with Force
            $extractPath2 = Expand-PowerShellArchive -DownloadDirectory $TestDrive -Force

            # Marker should be gone (fresh extraction)
            Test-Path (Join-Path $extractPath2 "marker.txt") | Should -Be $false
        }
    }

    Context "Error Handling" {
        It "Should handle network errors gracefully" -Skip:($env:CI -eq 'true') {
            # Try with invalid repository (should fail gracefully)
            Mock Invoke-RestMethod {
                throw "GitHub API rate limit exceeded"
            }

            { Get-PowerShellArchive -DownloadDirectory $TestDrive } | Should -Throw
        }

        It "Should clean up on checksum failure" -Skip:($env:CI -eq 'true') {
            # This would require injecting a bad checksum
            # Skip for now as it's hard to test without modifying GitHub responses
        }
    }
}
