# 00_unified_launcher.ps1 — Unified Service Desk Toolkit (Básico / Avanzado)
# Ejecutar como Administrador
$ErrorActionPreference = 'SilentlyContinue'
function Title($t){ Write-Host "`n=== $t ===`n" -ForegroundColor Cyan }
function Pause(){ Write-Host ; Read-Host "Pulsa ENTER para continuar..." | Out-Null }

# Logging
$logFolder = "C:\SDToolLogs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$comp = $env:COMPUTERNAME
$user = $env:USERNAME
$logFile = Join-Path $logFolder ("UnifiedToolkit_" + $stamp + "_" + $comp + "_" + $user + ".txt")
try { Start-Transcript -Path $logFile -Force } catch {}

# Set working dir
$base = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $base

# ExecutionPolicy helper
Write-Host "Comprobando ExecutionPolicy..." -ForegroundColor Cyan
try { Get-ExecutionPolicy -List | Format-Table -AutoSize | Out-Host } catch {}
try { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force } catch {}

function Menu-Basico {
    while ($true) {
        Clear-Host
        Write-Host "== MENÚ BÁSICO (L2 Windows & Office) ==" -ForegroundColor Green
        Write-Host "1) Diagnóstico rápido (CPU/RAM/Disco/Top procesos)"
        Write-Host "2) Limpieza temporales y cachés (usuario)"
        Write-Host "3) Reparación Office (Quick / Online)"
        Write-Host "4) Limpiar caché de Teams"
        Write-Host "5) Reset OneDrive (usuario)"
        Write-Host "6) SFC /scannow + DISM RestoreHealth"
        Write-Host \"7) PERFILAZO — guardar datos y borrar perfil\"
        Write-Host \"8) Volver al menú principal\"
        $opt = Read-Host "Elige opción"

        switch ($opt) {
            '1' { Title "Diagnóstico rápido"; & powershell -ExecutionPolicy Bypass -File ".\06_quick_diag.ps1"; Pause }
            '2' { Title "Limpieza temporales"; 
                  $deep=Read-Host "¿Profunda (+WU/Prefetch)? (S/N)"; $brow=Read-Host "¿Cachés navegadores? (S/N)";
                  $args=@(); if($deep -match '^[sS]'){$args+='-Deep'}; if($brow -match '^[sS]'){$args+='-BrowserCaches'};
                  & powershell -ExecutionPolicy Bypass -File ".\01_cleanup.ps1" @args; Pause }
            '3' { Title "Reparación Office"; 
                  $quick=Read-Host "Quick Repair? (S/N)"; $online=Read-Host "Online Repair? (S/N)";
                  $args=@(); if($quick -match '^[sS]'){$args+='-OfficeQuickRepair'}; if($online -match '^[sS]'){$args+='-OfficeOnlineRepair'};
                  & powershell -ExecutionPolicy Bypass -File ".\09_office_teams_cleanup.ps1" @args; Pause }
            '4' { Title "Teams cache"; & powershell -ExecutionPolicy Bypass -File ".\09_office_teams_cleanup.ps1" -TeamsOnly; Pause }
            '5' { Title "OneDrive reset"; $full=Read-Host "¿Limpieza completa adicional? (S/N)"; $args=@(); if($full -match '^[sS]'){$args+='-Full'}; & powershell -ExecutionPolicy Bypass -File ".\10_onedrive_reset.ps1" @args; Pause }
            '6' { Title "SFC + DISM"; Start-Process DISM.exe "/Online /Cleanup-Image /RestoreHealth" -Wait -NoNewWindow; Start-Process sfc.exe "/scannow" -Wait -NoNewWindow; Pause }
            '8' { break }
            
            '7' {
                Title "PERFILAZO — copia y borrado de perfil"
                Write-Host "Este proceso:" -ForegroundColor Yellow
                Write-Host " - Copia Contacts, Documents, Desktop, Favorites, Pictures y Chrome (AppData) a C:\Shared\<usuario>_<fecha>." -ForegroundColor DarkGray
                Write-Host " - Requiere que el usuario objetivo NO esté logueado." -ForegroundColor DarkGray
                Write-Host " - Después, borra el perfil usando WMI (con fallback de carpeta si falla)." -ForegroundColor DarkGray
                $user = Read-Host "Nombre de usuario del perfil a tratar (ej. jlopez)"
                $c1 = Read-Host "CONFIRMACIÓN 1: ¿Proceder con la copia para '$user'? (S/N)"
                if ($c1 -notmatch '^[sS]') { Write-Host "Cancelado." -ForegroundColor Yellow; Pause; break }
                $c2 = Read-Host "CONFIRMACIÓN 2: ¿Borrar el perfil de '$user' tras la copia? (S/N)"
                if ($c2 -notmatch '^[sS]') { Write-Host "Se hará SOLO la copia, sin borrado." -ForegroundColor Yellow }
                $args = @()
                if ($user) { $args += @('-UserName', $user) }
                & powershell -ExecutionPolicy Bypass -File ".\12_perfilazo.ps1" @args
                Write-Host "`n--- RESUMEN ---" -ForegroundColor Cyan
                Write-Host "Copia en C:\Shared\<usuario>_<fecha>. Consulta el transcript en C:\SDToolLogs\UnifiedToolkit_*.txt" -ForegroundColor DarkGray
                Pause
            }

        default {}
        }
    }
}


function Menu-Avanzado {
    while ($true) {
        Clear-Host
        Write-Host "== MENÚ AVANZADO (casos puntuales) ==" -ForegroundColor Yellow
        Write-Host "1) Cisco Secure Client — fix rápido / hard reset"
        Write-Host "2) Reset Dock (HP/DisplayLink/Thunderbolt)"
        Write-Host "3) MECM/SCCM — ciclo post bare-metal (Software Center)"
        Write-Host "4) Purgar registros residuales de una app (con backup .reg)"
        Write-Host "5) Reparar WMI (Salvage / Reset agresivo)"
        Write-Host "6) Limpiar/respaldar Event Logs"
        Write-Host "7) Volver al menú principal"
        $opt = Read-Host "Elige opción"

        switch ($opt) {
            '1' { Title "Cisco Secure Client"
                  $hard=Read-Host "¿Hard reset (Winsock/TCP-IP + perfiles)? (S/N)"
                  $args=@(); if($hard -match '^[sS]'){ $prof=Read-Host "Ruta perfil XML (ENTER si no)"; if($prof){$args+=@('-HardReset','-ProfileSource',"$prof")} else {$args+='-HardReset'} }
                  & powershell -ExecutionPolicy Bypass -File ".\03_fix_cisco_secure_client.ps1" @args; Pause }
            '2' { Title "Reset Dock"
                  $dl=Read-Host "¿Incluir DisplayLink? (S/N)"; $uh=Read-Host "¿Reset USB Root Hubs? (S/N)"; $dn=Read-Host "¿Reset NICs del dock? (S/N)"
                  $args=@(); if($dl -match '^[sS]'){$args+='-TryDisplayLink'}; if($uh -match '^[sS]'){$args+='-ResetUSBHubs'}; if($dn -match '^[sS]'){$args+='-ResetDockNICs'}
                  & powershell -ExecutionPolicy Bypass -File ".\04_reset_dock.ps1" @args; Pause }
            '3' { Title "MECM/SCCM — kick"
                  $purge=Read-Host "¿Vaciar ccmcache? (S/N)"; $sec=Read-Host "Segundos entre ciclos (20 por defecto)"
                  $args=@(); if($purge -match '^[sS]'){$args+='-PurgeCcmCache'}; if($sec -match '^\d+$'){$args+=@('-PolicyWaitSeconds',$sec)}
                  & powershell -ExecutionPolicy Bypass -File ".\05_mecm_softwarecenter_kick.ps1" @args; Pause }
            '4' { 
                  Title "Purgar registros residuales (con backup)"
                  Write-Host "Este proceso:" -ForegroundColor Yellow
                  Write-Host " - Busca claves relacionadas en: Uninstall (HKLM/HKCU 32/64), SOFTWARE (HKLM/HKCU), App Paths, y opcionalmente Services." -ForegroundColor DarkGray
                  Write-Host " - Exporta CADA clave encontrada a .reg dentro de C:\RegBackups\<carpeta_fecha>." -ForegroundColor DarkGray
                  Write-Host " - Elimina las claves exportadas (si no eliges modo simulación)." -ForegroundColor DarkGray
                  $app=Read-Host "Nombre de la app"
                  $incSrv=Read-Host "¿Incluir servicios (HKLM\\SYSTEM\\...\\Services)? (S/N)"
                  $hkcu=Read-Host "¿Incluir HKCU del usuario actual? (S/N)"
                  $simu=Read-Host "¿Simulación (no borra, solo muestra y exporta)? (S/N)"
                  Write-Host ""
                  $c1 = Read-Host "CONFIRMACIÓN 1: ¿Deseas continuar con la purga de '$app'? (S/N)"
                  if ($c1 -notmatch '^[sS]') { Write-Host "Cancelado." -ForegroundColor Yellow; Pause; break }
                  $c2 = Read-Host "CONFIRMACIÓN 2: Esto eliminará claves del Registro (con backup). ¿Continuar? (S/N)"
                  if ($c2 -notmatch '^[sS]') { Write-Host "Cancelado." -ForegroundColor Yellow; Pause; break }

                  $args=@(); if($app){$args+=@('-AppName',$app)}; if($incSrv -match '^[sS]'){$args+='-IncludeServices'}; if($hkcu -match '^[sS]'){$args+='-AlsoCurrentUser'}; if($simu -match '^[sS]'){$args+='-WhatIfOnly'}
                  & powershell -ExecutionPolicy Bypass -File ".\07_purge_app_registry.ps1" @args

                  Write-Host "`n--- RESUMEN ---" -ForegroundColor Cyan
                  Write-Host "Copia de seguridad (si se realizó): C:\RegBackups" -ForegroundColor DarkGray
                  if (Test-Path "C:\RegBackups") {
                      Write-Host "Contenido de C:\RegBackups (2 niveles):" -ForegroundColor DarkGray
                      Get-ChildItem "C:\RegBackups" -Recurse -Depth 2 | Select-Object FullName,Length,LastWriteTime | Format-Table -AutoSize
                  } else {
                      Write-Host "No se encontró C:\RegBackups (posible modo simulación o sin hallazgos)." -ForegroundColor DarkGray
                  }
                  Write-Host "Consulta detallada en el transcript: C:\SDToolLogs\UnifiedToolkit_*.txt" -ForegroundColor DarkGray
                  Pause 
            }
            '5' { 
                  Title "WMI Repair"
                  $salv=Read-Host "¿Solo Salvage (recomendado)? (S/N)"
                  $force=Read-Host "¿Force Reset agresivo? (S/N)"
                  if ($force -match '^[sS]') {
                      Write-Host "Este proceso AGRESIVO:" -ForegroundColor Yellow
                      Write-Host " - Detiene WMI, hace copia del repositorio (\\Windows\\System32\\wbem\\Repository -> *.bak_YYYYMMDD_HHMMSS)" -ForegroundColor DarkGray
                      Write-Host " - Ejecuta winmgmt /resetrepository y re-registra DLLs + recompila MOFs." -ForegroundColor DarkGray
                      Write-Host " - Reinicia WMI y verifica consulta básica." -ForegroundColor DarkGray
                      $c1 = Read-Host "CONFIRMACIÓN 1: ¿Continuar con WMI Reset agresivo? (S/N)"
                      if ($c1 -notmatch '^[sS]') { Write-Host "Cancelado." -ForegroundColor Yellow; Pause; break }
                      $c2 = Read-Host "CONFIRMACIÓN 2: Entiendo el impacto y que requiere permisos de admin. ¿Continuar? (S/N)"
                      if ($c2 -notmatch '^[sS]') { Write-Host "Cancelado." -ForegroundColor Yellow; Pause; break }
                  }

                  $args=@(); if($salv -match '^[sS]'){$args+='-SalvageOnly'}; if($force -match '^[sS]'){$args+='-ForceReset'}
                  & powershell -ExecutionPolicy Bypass -File ".\11_repair_wmi.ps1" @args

                  Write-Host "`n--- RESUMEN ---" -ForegroundColor Cyan
                  $wbem = "$env:WINDIR\System32\wbem"
                  Write-Host "Listado de $wbem y posibles copias Repository.bak_*:" -ForegroundColor DarkGray
                  Get-ChildItem $wbem -Force | Where-Object { $_.Name -like 'Repository*' } | Select-Object Name,Length,LastWriteTime | Format-Table -AutoSize
                  Pause
            }
            '6' { 
                  Title "Event Logs"
                  $bkp=Read-Host "¿Backup .evtx antes? (S/N)"
                  $only=Read-Host "¿Solo Application/System/Security/Setup? (S/N)"
                  if ($bkp -match '^[sS]') {
                      Write-Host "Este proceso:" -ForegroundColor Yellow
                      Write-Host " - Exporta los registros seleccionados a .evtx en C:\EventLogBackups\EventLogs_YYYYMMDD_HHMMSS" -ForegroundColor DarkGray
                      Write-Host " - Limpia el contenido de esos registros con wevtutil cl <log>" -ForegroundColor DarkGray
                      $c1 = Read-Host "CONFIRMACIÓN 1: ¿Continuar con backup y limpieza de Event Logs? (S/N)"
                      if ($c1 -notmatch '^[sS]') { Write-Host "Cancelado." -ForegroundColor Yellow; Pause; break }
                      $c2 = Read-Host "CONFIRMACIÓN 2: Esto vaciará registros del Visor de eventos. ¿Continuar? (S/N)"
                      if ($c2 -notmatch '^[sS]') { Write-Host "Cancelado." -ForegroundColor Yellow; Pause; break }
                  }

                  $args=@(); if($bkp -match '^[sS]'){$args+='-Backup'}; if($only -match '^[sS]'){$args+='-OnlyOperational'}
                  & powershell -ExecutionPolicy Bypass -File ".\08_clear_eventlogs.ps1" @args

                  Write-Host "`n--- RESUMEN ---" -ForegroundColor Cyan
                  if (Test-Path "C:\EventLogBackups") {
                      Write-Host "Contenido de C:\EventLogBackups (2 niveles):" -ForegroundColor DarkGray
                      Get-ChildItem "C:\EventLogBackups" -Recurse -Depth 2 | Select-Object FullName,Length,LastWriteTime | Format-Table -AutoSize
                  } else {
                      Write-Host "No hay carpeta de backups de Event Logs (no se hizo backup)." -ForegroundColor DarkGray
                  }
                  Write-Host "Estado actual de los logs: listado de nombres disponibles" -ForegroundColor DarkGray
                  wevtutil el | Sort-Object | Select-Object -First 50 | Format-Table -AutoSize
                  Pause
            }
            '8' { break }
            
            '7' {
                Title "PERFILAZO — copia y borrado de perfil"
                Write-Host "Este proceso:" -ForegroundColor Yellow
                Write-Host " - Copia Contacts, Documents, Desktop, Favorites, Pictures y Chrome (AppData) a C:\Shared\<usuario>_<fecha>." -ForegroundColor DarkGray
                Write-Host " - Requiere que el usuario objetivo NO esté logueado." -ForegroundColor DarkGray
                Write-Host " - Después, borra el perfil usando WMI (con fallback de carpeta si falla)." -ForegroundColor DarkGray
                $user = Read-Host "Nombre de usuario del perfil a tratar (ej. jlopez)"
                $c1 = Read-Host "CONFIRMACIÓN 1: ¿Proceder con la copia para '$user'? (S/N)"
                if ($c1 -notmatch '^[sS]') { Write-Host "Cancelado." -ForegroundColor Yellow; Pause; break }
                $c2 = Read-Host "CONFIRMACIÓN 2: ¿Borrar el perfil de '$user' tras la copia? (S/N)"
                if ($c2 -notmatch '^[sS]') { Write-Host "Se hará SOLO la copia, sin borrado." -ForegroundColor Yellow }
                $args = @()
                if ($user) { $args += @('-UserName', $user) }
                & powershell -ExecutionPolicy Bypass -File ".\12_perfilazo.ps1" @args
                Write-Host "`n--- RESUMEN ---" -ForegroundColor Cyan
                Write-Host "Copia en C:\Shared\<usuario>_<fecha>. Consulta el transcript en C:\SDToolLogs\UnifiedToolkit_*.txt" -ForegroundColor DarkGray
                Pause
            }

        default {}
        }
    }
}

while ($true) {
        Clear-Host
        Write-Host "== MENÚ AVANZADO (casos puntuales) ==" -ForegroundColor Yellow
        Write-Host "1) Cisco Secure Client — fix rápido / hard reset"
        Write-Host "2) Reset Dock (HP/DisplayLink/Thunderbolt)"
        Write-Host "3) MECM/SCCM — ciclo post bare-metal (Software Center)"
        Write-Host "4) Purgar registros residuales de una app (con backup .reg)"
        Write-Host "5) Reparar WMI (Salvage / Reset agresivo)"
        Write-Host "6) Limpiar/respaldar Event Logs"
        Write-Host "7) Volver al menú principal"
        $opt = Read-Host "Elige opción"

        switch ($opt) {
            '1' { Title "Cisco Secure Client"
                  $hard=Read-Host "¿Hard reset (Winsock/TCP-IP + perfiles)? (S/N)"
                  $args=@(); if($hard -match '^[sS]'){ $prof=Read-Host "Ruta perfil XML (ENTER si no)"; if($prof){$args+=@('-HardReset','-ProfileSource',"$prof")} else {$args+='-HardReset'} }
                  & powershell -ExecutionPolicy Bypass -File ".\03_fix_cisco_secure_client.ps1" @args; Pause }
            '2' { Title "Reset Dock"
                  $dl=Read-Host "¿Incluir DisplayLink? (S/N)"; $uh=Read-Host "¿Reset USB Root Hubs? (S/N)"; $dn=Read-Host "¿Reset NICs del dock? (S/N)"
                  $args=@(); if($dl -match '^[sS]'){$args+='-TryDisplayLink'}; if($uh -match '^[sS]'){$args+='-ResetUSBHubs'}; if($dn -match '^[sS]'){$args+='-ResetDockNICs'}
                  & powershell -ExecutionPolicy Bypass -File ".\04_reset_dock.ps1" @args; Pause }
            '3' { Title "MECM/SCCM — kick"
                  $purge=Read-Host "¿Vaciar ccmcache? (S/N)"; $sec=Read-Host "Segundos entre ciclos (20 por defecto)"
                  $args=@(); if($purge -match '^[sS]'){$args+='-PurgeCcmCache'}; if($sec -match '^\d+$'){$args+=@('-PolicyWaitSeconds',$sec)}
                  & powershell -ExecutionPolicy Bypass -File ".\05_mecm_softwarecenter_kick.ps1" @args; Pause }
            '4' { Title "Purgar registros residuales (con backup)"
                  $app=Read-Host "Nombre de la app"; $incSrv=Read-Host "¿Incluir servicios? (S/N)"; $hkcu=Read-Host "¿Incluir HKCU? (S/N)"; $simu=Read-Host "¿Simulación (no borra)? (S/N)"
                  $args=@(); if($app){$args+=@('-AppName',$app)}; if($incSrv -match '^[sS]'){$args+='-IncludeServices'}; if($hkcu -match '^[sS]'){$args+='-AlsoCurrentUser'}; if($simu -match '^[sS]'){$args+='-WhatIfOnly'}
                  & powershell -ExecutionPolicy Bypass -File ".\07_purge_app_registry.ps1" @args; Pause }
            '5' { Title "WMI Repair"
                  $salv=Read-Host "¿Solo Salvage? (S/N)"; $force=Read-Host "¿Force Reset agresivo? (S/N)"
                  $args=@(); if($salv -match '^[sS]'){$args+='-SalvageOnly'}; if($force -match '^[sS]'){$args+='-ForceReset'}
                  & powershell -ExecutionPolicy Bypass -File ".\11_repair_wmi.ps1" @args; Pause }
            '6' { Title "Event Logs"
                  $bkp=Read-Host "¿Backup .evtx antes? (S/N)"; $only=Read-Host "¿Solo Application/System/Security/Setup? (S/N)"
                  $args=@(); if($bkp -match '^[sS]'){$args+='-Backup'}; if($only -match '^[sS]'){$args+='-OnlyOperational'}
                  & powershell -ExecutionPolicy Bypass -File ".\08_clear_eventlogs.ps1" @args; Pause }
            '8' { break }
            
            '7' {
                Title "PERFILAZO — copia y borrado de perfil"
                Write-Host "Este proceso:" -ForegroundColor Yellow
                Write-Host " - Copia Contacts, Documents, Desktop, Favorites, Pictures y Chrome (AppData) a C:\Shared\<usuario>_<fecha>." -ForegroundColor DarkGray
                Write-Host " - Requiere que el usuario objetivo NO esté logueado." -ForegroundColor DarkGray
                Write-Host " - Después, borra el perfil usando WMI (con fallback de carpeta si falla)." -ForegroundColor DarkGray
                $user = Read-Host "Nombre de usuario del perfil a tratar (ej. jlopez)"
                $c1 = Read-Host "CONFIRMACIÓN 1: ¿Proceder con la copia para '$user'? (S/N)"
                if ($c1 -notmatch '^[sS]') { Write-Host "Cancelado." -ForegroundColor Yellow; Pause; break }
                $c2 = Read-Host "CONFIRMACIÓN 2: ¿Borrar el perfil de '$user' tras la copia? (S/N)"
                if ($c2 -notmatch '^[sS]') { Write-Host "Se hará SOLO la copia, sin borrado." -ForegroundColor Yellow }
                $args = @()
                if ($user) { $args += @('-UserName', $user) }
                & powershell -ExecutionPolicy Bypass -File ".\12_perfilazo.ps1" @args
                Write-Host "`n--- RESUMEN ---" -ForegroundColor Cyan
                Write-Host "Copia en C:\Shared\<usuario>_<fecha>. Consulta el transcript en C:\SDToolLogs\UnifiedToolkit_*.txt" -ForegroundColor DarkGray
                Pause
            }

        default {}
        }
    }
}

while ($true) {
    Clear-Host
    Write-Host "UNIFIED SERVICE DESK TOOLKIT" -ForegroundColor Magenta
    Write-Host "1) Menú BÁSICO (Windows & Office)"
    Write-Host "2) Menú AVANZADO (VPN/Docks/SCCM/Registro/WMI/EventLogs)"
    Write-Host "0) Salir"
    $ch = Read-Host "Elige"

    switch ($ch) {
        '1' { Menu-Basico }
        '2' { Menu-Avanzado }
        '0' { try { Stop-Transcript } catch {}; break }
        
            '7' {
                Title "PERFILAZO — copia y borrado de perfil"
                Write-Host "Este proceso:" -ForegroundColor Yellow
                Write-Host " - Copia Contacts, Documents, Desktop, Favorites, Pictures y Chrome (AppData) a C:\Shared\<usuario>_<fecha>." -ForegroundColor DarkGray
                Write-Host " - Requiere que el usuario objetivo NO esté logueado." -ForegroundColor DarkGray
                Write-Host " - Después, borra el perfil usando WMI (con fallback de carpeta si falla)." -ForegroundColor DarkGray
                $user = Read-Host "Nombre de usuario del perfil a tratar (ej. jlopez)"
                $c1 = Read-Host "CONFIRMACIÓN 1: ¿Proceder con la copia para '$user'? (S/N)"
                if ($c1 -notmatch '^[sS]') { Write-Host "Cancelado." -ForegroundColor Yellow; Pause; break }
                $c2 = Read-Host "CONFIRMACIÓN 2: ¿Borrar el perfil de '$user' tras la copia? (S/N)"
                if ($c2 -notmatch '^[sS]') { Write-Host "Se hará SOLO la copia, sin borrado." -ForegroundColor Yellow }
                $args = @()
                if ($user) { $args += @('-UserName', $user) }
                & powershell -ExecutionPolicy Bypass -File ".\12_perfilazo.ps1" @args
                Write-Host "`n--- RESUMEN ---" -ForegroundColor Cyan
                Write-Host "Copia en C:\Shared\<usuario>_<fecha>. Consulta el transcript en C:\SDToolLogs\UnifiedToolkit_*.txt" -ForegroundColor DarkGray
                Pause
            }

        default {}
    }
}
