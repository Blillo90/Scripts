# 10_onedrive_reset.ps1 — Reset de OneDrive del usuario actual
[CmdletBinding()]
param(
    [switch]$Full,    # También borra cachés locales y re-registra shell extension
    [switch]$PerMachine # OneDrive instalado por máquina
)

function Stop-IfRunning($names){
    foreach($n in $names){ Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
}

Write-Host "Cerrando OneDrive..." -ForegroundColor Cyan
Stop-IfRunning @('OneDrive','FileCoAuth')

$pathCandidates = @()
if ($PerMachine) {
    $pathCandidates += "C:\Program Files\Microsoft OneDrive\OneDrive.exe"
} else {
    $pathCandidates += "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
    $pathCandidates += "C:\Program Files\Microsoft OneDrive\OneDrive.exe"
}

$exe = $pathCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $exe) { Write-Warning "No se encontró OneDrive.exe"; exit 1 }

Write-Host "Reseteando OneDrive..." -ForegroundColor Yellow
Start-Process $exe "/reset" -Wait

Start-Sleep -Seconds 5
Write-Host "Iniciando OneDrive..." -ForegroundColor Cyan
Start-Process $exe

if ($Full) {
    Write-Host "Limpieza adicional de cachés..." -ForegroundColor Cyan
    $paths = @(
        "$env:LOCALAPPDATA\Microsoft\OneDrive\settings\Business1.adml",
        "$env:LOCALAPPDATA\Microsoft\OneDrive\logs\*",
        "$env:LOCALAPPDATA\Microsoft\Office\16.0\FileCache\*"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Write-Host "Hecho. Es posible que OneDrive tarde en reindexar/reenlazar." -ForegroundColor DarkGray
}

Write-Host "Reset de OneDrive completado." -ForegroundColor Green
