# 00_launcher.ps1 - Menú de utilidades Service Desk
# Ejecutar como Administrador
$ErrorActionPreference = 'SilentlyContinue'
function Title($t){ Write-Host "`n=== $t ===`n" -ForegroundColor Cyan }

$base = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $base

# ==== Comprobación inicial de ExecutionPolicy ====
Write-Host "Comprobando ExecutionPolicy..." -ForegroundColor Cyan
try {
    $pols = Get-ExecutionPolicy -List | Format-Table -AutoSize | Out-String
    Write-Host $pols
} catch {
    Write-Host "No se pudo consultar ExecutionPolicy: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "Opciones de ExecutionPolicy:" -ForegroundColor Green
Write-Host "  1) Establecer 'Bypass' SOLO para esta sesión (Scope=Process) — recomendado"
Write-Host "  2) Establecer 'RemoteSigned' para el usuario actual (Scope=CurrentUser)"
Write-Host "  3) No cambiar nada"
$epChoice = Read-Host "Elige (1/2/3). Por defecto 1"

switch ($epChoice) {
    '2' {
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
            Write-Host "ExecutionPolicy (CurrentUser) cambiado a RemoteSigned." -ForegroundColor Yellow
        } catch {
            Write-Warning "No se pudo cambiar CurrentUser: $($_.Exception.Message)"
        }
    }
    '3' { Write-Host "Sin cambios en ExecutionPolicy." -ForegroundColor DarkGray }
    Default {
        try {
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction Stop
            Write-Host "ExecutionPolicy (Process) establecido a Bypass para esta sesión." -ForegroundColor Yellow
        } catch {
            Write-Warning "No se pudo establecer Bypass en Process: $($_.Exception.Message)"
        }
    }
}
# ==== Fin comprobación ExecutionPolicy ====



function Pause(){ Write-Host ; Read-Host "Pulsa ENTER para continuar..." | Out-Null }

while ($true) {
    Clear-Host
    Write-Host "Service Desk Toolkit — Launcher" -ForegroundColor Green
    Write-Host "1) Limpieza segura (temporales/cachés)"
    Write-Host "2) Desinstalar/Reinstalar silencioso"
    Write-Host "3) Cisco Secure Client — fix rápido / hard reset"
    Write-Host "4) Reset de Dock (HP/DisplayLink/Thunderbolt)"
    Write-Host "5) MECM/SCCM — ciclo post bare-metal (Software Center)"
    Write-Host "6) Diagnóstico rápido de equipo lento"
    Write-Host "7) Purgar registros residuales de una app"
    
    Write-Host "8) Limpiar/respaldar registros de eventos (Event Viewer)"
    Write-Host "9) Limpieza Office/Teams y reparación Office"
    Write-Host "10) Reset de OneDrive"
    Write-Host "11) Reparación de WMI"

    Write-Host "0) Salir"
    $opt = Read-Host "Elige opción"

    switch ($opt) {
        '1' {
            Title "Limpieza segura"
            $deep = Read-Host "¿Limpieza profunda (+WU/Prefetch)? (S/N)"
            $brow = Read-Host "¿Incluir cachés de navegadores? (S/N)"
            $allp = Read-Host "¿Todos los perfiles de usuario? (S/N)"
            $args = @()
            if ($deep -match '^[sS]') { $args += '-Deep' }
            if ($brow -match '^[sS]') { $args += '-BrowserCaches' }
            if ($allp -match '^[sS]') { $args += '-AllProfiles' }
            & powershell -ExecutionPolicy Bypass -File ".\01_cleanup.ps1" @args
            Pause
        }
        '2' {
            Title "Desinstalar/Reinstalar"
            $name = Read-Host "Nombre parecido de la aplicación a desinstalar (DisplayName)"
            if ($name) {
                & powershell -ExecutionPolicy Bypass -File ".\02_install_uninstall.ps1" -Command "Uninstall-ByName -NameLike `"$name`" -Quiet"
            }
            $inst = Read-Host "Ruta completa del instalador (MSI/EXE) o ENTER para omitir"
            if ($inst) {
                $silent = Read-Host "Parámetros silenciosos extra (ENTER para auto)"
                if ($silent) {
                    & powershell -ExecutionPolicy Bypass -File ".\02_install_uninstall.ps1" -Command "Install-PackageSilent -Path `"$inst`" -SilentArgs `"$silent`""
                } else {
                    & powershell -ExecutionPolicy Bypass -File ".\02_install_uninstall.ps1" -Command "Install-PackageSilent -Path `"$inst`""
                }
            }
            Pause
        }
        '3' {
            Title "Cisco Secure Client"
            $hard = Read-Host "¿Hard reset (Winsock/TCP-IP + perfiles)? (S/N)"
            $args = @()
            if ($hard -match '^[sS]') {
                $prof = Read-Host "Ruta del perfil corporativo XML (ENTER si no)"
                if ($prof) { $args += @('-HardReset','-ProfileSource',"$prof") } else { $args += '-HardReset' }
            }
            & powershell -ExecutionPolicy Bypass -File ".\03_fix_cisco_secure_client.ps1" @args
            Pause
        }
        '4' {
            Title "Reset Dock"
            $dl = Read-Host "¿Incluir DisplayLink? (S/N)"
            $uh = Read-Host "¿Reset USB Root Hubs? (S/N)"
            $dn = Read-Host "¿Reset NICs del dock? (S/N)"
            $args = @()
            if ($dl -match '^[sS]') { $args += '-TryDisplayLink' }
            if ($uh -match '^[sS]') { $args += '-ResetUSBHubs' }
            if ($dn -match '^[sS]') { $args += '-ResetDockNICs' }
            & powershell -ExecutionPolicy Bypass -File ".\04_reset_dock.ps1" @args
            Pause
        }
        '5' {
            Title "MECM/SCCM — kick Software Center"
            $purge = Read-Host "¿Vaciar ccmcache? (S/N)"
            $sec = Read-Host "Segundos de espera entre ciclos (por defecto 20)"
            $args = @()
            if ($purge -match '^[sS]') { $args += '-PurgeCcmCache' }
            if ($sec -match '^\d+$') { $args += @('-PolicyWaitSeconds', $sec) }
            & powershell -ExecutionPolicy Bypass -File ".\05_mecm_softwarecenter_kick.ps1" @args
            Pause
        }
        '6' {
            Title "Diagnóstico rápido"
            & powershell -ExecutionPolicy Bypass -File ".\06_quick_diag.ps1"
            Pause
        }
        '7' {
            Title "Purgar registros residuales"
            $app = Read-Host "Nombre de la aplicación (ej. 'Cisco', '7-Zip')"
            $incSrv = Read-Host "¿Incluir claves de servicios? (S/N)"
            $hkcu = Read-Host "¿Incluir HKCU del usuario actual? (S/N)"
            $simu = Read-Host "¿Modo simulación (no borra, solo muestra y exporta)? (S/N)"
            $args = @()
            if ($app){ $args += @('-AppName', $app) }
            if ($incSrv -match '^[sS]') { $args += '-IncludeServices' }
            if ($hkcu  -match '^[sS]') { $args += '-AlsoCurrentUser' }
            if ($simu  -match '^[sS]') { $args += '-WhatIfOnly' }
            & powershell -ExecutionPolicy Bypass -File ".\07_purge_app_registry.ps1" @args
            Pause
        }
        '0' { break }
        
        '8' {
            Title "Event Logs — limpiar/respaldar"
            $bkp = Read-Host "¿Hacer backup .evtx antes? (S/N)"
            $only = Read-Host "¿Solo Application/System/Security/Setup? (S/N)"
            $args = @()
            if ($bkp -match '^[sS]') { $args += '-Backup' }
            if ($only -match '^[sS]') { $args += '-OnlyOperational' }
            & powershell -ExecutionPolicy Bypass -File ".\08_clear_eventlogs.ps1" @args
            Pause
        }
        '9' {
            Title "Office/Teams — limpieza y reparación"
            $teamsOnly = Read-Host "¿Solo limpiar Teams (sin reparar Office)? (S/N)"
            $quick = Read-Host "¿Hacer Quick Repair de Office? (S/N)"
            $online = Read-Host "¿Hacer Online Repair de Office (lento)? (S/N)"
            $args = @()
            if ($teamsOnly -match '^[sS]') { $args += '-TeamsOnly' }
            if ($quick -match '^[sS]') { $args += '-OfficeQuickRepair' }
            if ($online -match '^[sS]') { $args += '-OfficeOnlineRepair' }
            & powershell -ExecutionPolicy Bypass -File ".\09_office_teams_cleanup.ps1" @args
            Pause
        }
        '10' {
            Title "OneDrive — reset"
            $full = Read-Host "¿Limpieza completa adicional (logs/cache)? (S/N)"
            $pm = Read-Host "¿OneDrive per-machine (en Program Files)? (S/N)"
            $args = @()
            if ($full -match '^[sS]') { $args += '-Full' }
            if ($pm -match '^[sS]') { $args += '-PerMachine' }
            & powershell -ExecutionPolicy Bypass -File ".\10_onedrive_reset.ps1" @args
            Pause
        }
        '11' {
            Title "WMI — reparación"
            $salv = Read-Host "¿Solo Salvage (recomendado)? (S/N)"
            $force = Read-Host "¿Forzar Reset agresivo (bajo tu responsabilidad)? (S/N)"
            $args = @()
            if ($salv -match '^[sS]') { $args += '-SalvageOnly' }
            if ($force -match '^[sS]') { $args += '-ForceReset' }
            & powershell -ExecutionPolicy Bypass -File ".\11_repair_wmi.ps1" @args
            Pause
        }
default { }
    }
}
