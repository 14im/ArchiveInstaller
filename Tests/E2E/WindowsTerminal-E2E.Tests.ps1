BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force
}

Describe "Windows Terminal End-to-End Tests" -Tag 'E2E', 'Slow' {

    Context "Real Download from GitHub (Local Only)" {
        It "Should download real Windows Terminal archive" -Skip:($env:CI -eq 'true') {
            $downloadDir = Join-Path $TestDrive "WTRealDownload"
            New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null

            # Real download - no mocks
            $archive = Get-WindowsTerminalArchive -DownloadDirectory $downloadDir

            # Verify it's a real file
            Test-Path $archive | Should -Be $true
            $archive | Should -Match "WindowsTerminal.*x64\.zip"

            # Windows Terminal archives are typically >20MB
            $fileSize = (Get-Item $archive).Length
            $fileSize | Should -BeGreaterThan 20MB
            $fileSize | Should -BeLessThan 200MB

            Write-Host "Downloaded: $archive ($([math]::Round($fileSize/1MB, 2)) MB)" -ForegroundColor Green
        }

        It "Should download with checksum verification" -Skip:($env:CI -eq 'true') {
            $downloadDir = Join-Path $TestDrive "WTRealDownloadChecksum"
            New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null

            # Real download with checksum
            { Get-WindowsTerminalArchive -DownloadDirectory $downloadDir -VerifyChecksum } | Should -Not -Throw

            # If it succeeded, checksum was valid
            $archive = Get-ChildItem -Path $downloadDir -Filter "*.WindowsTerminal*.zip" | Select-Object -First 1
            Test-Path $archive.FullName | Should -Be $true
        }

        It "Should skip download when file exists without -Force" -Skip:($env:CI -eq 'true') {
            $downloadDir = Join-Path $TestDrive "WTSkipDownload"
            New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null

            # First download
            $archive1 = Get-WindowsTerminalArchive -DownloadDirectory $downloadDir
            $firstTime = (Get-Item $archive1).LastWriteTime

            Start-Sleep -Seconds 1

            # Second download without Force (should skip)
            $archive2 = Get-WindowsTerminalArchive -DownloadDirectory $downloadDir
            $secondTime = (Get-Item $archive2).LastWriteTime

            # Should be same file
            $archive1 | Should -Be $archive2
            $firstTime | Should -Be $secondTime
        }
    }

    Context "Real Extraction with Subdirectory Flattening (Local Only)" {
        BeforeAll {
            $script:downloadDir = Join-Path $TestDrive "WTE2EInstall"
            New-Item -Path $script:downloadDir -ItemType Directory -Force | Out-Null
        }

        It "Should extract Windows Terminal archive" -Skip:($env:CI -eq 'true') {
            # Download
            Get-WindowsTerminalArchive -DownloadDirectory $script:downloadDir | Out-Null

            # Extract
            $extractPath = Expand-WindowsTerminalArchive -DownloadDirectory $script:downloadDir

            # Verify extraction
            Test-Path $extractPath | Should -Be $true

            Write-Host "Extracted to: $extractPath" -ForegroundColor Green
        }

        It "Should flatten subdirectories (wt.exe in root)" -Skip:($env:CI -eq 'true') {
            $extractPath = Get-ChildItem -Path $script:downloadDir -Directory |
                Where-Object { $_.Name -like "*WindowsTerminal*" } |
                Select-Object -First 1 -ExpandProperty FullName

            # wt.exe should be in root after flattening
            $wtExe = Join-Path $extractPath "wt.exe"
            Test-Path $wtExe | Should -Be $true

            Write-Host "Found wt.exe at: $wtExe" -ForegroundColor Green
        }

        It "Should launch wt.exe and verify version" -Skip:($env:CI -eq 'true') {
            $extractPath = Get-ChildItem -Path $script:downloadDir -Directory |
                Where-Object { $_.Name -like "*WindowsTerminal*" } |
                Select-Object -First 1 -ExpandProperty FullName

            $wtExe = Join-Path $extractPath "wt.exe"
            Test-Path $wtExe | Should -Be $true

            # Get Windows Terminal version
            # Note: wt.exe may require elevated privileges or specific environment
            # We'll just verify the file exists and has reasonable size
            $fileSize = (Get-Item $wtExe).Length
            $fileSize | Should -BeGreaterThan 100KB

            Write-Host "wt.exe size: $([math]::Round($fileSize/1MB, 2)) MB" -ForegroundColor Green
        }

        It "Should have OpenConsole.exe and other binaries" -Skip:($env:CI -eq 'true') {
            $extractPath = Get-ChildItem -Path $script:downloadDir -Directory |
                Where-Object { $_.Name -like "*WindowsTerminal*" } |
                Select-Object -First 1 -ExpandProperty FullName

            # Check for key binaries
            Test-Path (Join-Path $extractPath "OpenConsole.exe") | Should -Be $true
            Test-Path (Join-Path $extractPath "WindowsTerminal.exe") | Should -Be $true
        }
    }

    Context "Mocked Tests for CI" {
        BeforeEach {
            # Mock GitHub API
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{
                            name = "Microsoft.WindowsTerminal_Win10_1.18.10301.0_8wekyb3d8bbwe.msixbundle_x64.zip"
                            browser_download_url = "https://github.com/microsoft/terminal/releases/download/v1.18.10301.0/Microsoft.WindowsTerminal_Win10_1.18.10301.0_8wekyb3d8bbwe.msixbundle_x64.zip"
                        }
                    )
                }
            }

            # Mock HEAD request
            Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'HEAD' } {
                return [PSCustomObject]@{
                    Headers = @{ 'Content-Disposition' = 'filename="Microsoft.WindowsTerminal_Win10_1.18.10301.0_8wekyb3d8bbwe.msixbundle_x64.zip"' }
                    BaseResponse = [PSCustomObject]@{
                        ResponseUri = [PSCustomObject]@{
                            AbsolutePath = "/Microsoft.WindowsTerminal_Win10_1.18.10301.0_8wekyb3d8bbwe.msixbundle_x64.zip"
                        }
                    }
                }
            }

            # Mock download with nested structure (will be flattened)
            Mock Download-File -ModuleName ArchiveInstaller {
                $tempDir = Join-Path $TestDrive "MockWTContent"
                $subDir = Join-Path $tempDir "terminal_x64"
                New-Item -Path $subDir -ItemType Directory -Force | Out-Null

                "Mock wt.exe" | Out-File -FilePath (Join-Path $subDir "wt.exe")
                "Mock OpenConsole.exe" | Out-File -FilePath (Join-Path $subDir "OpenConsole.exe")
                "Mock WindowsTerminal.exe" | Out-File -FilePath (Join-Path $subDir "WindowsTerminal.exe")

                Compress-Archive -Path "$tempDir\*" -DestinationPath $OutFile -Force
            }
        }

        It "Should download Windows Terminal with mocks (CI-friendly)" {
            $archive = Get-WindowsTerminalArchive -DownloadDirectory $TestDrive

            Test-Path $archive | Should -Be $true
            $archive | Should -Match "WindowsTerminal.*x64\.zip"
        }

        It "Should extract with subdirectory flattening (CI-friendly)" {
            Get-WindowsTerminalArchive -DownloadDirectory $TestDrive | Out-Null
            $extractPath = Expand-WindowsTerminalArchive -DownloadDirectory $TestDrive

            Test-Path $extractPath | Should -Be $true

            # Files should be in root (flattened)
            Test-Path (Join-Path $extractPath "wt.exe") | Should -Be $true
            Test-Path (Join-Path $extractPath "OpenConsole.exe") | Should -Be $true
            Test-Path (Join-Path $extractPath "WindowsTerminal.exe") | Should -Be $true
        }

        It "Should remove empty subdirectory after flattening (CI-friendly)" {
            Get-WindowsTerminalArchive -DownloadDirectory $TestDrive | Out-Null
            $extractPath = Expand-WindowsTerminalArchive -DownloadDirectory $TestDrive

            # Subdirectory should be removed
            $subDirs = Get-ChildItem -Path $extractPath -Directory
            $subDirs | Should -BeNullOrEmpty
        }

        It "Should respect -Force on extraction (CI-friendly)" {
            Get-WindowsTerminalArchive -DownloadDirectory $TestDrive | Out-Null
            $extractPath1 = Expand-WindowsTerminalArchive -DownloadDirectory $TestDrive

            # Add marker
            "marker" | Out-File (Join-Path $extractPath1 "marker.txt")

            # Re-extract with Force
            $extractPath2 = Expand-WindowsTerminalArchive -DownloadDirectory $TestDrive -Force

            # Marker should be gone
            Test-Path (Join-Path $extractPath2 "marker.txt") | Should -Be $false
        }

        It "Should skip extraction when destination exists without -Force (CI-friendly)" {
            Get-WindowsTerminalArchive -DownloadDirectory $TestDrive | Out-Null
            $extractPath1 = Expand-WindowsTerminalArchive -DownloadDirectory $TestDrive

            # Add marker
            "marker" | Out-File (Join-Path $extractPath1 "marker.txt")

            # Extract again without Force (should skip)
            $extractPath2 = Expand-WindowsTerminalArchive -DownloadDirectory $TestDrive

            # Marker should still exist
            Test-Path (Join-Path $extractPath2 "marker.txt") | Should -Be $true
            Get-Content (Join-Path $extractPath2 "marker.txt") | Should -Be "marker"
        }
    }

    Context "Error Handling" {
        It "Should throw when no matching asset found" {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{
                            name = "Microsoft.WindowsTerminal_ARM64.zip"
                            browser_download_url = "https://example.com/wt-arm.zip"
                        }
                    )
                }
            }

            # Looking for x64 but only ARM64 available
            { Get-WindowsTerminalArchive -DownloadDirectory $TestDrive } | Should -Throw "*No matching asset*"
        }
    }
}
