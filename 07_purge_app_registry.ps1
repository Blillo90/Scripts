# 07_purge_app_registry.ps1
# Requiere PowerShell elevado (Run as Administrator)
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$false)]
    [string]$AppName,

    [switch]$IncludeServices,        # También limpia claves de servicios relacionadas
    [switch]$AlsoCurrentUser,        # Incluye HKCU del usuario que ejecuta
    [switch]$WhatIfOnly              # Simula sin borrar (además del -WhatIf estándar)
)

function Require-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    if (!$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Este script debe ejecutarse como Administrador."
    }
}
Require-Admin

if (-not $AppName -or $AppName.Trim().Length -eq 0) {
    $AppName = Read-Host "Introduce el nombre de la aplicación a purgar (ej. 'Cisco', '7-Zip')"
}
$AppName = $AppName.Trim()
if ($AppName.Length -lt 2) { throw "El nombre es demasiado corto." }

$escaped = [Regex]::Escape($AppName)
$pattern = "(?i)\b$escaped\b"

$targets = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE',
    'HKLM:\SOFTWARE\WOW6432Node',
    'HKCU:\SOFTWARE',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths'
)

if (-not $AlsoCurrentUser) {
    $targets = $targets | Where-Object { $_ -notlike 'HKCU:*' }
}

if ($IncludeServices) {
    $targets += 'HKLM:\SYSTEM\CurrentControlSet\Services'
}

function Convert-ToRegExePath {
    param([string]$PsPath)
    $p = $PsPath.Replace('HKLM:\','HKEY_LOCAL_MACHINE\').Replace('HKCU:\','HKEY_CURRENT_USER\')
    return $p
}

$matches = New-Object System.Collections.Generic.List[Hashtable]

Write-Host "Buscando restos de '$AppName' en el registro..." -ForegroundColor Cyan

foreach ($root in $targets) {
    if (-not (Test-Path $root)) { continue }

    if ($root -match '\\Uninstall$') {
        Get-ChildItem $root -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $props = Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue
                $hit = $false
                if ($_.PSChildName -match $pattern) { $hit = $true }
                foreach ($field in @('DisplayName','Publisher','DisplayVersion','InstallLocation','UninstallString')) {
                    if ($props.$field -and ($props.$field -match $pattern)) { $hit = $true }
                }
                if ($hit) {
                    $matches.Add(@{ PsPath=$_.PsPath; Root=$root; Type='Uninstall'; Name=$props.DisplayName; Publisher=$props.Publisher })
                }
            } catch { }
        }
        continue
    }

    if ($root -match '\\Services$') {
        Get-ChildItem $root -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $props = Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue
                $hit = ($_.PSChildName -match $pattern) -or ($props.DisplayName -and $props.DisplayName -match $pattern)
                if ($hit) {
                    $matches.Add(@{ PsPath=$_.PsPath; Root=$root; Type='Service'; Name=$props.DisplayName; Publisher=$null })
                }
            } catch { }
        }
        continue
    }

    Get-ChildItem $root -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $props = Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue
            $hit = ($_.PSChildName -match $pattern)
            foreach ($field in @('DisplayName','Publisher','Path','(default)','InstallLocation','InprocServer32')) {
                if (-not $hit -and $props.$field -and ($props.$field -match $pattern)) { $hit = $true }
            }
            if ($hit) {
                $matches.Add(@{ PsPath=$_.PsPath; Root=$root; Type='Key'; Name=$_.PSChildName; Publisher=$props.Publisher })
            }
        } catch { }
    }
}

if ($matches.Count -eq 0) {
    Write-Host "No se encontraron claves relacionadas con '$AppName' en las ubicaciones objetivo." -ForegroundColor Yellow
    return
}

Write-Host "`nSe han encontrado $($matches.Count) claves candidatas:" -ForegroundColor Green
$matches | Select-Object Type, Name, @{n='Hive';e={ ($_['PsPath'] -split ':')[0] }}, @{n='Ruta';e={ $_['PsPath'] }} | Format-Table -AutoSize

$confirm = Read-Host "`n¿Quieres exportar y eliminar TODAS estas claves? (S/N)"
if ($confirm -notin @('S','s','Y','y','Sí','Si','yes')) {
    Write-Host "Operación cancelada." -ForegroundColor Yellow
    return
}

$backupRoot = "C:\RegBackups\Purge_$($AppName.Replace(' ','_'))" + "_" + (Get-Date -Format 'yyyyMMdd_HHmmss')
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

$errors = 0
foreach ($m in $matches) {
    $ps = $m['PsPath']
    if (-not (Test-Path $ps)) { continue }

    $regPath = Convert-ToRegExePath $ps
    $fname = ($regPath -replace '[\\/:*?""<>|]','_') + ".reg"
    $dest = Join-Path $backupRoot $fname

    try {
        & reg.exe export "$regPath" "$dest" /y | Out-Null
        Write-Host "Backup: $regPath -> $dest" -ForegroundColor DarkGray

        if ($PSCmdlet.ShouldProcess($ps, "Remove-Item -Recurse -Force") -and -not $WhatIfOnly) {
            Remove-Item -LiteralPath $ps -Recurse -Force -ErrorAction Stop
            Write-Host "Eliminada: $ps" -ForegroundColor Cyan
        } else {
            Write-Host "Simulación (no borrado): $ps" -ForegroundColor Yellow
        }
    } catch {
        $errors++
        Write-Warning "Fallo con $ps : $($_.Exception.Message)"
    }
}

Write-Host "`nBackup de registro en: $backupRoot" -ForegroundColor Green
if ($WhatIfOnly) {
    Write-Host "Ejecutado en modo simulación (WhatIfOnly). Repite sin -WhatIfOnly para aplicar." -ForegroundColor Yellow
}
if ($errors -gt 0) {
    Write-Warning "Terminado con $errors errores. Revisa permisos / claves protegidas."
} else {
    Write-Host "Limpieza de registro para '$AppName' completada." -ForegroundColor Green
}
Write-Host "`nSugerencia: reinicia antes de reinstalar en limpio."
