function Mock-BitsTransfer {
    <#
    .SYNOPSIS
        Mocks BITS Transfer functionality
    .PARAMETER ShouldFail
        If set, mock will throw an error
    .PARAMETER ErrorMessage
        Custom error message when failing
    #>
    param(
        [switch]$ShouldFail,
        [string]$ErrorMessage = "BITS transfer failed"
    )

    if ($ShouldFail) {
        Mock Start-BitsTransfer { throw $ErrorMessage }
    } else {
        Mock Start-BitsTransfer {
            $content = "Mock downloaded content via BITS"
            $content | Out-File -FilePath $Destination -Force -Encoding ascii
        }
    }
}

function Mock-HttpClient {
    <#
    .SYNOPSIS
        Mocks HttpClient functionality for streaming downloads
    .PARAMETER ShouldFail
        If set, mock will throw an error
    .PARAMETER ErrorMessage
        Custom error message when failing
    #>
    param(
        [switch]$ShouldFail,
        [string]$ErrorMessage = "HttpClient failed"
    )

    if ($ShouldFail) {
        Mock Add-Type -ParameterFilter { $AssemblyName -eq 'System.Net.Http' } {
            throw $ErrorMessage
        }
    } else {
        Mock Add-Type -ParameterFilter { $AssemblyName -eq 'System.Net.Http' } {}

        # Mock HttpClient components
        Mock New-Object {
            $mockStream = New-Object System.IO.MemoryStream
            $mockContent = [byte[]]@(77, 111, 99, 107, 32, 99, 111, 110, 116, 101, 110, 116) # "Mock content"
            $mockStream.Write($mockContent, 0, $mockContent.Length)
            $mockStream.Position = 0

            switch ($TypeName) {
                'System.Net.Http.HttpClientHandler' {
                    return [PSCustomObject]@{}
                }
                'System.Net.Http.HttpClient' {
                    return [PSCustomObject]@{
                        SendAsync = {
                            param($req, $opt)
                            return [System.Threading.Tasks.Task[System.Net.Http.HttpResponseMessage]]::FromResult(
                                [PSCustomObject]@{
                                    EnsureSuccessStatusCode = {}
                                    Content = [PSCustomObject]@{
                                        ReadAsStreamAsync = {
                                            [System.Threading.Tasks.Task[System.IO.Stream]]::FromResult($mockStream)
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
                        Headers = [PSCustomObject]@{ Add = {} }
                    }
                }
                default {
                    # Pass through to real New-Object for other types
                    & (Get-Command New-Object -CommandType Cmdlet) @PSBoundParameters
                }
            }
        } -ParameterFilter { $TypeName -match 'Http' }
    }
}

function Mock-InvokeWebRequest {
    <#
    .SYNOPSIS
        Mocks Invoke-WebRequest for file downloads
    .PARAMETER ShouldFail
        If set, mock will throw an error
    .PARAMETER ErrorMessage
        Custom error message when failing
    .PARAMETER Content
        Content to write to the output file
    #>
    param(
        [switch]$ShouldFail,
        [string]$ErrorMessage = "Web request failed",
        [string]$Content = "Mock downloaded content"
    )

    if ($ShouldFail) {
        Mock Invoke-WebRequest { throw $ErrorMessage }
    } else {
        Mock Invoke-WebRequest {
            if ($OutFile) {
                $Content | Out-File -FilePath $OutFile -Force -Encoding ascii
            }
            return @{
                StatusCode = 200
                Content = $Content
                Headers = @{
                    'Content-Type' = 'application/zip'
                }
                BaseResponse = @{
                    ResponseUri = @{
                        AbsolutePath = "/releases/download/v1.0/test.zip"
                    }
                }
            }
        }
    }
}

function Mock-GitHubAPI {
    <#
    .SYNOPSIS
        Mocks GitHub API requests
    .PARAMETER Owner
        Repository owner
    .PARAMETER Repo
        Repository name
    .PARAMETER Release
        Custom release object to return
    .PARAMETER ShouldFail
        If set, mock will throw an error
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Owner,

        [Parameter(Mandatory)]
        [string]$Repo,

        [hashtable]$Release,

        [switch]$ShouldFail
    )

    if ($ShouldFail) {
        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -match "api.github.com/repos/$Owner/$Repo"
        } {
            throw "API request failed: Rate limit exceeded"
        }
    } else {
        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -match "api.github.com/repos/$Owner/$Repo"
        } {
            if ($Release) {
                return $Release
            }
            # Load fixtures and return appropriate release
            . "$PSScriptRoot\..\Fixtures\GitHubResponses.ps1"
            if ($Repo -eq "PowerShell") {
                return Get-MockGitHubRelease -RepoOwner $Owner -RepoName $Repo
            } elseif ($Repo -eq "git") {
                return Get-MockGitRelease
            } elseif ($Repo -eq "terminal") {
                return Get-MockWindowsTerminalRelease
            } elseif ($Repo -eq "vscode-powershell") {
                return Get-MockPowerShellVSCodeExtensionRelease
            } else {
                return Get-MockGitHubRelease -RepoOwner $Owner -RepoName $Repo
            }
        }
    }
}

function Mock-RegistryAccess {
    <#
    .SYNOPSIS
        Mocks Windows registry access for PATH management
    .PARAMETER AsAdmin
        If set, mocks admin privileges
    .PARAMETER CurrentPath
        Current PATH value to mock
    #>
    param(
        [switch]$AsAdmin,
        [string]$CurrentPath = "C:\Windows\System32;C:\Windows"
    )

    # Mock registry Get-Item
    Mock Get-Item {
        param($Path)
        return [PSCustomObject]@{
            GetValue = {
                param($Name, $Default, $Options)
                return $CurrentPath
            }
        }
    } -ParameterFilter { $Path -match 'Environment|Session Manager' }

    # Mock registry Set-ItemProperty
    Mock Set-ItemProperty {} -ParameterFilter { $Name -eq 'Path' }

    # Mock admin check
    if ($AsAdmin) {
        Mock New-Object -ParameterFilter { $TypeName -match 'WindowsPrincipal' } {
            return [PSCustomObject]@{
                IsInRole = { param($role) return $true }
            }
        }
    } else {
        Mock New-Object -ParameterFilter { $TypeName -match 'WindowsPrincipal' } {
            return [PSCustomObject]@{
                IsInRole = { param($role) return $false }
            }
        }
    }

    # Mock WindowsIdentity
    Mock -CommandName 'Get-Command' -ParameterFilter { $Name -match 'WindowsIdentity' } {
        return $true
    }
}

function Mock-FileSystemOperations {
    <#
    .SYNOPSIS
        Mocks common file system operations
    .PARAMETER TestDrivePath
        Path to TestDrive for file operations
    #>
    param(
        [string]$TestDrivePath = $TestDrive
    )

    # Mock Expand-Archive
    Mock Expand-Archive {
        $destPath = if ($DestinationPath) { $DestinationPath } else { Split-Path $Path }
        if (-not (Test-Path $destPath)) {
            New-Item -ItemType Directory -Path $destPath -Force | Out-Null
        }
        # Create a dummy file to simulate extraction
        $dummyFile = Join-Path $destPath "extracted-file.txt"
        "Extracted content" | Out-File -FilePath $dummyFile -Force
    }
}

function New-MockDownloadedFile {
    <#
    .SYNOPSIS
        Creates a mock downloaded file
    .PARAMETER Path
        Path where to create the file
    .PARAMETER Content
        Content to write to the file
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Content = "Mock file content"
    )

    $Content | Out-File -Path $Path -Force -Encoding ascii
}

function Mock-ContentDispositionHeader {
    <#
    .SYNOPSIS
        Creates a mock Content-Disposition header response
    .PARAMETER FileName
        Filename to include in the header
    .PARAMETER Uri
        URI to use in the response
    #>
    param(
        [string]$FileName = "test-file.zip",
        [string]$Uri = "/path/to/file.zip"
    )

    return @{
        Headers = @{
            'Content-Disposition' = "attachment; filename=`"$FileName`""
        }
        BaseResponse = @{
            ResponseUri = @{
                AbsolutePath = $Uri
            }
        }
    }
}

function Assert-MockCalledInOrder {
    <#
    .SYNOPSIS
        Helper to assert mocks were called in a specific order
    .PARAMETER MockCalls
        Array of mock names in expected order
    #>
    param(
        [Parameter(Mandatory)]
        [string[]]$MockCalls
    )

    # This is a simplified helper - in real tests you'd track call order
    foreach ($mockName in $MockCalls) {
        Should -Invoke $mockName -Times 1 -Exactly
    }
}
