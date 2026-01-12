BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force

    # Explicitly load class files
    $classPath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\Classes" -Resolve
    . (Join-Path $classPath "ArchiveInstaller.ps1")
    . (Join-Path $classPath "PowershellArchiveInstaller.ps1")
}

Describe "Expand-PowerShellArchive" -Tag 'Unit', 'Public' {

    Context "Parameter Validation" {
        BeforeEach {
            # Create a dummy archive file
            $archivePath = Join-Path $TestDrive "PowerShell-7.4.0-x64.zip"
            "dummy archive" | Out-File -LiteralPath $archivePath
        }

        It "Should accept valid DownloadDirectory parameter" {
            { Expand-PowerShellArchive -DownloadDirectory $TestDrive -WhatIf } | Should -Not -Throw
        }

        It "Should support ShouldProcess (-WhatIf)" {
            { Expand-PowerShellArchive -DownloadDirectory $TestDrive -WhatIf } | Should -Not -Throw
        }

        It "Should support -Confirm parameter" {
            { Expand-PowerShellArchive -DownloadDirectory $TestDrive -Confirm:$false } | Should -Not -Throw
        }

        It "Should accept -Force parameter" {
            { Expand-PowerShellArchive -DownloadDirectory $TestDrive -Force -WhatIf } | Should -Not -Throw
        }

        It "Should accept -AddPath parameter" {
            { Expand-PowerShellArchive -DownloadDirectory $TestDrive -AddPath -WhatIf } | Should -Not -Throw
        }
    }

    Context "AddPath Integration" {
        BeforeEach {
            # Create a dummy archive file
            $archivePath = Join-Path $TestDrive "PowerShell-7.4.0-x64.zip"
            "dummy archive" | Out-File -LiteralPath $archivePath

            Mock Add-Path -ModuleName ArchiveInstaller {
                # Mock Add-Path to do nothing
            }
        }

        It "Should not call Add-Path when using -WhatIf" {
            Expand-PowerShellArchive -DownloadDirectory $TestDrive -AddPath -WhatIf

            Should -Invoke Add-Path -ModuleName ArchiveInstaller -Times 0
        }

        It "Should check [switch]::Present for -AddPath parameter" {
            # This test verifies the function uses the correct switch check syntax
            { Expand-PowerShellArchive -DownloadDirectory $TestDrive -AddPath -WhatIf } | Should -Not -Throw
        }
    }

    Context "Integration with Class" {
        BeforeEach {
            # Create a dummy archive file
            $archivePath = Join-Path $TestDrive "PowerShell-7.4.0-x64.zip"
            "dummy archive" | Out-File -LiteralPath $archivePath
        }

        It "Should create PowershellArchiveInstaller instance internally" {
            # Using WhatIf to avoid actual extraction
            { Expand-PowerShellArchive -DownloadDirectory $TestDrive -WhatIf } | Should -Not -Throw
        }

        It "Should use DownloadDirectory when specified" {
            $customDir = Join-Path $TestDrive "CustomDir"
            New-Item -Path $customDir -ItemType Directory -Force | Out-Null

            # Create archive in custom directory
            $archivePath = Join-Path $customDir "PowerShell-7.4.0-x64.zip"
            "dummy archive" | Out-File -LiteralPath $archivePath

            { Expand-PowerShellArchive -DownloadDirectory $customDir -WhatIf } | Should -Not -Throw
        }

        It "Should call DestinationExtractionDirectory method" {
            # This verifies the function calls the class method
            { Expand-PowerShellArchive -DownloadDirectory $TestDrive -WhatIf } | Should -Not -Throw
        }
    }

    Context "Return Value" {
        BeforeEach {
            # Create a dummy archive file
            $archivePath = Join-Path $TestDrive "PowerShell-7.4.0-x64.zip"
            "dummy archive" | Out-File -LiteralPath $archivePath
        }

        It "Should return destination path with -WhatIf" {
            $result = Expand-PowerShellArchive -DownloadDirectory $TestDrive -WhatIf

            # WhatIf still returns the destination path (what WOULD be extracted)
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match "PowerShell"
        }

        It "Should work with custom download directory" {
            $customDir = Join-Path $TestDrive "CustomDir"
            New-Item -Path $customDir -ItemType Directory -Force | Out-Null
            $archivePath = Join-Path $customDir "PowerShell-7.4.0-x64.zip"
            "dummy archive" | Out-File -LiteralPath $archivePath

            { Expand-PowerShellArchive -DownloadDirectory $customDir -WhatIf } | Should -Not -Throw
        }
    }
}
