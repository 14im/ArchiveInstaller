function Expand-WindowsTerminalArchive {
    [CmdletBinding(SupportsShouldProcess=$true)] param(
        [string]$DownloadDirectory,
        [switch]$AddPath,
        [switch]$Force
    )
    $ai = [WindowsTerminalArchiveInstaller]::new()
    if ($DownloadDirectory) { $ai.DownloadDirectory = $DownloadDirectory }
    $dest = $ai.DestinationExtractionDirectory()
    if ((Test-Path $dest) -and (-not $Force)) { Write-Verbose "Destination already exists: $dest. Use -Force to overwrite."; return $dest }
    if ($PSCmdlet.ShouldProcess($dest,'Expand Windows Terminal archive')) {
        $dest = $ai.ExtractLastLocalArchive()
        if ($AddPath -eq [switch]::Present) { Add-Path -LiteralPath $dest -Scope CurrentUser }
    }
    return $dest
}