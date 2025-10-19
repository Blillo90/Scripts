# 08_clear_eventlogs.ps1 — Limpieza/rotación de registros de eventos
# Ejecutar como Administrador
[CmdletBinding()]
param(
    [switch]$Backup,                   # Exporta .evtx antes de limpiar
    [string]$BackupPath = "C:\EventLogBackups",
    [switch]$OnlyOperational           # Solo 'Application','System','Security','Setup'
)

function Require-Admin {
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    $p=New-Object Security.Principal.WindowsPrincipal($id)
    if (!$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Este script debe ejecutarse como Administrador."
    }
}
Require-Admin

$logs = wevtutil el
if ($OnlyOperational) {
    $logs = @('Application','System','Security','Setup')
}

if ($Backup) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $dest = Join-Path $BackupPath ("EventLogs_"+$stamp)
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
}

foreach ($log in $logs) {
    try {
        if ($Backup) {
            $file = Join-Path $dest ($log + ".evtx")
            wevtutil epl "$log" "$file"
            Write-Host "Backup -> $log -> $file" -ForegroundColor DarkGray
        }
        wevtutil cl "$log"
        Write-Host "Limpiado: $log" -ForegroundColor Green
    } catch {
        Write-Warning "No se pudo limpiar '$log' : $($_.Exception.Message)"
    }
}

Write-Host "Hecho." -ForegroundColor Yellow
