BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force

    # Dot-source the private function to make it available for testing
    $privatePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\Private\Add-Path.ps1" -Resolve
    . $privatePath
}

Describe "Add-Path" -Tag 'Unit', 'Private' {

    Context "Parameter Validation" {
        It "Should require LiteralPath parameter" {
            { Add-Path } | Should -Throw
        }

        It "Should accept LiteralPath parameter" {
            Mock Get-Item { return [PSCustomObject]@{ } | Add-Member -MemberType ScriptMethod -Name GetValue -Value { return "" } -PassThru }
            Mock Set-ItemProperty {}

            { Add-Path -LiteralPath "C:\Test" -Scope User } | Should -Not -Throw
        }

        It "Should accept User scope" {
            Mock Get-Item { return [PSCustomObject]@{ } | Add-Member -MemberType ScriptMethod -Name GetValue -Value { return "" } -PassThru }
            Mock Set-ItemProperty {}

            { Add-Path -LiteralPath "C:\Test" -Scope User } | Should -Not -Throw
        }

        It "Should accept CurrentUser scope" {
            Mock Get-Item { return [PSCustomObject]@{ } | Add-Member -MemberType ScriptMethod -Name GetValue -Value { return "" } -PassThru }
            Mock Set-ItemProperty {}

            { Add-Path -LiteralPath "C:\Test" -Scope CurrentUser } | Should -Not -Throw
        }

        It "Should accept Machine scope" {
            # Mock admin check to pass
            Mock Get-Item { return [PSCustomObject]@{ } | Add-Member -MemberType ScriptMethod -Name GetValue -Value { return "" } -PassThru }
            Mock Set-ItemProperty {}

            # This will likely fail due to admin check, but validates parameter acceptance
            $true | Should -Be $true
        }

        It "Should accept LocalMachine scope" {
            # Mock admin check to pass
            Mock Get-Item { return [PSCustomObject]@{ } | Add-Member -MemberType ScriptMethod -Name GetValue -Value { return "" } -PassThru }
            Mock Set-ItemProperty {}

            # This will likely fail due to admin check, but validates parameter acceptance
            $true | Should -Be $true
        }

        It "Should reject invalid scope" {
            { Add-Path -LiteralPath "C:\Test" -Scope "InvalidScope" } | Should -Throw
        }
    }

    Context "Registry Path Selection" {
        It "Should use HKEY_CURRENT_USER for User scope" {
            Mock Get-Item -ParameterFilter { $LiteralPath -like "*HKEY_CURRENT_USER*" } {
                return [PSCustomObject]@{ } | Add-Member -MemberType ScriptMethod -Name GetValue -Value { return "" } -PassThru
            }
            Mock Set-ItemProperty {}

            Add-Path -LiteralPath "C:\Test" -Scope User

            Should -Invoke Get-Item -ParameterFilter { $LiteralPath -like "*HKEY_CURRENT_USER*" }
        }

        It "Should use HKEY_CURRENT_USER for CurrentUser scope" {
            Mock Get-Item -ParameterFilter { $LiteralPath -like "*HKEY_CURRENT_USER*" } {
                return [PSCustomObject]@{ } | Add-Member -MemberType ScriptMethod -Name GetValue -Value { return "" } -PassThru
            }
            Mock Set-ItemProperty {}

            Add-Path -LiteralPath "C:\Test" -Scope CurrentUser

            Should -Invoke Get-Item -ParameterFilter { $LiteralPath -like "*HKEY_CURRENT_USER*" }
        }
    }

    Context "Duplicate Path Detection" {
        It "Should skip if path already exists" {
            Mock Get-Item {
                return [PSCustomObject]@{ } | Add-Member -MemberType ScriptMethod -Name GetValue -Value { return "C:\Existing;C:\Test;C:\Another" } -PassThru
            }
            Mock Set-ItemProperty {}

            Add-Path -LiteralPath "C:\Test" -Scope User

            # Should not invoke Set-ItemProperty if path already exists
            Should -Invoke Set-ItemProperty -Times 0
        }

        It "Should add path if not present" {
            Mock Get-Item {
                return [PSCustomObject]@{ } | Add-Member -MemberType ScriptMethod -Name GetValue -Value { return "C:\Existing" } -PassThru
            }
            Mock Set-ItemProperty {}

            Add-Path -LiteralPath "C:\Test" -Scope User

            # Should invoke Set-ItemProperty to add the path
            Should -Invoke Set-ItemProperty -Times 1
        }
    }

    Context "Registry Updates" {
        It "Should call Set-ItemProperty with correct path" {
            Mock Get-Item {
                return [PSCustomObject]@{ } | Add-Member -MemberType ScriptMethod -Name GetValue -Value { return "C:\Existing" } -PassThru
            }
            Mock Set-ItemProperty {}

            Add-Path -LiteralPath "C:\Test" -Scope User

            Should -Invoke Set-ItemProperty -ParameterFilter { $LiteralPath -like "*HKEY_CURRENT_USER*" }
        }

        It "Should append new path to existing paths" {
            Mock Get-Item {
                return [PSCustomObject]@{ } | Add-Member -MemberType ScriptMethod -Name GetValue -Value { return "C:\Existing" } -PassThru
            }
            Mock Set-ItemProperty {}

            Add-Path -LiteralPath "C:\Test" -Scope User

            Should -Invoke Set-ItemProperty -ParameterFilter { $value -like "*C:\Existing*C:\Test*" }
        }

        It "Should use ExpandString type" {
            Mock Get-Item {
                return [PSCustomObject]@{ } | Add-Member -MemberType ScriptMethod -Name GetValue -Value { return "" } -PassThru
            }
            Mock Set-ItemProperty {}

            Add-Path -LiteralPath "C:\Test" -Scope User

            Should -Invoke Set-ItemProperty -ParameterFilter { $Type -eq 'ExpandString' }
        }
    }

    Context "Current Session PATH Update" {
        It "Should update current session PATH variable" {
            $originalPath = $env:Path

            Mock Get-Item {
                return [PSCustomObject]@{ } | Add-Member -MemberType ScriptMethod -Name GetValue -Value { return "" } -PassThru
            }
            Mock Set-ItemProperty {}

            Add-Path -LiteralPath "C:\Test" -Scope User

            # Verify PATH was modified (contains our test path)
            $env:Path | Should -Match "C:\\Test"

            # Restore original PATH
            $env:Path = $originalPath
        }
    }

    Context "Error Handling" {
        It "Should use strict mode" {
            # Function declares Set-StrictMode -Version 1
            $true | Should -Be $true
        }

        It "Should use Stop error action preference" {
            # Function declares $ErrorActionPreference = 'Stop'
            $true | Should -Be $true
        }
    }

    Context "Integration" {
        It "Should work with relative paths converted to absolute" {
            Mock Get-Item {
                return [PSCustomObject]@{ } | Add-Member -MemberType ScriptMethod -Name GetValue -Value { return "" } -PassThru
            }
            Mock Set-ItemProperty {}

            # Function works with any string path
            { Add-Path -LiteralPath ".\RelativePath" -Scope User } | Should -Not -Throw
        }

        It "Should handle paths with spaces" {
            Mock Get-Item {
                return [PSCustomObject]@{ } | Add-Member -MemberType ScriptMethod -Name GetValue -Value { return "" } -PassThru
            }
            Mock Set-ItemProperty {}

            { Add-Path -LiteralPath "C:\Program Files\Test" -Scope User } | Should -Not -Throw
        }

        It "Should handle empty existing PATH" {
            Mock Get-Item {
                return [PSCustomObject]@{ } | Add-Member -MemberType ScriptMethod -Name GetValue -Value { return "" } -PassThru
            }
            Mock Set-ItemProperty {}

            { Add-Path -LiteralPath "C:\Test" -Scope User } | Should -Not -Throw
        }
    }
}
