function Install-Git {
    [CmdletBinding(SupportsShouldProcess=$true)] param(
        [string]$DownloadDirectory,
        [switch]$AddPath,
        [switch]$Force
    )
    $ai = [GitArchiveInstaller]::new()
    if ($DownloadDirectory) { $ai.DownloadDirectory = $DownloadDirectory }
    $dest = $ai.DestinationExtractionDirectory()
    if ((Test-Path $dest) -and (-not $Force)) { Write-Verbose "Destination already exists: $dest. Use -Force to overwrite."; return $dest }
    if ($PSCmdlet.ShouldProcess($dest,'Install Git')) {
        $dest = $ai.ExtractLastLocalArchive()
        if ($AddPath -eq [switch]::Present) {
            $BinDirectory = Join-Path -Path  (Join-Path -Path $dest -ChildPath 'mingw64') -ChildPath 'bin'
            Add-Path -LiteralPath $BinDirectory -Scope CurrentUser
        }
    }
    return $dest
}