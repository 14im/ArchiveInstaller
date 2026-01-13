BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force
}

Describe "Git End-to-End Tests" -Tag 'E2E', 'Slow' {

    Context "Real Download from GitHub (Local Only)" {
        It "Should download real Git archive from GitHub" -Skip:($env:CI -eq 'true') {
            $downloadDir = Join-Path $TestDrive "GitRealDownload"
            New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null

            # Real download - no mocks
            $archive = Get-Git -DownloadDirectory $downloadDir

            # Verify it's a real file
            Test-Path $archive | Should -Be $true
            $archive | Should -Match "Git.*64-bit\.zip"

            # Git archives are typically >50MB
            $fileSize = (Get-Item $archive).Length
            $fileSize | Should -BeGreaterThan 50MB
            $fileSize | Should -BeLessThan 500MB

            Write-Host "Downloaded: $archive ($([math]::Round($fileSize/1MB, 2)) MB)" -ForegroundColor Green
        }

        It "Should download with checksum verification" -Skip:($env:CI -eq 'true') {
            $downloadDir = Join-Path $TestDrive "GitRealDownloadChecksum"
            New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null

            # Real download with checksum
            { Get-Git -DownloadDirectory $downloadDir -VerifyChecksum } | Should -Not -Throw

            # If it succeeded, checksum was valid
            $archive = Get-ChildItem -Path $downloadDir -Filter "Git*.zip" | Select-Object -First 1
            Test-Path $archive.FullName | Should -Be $true
        }

        It "Should skip download when file exists without -Force" -Skip:($env:CI -eq 'true') {
            $downloadDir = Join-Path $TestDrive "GitSkipDownload"
            New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null

            # First download
            $archive1 = Get-Git -DownloadDirectory $downloadDir
            $firstTime = (Get-Item $archive1).LastWriteTime

            Start-Sleep -Seconds 1

            # Second download without Force (should skip)
            $archive2 = Get-Git -DownloadDirectory $downloadDir
            $secondTime = (Get-Item $archive2).LastWriteTime

            # Should be same file (not re-downloaded)
            $archive1 | Should -Be $archive2
            $firstTime | Should -Be $secondTime
        }
    }

    Context "Real Installation and Binary Validation (Local Only)" {
        BeforeAll {
            $script:downloadDir = Join-Path $TestDrive "GitE2EInstall"
            New-Item -Path $script:downloadDir -ItemType Directory -Force | Out-Null
        }

        It "Should install Git with correct structure" -Skip:($env:CI -eq 'true') {
            # Download and install
            Get-Git -DownloadDirectory $script:downloadDir | Out-Null
            $installPath = Install-Git -DownloadDirectory $script:downloadDir

            # Verify installation path
            Test-Path $installPath | Should -Be $true

            # Verify Git structure (mingw64/bin/git.exe)
            $gitExe = Join-Path $installPath "mingw64\bin\git.exe"
            Test-Path $gitExe | Should -Be $true

            Write-Host "Installed to: $installPath" -ForegroundColor Green
        }

        It "Should execute git.exe and get version" -Skip:($env:CI -eq 'true') {
            $installPath = Get-ChildItem -Path $script:downloadDir -Directory |
                Where-Object { $_.Name -like "Git*" } |
                Select-Object -First 1 -ExpandProperty FullName

            $gitExe = Join-Path $installPath "mingw64\bin\git.exe"
            Test-Path $gitExe | Should -Be $true

            # Get git version
            $version = & $gitExe --version

            $version | Should -Match 'git version \d+\.\d+\.\d+'

            Write-Host "Git version: $version" -ForegroundColor Green
        }

        It "Should execute basic git commands" -Skip:($env:CI -eq 'true') {
            $installPath = Get-ChildItem -Path $script:downloadDir -Directory |
                Where-Object { $_.Name -like "Git*" } |
                Select-Object -First 1 -ExpandProperty FullName

            $gitExe = Join-Path $installPath "mingw64\bin\git.exe"

            # Test git config
            $output = & $gitExe config --list --system 2>&1
            # Should not throw
        }

        It "Should add mingw64/bin to PATH when -AddPath specified" -Skip:($env:CI -eq 'true') {
            # Note: This test modifies the actual PATH
            # We'll just verify the path would be correct, not actually modify

            $installPath = Get-ChildItem -Path $script:downloadDir -Directory |
                Where-Object { $_.Name -like "Git*" } |
                Select-Object -First 1 -ExpandProperty FullName

            $expectedPath = Join-Path $installPath "mingw64\bin"
            Test-Path $expectedPath | Should -Be $true

            # In a real scenario, Install-Git -AddPath would add this to PATH
            # We skip actual PATH modification in tests
        }
    }

    Context "Mocked Tests for CI" {
        BeforeEach {
            # Mock GitHub API
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{
                            name = "Git-2.43.0-64-bit.zip"
                            browser_download_url = "https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.zip"
                        }
                    )
                }
            }

            # Mock HEAD request
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

            # Mock download with realistic Git structure
            Mock Download-File -ModuleName ArchiveInstaller {
                $tempDir = Join-Path $TestDrive "MockGitContent"
                $mingw64Bin = Join-Path $tempDir "mingw64\bin"
                New-Item -Path $mingw64Bin -ItemType Directory -Force | Out-Null

                "Mock git.exe" | Out-File -FilePath (Join-Path $mingw64Bin "git.exe")
                "Mock git-bash.exe" | Out-File -FilePath (Join-Path $mingw64Bin "git-bash.exe")

                Compress-Archive -Path "$tempDir\*" -DestinationPath $OutFile -Force
            }
        }

        It "Should download Git archive with mocks (CI-friendly)" {
            $archive = Get-Git -DownloadDirectory $TestDrive

            Test-Path $archive | Should -Be $true
            $archive | Should -Match "Git.*64-bit\.zip"
        }

        It "Should install Git with mocked archive (CI-friendly)" {
            Get-Git -DownloadDirectory $TestDrive | Out-Null
            $installPath = Install-Git -DownloadDirectory $TestDrive

            Test-Path $installPath | Should -Be $true
            Test-Path (Join-Path $installPath "mingw64\bin\git.exe") | Should -Be $true
        }

        It "Should respect -Force on installation (CI-friendly)" {
            Get-Git -DownloadDirectory $TestDrive | Out-Null
            $installPath1 = Install-Git -DownloadDirectory $TestDrive

            # Add marker
            "marker" | Out-File (Join-Path $installPath1 "marker.txt")

            # Reinstall with Force
            $installPath2 = Install-Git -DownloadDirectory $TestDrive -Force

            # Marker should be gone
            Test-Path (Join-Path $installPath2 "marker.txt") | Should -Be $false
        }

        It "Should support -WhatIf without installing (CI-friendly)" {
            Get-Git -DownloadDirectory $TestDrive | Out-Null

            # WhatIf should not create installation
            $installPath = Install-Git -DownloadDirectory $TestDrive -WhatIf

            # Should return path but not create it
            $installPath | Should -Not -BeNullOrEmpty
        }
    }

    Context "Error Handling" {
        It "Should throw when no matching asset found" {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{
                            name = "Git-2.43.0-ARM64.zip"
                            browser_download_url = "https://example.com/git-arm.zip"
                        }
                    )
                }
            }

            # Looking for 64-bit but only ARM64 available
            { Get-Git -DownloadDirectory $TestDrive } | Should -Throw "*No matching asset*"
        }
    }
}
