class ArchiveInstaller {
    [string] $DownloadDirectory = $(Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders").PSObject.Properties["{374DE290-123F-4565-9164-39C4925E467B}"].Value
    [string] $DownloadUrl
    [string] $GithubRepositoryOwner
    [string] $GithubRepositoryName
    [string] $ArchiveGlob = '*x64.zip'

    static [string] DefaultDestination() {
        return Join-Path -Path (Join-Path -Path $([environment]::GetFolderPath('LocalApplicationData')) -ChildPath 'Programs') -ChildPath 'Microsoft'
    }

    ArchiveInstaller() {}
    ArchiveInstaller([string] $DownloadUrl) { $this.DownloadUrl = $DownloadUrl }
    ArchiveInstaller([string] $GithubRepositoryOwner, [string] $GithubRepositoryName) { $this.GithubRepositoryOwner = $GithubRepositoryOwner; $this.GithubRepositoryName = $GithubRepositoryName }
    ArchiveInstaller([string] $GithubRepositoryOwner, [string] $GithubRepositoryName, [string] $Glob) { $this.GithubRepositoryOwner = $GithubRepositoryOwner; $this.GithubRepositoryName = $GithubRepositoryName; $this.ArchiveGlob = $Glob }

    [string] Download() {
        if ($null -eq $this.DownloadUrl) { if ($this.GithubRepositoryName -and $this.GithubRepositoryOwner) { $this.DownloadUrl = $this.GetGitHubDownloadUrl() } }
        if ($null -eq $this.DownloadUrl) { throw "Download Url is missing" }
        $headers = @{ 'User-Agent' = 'ArchiveInstaller' }
        $DownloadArchive = Join-Path -Path $this.DownloadDirectory -ChildPath $this.GetDownloadArchive()
        Write-Verbose "Downloading from $($this.DownloadUrl) to $DownloadArchive"
        Invoke-WebRequest -Uri $this.DownloadUrl -OutFile $DownloadArchive -UseBasicParsing -Headers $headers
        Write-Verbose "Download complete: $DownloadArchive"
        return $DownloadArchive
    }

    [string] GetGitHubDownloadUrl() {
        $headers = @{ 'User-Agent' = 'ArchiveInstaller' }
        Write-Verbose "Querying GitHub latest release for $($this.GithubRepositoryOwner)/$($this.GithubRepositoryName)"
        $release = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$($this.GithubRepositoryOwner)/$($this.GithubRepositoryName)/releases/latest"
        $asset = @($release.assets | Where-Object name -Like $($this.ArchiveGlob)) | Select-Object -First 1
        if ($null -eq $asset) { throw "No matching asset found with glob '$($this.ArchiveGlob)'" }
        Write-Verbose "Selected asset: $($asset.name)"
        return $asset.browser_download_url
    }

    [string] GetDownloadArchive() {
        if ($null -eq $this.DownloadUrl) { if ($this.GithubRepositoryName -and $this.GithubRepositoryOwner) { $this.DownloadUrl = $this.GetGitHubDownloadUrl() } }
        if ($null -eq $this.DownloadUrl) { throw "Download Url is missing" }
        $headers = @{ 'User-Agent' = 'ArchiveInstaller' }
        Write-Verbose "Resolving filename from $($this.DownloadUrl)"
        $WebResponseObject = Invoke-WebRequest -Uri $this.DownloadUrl -Method HEAD -UseBasicParsing -Headers $headers
        $filename = $null
        $cd = $WebResponseObject.Headers['Content-Disposition']
        if ($cd) {
            $ContentDisposition = @{}
            foreach ($segment in ($cd -split ';')) {
                $pair = $segment -split '=', 2
                if ($pair.Count -eq 2) { $key = ($pair[0] -replace '^\s*'); $val = ($pair[1] -replace '"'); $ContentDisposition[$key] = $val }
            }
            if ($ContentDisposition.ContainsKey('filename')) { $filename = $ContentDisposition['filename'] }
        }
        if (-not $filename) { $uriLeaf = Split-Path -Path $WebResponseObject.BaseResponse.ResponseUri.AbsolutePath -Leaf; if ($uriLeaf) { $filename = $uriLeaf } }
        if (-not $filename) { $filename = Split-Path -Path $this.DownloadUrl -Leaf }
        if (-not $filename) { throw "Unable to determine filename from headers or URL." }
        Write-Verbose "Resolved filename: $filename"
        return $filename
    }

    [string] GetLastLocalArchive() { $Archive = @(Get-ChildItem -Path $this.DownloadDirectory | Where-Object Name -iLike $this.ArchiveGlob | Sort-Object -Property Name)[-1].Fullname; Write-Verbose "Last local archive: $Archive"; return $Archive }
    [string] ExtractLastLocalArchive() { return $this.ExtractLastLocalArchive([ArchiveInstaller]::DefaultDestination()) }
    [string] DestinationExtractionDirectory() { $Destination = [ArchiveInstaller]::DefaultDestination(); $Archive = $this.GetLastLocalArchive(); $DestinationPath = Join-Path -Path $Destination -ChildPath $((Split-Path -Path $Archive -Leaf) -replace '\\.zip$' -replace '\\.0_x64$'); Write-Verbose "Destination directory: $DestinationPath"; return $DestinationPath }
    [string] DestinationExtractionDirectory($Archive) { $Destination = [ArchiveInstaller]::DefaultDestination(); $DestinationPath = Join-Path -Path $Destination -ChildPath $((Split-Path -Path $Archive -Leaf) -replace '\\.zip$' -replace '\\.0_x64$'); Write-Verbose "Destination directory: $DestinationPath"; return $DestinationPath }
    [string] ExtractLastLocalArchive($Destination) { if (-not (Test-Path $Destination)) { Write-Verbose "Creating destination: $Destination"; New-Item -Path $Destination -ItemType Directory | Out-Null }; $Archive = $this.GetLastLocalArchive(); $DestinationPath = Join-Path -Path $Destination -ChildPath $((Split-Path -Path $Archive -Leaf) -replace '\\.zip$' -replace '\\.0_x64$'); Write-Verbose "Expanding $Archive to $DestinationPath"; Expand-Archive -Path $Archive -DestinationPath $DestinationPath -Force; Write-Verbose "Extraction complete: $DestinationPath"; return $DestinationPath }
}