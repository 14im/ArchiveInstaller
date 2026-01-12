function Install-PowershellVSCodeExtension {
    [CmdletBinding(SupportsShouldProcess=$true)] param(
        [string]$DownloadDirectory,
        $VSCodeDirectory = ([VSCodeArchiveInstaller]::new()).DestinationExtractionDirectory(),
        [switch] $Portable,
        [switch] $Force
    )
    $VSCodeLauncher = Join-Path -Path (Join-Path -Path $VSCodeDirectory -ChildPath 'bin' ) -ChildPath 'code.cmd'
    if( -not (Test-Path -Path $VSCodeLauncher) ) { Throw "vscode missing" }
    $ai = [PowershellVSCodeExtensionArchiveInstaller]::new()
    if( $DownloadDirectory ) { $ai.DownloadDirectory = $DownloadDirectory }

    try { Add-Type -AssemblyName System.IO.Compression.FileSystem } catch {}
    $zip = [IO.Compression.ZipFile]::OpenRead($ai.GetLastLocalArchive())
    $entry = $zip.Entries | Where-Object Name -EQ 'extension.vsixmanifest'
    $stream = $entry.Open(); $reader = New-Object System.IO.StreamReader($stream); $content = $reader.ReadToEnd(); $reader.Dispose(); $stream.Dispose(); $zip.Dispose()
    $xml = [xml]$content
    $extensionID = '{0}.{1}' -f ($xml.PackageManifest.Metadata.Identity.Publisher,$xml.PackageManifest.Metadata.Identity.Id)

    $InstalledExtensions = & $VSCodeLauncher --list-extensions
    if( (-not $Force) -and ($InstalledExtensions -split "`n" -contains $extensionID) ) {
        Write-Verbose "Extension already installed: $extensionID. Use -Force to reinstall."
        return $extensionID
    }

    if( $Portable ) {
        $DataDirectory = Join-Path -Path $VSCodeDirectory -ChildPath 'data'
        if( -not (Test-Path -Path $DataDirectory) ) { New-Item -Type Directory -Path $DataDirectory | Out-Null }
    }

    if ($PSCmdlet.ShouldProcess($extensionID,'Install VSCode PowerShell extension')) {
        $commandLine = '/c {0} --install-extension {1}' -f ($VSCodeLauncher, $ai.GetLastLocalArchive())
        Write-Verbose "Installing extension: $extensionID from $($ai.GetLastLocalArchive())"
        Start-Process -FilePath 'cmd' -ArgumentList $commandLine -Wait
    }
}