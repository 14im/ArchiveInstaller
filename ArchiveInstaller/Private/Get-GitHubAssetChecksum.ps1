function Get-GitHubAssetChecksum {
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$ArchiveName
    )
    $headers = @{ 'User-Agent' = 'ArchiveInstaller' }
    try {
        $release = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$Owner/$Repo/releases/latest"
    } catch {
        Write-Verbose "GitHub API failed: $($_.Exception.Message)"
        return $null
    }
    $checksumAsset = $release.assets | Where-Object { $_.name -match 'sha256' -or $_.name -match 'checksum' -or $_.name -match 'sha256sum' } | Select-Object -First 1
    if (-not $checksumAsset) { return $null }
    $tmp = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $checksumAsset.name
    Invoke-WebRequest -Headers $headers -Uri $checksumAsset.browser_download_url -OutFile $tmp -UseBasicParsing
    $lines = Get-Content -LiteralPath $tmp
    foreach($line in $lines){
        if ($line -match [Regex]::Escape($ArchiveName)){
            $tokens = $line -split '\s+'
            if ($tokens.Count -ge 1){
                $hash = $tokens[0]
                if ($hash -match '^[A-Fa-f0-9]{64}$'){ return $hash }
            }
        }
    }
    return $null
}