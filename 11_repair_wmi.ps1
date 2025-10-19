# 11_repair_wmi.ps1 — Reparación de WMI (segura primero, agresiva opcional)
# Ejecutar como Administrador. ADVERTENCIA: En entornos corporativos, coordinar con TI.
[CmdletBinding()]
param(
    [switch]$SalvageOnly,   # Solo salvamento (recomendado)
    [switch]$ForceReset     # Reconstrucción completa (más agresivo)
)

function Require-Admin {
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    $p=New-Object Security.Principal.WindowsPrincipal($id)
    if (!$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Este script debe ejecutarse como Administrador."
    }
}
Require-Admin

Write-Host "Deteniendo servicios WMI dependientes..." -ForegroundColor Cyan
Stop-Service winmgmt -Force -ErrorAction SilentlyContinue
# Parar dependientes comunes (iphlpsvc a veces no depende directamente; intentamos)
Get-Service | Where-Object {$_.DependentServices.Name -contains 'winmgmt'} | ForEach-Object {
    try { Stop-Service $_.Name -Force -ErrorAction SilentlyContinue } catch {}
}

$repo = Join-Path $env:WINDIR "System32\wbem\Repository"
$backup = "$repo.bak_" + (Get-Date -Format "yyyyMMdd_HHmmss")
Copy-Item $repo $backup -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Ejecutando 'winmgmt /salvagerepository'..." -ForegroundColor Yellow
$salv = Start-Process -FilePath "winmgmt.exe" -ArgumentList "/salvagerepository" -NoNewWindow -PassThru -Wait
Write-Host "Código salida salvagerepository: $($salv.ExitCode)" -ForegroundColor DarkGray

if ($ForceReset -and -not $SalvageOnly) {
    Write-Host "Ejecutando 'winmgmt /resetrepository' (AGRESIVO)..." -ForegroundColor Yellow
    $reset = Start-Process -FilePath "winmgmt.exe" -ArgumentList "/resetrepository" -NoNewWindow -PassThru -Wait
    Write-Host "Código salida resetrepository: $($reset.ExitCode)" -ForegroundColor DarkGray

    Write-Host "Re-registrando librerías WMI..." -ForegroundColor Cyan
    pushd "$env:WINDIR\System32\wbem"
    for ($i=0; $i -lt 1; $i++) {} # placeholder
    cmd /c for %i in (*.dll) do regsvr32 /s %i
    Write-Host "Recompilando MOFs..." -ForegroundColor Cyan
    cmd /c for %i in (*.mof,*.mfl) do mofcomp %i
    popd
}

Write-Host "Iniciando servicio WMI..." -ForegroundColor Cyan
Start-Service winmgmt -ErrorAction SilentlyContinue

Write-Host "Probando consulta WMI básica (Win32_OperatingSystem)..." -ForegroundColor Cyan
try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    Write-Host "OK: $($os.Caption) $($os.Version)" -ForegroundColor Green
} catch {
    Write-Warning "WMI sigue fallando: $($_.Exception.Message)"
}

Write-Host "Reparación WMI finalizada. Reinicia si el problema persiste." -ForegroundColor Yellow
