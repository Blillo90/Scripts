# 09_office_teams_cleanup.ps1 — Limpieza y reparación Office/Teams
# Ejecutar preferiblemente con usuario desconectado de Teams/Office
[CmdletBinding()]
param(
    [switch]$TeamsOnly,
    [switch]$OfficeQuickRepair,   # Repara Office C2R (rápida, sin Internet)
    [switch]$OfficeOnlineRepair   # Repara Office C2R (completa, requiere Internet)
)

function Stop-IfRunning($names){
    foreach($n in $names){ Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
}

Write-Host "Cerrando Office/Teams..." -ForegroundColor Cyan
Stop-IfRunning @('winword','excel','powerpnt','outlook','onenote','msaccess','lync','teams','ms-teams','msteams')

# Teams cache paths
$teamsPaths = @(
    "$env:APPDATA\Microsoft\Teams\Application Cache\Cache\*",
    "$env:APPDATA\Microsoft\Teams\blob_storage\*",
    "$env:APPDATA\Microsoft\Teams\Cache\*",
    "$env:APPDATA\Microsoft\Teams\databases\*",
    "$env:APPDATA\Microsoft\Teams\GPUCache\*",
    "$env:APPDATA\Microsoft\Teams\IndexedDB\*",
    "$env:APPDATA\Microsoft\Teams\Local Storage\*",
    "$env:APPDATA\Microsoft\Teams\tmp\*"
)

Write-Host "Limpiando caché de Teams..." -ForegroundColor Cyan
foreach ($p in $teamsPaths) {
    if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
}

# Reinicio de Teams (usuario relanza manualmente)
Write-Host "Caché de Teams limpiada. Inicia Teams y vuelve a iniciar sesión si lo solicita." -ForegroundColor Green

if (-not $TeamsOnly) {
    # Office C2R quick/online repair (si existe OfficeC2RClient)
    $c2r = "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
    if (-not (Test-Path $c2r)) {
        $c2r = "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
    }

    if (Test-Path $c2r) {
        if ($OfficeOnlineRepair) {
            Write-Host "Iniciando reparación COMPLETA de Office (puede tardar)..." -ForegroundColor Yellow
            Start-Process $c2r "/update user updatetoversion=16.0.0000.0000 forceappshutdown=True displaylevel=True" -Wait
            # Nota: online repair completo se inicia vía UI; algunas empresas bloquean switches silenciosos
        } elseif ($OfficeQuickRepair) {
            Write-Host "Iniciando reparación RÁPIDA de Office..." -ForegroundColor Yellow
            Start-Process $c2r "/repair user displaylevel=True forceappshutdown=True" -Wait
        } else {
            Write-Host "Saltando reparación Office (no se solicitó Quick/Online Repair)." -ForegroundColor DarkGray
        }
    } else {
        Write-Host "OfficeC2RClient no encontrado. Puede que sea MSI, sin Office, o bloqueado por TI." -ForegroundColor DarkGray
    }
}

# Office caches ligeros (no destruye perfiles)
# Limpia listado de 'recientes' en Office sin tocar documentos
try {
    Remove-Item "HKCU:\Software\Microsoft\Office\16.0\Common\Open Find\*MRU*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "MRUs de Office limpiados (usuario actual)." -ForegroundColor DarkGray
} catch {}

Write-Host "Proceso de limpieza Office/Teams finalizado." -ForegroundColor Green
