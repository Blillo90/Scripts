# 12_perfilazo.ps1 — "Perfilazo": copia datos esenciales del perfil y elimina el perfil de Windows
# Ejecutar como Administrador y con el usuario objetivo DESLOGUEADO.
[CmdletBinding()]
param(
    [string]$UserName # si no se pasa, se pide
)

function Require-Admin {
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    $p=New-Object Security.Principal.WindowsPrincipal($id)
    if (!$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Este script debe ejecutarse como Administrador."
    }
}
Require-Admin

if (-not $UserName -or $UserName.Trim().Length -eq 0) {
    $UserName = Read-Host "Introduce el NOMBRE DE USUARIO cuyo perfil quieres tratar (ej. jlopez)"
}
$UserName = $UserName.Trim()

# Rutas y preparación
$profilePath = Join-Path "C:\Users" $UserName
if (-not (Test-Path $profilePath)) { throw "No existe el perfil: $profilePath" }
if ($UserName -ieq $env:USERNAME) { throw "No puedes borrar el perfil del usuario con el que estás logueado." }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$destRoot = "C:\Shared"
$dest = Join-Path $destRoot ("{0}_{1}" -f $UserName, $stamp)
New-Item -ItemType Directory -Force -Path $dest | Out-Null

# Rutas base predefinidas
$relativeSources = @(
    "Contacts",
    "Documents",
    "Desktop",
    "Favorites",
    "Pictures",
    "AppData\Local\Google\Chrome",
    "AppData\Google\Chrome"
)

# Preguntar por rutas EXTRA solo para este perfilazo
Write-Host "¿Quieres añadir rutas EXTRA solo para este perfilazo?" -ForegroundColor Cyan
Write-Host " - Puedes escribir rutas RELATIVAS al perfil (p.ej. 'Downloads' o 'AppData\\Roaming\\Mozilla')" -ForegroundColor DarkGray
Write-Host " - O rutas ABSOLUTAS (p.ej. 'D:\\Trabajo', '\\\\servidor\\compartida\\carpeta')" -ForegroundColor DarkGray
$addExtra = Read-Host "Añadir rutas extra? (S/N)"
$extraList = @()
if ($addExtra -match '^[sS]') {
    $raw = Read-Host "Introduce las rutas separadas por ';' (ej: Downloads;AppData\\Roaming\\Mozilla;D:\\Otro)"
    if ($raw) {
        $extraList = $raw -split '\s*;\s*' | Where-Object { $_ -and $_.Trim().Length -gt 0 }
    }
}

# Construimos lista final de rutas a copiar
$toCopy = New-Object System.Collections.Generic.List[string]
foreach ($rel in $relativeSources) { $toCopy.Add($rel) }
foreach ($x in $extraList) { $toCopy.Add($x) }

Write-Host "Se van a COPIAR las siguientes rutas, si existen:" -ForegroundColor Yellow
foreach ($item in $toCopy) {
    # Resolver ruta: si es absoluta/UNC la usamos tal cual; si no, es relativa al perfil
    if ([System.IO.Path]::IsPathRooted($item) -or $item.StartsWith('\\')) {
        $src = $item
        $dstName = ($item -replace '[:\\\/]','_')  # nombre "seguro" para destino si es absoluto
        $dst = Join-Path $dest $dstName
    } else {
        $src = Join-Path $profilePath $item
        $dst = Join-Path $dest $item
    }
    Write-Host " - $src" -ForegroundColor DarkGray
}

# Confirmación #1 (copia)
$c1 = Read-Host "CONFIRMACIÓN 1: ¿Proceder a COPIAR datos a '$dest'? (S/N)"
if ($c1 -notmatch '^[sS]') { Write-Host "Cancelado." -ForegroundColor Yellow; return }

# Confirmación extra si hay rutas personalizadas
if ($extraList.Count -gt 0) {
    Write-Host "Rutas EXTRA a incluir:" -ForegroundColor Yellow
    $extraList | ForEach-Object { Write-Host " * $_" -ForegroundColor DarkGray }
    $c1b = Read-Host "Confirmas incluir ESTAS rutas extra solo en este perfilazo? (S/N)"
    if ($c1b -notmatch '^[sS]') { Write-Host "Se omiten rutas extra. Continuando sin extras..." -ForegroundColor Yellow; $toCopy = $relativeSources }
}

# Copiar con Robocopy (resiliente, conserva fechas)
$copied = @()
foreach ($item in $toCopy) {
    if ([System.IO.Path]::IsPathRooted($item) -or $item.StartsWith('\\')) {
        $src = $item
        $dstName = ($item -replace '[:\\\/]','_')
        $dst = Join-Path $dest $dstName
    } else {
        $src = Join-Path $profilePath $item
        $dst = Join-Path $dest $item
    }

    if (Test-Path $src) {
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        $args = @("$src", "$dst", "/E", "/COPY:DAT", "/R:2", "/W:1", "/NFL", "/NDL", "/NP", "/MT:16")
        $rc = Start-Process -FilePath robocopy.exe -ArgumentList $args -NoNewWindow -PassThru -Wait
        $copied += $src
        Write-Host "Copiado -> $src" -ForegroundColor Green
    } else {
        Write-Host "No existe -> $src (saltado)" -ForegroundColor DarkGray
    }
}

# Resumen de copia (antes de borrar)
Write-Host "`n--- RESUMEN COPIA (PRE-BORRADO) ---" -ForegroundColor Cyan
if ($copied.Count -gt 0) {
    Write-Host "Se copiaron estas rutas:" -ForegroundColor DarkGray
    $copied | ForEach-Object { Write-Host " * $_" -ForegroundColor DarkGray }
} else {
    Write-Host "No se copió ninguna ruta (ninguna existía)." -ForegroundColor Yellow
}
Write-Host "Destino: $dest" -ForegroundColor Yellow
if (Test-Path $dest) {
    # Mostrar directorio de la copia hecha (2 niveles)
    Get-ChildItem $dest -Recurse -Depth 2 | Select-Object FullName,Length,LastWriteTime | Format-Table -AutoSize
} else {
    Write-Host "No existe el directorio de destino (¿fallo de permisos?)." -ForegroundColor Yellow
}

# Doble confirmación para BORRAR perfil
Write-Host "`nSe procederá a ELIMINAR el perfil de Windows: $profilePath" -ForegroundColor Yellow
Write-Host "Esto elimina archivos del perfil y entradas asociadas. El usuario debe estar deslogueado." -ForegroundColor DarkGray
$c2 = Read-Host "CONFIRMACIÓN 2: ¿Borrar el perfil de '$UserName' usando WMI (tras verificar la copia)? (S/N)"
if ($c2 -notmatch '^[sS]') { Write-Host "Borrado cancelado. Se mantiene el perfil; la copia ya está hecha." -ForegroundColor Yellow; return }

# Borrar con WMI (más limpio que Remove-Item)
try {
    $prof = Get-CimInstance Win32_UserProfile -Filter ("LocalPath = '{0}'" -f $profilePath.Replace('\','\\'))
} catch { $prof = $null }

if ($prof) {
    try {
        Remove-CimInstance $prof -ErrorAction Stop
        Write-Host "Perfil eliminado vía WMI: $profilePath" -ForegroundColor Green
    } catch {
        Write-Warning "No se pudo eliminar el perfil vía WMI: $($_.Exception.Message)"
        Write-Host "Intentando eliminación de carpeta (fallback)..." -ForegroundColor Yellow
        try {
            Takeown.exe /F "$profilePath" /R /D Y | Out-Null
            Icacls.exe "$profilePath" /grant Administrators:(OI)(CI)F /T | Out-Null
            Remove-Item "$profilePath" -Recurse -Force -ErrorAction Stop
            Write-Host "Carpeta de perfil eliminada: $profilePath" -ForegroundColor Green
        } catch {
            Write-Warning "Fallo eliminando carpeta de perfil: $($_.Exception.Message)"
        }
    }
} else {
    Write-Host "No se encontró instancia WMI del perfil. Intentando eliminar carpeta..." -ForegroundColor Yellow
    try {
        Takeown.exe /F "$profilePath" /R /D Y | Out-Null
        Icacls.exe "$profilePath" /grant Administrators:(OI)(CI)F /T | Out-Null
        Remove-Item "$profilePath" -Recurse -Force -ErrorAction Stop
        Write-Host "Carpeta de perfil eliminada: $profilePath" -ForegroundColor Green
    } catch {
        Write-Warning "Fallo eliminando carpeta de perfil: $($_.Exception.Message)"
    }
}

# Estado final
Write-Host "`n--- ESTADO FINAL ---" -ForegroundColor Cyan
Write-Host "Destino de copia: $dest" -ForegroundColor Yellow
if (Test-Path $dest) {
    Get-ChildItem $dest | Select-Object Name,Length,LastWriteTime | Format-Table -AutoSize
}

if (Test-Path $profilePath) {
    Write-Host "La carpeta de perfil AÚN existe: $profilePath" -ForegroundColor Yellow
    Get-ChildItem $profilePath | Select-Object Name,Length,LastWriteTime | Format-Table -AutoSize
} else {
    Write-Host "La carpeta de perfil ya no existe: $profilePath" -ForegroundColor Green
}

Write-Host "`nSugerencia: reinicia sesión del usuario para recrear el perfil limpio." -ForegroundColor DarkGray
