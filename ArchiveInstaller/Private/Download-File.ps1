function Download-File {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$OutFile,
        [switch]$FastDownload
    )
    $ProgressPreference = 'SilentlyContinue'
    $headers = @{ 'User-Agent' = 'ArchiveInstaller' }
    $isWindows = $false
    try { if ($PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows) { $isWindows = $true } } catch { $isWindows = $true }

    if ($FastDownload -and $isWindows -and (Get-Command Start-BitsTransfer -ErrorAction Ignore)) {
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