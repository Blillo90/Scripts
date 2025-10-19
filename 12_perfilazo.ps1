# 12_perfilazo.ps1
# PERFILAZO mejorado — copia de seguridad + borrado opcional de perfil de usuario
# by malaguita
[CmdletBinding()]
param(
    [string]$UserName
)

$ErrorActionPreference = 'Stop'
function Say([string]$msg,[string]$color='White'){ Write-Host $msg -ForegroundColor $color }

# --- Detectar perfiles locales ---
function Get-UserProfiles {
    Get-CimInstance Win32_UserProfile |
    Where-Object {
        $_.LocalPath -like "$env:SystemDrive\Users\*" -and
        ($_.LocalPath -notmatch 'Default|Public|All Users|Administrator|TEMP')
    } |
    Sort-Object LocalPath
}

# Si no se pasó un nombre, mostrar menú de usuarios
if (-not $UserName) {
    Say "`n== PERFILES DETECTADOS ==" 'Cyan'
    $profiles = Get-UserProfiles
    if (-not $profiles) { Say "No se detectaron perfiles válidos." 'Red'; exit }

    $i = 1
    foreach ($p in $profiles) {
        $u = Split-Path $p.LocalPath -Leaf
        $loaded = if ($p.Loaded) { "(CARGADO)" } else { "" }
        Write-Host ("[{0}] {1}  {2}" -f $i,$u,$loaded) -ForegroundColor (if ($p.Loaded) { "Yellow" } else { "Gray" })
        $i++
    }

    $choice = Read-Host "`nSelecciona número o escribe nombre de usuario"
    if ($choice -match '^\d+$') {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $profiles.Count) {
            $UserName = Split-Path $profiles[$idx].LocalPath -Leaf
        } else {
            Say "Número fuera de rango." 'Red'
            exit
        }
    } else {
        $UserName = $choice.Trim()
    }
}

# --- Validación de ruta ---
$profilePath = Join-Path $env:SystemDrive ("Users\" + $UserName)
if (-not (Test-Path -LiteralPath $profilePath)) {
    Say "[✗] No existe la ruta de perfil: $profilePath" 'Red'
    exit
}

# --- No permitir el propio perfil activo ---
if ($UserName -ieq $env:USERNAME) {
    Say "⚠ Estás intentando operar sobre tu propio perfil activo: $env:USERNAME" 'Yellow'
    $only = Read-Host "¿Hago SOLO COPIA DE SEGURIDAD y salgo? (S/N)"
    if ($only -match '^[sS]') {
        $doDelete = $false
    } else {
        Say "Operación cancelada." 'Yellow'
        return
    }
} else {
    $doDelete = $true
}

# --- Comprobar si el perfil está cargado ---
$profObj = Get-CimInstance Win32_UserProfile -Filter "LocalPath='$profilePath'" -ErrorAction SilentlyContinue
if ($profObj -and $profObj.Loaded) {
    Say "⚠ El perfil '$UserName' está actualmente CARGADO por el sistema. No se puede borrar mientras esté en uso." 'Yellow'
    Say "Se realizará la copia de seguridad. El borrado podrás hacerlo tras cerrar sesión." 'Yellow'
    $doDelete = $false
}

# --- Configuración de backup ---
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupRoot = Join-Path 'C:\SDToolLogs' ("Perfilazo_{0}_{1}" -f $UserName,$stamp)
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

# Carpetas por defecto
$defaultRel = @(
    'Desktop','Documents','Downloads','Pictures','Music','Videos','Favorites',
    'AppData\Roaming\Microsoft\Signatures',
    'AppData\Local\Microsoft\Outlook'
)

# Extra opcional
$extra = @()
$add = Read-Host "¿Quieres añadir RUTAS EXTRA (solo hoy)? (S/N)"
while ($add -match '^[sS]') {
    $p = Read-Host "Introduce ruta (relativa o absoluta)"
    if ($p) { $extra += $p }
    $add = Read-Host "¿Añadir otra? (S/N)"
}

# --- Preparar lista de copia ---
$targets = @()
foreach ($rel in $defaultRel) {
    $targets += [PSCustomObject]@{
        Source = Join-Path $profilePath $rel
        Rel    = $rel
    }
}
foreach ($p in $extra) {
    $full = ([IO.Path]::IsPathRooted($p)) ? $p : (Join-Path $profilePath $p)
    $rel  = ([IO.Path]::IsPathRooted($p)) ? ("ABS_"+($p -replace ':','')) : $p
    $targets += [PSCustomObject]@{ Source=$full; Rel=$rel }
}

# --- Mostrar resumen ---
Say "`n== PLAN DE COPIA ==" 'Cyan'
Say ("Perfil origen : {0}" -f $profilePath) 'Gray'
Say ("Backup destino: {0}" -f $backupRoot) 'Gray'
$targets | ForEach-Object {
    $icon = if (Test-Path $_.Source) { "[✔]" } else { "[ ]" }
    Write-Host "$icon  $($_.Source)" -ForegroundColor (if (Test-Path $_.Source) {'White'} else {'DarkGray'})
}

if ($doDelete) { Say "`nTras la COPIA se intentará BORRAR el perfil (si no está cargado)." 'Yellow' }

$ok1 = Read-Host "`nConfirmación 1: ¿Continuar con la COPIA? (S/N)"
if ($ok1 -notmatch '^[sS]') { Say "Cancelado." 'Yellow'; return }
$ok2 = Read-Host "Confirmación 2: Entiendo el impacto. Proceder. (S/N)"
if ($ok2 -notmatch '^[sS]') { Say "Cancelado." 'Yellow'; return }

# --- Copia con robocopy ---
Say "`n[>] Copiando datos..." 'Cyan'
foreach ($t in $targets) {
    if (-not (Test-Path -LiteralPath $t.Source)) { continue }
    $dest = Join-Path $backupRoot ($t.Rel -replace '[\\/:*?""<>|]','_')
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    $rcArgs = @($t.Source, $dest, '/E','/COPY:DAT','/R:1','/W:1','/NFL','/NDL','/NP')
    Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\robocopy.exe') -ArgumentList $rcArgs -Wait -WindowStyle Hidden
}
Say "[✓] Copia finalizada." 'Green'

# --- Mostrar backup resultante ---
Say "`n== CONTENIDO DEL BACKUP ==" 'Cyan'
Get-ChildItem -LiteralPath $backupRoot -Recurse -Force | Select-Object FullName,Length,LastWriteTime | Out-Host

# --- Borrado seguro (si procede) ---
if (-not $doDelete) {
    Say "`nNo se intentará borrar el perfil (activo o cargado)." 'Yellow'
    Say ("Backup en: {0}" -f $backupRoot) 'Gray'
    return
}

$del1 = Read-Host "`nConfirmación BORRADO 1: ¿Borrar perfil de '$UserName'? (S/N)"
if ($del1 -notmatch '^[sS]') { Say "Borrado cancelado." 'Yellow'; return }
$del2 = Read-Host "Confirmación BORRADO 2: Entiendo el impacto. (S/N)"
if ($del2 -notmatch '^[sS]') { Say "Borrado cancelado." 'Yellow'; return }

$profObj = Get-CimInstance Win32_UserProfile -Filter "LocalPath='$profilePath'" -ErrorAction SilentlyContinue
if ($profObj -and $profObj.Loaded) {
    Say "⚠ El perfil sigue cargado. No se borra." 'Yellow'
    return
}

try {
    if ($profObj) {
        Invoke-CimMethod -InputObject $profObj -MethodName Delete | Out-Null
        Say "[✓] Perfil eliminado correctamente." 'Green'
    } elseif (Test-Path -LiteralPath $profilePath) {
        Remove-Item -LiteralPath $profilePath -Recurse -Force
        Say "[✓] Carpeta de perfil eliminada (fallback)." 'Green'
    } else {
        Say "No se encontró carpeta de perfil." 'Yellow'
    }
} catch {
    Say "[✗] Error al borrar perfil: $($_.Exception.Message)" 'Red'
}

Say "`n== ESTADO FINAL ==" 'Cyan'
Say ("Perfil presente : {0}" -f (Test-Path $profilePath ? 'SI' : 'NO')) ((Test-Path $profilePath) ? 'Yellow' : 'Green')
Say ("Backup en      : {0}" -f $backupRoot) 'Gray'
