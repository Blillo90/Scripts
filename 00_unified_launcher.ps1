# 00_unified_launcher.ps1
# Unified Service Desk Toolkit — Pretty Launcher
# v1.4 — by malaguita
[CmdletBinding()] param()
$ErrorActionPreference = 'Continue'

# ===== Banner =====
function Show-Banner {
  Clear-Host
@'
              

                          $$\   $$\           $$\           $$$$$$$\                      $$\             
                          $$ |  $$ |          $$ |          $$  __$$\                     $$ |            
                          $$ |  $$ | $$$$$$\  $$ | $$$$$$\  $$ |  $$ | $$$$$$\   $$$$$$$\ $$ |  $$\       
                          $$$$$$$$ |$$  __$$\ $$ |$$  __$$\ $$ |  $$ |$$  __$$\ $$  _____|$$ | $$  |      
                          $$  __$$ |$$$$$$$$ |$$ |$$ /  $$ |$$ |  $$ |$$$$$$$$ |\$$$$$$\  $$$$$$  /       
                          $$ |  $$ |$$   ____|$$ |$$ |  $$ |$$ |  $$ |$$   ____| \____$$\ $$  _$$<        
                          $$ |  $$ |\$$$$$$$\ $$ |$$$$$$$  |$$$$$$$  |\$$$$$$$\ $$$$$$$  |$$ | \$$\       
                          \__|  \__| \_______|\__|$$  ____/ \_______/  \_______|\_______/ \__|  \__|      
                                                  $$ |                                                    
                                                  $$ |                                                    
                                                  \__|       
                   $$$$$$$$\                  $$\ $$\       $$\   $$\                       $$\        $$$$$$\  
                   \__$$  __|                 $$ |$$ |      \__|  $$ |                    $$$$ |      $$  __$$\ 
                      $$ | $$$$$$\   $$$$$$\  $$ |$$ |  $$\ $$\ $$$$$$\         $$\    $$\\_$$ |      \__/  $$ |
                      $$ |$$  __$$\ $$  __$$\ $$ |$$ | $$  |$$ |\_$$  _|        \$$\  $$  | $$ |       $$$$$$  |
                      $$ |$$ /  $$ |$$ /  $$ |$$ |$$$$$$  / $$ |  $$ |           \$$\$$  /  $$ |      $$  ____/ 
                      $$ |$$ |  $$ |$$ |  $$ |$$ |$$  _$$<  $$ |  $$ |$$\         \$$$  /   $$ |      $$ |      
                      $$ |\$$$$$$  |\$$$$$$  |$$ |$$ | \$$\ $$ |  \$$$$  |         \$  /  $$$$$$\ $$\ $$$$$$$$\ 
                      \__| \______/  \______/ \__|\__|  \__|\__|   \____/           \_/   \______|\__|\________|


                                                      By Malaguita
'@ | Write-Host -ForegroundColor Magenta
  Write-Host ""
}

# ===== UI helpers bonitos =====
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch {}

function Get-ConsoleWidth { 
  try { return $Host.UI.RawUI.WindowSize.Width } catch { return 100 }
}

function Write-Panel {
  param(
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string]$Subtitle,
    [ConsoleColor]$Color = 'Green',
    [int]$MaxWidth = 76
  )
  $w = [Math]::Min((Get-ConsoleWidth) - 4, $MaxWidth)
  if ($w -lt 40) { $w = 40 }

  $leftPad = [Math]::Floor(((Get-ConsoleWidth) - $w) / 2)
  $L = '╭' + ('─' * ($w-2)) + '╮'
  $S = '├' + ('─' * ($w-2)) + '┤'
  $R = '╰' + ('─' * ($w-2)) + '╯'

  function _w($s,[ConsoleColor]$c){ (' ' * $leftPad) + $s | Write-Host -ForegroundColor $c }
  function _line([string]$t){
    $t = ' ' + $t.Trim() + ' '
    if ($t.Length -gt ($w-2)) { $t = $t.Substring(0, ($w-5)) + '… ' }
    $pad = ($w-2 - $t.Length)
    $l = [Math]::Floor($pad/2); $r = [Math]::Ceiling($pad/2)
    return '│' + (' ' * $l) + $t + (' ' * $r) + '│'
  }

  _w $L $Color
  _w (_line $Title) $Color
  _w $S $Color
  _w (_line $Subtitle) $Color
  _w $R $Color
  Write-Host ''
}

function Write-MenuList {
  param(
    [Parameter(Mandatory)][string[]]$Items,
    [int]$Start = 1,
    [int]$Indent = 2,
    [ConsoleColor]$NumberColor = 'Cyan',
    [ConsoleColor]$TextColor = 'White'
  )
  $numW = ([string]($Items.Count + $Start - 1)).Length
  $prefix = ' ' * $Indent
  $i = $Start
  foreach($txt in $Items){
    $num = ('[{0}]' -f $i.ToString().PadLeft($numW))
    Write-Host ($prefix + $num + '  ') -NoNewline -ForegroundColor $NumberColor
    Write-Host $txt -ForegroundColor $TextColor
    $i++
  }
  Write-Host ''
}

# ===== Invocador unificado (.ps1 con spinner; DISM/SFC en streaming) =====
function Pause { Write-Host; Read-Host "Pulsa ENTER para continuar..." | Out-Null }

function Invoke-TaskWithSpinner {
  param(
    [Parameter(Mandatory)][string]$ScriptPath,   # .ps1 o .exe
    [array]$Params = @(),
    [string]$Message = $null
  )
  if (-not $Message) { $Message = "Ejecutando $([IO.Path]::GetFileName($ScriptPath))" }

  function Resolve-FullPath([string]$p) {
    if ([IO.Path]::IsPathRooted($p)) { return $p }
    if ($script:ToolRoot) { return (Join-Path $script:ToolRoot $p) }
    return (Resolve-Path -LiteralPath $p).Path
  }

  $full = Resolve-FullPath $ScriptPath
  if (-not (Test-Path -LiteralPath $full)) {
    Write-Host "[✗] No se encuentra: $full" -ForegroundColor Red
    return
  }

  $isPs1 = $full -match '\.ps1$'
  if ($isPs1) {
    # PS1 -> Job + spinner + recoger salida
    $psExe = (Get-Command powershell).Source
    $alist = @('-NoProfile','-ExecutionPolicy','Bypass','-File', $full) + $Params

    Write-Host ""; Write-Host "[>] $Message" -ForegroundColor Cyan
    $job = Start-Job -ScriptBlock {
      param($psExe,$alist,$wd)
      Set-Location $wd
      $InformationPreference = 'Continue'
      & $psExe @alist
    } -ArgumentList $psExe,$alist,$script:ToolRoot

    $spin='|','/','-','\'; $i=0
    while (($job.State -eq 'Running') -or ($job.State -eq 'NotStarted')) {
      Write-Host -NoNewline ("`r  {0}  " -f $spin[$i % $spin.Count]) -ForegroundColor Yellow
      Start-Sleep -Milliseconds 180; $i++
    }
    Write-Host "`r   " -NoNewline

    Receive-Job $job -Keep | Out-Host                                # Output
    $null = Receive-Job $job -Keep -InformationAction Continue -InformationVariable iv -ErrorAction SilentlyContinue
    if ($iv) { $iv | ForEach-Object { $_.MessageData } | Out-Host }  # Write-Host
    $null = Receive-Job $job -Keep -WarningAction Continue -WarningVariable wv -ErrorAction SilentlyContinue
    if ($wv) { Write-Host "`n[!] Avisos:" -ForegroundColor Yellow; $wv | Out-String | Write-Host -ForegroundColor Yellow }
    $null = Receive-Job $job -Keep -ErrorAction SilentlyContinue -ErrorVariable ev
    if ($ev) { Write-Host "`n[✗] Errores:" -ForegroundColor Red; $ev | Out-String | Write-Host -ForegroundColor Red }

    Remove-Job $job -Force
    Write-Host "[✓] Completado." -ForegroundColor Green
    return
  }

  # EXE -> DISM/SFC (ejecución directa con confirmación)
  $exe = $full
  $alist = $Params
  $baseExe = [IO.Path]::GetFileName($exe).ToLower()
  if ($baseExe -in @('dism.exe','sfc.exe')) {

    # Confirmar antes de ejecutar
    Write-Host ""
    Write-Host "Se va a ejecutar:" -ForegroundColor Yellow
    Write-Host "   $baseExe $($alist -join ' ')" -ForegroundColor Cyan
    $conf = Read-Host "¿Deseas continuar? (S/N)"
    if ($conf -notmatch '^[sS]') {
      Write-Host "Operación cancelada por el usuario." -ForegroundColor Yellow
      return
    }

    Write-Host ""
    Write-Host "[>] $Message" -ForegroundColor Cyan
    Push-Location $script:ToolRoot
    & $exe @alist
    $exit = $LASTEXITCODE
    Pop-Location
    if ($exit -eq 0) {
      Write-Host "[✓] Completado." -ForegroundColor Green
    } else {
      Write-Host "[✗] Fallo ($exit)" -ForegroundColor Red
    }
    return
  }



  # Otros EXE -> proceso con spinner
  Write-Host ""; Write-Host "[>] $Message" -ForegroundColor Cyan
  $p = Start-Process -FilePath $exe -ArgumentList $alist -WindowStyle Hidden -PassThru -WorkingDirectory $script:ToolRoot
  $spin='|','/','-','\'; $i=0
  while (-not $p.HasExited) {
    Write-Host -NoNewline ("`r  {0}  " -f $spin[$i % $spin.Count]) -ForegroundColor Yellow
    Start-Sleep -Milliseconds 180; $i++
  }
  Write-Host "`r   " -NoNewline
  if ($p.ExitCode -eq 0) { Write-Host "[✓] Completado." -ForegroundColor Green } else { Write-Host "[✗] Fallo ($($p.ExitCode))." -ForegroundColor Red }
}

# Alias de compatibilidad
function Invoke-ScriptWithSpinner {
  param([Parameter(Mandatory)][string]$ScriptPath,[array]$Params=@(),[string]$Message=$null)
  Invoke-TaskWithSpinner -ScriptPath $ScriptPath -Params $Params -Message $Message
}

# Ejecuta un .ps1 interactivo en ESTA consola (permite Read-Host)
function Invoke-InteractivePs1 {
  param([Parameter(Mandatory)][string]$ScriptPath,[array]$Params=@())
  if (-not [IO.Path]::IsPathRooted($ScriptPath)) { $ScriptPath = Join-Path $script:ToolRoot $ScriptPath }
  if (-not (Test-Path -LiteralPath $ScriptPath)) { Write-Host "[✗] No se encuentra: $ScriptPath" -ForegroundColor Red; return }
  Push-Location $script:ToolRoot; try { & $ScriptPath @Params } finally { Pop-Location }
}

# Encabezado para cada tarea: limpia pantalla + panel
function Show-TaskHeader {
  param([Parameter(Mandatory)][string]$Title,[Parameter(Mandatory)][string]$Subtitle,[ConsoleColor]$Color='Cyan')
  Clear-Host
  if (Get-Command Write-Panel -ErrorAction SilentlyContinue) {
    Write-Panel -Title $Title -Subtitle $Subtitle -Color $Color
  } else {
    Write-Host "== $Title ==" -ForegroundColor $Color
    Write-Host $Subtitle -ForegroundColor $Color
    Write-Host ''
  }
}

# ===== Preparación =====
$script:ToolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $script:ToolRoot

Show-Banner
Write-Host "ExecutionPolicy (lista):" -ForegroundColor Cyan
try { Get-ExecutionPolicy -List | Format-Table -AutoSize | Out-Host } catch {}
try { Set-ExecutionPolicy Bypass -Scope Process -Force } catch {}

if (-not (Test-Path 'C:\SDToolLogs')) { New-Item 'C:\SDToolLogs' -ItemType Directory -Force | Out-Null }

$stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$log   = "C:\SDToolLogs\UnifiedToolkit_{0}_{1}_{2}.txt" -f $stamp, $env:COMPUTERNAME, $env:USERNAME
try { Start-Transcript -Path $log -Force } catch {}

# ===== Menú Básico =====
function Show-MenuBasic {
  while ($true) {
    Clear-Host
    Write-Panel -Title 'BASICO' -Subtitle 'Tareas frecuentes (elige numero)' -Color Green
    $basicItems = @(
      'Diagnostico rapido',
      'Limpieza temporales',
      'Reparacion Office (Quick/Online)',
      'Limpiar cache Teams',
      'Reset OneDrive',
      'SFC + DISM',
      'PERFILAZO (copiar y borrar perfil)',
      'Volver'
    )
    Write-MenuList -Items $basicItems -Start 1 -Indent 2 -NumberColor Cyan -TextColor White
    $opt = ((Read-Host 'Opcion') -replace '[^\d]','').Trim()
    switch ($opt) {
      '1' {
        Show-TaskHeader -Title 'Diagnóstico rápido' -Subtitle 'Recolectando info básica del sistema' -Color Green
        Invoke-ScriptWithSpinner ".\06_quick_diag.ps1" -Message "Diagnóstico rápido"; Pause
      }
      '2' {
        Show-TaskHeader -Title 'Limpieza temporales' -Subtitle 'Temp, cache, WU/Prefetch (opcional)' -Color Green
        $p=@(); if ((Read-Host "Profunda (+WU/Prefetch)? (S/N)") -match '^[sS]') { $p += '-Deep' }
        if ((Read-Host "Incluir caches navegadores? (S/N)") -match '^[sS]') { $p += '-BrowserCaches' }
        Invoke-ScriptWithSpinner ".\01_cleanup.ps1" -Params $p -Message "Limpieza temporales"; Pause
      }
      '3' {
        Show-TaskHeader -Title 'Reparación Office' -Subtitle 'Quick/Online Repair + limpieza' -Color Green
        $p=@(); if ((Read-Host "Quick Repair? (S/N)") -match '^[sS]') { $p += '-OfficeQuickRepair' }
        if ((Read-Host "Online Repair? (S/N)") -match '^[sS]') { $p += '-OfficeOnlineRepair' }
        Invoke-ScriptWithSpinner ".\09_office_teams_cleanup.ps1" -Params $p -Message "Reparación Office"; Pause
      }
            '4' {
        # Confirmación antes de limpiar Teams
        Write-Host ""
        Write-Host "Esta acción eliminará la caché de Microsoft Teams," -ForegroundColor Yellow
        Write-Host "cerrando sesión y borrando datos locales temporales." -ForegroundColor Yellow
        $conf = Read-Host "¿Deseas continuar con la limpieza de Teams? (S/N)"
        if ($conf -notmatch '^[sS]') {
          Write-Host "Operación cancelada por el usuario." -ForegroundColor Yellow
          Pause
          continue
        }

        # Ejecutar limpieza
        Invoke-ScriptWithSpinner ".\09_office_teams_cleanup.ps1" -Message "Limpiando cache Teams"
        Pause
      }

      '5' {
        Show-TaskHeader -Title 'OneDrive' -Subtitle 'Reset y limpieza adicional (opcional)' -Color Green
        $p=@(); if ((Read-Host "Limpieza completa adicional? (S/N)") -match '^[sS]') { $p += '-Full' }
        Invoke-ScriptWithSpinner ".\10_onedrive_reset.ps1" -Params $p -Message "Reset OneDrive"; Pause
      }
      '6' {
        Show-TaskHeader -Title 'Integridad del sistema' -Subtitle 'DISM /RestoreHealth + SFC /Scannow' -Color Green
        Invoke-ScriptWithSpinner (Get-Command DISM).Source -Params @('/Online','/Cleanup-Image','/RestoreHealth') -Message "DISM /Online /Cleanup-Image /RestoreHealth"
        Invoke-ScriptWithSpinner (Get-Command sfc).Source  -Params @('/scannow') -Message "SFC /scannow"
        Pause
      }
      '7' {
        Show-TaskHeader -Title 'PERFILAZO' -Subtitle 'Selector de usuarios, backup y borrado opcional' -Color Yellow
        Invoke-InteractivePs1 '.\12_perfilazo.ps1'
        Pause
      }
      '8' { return }
      '0' { return }
      default { Write-Host "Opcion no valida." -ForegroundColor Red; Start-Sleep -Milliseconds 600 }
    }
  }
}

# ===== Menú Avanzado =====
function Show-MenuAdvanced {
  while ($true) {
    Clear-Host
    Write-Panel -Title 'AVANZADO' -Subtitle 'Acciones sensibles y puntuales' -Color Yellow
    $advItems = @(
      'Cisco Secure Client (fix/hard reset)',
      'Reset Dock (HP/DisplayLink)',
      'MECM/SCCM — ciclo post bare-metal',
      'Purgar registro por app (backup .reg)',
      'Reparar WMI (Salvage/Reset agresivo)',
      'Limpiar/respaldar Event Logs',
      'Volver'
    )
    Write-MenuList -Items $advItems -Start 1 -Indent 2 -NumberColor Yellow -TextColor White
    $opt = ((Read-Host 'Opcion') -replace '[^\d]','').Trim()
    switch ($opt) {
      '1' {
        Show-TaskHeader -Title 'Cisco Secure Client' -Subtitle 'Fix / Hard reset (opcional perfil XML)' -Color Yellow
        $p=@()
        if ((Read-Host "Hard reset? (S/N)") -match '^[sS]') {
          $xml = Read-Host "Ruta perfil XML (ENTER si no)"
          if ($xml) { $p += @('-HardReset','-ProfileSource',$xml) } else { $p += '-HardReset' }
        }
        Invoke-ScriptWithSpinner ".\03_fix_cisco_secure_client.ps1" -Params $p -Message "Cisco Secure Client"; Pause
      }
      '2' {
        Show-TaskHeader -Title 'Docks' -Subtitle 'HP/DisplayLink, reset hubs/NICs' -Color Yellow
        $p=@()
        if ((Read-Host "Incluir DisplayLink? (S/N)") -match '^[sS]') { $p += '-TryDisplayLink' }
        if ((Read-Host "Reset USB Hubs? (S/N)") -match '^[sS]') { $p += '-ResetUSBHubs' }
        if ((Read-Host "Reset NICs del dock? (S/N)") -match '^[sS]') { $p += '-ResetDockNICs' }
        Invoke-ScriptWithSpinner ".\04_reset_dock.ps1" -Params $p -Message "Reset Dock"; Pause
      }
      '3' {
        Show-TaskHeader -Title 'MECM / SCCM' -Subtitle 'Ciclo post bare-metal, ccmcache opcional' -Color Yellow
        $p=@()
        if ((Read-Host "Vaciar ccmcache? (S/N)") -match '^[sS]') { $p += '-PurgeCcmCache' }
        $sec = Read-Host "Segundos entre ciclos (20 por defecto)"; if ($sec -match '^\d+$') { $p += @('-PolicyWaitSeconds',$sec) }
        Invoke-ScriptWithSpinner ".\05_mecm_softwarecenter_kick.ps1" -Params $p -Message "Kick SCCM/MECM"; Pause
      }
      '4' {
        Show-TaskHeader -Title 'Registro por aplicación' -Subtitle 'Backup .reg + eliminación selectiva' -Color Yellow
        Write-Host "Se haran backups .reg antes de borrar." -ForegroundColor Yellow
        $app = Read-Host "Nombre app"; $inc = Read-Host "Incluir Services? (S/N)"; $hk = Read-Host "Incluir HKCU? (S/N)"; $sim = Read-Host "Simulacion (no borra)? (S/N)"
        $c1 = Read-Host "CONF1 continuar? (S/N)"; if ($c1 -notmatch '^[sS]') { Write-Host "Cancelado."; Pause; return }
        $c2 = Read-Host "CONF2 eliminar claves (con backup)? (S/N)"; if ($c2 -notmatch '^[sS]') { Write-Host "Cancelado."; Pause; return }
        $p=@(); if ($app) { $p += @('-AppName',$app) }; if ($inc -match '^[sS]') { $p += '-IncludeServices' }; if ($hk -match '^[sS]') { $p += '-AlsoCurrentUser' }; if ($sim -match '^[sS]') { $p += '-WhatIfOnly' }
        Invoke-ScriptWithSpinner ".\07_purge_app_registry.ps1" -Params $p -Message "Purgar registro ($app)"; Pause
      }
      '5' {
        Show-TaskHeader -Title 'WMI Repair' -Subtitle 'Salvage o Reset agresivo' -Color Yellow
        $sal = (Read-Host "Solo Salvage? (S/N)") -match '^[sS]'; $for = (Read-Host "Force Reset agresivo? (S/N)") -match '^[sS]'
        if ($for) { $x = Read-Host "CONF1 reset agresivo? (S/N)"; if ($x -notmatch '^[sS]') { Pause; return }; $y = Read-Host "CONF2 entiendo impacto. Continuar? (S/N)"; if ($y -notmatch '^[sS]') { Pause; return } }
        $p=@(); if ($sal) { $p += '-SalvageOnly' }; if ($for) { $p += '-ForceReset' }
        Invoke-ScriptWithSpinner ".\11_repair_wmi.ps1" -Params $p -Message "WMI Repair"; Pause
      }
      '6' {
        Show-TaskHeader -Title 'Event Logs' -Subtitle 'Backup opcional y limpieza' -Color Yellow
        $b = (Read-Host "Backup .evtx antes? (S/N)") -match '^[sS]'; $o = (Read-Host "Solo App/System/Security/Setup? (S/N)") -match '^[sS]'
        if ($b) { $x = Read-Host "CONF1 backup+limpieza? (S/N)"; if ($x -notmatch '^[sS]') { Pause; return }; $y = Read-Host "CONF2 vaciar registros? (S/N)"; if ($y -notmatch '^[sS]') { Pause; return } }
        $p=@(); if ($b) { $p += '-Backup' }; if ($o) { $p += '-OnlyOperational' }
        Invoke-ScriptWithSpinner ".\08_clear_eventlogs.ps1" -Params $p -Message "Event Logs"; Pause
      }
      '7' { return }
      '0' { return }
      default { Write-Host "Opcion no valida." -ForegroundColor Red; Start-Sleep -Milliseconds 600 }
    }
  }
}

# ===== MAIN LOOP =====
while ($true) {
  Show-Banner
  Write-Host "              [1] Menu BASICO     
              [2] Menu AVANZADO     
              [0] Salir
  
  " -ForegroundColor DarkCyan
  $choice = ((Read-Host "Elige") -replace '[^\d]','').Trim()
  switch ($choice) {
    '1' { Show-MenuBasic }
    '2' { Show-MenuAdvanced }
    '0' { try { Stop-Transcript } catch {}; Write-Host "`nGracias por usar Unified Toolkit — by malaguita" -ForegroundColor DarkYellow; exit }
    default { Write-Host "Opcion no valida." -ForegroundColor Red; Start-Sleep -Milliseconds 600 }
  }
}
