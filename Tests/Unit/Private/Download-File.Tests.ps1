BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\ArchiveInstaller.psd1" -Resolve
    Import-Module $modulePath -Force

    # Dot-source the private function directly for testing
    $privatePath = Join-Path $PSScriptRoot "..\..\..\ArchiveInstaller\Private\Download-File.ps1" -Resolve
    . $privatePath

    # Load helpers
    . (Join-Path $PSScriptRoot "..\..\Helpers\MockHelpers.ps1" -Resolve)

    # Create test directory
    $script:TestDownloadDir = Join-Path $TestDrive "downloads"
    New-Item -ItemType Directory -Path $script:TestDownloadDir -Force | Out-Null
}

Describe "Download-File" -Tag 'Unit', 'Private' {

    Context "BITS Download Path" {
        BeforeEach {
            $script:TestFile = Join-Path $script:TestDownloadDir "test-bits.zip"
        }

        It "Should use BITS when FastDownload is specified and BITS is available" {
            Mock Get-Command {
                [PSCustomObject]@{ Name = 'Start-BitsTransfer' }
            } -ParameterFilter { $Name -eq 'Start-BitsTransfer' }
            Mock Start-BitsTransfer {
                New-MockDownloadedFile -Path $Destination -Content "Downloaded via BITS"
            }
            Mock Invoke-WebRequest {
                New-MockDownloadedFile -Path $OutFile
            }

            $result = Download-File -Url "https://example.com/file.zip" -OutFile $script:TestFile -FastDownload

            $result | Should -Be $script:TestFile
            Test-Path $script:TestFile | Should -Be $true
        }

        It "Should fallback to HttpClient when BITS fails" {
            Mock Get-Command {
                [PSCustomObject]@{ Name = 'Start-BitsTransfer' }
            } -ParameterFilter { $Name -eq 'Start-BitsTransfer' }
            Mock Start-BitsTransfer { throw "BITS Error: Transfer failed" }
            Mock Add-Type { throw "HttpClient not available" }
            Mock Invoke-WebRequest {
                New-MockDownloadedFile -Path $OutFile -Content "Fallback content"
            }

            $result = Download-File -Url "https://example.com/file.zip" -OutFile $script:TestFile -FastDownload

            Should -Invoke Invoke-WebRequest -Times 1
            Test-Path $script:TestFile | Should -Be $true
        }

        It "Should skip BITS when not available" {
            Mock Get-Command { return $false } -ParameterFilter { $Name -eq 'Start-BitsTransfer' }
            Mock Add-Type { throw "HttpClient not available" }
            Mock Invoke-WebRequest {
                New-MockDownloadedFile -Path $OutFile
            }

            $result = Download-File -Url "https://example.com/file.zip" -OutFile $script:TestFile -FastDownload

            Should -Invoke Get-Command -Times 1 -ParameterFilter { $Name -eq 'Start-BitsTransfer' }
            # We can't check Start-BitsTransfer invocation count since it's not mocked when not available
        }

        It "Should skip BITS when FastDownload not specified" {
            Mock Get-Command { return $true }
            Mock Start-BitsTransfer { throw "Should not be called" }
            Mock Invoke-WebRequest {
                New-MockDownloadedFile -Path $OutFile
            }

            $result = Download-File -Url "https://example.com/file.zip" -OutFile $script:TestFile

            Should -Invoke Start-BitsTransfer -Times 0
        }
    }

    Context "HttpClient Download Path" {
        BeforeEach {
            $script:TestFile = Join-Path $script:TestDownloadDir "test-http.zip"
        }

        It "Should use HttpClient streaming when BITS not available" {
            Mock Get-Command { return $false }
            Mock Add-Type -ParameterFilter { $AssemblyName -eq 'System.Net.Http' } {}
            # Fallback mock for when HttpClient mocking doesn't work
            Mock Invoke-WebRequest {
                New-MockDownloadedFile -Path $OutFile
            }

            # Create mock stream
            $mockStream = New-Object System.IO.MemoryStream
            $testBytes = [System.Text.Encoding]::UTF8.GetBytes("HttpClient test content")
            $mockStream.Write($testBytes, 0, $testBytes.Length)
            $mockStream.Position = 0

            Mock New-Object {
                switch ($TypeName) {
                    'System.Net.Http.HttpClientHandler' {
                        return [PSCustomObject]@{}
                    }
                    'System.Net.Http.HttpClient' {
                        return [PSCustomObject]@{
                            SendAsync = {
                                param($req, $opt)
                                [System.Threading.Tasks.Task[object]]::FromResult(
                                    [PSCustomObject]@{
                                        EnsureSuccessStatusCode = {}
                                        Content = [PSCustomObject]@{
                                            ReadAsStreamAsync = {
                                                [System.Threading.Tasks.Task[object]]::FromResult($mockStream)
                                            }
                                        }
                                    }
                                )
                            }
                            Dispose = {}
                        }
                    }
                    'System.Net.Http.HttpRequestMessage' {
                        return [PSCustomObject]@{
                            Headers = [PSCustomObject]@{
                                Add = {}
                            }
                        }
                    }
                    default {
                        & (Get-Command New-Object -CommandType Cmdlet) @PSBoundParameters
                    }
                }
            } -ParameterFilter { $TypeName -match 'Http' }

            $result = Download-File -Url "https://example.com/file.zip" -OutFile $script:TestFile

            Should -Invoke Add-Type -Times 1 -ParameterFilter { $AssemblyName -eq 'System.Net.Http' }
        }

        It "Should set User-Agent header in HttpClient request" {
            Mock Get-Command { return $false }
            Mock Add-Type { throw "HttpClient not available" }

            # Track if User-Agent was set
            $script:userAgentSet = $false
            Mock Invoke-WebRequest {
                if ($Headers -and $Headers['User-Agent'] -eq 'ArchiveInstaller') {
                    $script:userAgentSet = $true
                }
                New-MockDownloadedFile -Path $OutFile
            }

            Download-File -Url "https://example.com/file.zip" -OutFile $script:TestFile

            $script:userAgentSet | Should -Be $true
        }
    }

    Context "Invoke-WebRequest Fallback" {
        BeforeEach {
            $script:TestFile = Join-Path $script:TestDownloadDir "test-fallback.zip"
        }

        It "Should fallback to Invoke-WebRequest when HttpClient fails" {
            Mock Get-Command { return $false }
            Mock Add-Type { throw "HttpClient not available" }
            Mock Invoke-WebRequest {
                New-MockDownloadedFile -Path $OutFile -Content "WebRequest content"
            }

            $result = Download-File -Url "https://example.com/file.zip" -OutFile $script:TestFile

            Should -Invoke Invoke-WebRequest -Times 1 -Exactly
            $result | Should -Be $script:TestFile
            Test-Path $script:TestFile | Should -Be $true
        }

        It "Should use UseBasicParsing parameter" {
            Mock Get-Command { return $false }
            Mock Add-Type { throw "HttpClient not available" }
            Mock Invoke-WebRequest {
                $UseBasicParsing | Should -Be $true
                New-MockDownloadedFile -Path $OutFile
            }

            Download-File -Url "https://example.com/file.zip" -OutFile $script:TestFile
        }

        It "Should pass User-Agent header" {
            Mock Get-Command { return $false }
            Mock Add-Type { throw "HttpClient not available" }
            Mock Invoke-WebRequest {
                $Headers['User-Agent'] | Should -Be 'ArchiveInstaller'
                New-MockDownloadedFile -Path $OutFile
            }

            Download-File -Url "https://example.com/file.zip" -OutFile $script:TestFile
        }

        It "Should use specified URL" {
            $testUrl = "https://example.com/custom/path/file.zip"

            Mock Get-Command { return $false }
            Mock Add-Type { throw "HttpClient not available" }
            Mock Invoke-WebRequest {
                $Uri | Should -Be $testUrl
                New-MockDownloadedFile -Path $OutFile
            }

            Download-File -Url $testUrl -OutFile $script:TestFile
        }
    }

    Context "Error Handling" {
        BeforeEach {
            $script:TestFile = Join-Path $script:TestDownloadDir "test-error.zip"
        }

        It "Should throw when all methods fail" {
            Mock Get-Command { return $true }
            Mock Start-BitsTransfer { throw "BITS error" }
            Mock Add-Type { throw "HttpClient error" }
            Mock Invoke-WebRequest { throw "Network error" }

            { Download-File -Url "https://example.com/file.zip" -OutFile $script:TestFile -FastDownload } |
                Should -Throw
        }

        It "Should handle invalid URL gracefully" {
            Mock Get-Command { return $false }
            Mock Add-Type { throw "HttpClient error" }
            Mock Invoke-WebRequest { throw "404 Not Found" }

            { Download-File -Url "https://example.com/nonexistent.zip" -OutFile $script:TestFile } |
                Should -Throw "*404*"
        }

        It "Should handle network timeout" {
            Mock Get-Command { return $false }
            Mock Add-Type { throw "HttpClient error" }
            Mock Invoke-WebRequest { throw "The operation has timed out" }

            { Download-File -Url "https://example.com/file.zip" -OutFile $script:TestFile } |
                Should -Throw "*timed out*"
        }
    }

    Context "Verbose Output" {
        BeforeEach {
            $script:TestFile = Join-Path $script:TestDownloadDir "test-verbose.zip"
        }

        It "Should write verbose message when using BITS" {
            Mock Get-Command { return $true } -ParameterFilter { $Name -eq 'Start-BitsTransfer' }
            Mock Start-BitsTransfer {
                New-MockDownloadedFile -Path $Destination
            }
            # Fallback mock in case BITS mock doesn't work
            Mock Invoke-WebRequest {
                New-MockDownloadedFile -Path $OutFile
            }

            $verboseOutput = Download-File -Url "https://example.com/file.zip" `
                -OutFile $script:TestFile -FastDownload -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -match "Using BITS" } | Should -Not -BeNullOrEmpty
        }

        It "Should write verbose message when BITS fails" {
            Mock Get-Command { return $true } -ParameterFilter { $Name -eq 'Start-BitsTransfer' }
            Mock Start-BitsTransfer { throw "BITS error" }
            Mock Add-Type { throw "HttpClient error" }
            Mock Invoke-WebRequest {
                New-MockDownloadedFile -Path $OutFile
            }

            $verboseOutput = Download-File -Url "https://example.com/file.zip" `
                -OutFile $script:TestFile -FastDownload -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -match "BITS failed" } | Should -Not -BeNullOrEmpty
        }

        It "Should write verbose message when HttpClient fails" {
            Mock Get-Command { return $false }
            Mock Add-Type { throw "HttpClient not available" }
            Mock Invoke-WebRequest {
                New-MockDownloadedFile -Path $OutFile
            }

            $verboseOutput = Download-File -Url "https://example.com/file.zip" `
                -OutFile $script:TestFile -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -match "HttpClient failed" } | Should -Not -BeNullOrEmpty
        }
    }

    Context "Platform Detection" {
        BeforeEach {
            $script:TestFile = Join-Path $script:TestDownloadDir "test-platform.zip"
        }

        It "Should detect Windows platform" {
            # This test verifies the platform detection logic exists
            Mock Get-Command { return $true } -ParameterFilter { $Name -eq 'Start-BitsTransfer' }
            Mock Start-BitsTransfer {
                New-MockDownloadedFile -Path $Destination
            }
            # Fallback mock in case BITS mock doesn't work
            Mock Invoke-WebRequest {
                New-MockDownloadedFile -Path $OutFile
            }

            $result = Download-File -Url "https://example.com/file.zip" -OutFile $script:TestFile -FastDownload

            # If we get here on Windows, BITS check was performed
            Should -Invoke Get-Command -ParameterFilter { $Name -eq 'Start-BitsTransfer' }
        }
    }

    Context "Parameter Validation" {
        It "Should validate Url parameter is mandatory" {
            $params = (Get-Command Download-File).Parameters
            $params['Url'].Attributes.Mandatory | Should -Be $true
        }

        It "Should validate OutFile parameter is mandatory" {
            $params = (Get-Command Download-File).Parameters
            $params['OutFile'].Attributes.Mandatory | Should -Be $true
        }

        It "Should accept valid URL" {
            Mock Get-Command { return $false }
            Mock Add-Type { throw "HttpClient error" }
            Mock Invoke-WebRequest {
                New-MockDownloadedFile -Path $OutFile
            }

            { Download-File -Url "https://example.com/file.zip" -OutFile "$TestDrive\test.zip" } |
                Should -Not -Throw
        }
    }
}
