BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force
}

Describe "VS Code End-to-End Tests" -Tag 'E2E', 'Slow' {

    Context "Real Download from Microsoft (Local Only)" {
        It "Should download real VS Code archive" -Skip:($env:CI -eq 'true') {
            $downloadDir = Join-Path $TestDrive "VSCodeRealDownload"
            New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null

            # Real download - no mocks (direct URL, not GitHub)
            $archive = Get-VSCodeArchive -DownloadDirectory $downloadDir

            # Verify it's a real file
            Test-Path $archive | Should -Be $true
            $archive | Should -Match "VSCode.*x64.*\.zip"

            # VS Code archives are typically >100MB
            $fileSize = (Get-Item $archive).Length
            $fileSize | Should -BeGreaterThan 100MB
            $fileSize | Should -BeLessThan 500MB

            Write-Host "Downloaded: $archive ($([math]::Round($fileSize/1MB, 2)) MB)" -ForegroundColor Green
        }

        It "Should skip download when file exists without -Force" -Skip:($env:CI -eq 'true') {
            $downloadDir = Join-Path $TestDrive "VSCodeSkipDownload"
            New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null

            # First download
            $archive1 = Get-VSCodeArchive -DownloadDirectory $downloadDir
            $firstTime = (Get-Item $archive1).LastWriteTime

            Start-Sleep -Seconds 1

            # Second download without Force (should skip)
            $archive2 = Get-VSCodeArchive -DownloadDirectory $downloadDir
            $secondTime = (Get-Item $archive2).LastWriteTime

            # Should be same file
            $archive1 | Should -Be $archive2
            $firstTime | Should -Be $secondTime
        }

        It "Should re-download with -Force" -Skip:($env:CI -eq 'true') {
            $downloadDir = Join-Path $TestDrive "VSCodeForceDownload"
            New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null

            # First download
            $archive1 = Get-VSCodeArchive -DownloadDirectory $downloadDir
            $firstTime = (Get-Item $archive1).LastWriteTime

            Start-Sleep -Seconds 2

            # Re-download with Force
            $archive2 = Get-VSCodeArchive -DownloadDirectory $downloadDir -Force
            $secondTime = (Get-Item $archive2).LastWriteTime

            # Should have new timestamp
            $secondTime | Should -BeGreaterThan $firstTime
        }
    }

    Context "Real Extraction and Binary Validation (Local Only)" {
        BeforeAll {
            $script:downloadDir = Join-Path $TestDrive "VSCodeE2EInstall"
            New-Item -Path $script:downloadDir -ItemType Directory -Force | Out-Null
        }

        It "Should extract VS Code archive" -Skip:($env:CI -eq 'true') {
            # Download
            Get-VSCodeArchive -DownloadDirectory $script:downloadDir | Out-Null

            # Extract
            $extractPath = Expand-VSCodeArchive -DownloadDirectory $script:downloadDir

            # Verify extraction
            Test-Path $extractPath | Should -Be $true
            Test-Path (Join-Path $extractPath "Code.exe") | Should -Be $true
            Test-Path (Join-Path $extractPath "bin\code.cmd") | Should -Be $true

            Write-Host "Extracted to: $extractPath" -ForegroundColor Green
        }

        It "Should launch Code.exe and verify version" -Skip:($env:CI -eq 'true') {
            $extractPath = Get-ChildItem -Path $script:downloadDir -Directory |
                Where-Object { $_.Name -like "VSCode*" } |
                Select-Object -First 1 -ExpandProperty FullName

            $codeExe = Join-Path $extractPath "Code.exe"
            Test-Path $codeExe | Should -Be $true

            # Get VS Code version
            $version = & $codeExe --version 2>&1 | Select-Object -First 1

            $version | Should -Match '^\d+\.\d+\.\d+'

            Write-Host "VS Code version: $version" -ForegroundColor Green
        }

        It "Should have code.cmd launcher in bin folder" -Skip:($env:CI -eq 'true') {
            $extractPath = Get-ChildItem -Path $script:downloadDir -Directory |
                Where-Object { $_.Name -like "VSCode*" } |
                Select-Object -First 1 -ExpandProperty FullName

            $codeCmdPath = Join-Path $extractPath "bin\code.cmd"
            Test-Path $codeCmdPath | Should -Be $true
        }
    }

    Context "PowerShell Extension Installation (Local Only)" {
        BeforeAll {
            $script:downloadDir = Join-Path $TestDrive "VSCodeExtension"
            New-Item -Path $script:downloadDir -ItemType Directory -Force | Out-Null
        }

        It "Should download PowerShell extension VSIX" -Skip:($env:CI -eq 'true') {
            $vsix = Get-PowershellVSCodeExtension -DownloadDirectory $script:downloadDir

            Test-Path $vsix | Should -Be $true
            $vsix | Should -Match "powershell.*\.vsix"

            # VSIX files are typically a few MB
            $fileSize = (Get-Item $vsix).Length
            $fileSize | Should -BeGreaterThan 1MB
            $fileSize | Should -BeLessThan 50MB

            Write-Host "Downloaded extension: $vsix" -ForegroundColor Green
        }

        It "Should extract extension ID from VSIX manifest" -Skip:($env:CI -eq 'true') {
            $vsix = Get-PowershellVSCodeExtension -DownloadDirectory $script:downloadDir

            # Extract VSIX (it's a ZIP) and read manifest
            $tempExtract = Join-Path $TestDrive "VsixExtract"
            Expand-Archive -Path $vsix -DestinationPath $tempExtract -Force

            $manifest = Join-Path $tempExtract "extension.vsixmanifest"
            Test-Path $manifest | Should -Be $true

            # Read manifest
            [xml]$manifestContent = Get-Content $manifest
            $identity = $manifestContent.PackageManifest.Metadata.Identity

            $identity.Id | Should -Match "powershell"
            $identity.Publisher | Should -Not -BeNullOrEmpty

            Write-Host "Extension ID: $($identity.Id)" -ForegroundColor Green
        }
    }

    Context "Mocked Tests for CI" {
        BeforeEach {
            # Mock HEAD request for VS Code
            Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'HEAD' } {
                return [PSCustomObject]@{
                    Headers = @{ 'Content-Disposition' = 'filename="VSCode-win32-x64-1.85.0.zip"' }
                    BaseResponse = [PSCustomObject]@{
                        ResponseUri = [PSCustomObject]@{
                            AbsolutePath = "/stable/abc123/VSCode-win32-x64-1.85.0.zip"
                        }
                    }
                }
            }

            # Mock download
            Mock Download-File -ModuleName ArchiveInstaller {
                $tempDir = Join-Path $TestDrive "MockVSCodeContent"
                $binDir = Join-Path $tempDir "bin"
                New-Item -Path $binDir -ItemType Directory -Force | Out-Null

                "Mock Code.exe" | Out-File -FilePath (Join-Path $tempDir "Code.exe")
                "Mock code.cmd" | Out-File -FilePath (Join-Path $binDir "code.cmd")

                Compress-Archive -Path "$tempDir\*" -DestinationPath $OutFile -Force
            }
        }

        It "Should download VS Code with mocks (CI-friendly)" {
            $archive = Get-VSCodeArchive -DownloadDirectory $TestDrive

            Test-Path $archive | Should -Be $true
            $archive | Should -Match "VSCode.*x64.*\.zip"
        }

        It "Should extract VS Code with mocks (CI-friendly)" {
            Get-VSCodeArchive -DownloadDirectory $TestDrive | Out-Null
            $extractPath = Expand-VSCodeArchive -DownloadDirectory $TestDrive

            Test-Path $extractPath | Should -Be $true
            Test-Path (Join-Path $extractPath "Code.exe") | Should -Be $true
            Test-Path (Join-Path $extractPath "bin\code.cmd") | Should -Be $true
        }

        It "Should respect -Force on extraction (CI-friendly)" {
            Get-VSCodeArchive -DownloadDirectory $TestDrive | Out-Null
            $extractPath1 = Expand-VSCodeArchive -DownloadDirectory $TestDrive

            # Add marker
            "marker" | Out-File (Join-Path $extractPath1 "marker.txt")

            # Re-extract with Force
            $extractPath2 = Expand-VSCodeArchive -DownloadDirectory $TestDrive -Force

            # Marker should be gone
            Test-Path (Join-Path $extractPath2 "marker.txt") | Should -Be $false
        }
    }

    Context "Extension Installation Mocked (CI)" {
        BeforeEach {
            # Mock extension download
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{
                            name = "powershell-2023.11.0.vsix"
                            browser_download_url = "https://github.com/PowerShell/vscode-powershell/releases/download/v2023.11.0/powershell-2023.11.0.vsix"
                        }
                    )
                }
            }

            Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'HEAD' } {
                return [PSCustomObject]@{
                    Headers = @{ 'Content-Disposition' = 'filename="powershell-2023.11.0.vsix"' }
                    BaseResponse = [PSCustomObject]@{
                        ResponseUri = [PSCustomObject]@{
                            AbsolutePath = "/powershell-2023.11.0.vsix"
                        }
                    }
                }
            }

            Mock Download-File -ModuleName ArchiveInstaller {
                # Create mock VSIX (ZIP with manifest)
                $tempDir = Join-Path $TestDrive "MockVsix"
                New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

                $manifest = @'
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest>
  <Metadata>
    <Identity Id="ms-vscode.powershell" Version="2023.11.0" Publisher="Microsoft" />
    <DisplayName>PowerShell</DisplayName>
  </Metadata>
</PackageManifest>
'@
                $manifest | Out-File -FilePath (Join-Path $tempDir "extension.vsixmanifest")

                Compress-Archive -Path "$tempDir\*" -DestinationPath $OutFile -Force
            }

            # Mock VS Code directory
            $script:mockVSCodeDir = Join-Path $TestDrive "MockVSCode"
            $script:mockBinDir = Join-Path $script:mockVSCodeDir "bin"
            New-Item -Path $script:mockBinDir -ItemType Directory -Force | Out-Null
            "mock code.cmd" | Out-File (Join-Path $script:mockBinDir "code.cmd")

            Mock Start-Process { }
        }

        It "Should download PowerShell extension (CI-friendly)" {
            $vsix = Get-PowershellVSCodeExtension -DownloadDirectory $TestDrive

            Test-Path $vsix | Should -Be $true
            $vsix | Should -Match "powershell.*\.vsix"
        }

        It "Should call Install-PowershellVSCodeExtension with VSCodeDirectory (CI-friendly)" {
            Get-PowershellVSCodeExtension -DownloadDirectory $TestDrive | Out-Null

            { Install-PowershellVSCodeExtension -DownloadDirectory $TestDrive -VSCodeDirectory $script:mockVSCodeDir -WhatIf } |
                Should -Not -Throw
        }

        It "Should throw when VS Code not found (CI-friendly)" {
            Mock Test-Path { return $false }

            Get-PowershellVSCodeExtension -DownloadDirectory $TestDrive | Out-Null

            { Install-PowershellVSCodeExtension -DownloadDirectory $TestDrive } |
                Should -Throw "*VS Code not found*"
        }
    }
}
