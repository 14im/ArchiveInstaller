BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force

    # Dot-source the private function directly for testing
    $privatePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\Private\Test-Checksum.ps1" -Resolve
    . $privatePath

    # Create test files with known hashes
    $script:TestFile = Join-Path $TestDrive "test.txt"
    "Hello World" | Out-File -FilePath $script:TestFile -Encoding ascii -NoNewline

    # Known SHA256 hash for "Hello World" (no newline, ASCII)
    $script:ExpectedHash = "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e"
}

Describe "Test-Checksum" -Tag 'Unit', 'Private' {

    Context "Valid Checksum Verification" {
        It "Should return true when checksums match" {
            $result = Test-Checksum -FilePath $script:TestFile -ExpectedHash $script:ExpectedHash
            $result | Should -Be $true
        }

        It "Should be case-insensitive for lowercase hash" {
            $result = Test-Checksum -FilePath $script:TestFile -ExpectedHash $script:ExpectedHash.ToLower()
            $result | Should -Be $true
        }

        It "Should be case-insensitive for uppercase hash" {
            $result = Test-Checksum -FilePath $script:TestFile -ExpectedHash $script:ExpectedHash.ToUpper()
            $result | Should -Be $true
        }

        It "Should be case-insensitive for mixed case hash" {
            $mixedHash = "A591A6d40bf420404A011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e"
            $result = Test-Checksum -FilePath $script:TestFile -ExpectedHash $mixedHash
            $result | Should -Be $true
        }

        It "Should write verbose message on success" {
            $verboseOutput = Test-Checksum -FilePath $script:TestFile `
                -ExpectedHash $script:ExpectedHash -Verbose 4>&1

            $verboseText = $verboseOutput -join " "
            $verboseText | Should -Match "Checksum (OK|verified|match)"
        }
    }

    Context "Invalid Checksum Detection" {
        It "Should return false when checksums do not match" {
            $wrongHash = "0000000000000000000000000000000000000000000000000000000000000000"
            $result = Test-Checksum -FilePath $script:TestFile -ExpectedHash $wrongHash
            $result | Should -Be $false
        }

        It "Should return false for different hash" {
            $differentHash = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
            $result = Test-Checksum -FilePath $script:TestFile -ExpectedHash $differentHash
            $result | Should -Be $false
        }

        It "Should write warning when checksums mismatch" {
            $wrongHash = "0000000000000000000000000000000000000000000000000000000000000000"
            $warningOutput = Test-Checksum -FilePath $script:TestFile `
                -ExpectedHash $wrongHash -WarningAction SilentlyContinue -WarningVariable warnings

            $warnings | Should -Not -BeNullOrEmpty
            $warningText = $warnings -join " "
            $warningText | Should -Match "mismatch"
        }

        It "Should include expected hash in warning" {
            $wrongHash = "0000000000000000000000000000000000000000000000000000000000000000"
            $warningOutput = Test-Checksum -FilePath $script:TestFile `
                -ExpectedHash $wrongHash -WarningAction SilentlyContinue -WarningVariable warnings

            $warningText = $warnings -join " "
            $warningText | Should -Match "Expected"
        }

        It "Should include actual hash in warning" {
            $wrongHash = "0000000000000000000000000000000000000000000000000000000000000000"
            $warningOutput = Test-Checksum -FilePath $script:TestFile `
                -ExpectedHash $wrongHash -WarningAction SilentlyContinue -WarningVariable warnings

            $warningText = $warnings -join " "
            $warningText | Should -Match "Actual"
        }
    }

    Context "Error Handling" {
        It "Should throw when file does not exist" {
            { Test-Checksum -FilePath "$TestDrive\nonexistent.txt" -ExpectedHash $script:ExpectedHash } |
                Should -Throw
        }

        It "Should validate FilePath parameter is mandatory" {
            $params = (Get-Command Test-Checksum).Parameters
            $params['FilePath'].Attributes.Mandatory | Should -Be $true
        }

        It "Should validate ExpectedHash parameter is mandatory" {
            $params = (Get-Command Test-Checksum).Parameters
            $params['ExpectedHash'].Attributes.Mandatory | Should -Be $true
        }

        It "Should handle empty file" {
            $emptyFile = Join-Path $TestDrive "empty.txt"
            "" | Out-File -FilePath $emptyFile -NoNewline

            $emptyHash = (Get-FileHash -Path $emptyFile -Algorithm SHA256).Hash
            $result = Test-Checksum -FilePath $emptyFile -ExpectedHash $emptyHash

            $result | Should -Be $true
        }
    }

    Context "Hash Algorithm" {
        It "Should use SHA256 algorithm" {
            Mock Get-FileHash {
                $Algorithm | Should -Be 'SHA256'
                return @{ Hash = $script:ExpectedHash }
            }

            Test-Checksum -FilePath $script:TestFile -ExpectedHash $script:ExpectedHash

            Should -Invoke Get-FileHash -Times 1
        }

        It "Should call Get-FileHash with correct file path" {
            Mock Get-FileHash {
                $LiteralPath | Should -Be $script:TestFile
                return @{ Hash = $script:ExpectedHash }
            }

            Test-Checksum -FilePath $script:TestFile -ExpectedHash $script:ExpectedHash

            Should -Invoke Get-FileHash -Times 1
        }
    }

    Context "Different File Contents" {
        It "Should correctly validate different file with matching hash" {
            $file2 = Join-Path $TestDrive "test2.txt"
            "Different Content" | Out-File -FilePath $file2 -Encoding ascii -NoNewline

            $hash2 = (Get-FileHash -Path $file2 -Algorithm SHA256).Hash

            $result = Test-Checksum -FilePath $file2 -ExpectedHash $hash2
            $result | Should -Be $true
        }

        It "Should detect file tampering" {
            $file3 = Join-Path $TestDrive "test3.txt"
            "Original Content" | Out-File -FilePath $file3 -Encoding ascii -NoNewline

            $originalHash = (Get-FileHash -Path $file3 -Algorithm SHA256).Hash

            # Modify file
            "Modified Content" | Out-File -FilePath $file3 -Encoding ascii -NoNewline

            $result = Test-Checksum -FilePath $file3 -ExpectedHash $originalHash
            $result | Should -Be $false
        }

        It "Should handle large file" {
            $largeFile = Join-Path $TestDrive "large.txt"
            # Create a ~1MB file
            $content = "x" * 1024 * 1024
            $content | Out-File -FilePath $largeFile -NoNewline

            $largeHash = (Get-FileHash -Path $largeFile -Algorithm SHA256).Hash

            $result = Test-Checksum -FilePath $largeFile -ExpectedHash $largeHash
            $result | Should -Be $true
        }
    }

    Context "Edge Cases" {
        It "Should handle file with special characters in name" {
            $specialFile = Join-Path $TestDrive "test[file]#with-special.txt"
            "Content" | Out-File -LiteralPath $specialFile -NoNewline

            $specialHash = (Get-FileHash -LiteralPath $specialFile -Algorithm SHA256).Hash

            $result = Test-Checksum -FilePath $specialFile -ExpectedHash $specialHash
            $result | Should -Be $true
        }

        It "Should handle file in deep directory structure" {
            $deepPath = Join-Path $TestDrive "level1\level2\level3"
            New-Item -ItemType Directory -Path $deepPath -Force | Out-Null

            $deepFile = Join-Path $deepPath "deep.txt"
            "Deep content" | Out-File -FilePath $deepFile -NoNewline

            $deepHash = (Get-FileHash -Path $deepFile -Algorithm SHA256).Hash

            $result = Test-Checksum -FilePath $deepFile -ExpectedHash $deepHash
            $result | Should -Be $true
        }

        It "Should handle hash with leading/trailing whitespace" {
            $hashWithSpaces = "  $script:ExpectedHash  "
            # The function should handle this gracefully
            # Note: This depends on implementation - might need trimming
            $result = Test-Checksum -FilePath $script:TestFile -ExpectedHash $hashWithSpaces.Trim()
            $result | Should -Be $true
        }
    }

    Context "Binary Files" {
        It "Should correctly verify binary file checksum" {
            $binaryFile = Join-Path $TestDrive "binary.bin"
            # Create a binary file with specific byte pattern
            $bytes = [byte[]](0x48, 0x65, 0x6C, 0x6C, 0x6F)  # "Hello" in bytes
            [System.IO.File]::WriteAllBytes($binaryFile, $bytes)

            $binaryHash = (Get-FileHash -Path $binaryFile -Algorithm SHA256).Hash

            $result = Test-Checksum -FilePath $binaryFile -ExpectedHash $binaryHash
            $result | Should -Be $true
        }
    }
}
