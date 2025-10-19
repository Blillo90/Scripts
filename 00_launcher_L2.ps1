# 00_unified_launcher.ps1 — Unified Service Desk Toolkit (BASICO / AVANZADO)
# Ejecutar como Administrador
$ErrorActionPreference = 'SilentlyContinue'

function Title($t){ Write-Host "`n=== $t ===`n" -ForegroundColor Cyan }
function Pause(){ Write-Host ; Read-Host "Pulsa ENTER para continuar..." | Out-Null }

# Logging
$logFolder = 'C:\SDToolLogs'
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$logFile = Join-Path $logFolder ("UnifiedToolkit_{0}_{1}_{2}.txt" -f $stamp,$env:COMPUTERNAME,$env:USERNAME)
try { Start-Transcript -Path $logFile -Force } catch {}

# Directorio del script
$base = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $base

# ExecutionPolicy: mostrar y poner Bypass en esta sesion
Write-Host 'ExecutionPolicy actual (lista):' -ForegroundColor Cyan
try { Get-ExecutionPolicy -List | Format-Table -AutoSize | Out-Host } catch {}
try { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force } catch {}

function Show-MenuBasic {
  while ($true) {
    Clear-Host
    Write-Host '== MENU BASICO (Windows & Office) ==' -ForegroundColor Green
    Write-Host '1) Diagnostico rapido'
    Write-Host '2) Limpieza temporales'
    Write-Host '3) Reparacion Office (Quick/Online)'
    Write-Host '4) Limpiar cache de Teams'
    Write-Host '5) Reset OneDrive'
    Write-Host '6) SFC + DISM RestoreHealth'
    Write-Host '7) PERFILAZO (copiar datos y borrar perfil)'
    Write-Host '8) Volver al menu principal'
    $opt = Read-Host 'Elige opcion'
    switch ($opt) {
      '1' {
        Title 'Diagnostico rapido'
        & powershell -NoProfile -ExecutionPolicy Bypass -File '.\06_quick_diag.ps1'
        Pause
      }
      '2' {
        Title 'Limpieza temporales'
        $deep = Read-Host 'Limpieza profunda? (S/N)'
        $brow = Read-Host 'Incluir caches de navegadores? (S/N)'
        $paramsList = @()
        if ($deep -match '^[sS]') { $paramsList += '-Deep' }
        if ($brow -match '^[sS]') { $paramsList += '-BrowserCaches' }
        & powershell -NoProfile -ExecutionPolicy Bypass -File '.\01_cleanup.ps1' $paramsList
        Pause
      }
      '3' {
        Title 'Reparacion Office'
        $quick  = Read-Host 'Quick Repair? (S/N)'
        $online = Read-Host 'Online Repair? (S/N)'
        $paramsList = @()
        if ($quick  -match '^[sS]') { $paramsList += '-OfficeQuickRepair' }
        if ($online -match '^[sS]') { $paramsList += '-OfficeOnlineRepair' }
        & powershell -NoProfile -ExecutionPolicy Bypass -File '.\09_office_teams_cleanup.ps1' $paramsList
        Pause
      }
      '4' {
        Title 'Teams cache'
        & powershell -NoProfile -ExecutionPolicy Bypass -File '.\09_office_teams_cleanup.ps1' -TeamsOnly
        Pause
      }
      '5' {
        Title 'OneDrive reset'
        $full = Read-Host 'Limpieza completa adicional? (S/N)'
        $paramsList = @()
        if ($full -match '^[sS]') { $paramsList += '-Full' }
        & powershell -NoProfile -ExecutionPolicy Bypass -File '.\10_onedrive_reset.ps1' $paramsList
        Pause
      }
      '6' {
        Title 'SFC + DISM'
        Start-Process DISM.exe '/Online /Cleanup-Image /RestoreHealth' -Wait -NoNewWindow
        Start-Process sfc.exe '/scannow' -Wait -NoNewWindow
        Pause
      }
      '7' {
        Title 'PERFILAZO'
        $user = Read-Host 'Usuario del perfil (ej. jlopez)'
        if ($user) {
          & powershell -NoProfile -ExecutionPolicy Bypass -File '.\12_perfilazo.ps1' -UserName $user
        }
        Pause
      }
      '8' { break }
      default { }
    }
  }
}

function Show-MenuAdvanced {
  while ($true) {
    Clear-Host
    Write-Host '== MENU AVANZADO (casos puntuales) ==' -ForegroundColor Yellow
    Write-Host '1) Cisco Secure Client (fix rapido / hard reset)'
    Write-Host '2) Reset Dock (HP/DisplayLink/Thunderbolt)'
    Write-Host '3) MECM/SCCM: ciclo post bare-metal'
    Write-Host '4) Purgar registro por aplicacion (con backup .reg)'
    Write-Host '5) Reparar WMI (Salvage / Reset agresivo)'
    Write-Host '6) Limpiar/respaldar Event Logs'
    Write-Host '7) Volver al menu principal'
    $opt = Read-Host 'Elige opcion'
    switch ($opt) {
      '1' {
        Title 'Cisco Secure Client'
        $hard = Read-Host 'Hard reset? (S/N)'
        $paramsList = @()
        if ($hard -match '^[sS]') {
          $prof = Read-Host 'Ruta perfil XML (ENTER si no)'
          if ($prof) { $paramsList += @('-HardReset','-ProfileSource',"$prof") } else { $paramsList += '-HardReset' }
        }
        & powershell -NoProfile -ExecutionPolicy Bypass -File '.\03_fix_cisco_secure_client.ps1' $paramsList
        Pause
      }
      '2' {
        Title 'Reset Dock'
        $dl = Read-Host 'Incluir DisplayLink? (S/N)'
        $uh = Read-Host 'Reset USB Root Hubs? (S/N)'
        $dn = Read-Host 'Reset NICs del dock? (S/N)'
        $paramsList = @()
        if ($dl -match '^[sS]') { $paramsList += '-TryDisplayLink' }
        if ($uh -match '^[sS]') { $paramsList += '-ResetUSBHubs' }
        if ($dn -match '^[sS]') { $paramsList += '-ResetDockNICs' }
        & powershell -NoProfile -ExecutionPolicy Bypass -File '.\04_reset_dock.ps1' $paramsList
        Pause
      }
      '3' {
        Title 'MECM/SCCM'
        $purge = Read-Host 'Vaciar ccmcache? (S/N)'
        $sec   = Read-Host 'Segundos entre ciclos (20 por defecto)'
        $paramsList = @()
        if ($purge -match '^[sS]') { $paramsList += '-PurgeCcmCache' }
        if ($sec -match '^\d+$')   { $paramsList += @('-PolicyWaitSeconds',$sec) }
        & powershell -NoProfile -ExecutionPolicy Bypass -File '.\05_mecm_softwarecenter_kick.ps1' $paramsList
        Pause
      }
      '4' {
        Title 'Purgar registro por app (backup + doble confirmacion)'
        Write-Host 'Se buscaran claves en Uninstall (HKLM/HKCU 32/64), SOFTWARE (HKLM/HKCU), App Paths y opcionalmente Services.' -ForegroundColor DarkGray
        $app   = Read-Host 'Nombre de la app'
        $incSrv= Read-Host 'Incluir Services? (S/N)'
        $hkcu  = Read-Host 'Incluir HKCU? (S/N)'
        $simu  = Read-Host 'Simulacion (no borra)? (S/N)'
        $c1 = Read-Host 'Confirmacion 1: continuar? (S/N)'; if ($c1 -notmatch '^[sS]') { Write-Host 'Cancelado.'; Pause; break }
        $c2 = Read-Host 'Confirmacion 2: se eliminaran claves (con backup). Continuar? (S/N)'; if ($c2 -notmatch '^[sS]') { Write-Host 'Cancelado.'; Pause; break }
        $paramsList = @()
        if ($app)                  { $paramsList += @('-AppName',$app) }
        if ($incSrv -match '^[sS]'){ $paramsList += '-IncludeServices' }
        if ($hkcu   -match '^[sS]'){ $paramsList += '-AlsoCurrentUser' }
        if ($simu   -match '^[sS]'){ $paramsList += '-WhatIfOnly' }
        & powershell -NoProfile -ExecutionPolicy Bypass -File '.\07_purge_app_registry.ps1' $paramsList
        Write-Host 'Backups en C:\RegBackups (si hubo).' -ForegroundColor DarkGray
        if (Test-Path 'C:\RegBackups') { Get-ChildItem 'C:\RegBackups' -Recurse -Depth 2 | Select-Object FullName,Length,LastWriteTime | Format-Table -AutoSize }
        Pause
      }
      '5' {
        Title 'WMI Repair'
        $salv  = Read-Host 'Solo Salvage? (S/N)'
        $force = Read-Host 'Force Reset agresivo? (S/N)'
        if ($force -match '^[sS]') {
          $c1 = Read-Host 'Confirmacion 1: continuar con reset agresivo? (S/N)'; if ($c1 -notmatch '^[sS]') { Pause; break }
          $c2 = Read-Host 'Confirmacion 2: entiendo el impacto. Continuar? (S/N)'; if ($c2 -notmatch '^[sS]') { Pause; break }
        }
        $paramsList = @()
        if ($salv  -match '^[sS]') { $paramsList += '-SalvageOnly' }
        if ($force -match '^[sS]') { $paramsList += '-ForceReset' }
        & powershell -NoProfile -ExecutionPolicy Bypass -File '.\11_repair_wmi.ps1' $paramsList
        $wbem = Join-Path $env:WINDIR 'System32\wbem'
        Get-ChildItem $wbem -Force | Where-Object { $_.Name -like 'Repository*' } | Select-Object Name,Length,LastWriteTime | Format-Table -AutoSize
        Pause
      }
      '6' {
        Title 'Event Logs'
        $bkp  = Read-Host 'Hacer backup .evtx antes? (S/N)'
        $only = Read-Host 'Solo Application/System/Security/Setup? (S/N)'
        if ($bkp -match '^[sS]') {
          $c1 = Read-Host 'Confirmacion 1: continuar con backup y limpieza? (S/N)'; if ($c1 -notmatch '^[sS]') { Pause; break }
          $c2 = Read-Host 'Confirmacion 2: se vaciaran registros. Continuar? (S/N)'; if ($c2 -notmatch '^[sS]') { Pause; break }
        }
        $paramsList = @()
        if ($bkp  -match '^[sS]') { $paramsList += '-Backup' }
        if ($only -match '^[sS]') { $paramsList += '-OnlyOperational' }
        & powershell -NoProfile -ExecutionPolicy Bypass -File '.\08_clear_eventlogs.ps1' $paramsList
        if (Test-Path 'C:\EventLogBackups') { Get-ChildItem 'C:\EventLogBackups' -Recurse -Depth 2 | Select-Object FullName,Length,LastWriteTime | Format-Table -AutoSize }
        wevtutil el | Sort-Object | Select-Object -First 50 | Format-Table -AutoSize
        Pause
      }
      '7' { break }
      default { }
    }
  }
}

while ($true) {
  Clear-Host
  Write-Host 'UNIFIED SERVICE DESK TOOLKIT' -ForegroundColor Magenta
  Write-Host '1) Menu BASICO (Windows & Office)'
  Write-Host '2) Menu AVANZADO (VPN/Docks/SCCM/Registro/WMI/EventLogs)'
  Write-Host '0) Salir'
  $ch = Read-Host 'Elige'
  switch ($ch) {
    '1' { Show-MenuBasic }
    '2' { Show-MenuAdvanced }
    '0' { try { Stop-Transcript } catch {}; break }
    default { }
  }
}
