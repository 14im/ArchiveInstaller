function Get-PowershellVSCodeExtension {
    [CmdletBinding()] param(
        [string]$DownloadDirectory,
        [switch]$Force,
        [switch]$FastDownload,
        [switch]$VerifyChecksum,
        [switch]$Strict,
        [string]$ChecksumFile
    )
    $ai = [PowershellVSCodeExtensionArchiveInstaller]::new()
    if ($DownloadDirectory) { $ai.DownloadDirectory = $DownloadDirectory }

    $targetName = $ai.GetDownloadArchive()
    $targetPath = Join-Path -Path $ai.DownloadDirectory -ChildPath $targetName

    if ((Test-Path $targetPath) -and (-not $Force)) {
        Write-Verbose "File already exists: $targetPath. Use -Force to overwrite."
        return $targetPath
    }

    if (-not (Test-Path $ai.DownloadDirectory)) { New-Item -ItemType Directory -Path $ai.DownloadDirectory | Out-Null }
    if (-not $ai.DownloadUrl) { if ($ai.GithubRepositoryName -and $ai.GithubRepositoryOwner) { $ai.DownloadUrl = $ai.GetGitHubDownloadUrl() } }
    Write-Verbose "Download URL: $($ai.DownloadUrl)"

    Download-File -Url $ai.DownloadUrl -OutFile $targetPath -FastDownload:$FastDownload | Out-Null

    if ($VerifyChecksum) {
        $expectedHash = $null
        if ($ChecksumFile) {
            if ($ChecksumFile -match '^(http|https)://') {
                $tmp = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath (Split-Path -Leaf $ChecksumFile)
                Invoke-WebRequest -Uri $ChecksumFile -OutFile $tmp -UseBasicParsing
                $ChecksumFile = $tmp
            }
            $lines = Get-Content -LiteralPath $ChecksumFile
            foreach($line in $lines) { if ($line -match [Regex]::Escape($targetName)) { $expectedHash = ($line -split '\s+')[0] } }
        } else {
            if ($ai.GithubRepositoryOwner -and $ai.GithubRepositoryName) {
                $expectedHash = Get-GitHubAssetChecksum -Owner $ai.GithubRepositoryOwner -Repo $ai.GithubRepositoryName -ArchiveName $targetName
            }
        }
        if (-not $expectedHash) {
            if ($Strict) { throw "Checksum not found for $targetName" } else { Write-Warning "Checksum not found. Skipping verification." }
        } else {
            $ok = Test-Checksum -FilePath $targetPath -ExpectedHash $expectedHash
            if (-not $ok) { throw "Checksum mismatch for $targetPath" }
        }
    }
    return $targetPath
}