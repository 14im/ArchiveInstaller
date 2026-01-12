Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
Get-ChildItem -LiteralPath "$PSScriptRoot/Classes" -Filter *.ps1  | ForEach-Object { . $_.FullName }
Get-ChildItem -LiteralPath "$PSScriptRoot/Private" -Filter *.ps1  | ForEach-Object { . $_.FullName }
Get-ChildItem -LiteralPath "$PSScriptRoot/Public"  -Filter *.ps1  | ForEach-Object { . $_.FullName }
$publicFunctions = (Get-ChildItem -LiteralPath "$PSScriptRoot/Public" -Filter *.ps1).BaseName
Export-ModuleMember -Function $publicFunctions