function Test-Checksum {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string]$ExpectedHash
    )
    $actualHash = (Get-FileHash -LiteralPath $FilePath -Algorithm SHA256).Hash.ToLower()
    if ($actualHash -eq $ExpectedHash.ToLower()) {
        Write-Verbose "Checksum OK: $actualHash"
        return $true
    } else {
        Write-Warning "Checksum mismatch! Expected: $ExpectedHash, Actual: $actualHash"
        return $false
    }
}