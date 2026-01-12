<#
.SYNOPSIS
    Runs Pester tests for the ArchiveInstaller module
.DESCRIPTION
    Executes Pester tests with configurable test types and code coverage options
.PARAMETER TestType
    Type of tests to run: Unit, Integration, E2E, or All
.PARAMETER CodeCoverage
    Enable code coverage analysis
.PARAMETER OutputFormat
    Format for test output (NUnitXml, JUnitXml)
.PARAMETER OutputFile
    Path to output file for test results
.EXAMPLE
    .\Run-Tests.ps1 -TestType Unit
    Runs only unit tests
.EXAMPLE
    .\Run-Tests.ps1 -TestType All -CodeCoverage
    Runs all tests with code coverage
#>
[CmdletBinding()]
param(
    [ValidateSet('Unit', 'Integration', 'E2E', 'All')]
    [string]$TestType = 'All',

    [switch]$CodeCoverage,

    [ValidateSet('NUnitXml', 'JUnitXml', 'None')]
    [string]$OutputFormat = 'None',

    [string]$OutputFile
)

# Ensure Pester is available
$pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pesterModule) {
    Write-Error "Pester module not found. Install it with: Install-Module -Name Pester -Force -SkipPublisherCheck"
    exit 1
}

if ($pesterModule.Version.Major -lt 5) {
    Write-Warning "Pester 5.x or higher is recommended. Current version: $($pesterModule.Version)"
}

Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

# Configure Pester
$config = New-PesterConfiguration

# Set verbosity
$config.Output.Verbosity = 'Detailed'

# Enable PassThru to get result object
$config.Run.PassThru = $true

# Set test path based on type
$config.Run.Path = "$PSScriptRoot"
switch ($TestType) {
    'Unit' {
        $config.Run.Path = "$PSScriptRoot\Unit"
        Write-Host "Running Unit Tests..." -ForegroundColor Cyan
    }
    'Integration' {
        $config.Run.Path = "$PSScriptRoot\Integration"
        $config.Filter.Tag = 'Integration'
        Write-Host "Running Integration Tests..." -ForegroundColor Cyan
    }
    'E2E' {
        $config.Run.Path = "$PSScriptRoot\E2E"
        $config.Filter.Tag = 'E2E'
        Write-Host "Running E2E Tests..." -ForegroundColor Cyan
        if ($env:CI) {
            Write-Warning "E2E tests will be skipped in CI environment"
        }
    }
    'All' {
        Write-Host "Running All Tests..." -ForegroundColor Cyan
    }
}

# Configure code coverage
if ($CodeCoverage) {
    Write-Host "Code coverage enabled" -ForegroundColor Yellow
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = "$PSScriptRoot\..\ArchiveInstaller"
    $config.CodeCoverage.OutputFormat = 'JaCoCo'
    $config.CodeCoverage.OutputPath = "$PSScriptRoot\..\coverage.xml"
    $config.CodeCoverage.OutputEncoding = 'UTF8'
}

# Configure test result output
if ($OutputFormat -ne 'None') {
    if (-not $OutputFile) {
        $OutputFile = "$PSScriptRoot\TestResults.xml"
    }
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputFormat = $OutputFormat
    $config.TestResult.OutputPath = $OutputFile
    Write-Host "Test results will be saved to: $OutputFile" -ForegroundColor Yellow
}

# Check if test files exist
$testPath = $config.Run.Path.Value
$testFiles = Get-ChildItem -Path $testPath -Filter "*.Tests.ps1" -Recurse -ErrorAction SilentlyContinue
if (-not $testFiles) {
    Write-Warning "No test files found in: $testPath"
    Write-Host "`nTest Summary:" -ForegroundColor Cyan
    Write-Host "  Total:    0" -ForegroundColor Yellow
    Write-Host "  Passed:   0" -ForegroundColor Yellow
    Write-Host "  Failed:   0" -ForegroundColor Yellow
    Write-Host "  Skipped:  0" -ForegroundColor Yellow
    Write-Host "`nNo tests to run" -ForegroundColor Yellow
    exit 0
}

# Run tests
Write-Host "`nStarting test execution..." -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Green

$result = Invoke-Pester -Configuration $config

# Output summary
Write-Host "`n" + ("=" * 80) -ForegroundColor Green
Write-Host "Test Summary:" -ForegroundColor Cyan

# Get test counts from Pester result object
$totalCount = $result.TotalCount
$passedCount = $result.PassedCount
$failedCount = $result.FailedCount
$skippedCount = $result.SkippedCount
$duration = $result.Duration

Write-Host "  Total:    $totalCount" -ForegroundColor White
Write-Host "  Passed:   $passedCount" -ForegroundColor Green
Write-Host "  Failed:   $failedCount" -ForegroundColor $(if ($failedCount -gt 0) { 'Red' } else { 'Green' })
Write-Host "  Skipped:  $skippedCount" -ForegroundColor Yellow
Write-Host "  Duration: $duration" -ForegroundColor White

if ($CodeCoverage -and $result.CodeCoverage) {
    $coveragePercent = [math]::Round(($result.CodeCoverage.CoveragePercent), 2)
    Write-Host "`nCode Coverage: $coveragePercent%" -ForegroundColor $(if ($coveragePercent -ge 80) { 'Green' } elseif ($coveragePercent -ge 60) { 'Yellow' } else { 'Red' })
}

# Exit with appropriate code
if ($failedCount -gt 0) {
    Write-Host "`nTests FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nAll tests PASSED" -ForegroundColor Green
    exit 0
}
