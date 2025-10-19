# Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [switch]$PurgeCcmCache,     # Opcional: borra C:\Windows\ccmcache
    [int]$PolicyWaitSeconds = 20
)

$ccmSvc = 'CcmExec' # SMS Agent Host

function Kill-Proc($n){ Get-Process $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }

Write-Host "Deteniendo procesos SCCM/SC..." -f Cyan
Kill-Proc 'SCClient','SCNotification','TSManager','CCMSetup','CCMRepair'

if ($PurgeCcmCache -and (Test-Path 'C:\Windows\ccmcache')) {
    Write-Host "Vaciando ccmcache..." -f Cyan
    try { Remove-Item 'C:\Windows\ccmcache\*' -Recurse -Force -ErrorAction SilentlyContinue } catch {}
}

Write-Host "Reiniciando servicio CcmExec..." -f Cyan
Stop-Service $ccmSvc -Force -ErrorAction SilentlyContinue
Start-Service $ccmSvc -ErrorAction SilentlyContinue

$triggers = @(
    '{00000000-0000-0000-0000-000000000021}', # Machine Policy Retrieval & Evaluation
    '{00000000-0000-0000-0000-000000000121}'  # Application Deployment Evaluation
)

Write-Host "Disparando ciclos de cliente..." -f Cyan
$null = Invoke-CimMethod -Namespace 'root\ccm' -ClassName 'SMS_Client' -MethodName 'TriggerSchedule' -Arguments @{sScheduleID=$triggers[0]} -ErrorAction SilentlyContinue
Start-Sleep -Seconds $PolicyWaitSeconds
$null = Invoke-CimMethod -Namespace 'root\ccm' -ClassName 'SMS_Client' -MethodName 'TriggerSchedule' -Arguments @{sScheduleID=$triggers[1]} -ErrorAction SilentlyContinue

Write-Host "Abriendo Software Center (si existe)..." -f Cyan
$sc = "$env:WINDIR\CCM\ClientUX\SCClient.exe"
if (Test-Path $sc) { Start-Process $sc } else { Write-Host "SCClient.exe no encontrado aún. Espera 1–2 minutos." -f Yellow }

Write-Host "Listo. Si Software Center no aparece, reintenta el script o verifica conectividad al MP/DP." -f Green
