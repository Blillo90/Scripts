# Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [switch]$HardReset,                # Limpieza de perfiles/preferences
    [string]$ProfileSource             # Ruta a perfil .xml corporativo para restaurar (opcional)
)

$services = @('vpnagent')  # Cisco Secure Client/AnyConnect Agent

function Restart-Services($names) {
    foreach ($n in $names) {
        Get-Service $n -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "Reiniciando servicio: $($_.Name)" -f Cyan
            Stop-Service $_ -Force -ErrorAction SilentlyContinue
            Start-Service $_ -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "Paso 1: Flush DNS / renovar IP" -f Cyan
ipconfig /flushdns | Out-Null

Write-Host "Paso 2: Reiniciar servicio AnyConnect" -f Cyan
Restart-Services $services

if ($HardReset) {
    Write-Host "Paso 3: Reset de Winsock/TCP-IP (requiere reinicio posterior)" -f Cyan
    netsh winsock reset | Out-Null
    netsh int ip reset | Out-Null

    Write-Host "Paso 4: Limpiar perfiles/preferences (con copia de seguridad)" -f Cyan
    $paths = @(
        "C:\ProgramData\Cisco\Cisco AnyConnect Secure Mobility Client\Profile",
        "C:\ProgramData\Cisco\Cisco Secure Client\VPN\Profile",
        "$env:ProgramData\Cisco\Cisco AnyConnect Secure Mobility Client\preferences.xml",
        "$env:ProgramData\Cisco\Cisco Secure Client\VPN\preferences.xml"
    )
    $backup = "C:\ProgramData\Cisco\Backup_$(Get-Date -Format yyyyMMdd_HHmmss)"
    New-Item -ItemType Directory -Force -Path $backup | Out-Null

    foreach ($p in $paths) {
        if (Test-Path $p) {
            Copy-Item $p $backup -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Limpiado: $p" -f Green
        }
    }

    if ($ProfileSource -and (Test-Path $ProfileSource)) {
        $dest = "C:\ProgramData\Cisco\Cisco Secure Client\VPN\Profile"
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        Copy-Item $ProfileSource $dest -Force
        Write-Host "Perfil restaurado desde: $ProfileSource" -f Yellow
    }

    Write-Host "Reiniciando servicio de nuevo..." -f Cyan
    Restart-Services $services
    Write-Host "IMPORTANTE: Reiniciar el equipo para aplicar Winsock/TCP-IP reset." -f Magenta
} else {
    Write-Host "Fix rápido completado (sin hard reset)." -f Green
}
