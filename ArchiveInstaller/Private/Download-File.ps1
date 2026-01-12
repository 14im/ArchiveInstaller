function Download-File {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$OutFile,
        [switch]$FastDownload
    )
    $ProgressPreference = 'SilentlyContinue'
    $headers = @{ 'User-Agent' = 'ArchiveInstaller' }

    # Detect Windows platform (compatible with PowerShell 5.1 and 7+)
    $isWindowsOS = $false
    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        # PowerShell 5.1 (Desktop edition) is Windows-only
        $isWindowsOS = $true
    } elseif ($PSVersionTable.Platform -eq 'Win32NT') {
        # PowerShell 7+ on Windows
        $isWindowsOS = $true
    } elseif (-not (Test-Path Variable:\IsWindows)) {
        # Variable doesn't exist, assume Windows (older PS versions)
        $isWindowsOS = $true
    } elseif ($IsWindows) {
        # PowerShell 7+ automatic variable
        $isWindowsOS = $true
    }

    if ($FastDownload -and $isWindowsOS -and (Get-Command Start-BitsTransfer -ErrorAction Ignore)) {
        try {
            Write-Verbose "Using BITS"
            Start-BitsTransfer -Source $Url -Destination $OutFile -Resume -ErrorAction Stop
            return $OutFile
        } catch {
            Write-Verbose "BITS failed: $($_.Exception.Message). Falling back to HttpClient."
        }
    }

    try {
        Write-Verbose "Using HttpClient streaming"
        Add-Type -AssemblyName System.Net.Http
        $handler = New-Object System.Net.Http.HttpClientHandler
        $client = New-Object System.Net.Http.HttpClient($handler)
        $request = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, $Url)
        foreach($k in $headers.Keys){ $request.Headers.Add($k,$headers[$k]) }
        $response = $client.SendAsync($request,[System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
        $response.EnsureSuccessStatusCode()
        $inStream = $response.Content.ReadAsStreamAsync().Result
        $outStream = [System.IO.File]::Open($OutFile,[System.IO.FileMode]::Create)
        $inStream.CopyTo($outStream)
        $outStream.Close(); $inStream.Close(); $client.Dispose()
        return $OutFile
    } catch {
        Write-Verbose "HttpClient failed: $($_.Exception.Message). Falling back to Invoke-WebRequest."
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -Headers $headers
        return $OutFile
    }
}