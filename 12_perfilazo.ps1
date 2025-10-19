# 12_perfilazo.ps1
# PERFILAZO — copia de seguridad + borrado opcional de perfil de usuario
# Compatible con Windows PowerShell 5.1 (sin operadores ternarios ni unicode)

[CmdletBinding()]
param(
    [string]$UserName
)

$ErrorActionPreference = 'Stop'

function Say([string]$msg,[string]$color='White'){ Write-Host $msg -ForegroundColor $color }

function Get-UserProfiles {
    Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue |
    Where-Object {
        $_ -and $_.LocalPath -and
        $_.LocalPath -is [string] -and
        $_.LocalPath -like "$env:SystemDrive\Users\*" -and
        $_.LocalPath -notmatch '\\(Default|Public|All Users|Administrator|TEMP)$'
    } |
    Sort-Object LocalPath
}

# ===== Selección del usuario (si no viene por parámetro) =====
if (-not $UserName) {
    Say "`n== PERFILES DETECTADOS ==" 'Cyan'
    $profiles = Get-UserProfiles

    if (-not $profiles -or $profiles.Count -eq 0) {
        Say "No se detectaron perfiles válidos." 'Red'
        exit
    }

    $i = 1
    foreach ($p in $profiles) {
        try {
            if (-not $p.LocalPath) { continue }
            $u = Split-Path -Path $p.LocalPath -Leaf -ErrorAction SilentlyContinue
            if (-not $u) { continue }
            $loaded = if ($p.Loaded) { '(CARGADO)' } else { '' }
            $fg = if ($p.Loaded) { 'Yellow' } else { 'Gray' }
            Write-Host ("[{0}] {1}  {2}" -f $i,$u,$loaded) -ForegroundColor $fg
            $i++
        } catch {
            # ignora entradas problemáticas
            continue
        }
    }

    # Si el bucle no imprimió nada util, aborta
    if ($i -eq 1) {
        Say "No hay perfiles mostrables." 'Red'
        exit
    }

    $choice = Read-Host "`nSelecciona número o escribe nombre de usuario"
    if ([string]::IsNullOrWhiteSpace($choice)) {
        Say "Cancelado por usuario." 'Yellow'
        exit
    }

    if ($choice -match '^\d+$') {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $profiles.Count) {
            $UserName = Split-Path -Path $profiles[$idx].LocalPath -Leaf
        } else {
            Say "Número fuera de rango." 'Red'
            exit
        }
    } else {
        $UserName = $choice.Trim()
    }
}


# ===== Validación de ruta =====
$profilePath = Join-Path $env:SystemDrive ("Users\" + $UserName)
if (-not (Test-Path -LiteralPath $profilePath)) {
    Say "[X] No existe la ruta de perfil: $profilePath" 'Red'
    exit
}

# ===== Política sobre el usuario actual =====
$doDelete = $true
if ($UserName -ieq $env:USERNAME) {
    Say "AVISO: estás operando sobre tu propio perfil activo: $env:USERNAME" 'Yellow'
    $only = Read-Host "¿Hago SOLO COPIA DE SEGURIDAD y salgo? (S/N)"
    if ($only -match '^[sS]') {
        $doDelete = $false
    } else {
        Say "Operación cancelada." 'Yellow'
        return
    }
}

# ===== Estado del perfil (cargado) =====
$profObj = Get-CimInstance Win32_UserProfile -Filter "LocalPath='$profilePath'" -ErrorAction SilentlyContinue
if ($profObj -and $profObj.Loaded) {
    Say "AVISO: el perfil '$UserName' está CARGADO. No se podrá borrar ahora." 'Yellow'
    $doDelete = $false
}

# ===== Configuración de backup =====
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupRoot = Join-Path 'C:\SDToolLogs' ("Perfilazo_{0}_{1}" -f $UserName,$stamp)
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

# Carpetas por defecto (incluye Downloads)
$defaultRel = @(
    'Desktop','Documents','Downloads','Pictures','Music','Videos','Favorites',
    'AppData\Roaming\Microsoft\Signatures',
    'AppData\Local\Microsoft\Outlook'
)

# Rutas extra (solo para esta ejecución)
$extra = @()
$add = Read-Host "¿Quieres añadir RUTAS EXTRA (solo hoy)? (S/N)"
while ($add -match '^[sS]') {
    $p = Read-Host "Introduce ruta (relativa al perfil o absoluta). Ej: AppData\Local\Google\Chrome\User Data"
    if ($p) { $extra += $p }
    $add = Read-Host "¿Añadir otra? (S/N)"
}

# Construir lista de copia
$targets = @()
foreach ($rel in $defaultRel) {
    $targets += [PSCustomObject]@{
        Source = Join-Path $profilePath $rel
        Rel    = $rel
    }
}
foreach ($p in $extra) {
    $isAbs = [IO.Path]::IsPathRooted($p)
    $full = $p
    if (-not $isAbs) { $full = Join-Path $profilePath $p }
    $rel = $p
    if ($isAbs) { $rel = ('ABS_' + ($p -replace ':','')) }
    $targets += [PSCustomObject]@{ Source=$full; Rel=$rel }
}

# Resumen y confirmaciones
Say "`n== PLAN DE COPIA ==" 'Cyan'
Say ("Perfil origen : {0}" -f $profilePath) 'Gray'
Say ("Backup destino: {0}" -f $backupRoot) 'Gray'

foreach ($t in $targets) {
    $exists = Test-Path -LiteralPath $t.Source
    $icon = if ($exists) { '[OK]' } else { '[  ]' }
    $fg   = if ($exists) { 'White' } else { 'DarkGray' }
    Write-Host ("{0}  {1}" -f $icon,$t.Source) -ForegroundColor $fg
}

if ($doDelete) {
    Say "`nTras la COPIA se intentará BORRAR el perfil (si no está cargado)." 'Yellow'
}

$ok = Read-Host "`nConfirmación 1: ¿Continuar con la COPIA? (S/N)"
if ($ok -notmatch '^[sS]') { Say "Cancelado." 'Yellow'; return }


# Copia con robocopy
Say "`n[>] Copiando datos..." 'Cyan'
foreach ($t in $targets) {
    if (-not (Test-Path -LiteralPath $t.Source)) { continue }
    $dest = Join-Path $backupRoot ($t.Rel -replace '[\\/:*?""<>|]','_')
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    $rc = Join-Path $env:SystemRoot 'System32\robocopy.exe'
    $rcArgs = @($t.Source, $dest, '/E','/COPY:DAT','/R:1','/W:1','/NFL','/NDL','/NP')
    Start-Process -FilePath $rc -ArgumentList $rcArgs -Wait -WindowStyle Hidden
}
Say "[OK] Copia finalizada." 'Green'

Say "`n== CONTENIDO DEL BACKUP ==" 'Cyan'
Get-ChildItem -LiteralPath $backupRoot -Recurse -Force | Select-Object FullName,Length,LastWriteTime | Out-Host

# Borrado (si procede)
if (-not $doDelete) {
    Say "`nNo se intentará borrar el perfil (activo/cargado o usuario canceló)." 'Yellow'
    Say ("Backup en: {0}" -f $backupRoot) 'Gray'
    return
}

$del1 = Read-Host "`nConfirmación BORRADO 1: ¿Borrar perfil de '$UserName'? (S/N)"
if ($del1 -notmatch '^[sS]') { Say "Borrado cancelado." 'Yellow'; return }
$del2 = Read-Host "Confirmación BORRADO 2: Sé que elimina carpeta y registro. (S/N)"
if ($del2 -notmatch '^[sS]') { Say "Borrado cancelado." 'Yellow'; return }

# Releer estado
$profObj = Get-CimInstance Win32_UserProfile -Filter "LocalPath='$profilePath'" -ErrorAction SilentlyContinue
if ($profObj -and $profObj.Loaded) {
    Say "AVISO: el perfil sigue CARGADO. No se borra." 'Yellow'
    return
}

try {
    if ($profObj) {
        Invoke-CimMethod -InputObject $profObj -MethodName Delete | Out-Null
        Say "[OK] Perfil eliminado (Win32_UserProfile)." 'Green'
    } elseif (Test-Path -LiteralPath $profilePath) {
        Remove-Item -LiteralPath $profilePath -Recurse -Force
        Say "[OK] Carpeta de perfil eliminada (fallback)." 'Green'
    } else {
        Say "No se encontró carpeta de perfil para borrar." 'Yellow'
    }
}
catch {
    Say ("[X] Error al borrar el perfil: {0}" -f $_.Exception.Message) 'Red'
    return
}

# Estado final
Say "`n== ESTADO FINAL ==" 'Cyan'
$present = Test-Path -LiteralPath $profilePath
$presTxt = if ($present) { 'SI' } else { 'NO' }
$presCol = if ($present) { 'Yellow' } else { 'Green' }
Say ("Perfil presente : {0}" -f $presTxt) $presCol
Say ("Backup en      : {0}" -f $backupRoot) 'Gray'
