# Requires -RunAsAdministrator
[CmdletBinding()]
param()

function Get-UninstallEntry {
    param([string]$NameLike)
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    Get-ItemProperty $paths -ErrorAction SilentlyContinue |
      Where-Object { $_.DisplayName -and $_.DisplayName -like "*$NameLike*" } |
      Select-Object DisplayName, DisplayVersion, UninstallString, PSPath
}

function Uninstall-ByName {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$NameLike,[switch]$Quiet)
    $app = Get-UninstallEntry -NameLike $NameLike | Select-Object -First 1
    if (-not $app) { throw "No se encontró '$NameLike'." }

    $cmd = $app.UninstallString
    if ($cmd -match 'msiexec\.exe') {
        if ($Quiet) { $cmd = ($cmd -replace '/I','/X') + ' /qn /norestart' }
    } else {
        if ($Quiet) { $cmd += ' /S /quiet /qn /norestart' }
    }
    Write-Host "Desinstalando: $($app.DisplayName)..." -f Cyan
    Start-Process cmd.exe "/c $cmd" -Wait -WindowStyle Hidden
}

function Install-PackageSilent {
    [CmdletBinding()]param(
        [Parameter(Mandatory)][string]$Path,
        [string]$SilentArgs # opcional para EXE no estándar
    )
    if (-not (Test-Path $Path)) { throw "No existe $Path" }
    $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($ext -eq '.msi') {
        Start-Process msiexec.exe "/i `"$Path`" /qn /norestart" -Wait -WindowStyle Hidden
    } else {
        $args = $SilentArgs
        if (-not $args) { $args = '/S /quiet /qn /norestart' }
        Start-Process $Path $args -Wait -WindowStyle Hidden
    }
}

<# Ejemplos:
Uninstall-ByName -NameLike "7-Zip" -Quiet
Install-PackageSilent -Path "\\servidor\software\7zip\7z2301-x64.msi"
Install-PackageSilent -Path "\\ruta\app.exe" -SilentArgs "/VERYSILENT /NORESTART"
#>
