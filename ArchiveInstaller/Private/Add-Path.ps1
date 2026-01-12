function Add-Path {
    param(
      [Parameter(Mandatory, Position=0)] [string] $LiteralPath,
      [ValidateSet('User','CurrentUser','Machine','LocalMachine')] [string] $Scope 
    )
    Set-StrictMode -Version 1; $ErrorActionPreference = 'Stop'
    $isMachineLevel = $Scope -in 'Machine','LocalMachine'
    if ($isMachineLevel) {
        $curr = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal $curr
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) { throw "You must run AS ADMIN to update the machine-level Path environment variable." }
    }
    $regPath = 'registry::' + ('HKEY_CURRENT_USER\Environment','HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment')[$isMachineLevel]
    $currDirs = (Get-Item -LiteralPath $regPath).GetValue('Path','', 'DoNotExpandEnvironmentNames') -split ';' -ne ''
    if ($LiteralPath -in $currDirs) { Write-Verbose "Already present in PATH: $LiteralPath"; return }
    $newValue = ($currDirs + $LiteralPath) -join ';'
    Set-ItemProperty -Type ExpandString -LiteralPath $regPath Path $newValue
    $dummyName = [guid]::NewGuid().ToString(); [Environment]::SetEnvironmentVariable($dummyName,'foo','User'); [Environment]::SetEnvironmentVariable($dummyName,[NullString]::value,'User')
    $env:Path = ($env:Path -replace ';$') + ';' + $LiteralPath
    Write-Verbose "Path updated with: $LiteralPath"
}