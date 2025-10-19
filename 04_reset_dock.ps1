# Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [switch]$TryDisplayLink,     # Reinicia servicio DisplayLink si existe
    [switch]$ResetUSBHubs,       # Deshabilita/Habilita USB Root Hubs (corte de periféricos ~3-5s)
    [switch]$ResetDockNICs       # Deshabilita/Habilita NICs USB/Realtek/DisplayLink/Intel USB
)

function Restart-ServiceIfExists($name) {
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Host "Reiniciando servicio: $name" -f Cyan
        Stop-Service $name -Force -ErrorAction SilentlyContinue
        Start-Service $name -ErrorAction SilentlyContinue
    }
}

Restart-ServiceIfExists -name 'ThunderboltService'
if ($TryDisplayLink) {
    Restart-ServiceIfExists -name 'DisplayLinkManager'
    Restart-ServiceIfExists -name 'DLSService'
}

if ($ResetUSBHubs) {
    Write-Host "Reseteando USB Root Hubs..." -f Cyan
    $hubs = Get-PnpDevice -Class 'USB' -FriendlyName '*Root Hub*' -Status OK -ErrorAction SilentlyContinue
    foreach ($h in $hubs) {
        try {
            Disable-PnpDevice -InstanceId $h.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 800
            Enable-PnpDevice  -InstanceId $h.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "Reset: $($h.FriendlyName)" -f Green
        } catch { Write-Warning "No se pudo resetear: $($h.FriendlyName)" }
    }
}

if ($ResetDockNICs) {
    Write-Host "Reseteando NICs del dock..." -f Cyan
    $nics = Get-NetAdapter | Where-Object {
        $_.InterfaceDescription -match 'Realtek.*USB|DisplayLink|Intel.*USB|HP Dock|USB.*Gigabit'
    }
    foreach ($n in $nics) {
        try {
            Disable-NetAdapter -Name $n.Name -Confirm:$false -PassThru | Out-Null
            Start-Sleep -Seconds 2
            Enable-NetAdapter -Name $n.Name -Confirm:$false -PassThru | Out-Null
            Write-Host "Reset NIC: $($n.Name)" -f Green
        } catch { Write-Warning "No se pudo resetear NIC: $($n.Name)" }
    }
}

Write-Host "Listo. Si sigue sin reconocer monitores/USB, desconecta corriente del dock 15s y vuelve a conectar." -f Yellow
