# Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [switch]$Deep,               # Incluye caché Windows Update y Prefetch
    [switch]$BrowserCaches,      # Limpia cachés de Chrome/Edge/Firefox del usuario actual
    [switch]$AllProfiles         # Intenta limpiar cachés de todos los perfiles (más lento)
)

function Stop-IfRunning($names) {
    foreach ($n in $names) { Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
}

Write-Host "Cerrando apps ruidosas (browsers/Office)..." -f Cyan
Stop-IfRunning @('chrome','msedge','firefox','winword','excel','powerpnt')

function Get-UserProfiles {
    if ($AllProfiles) {
        Get-ChildItem 'C:\Users' -Directory | Where-Object { $_.Name -notin @('Public','Default','Default User','All Users') }
    } else {
        ,(Get-Item "C:\Users\$env:USERNAME")
    }
}

$paths = @(
    "$env:TEMP\*",
    "C:\Windows\Temp\*"
)

if ($Deep) {
    $paths += @(
        "C:\Windows\Prefetch\*",
        "C:\Windows\SoftwareDistribution\Download\*"
    )
}

if ($BrowserCaches) {
    $profiles = Get-UserProfiles
    foreach ($p in $profiles) {
        $paths += @(
            "$($p.FullName)\AppData\Local\Google\Chrome\User Data\Default\Cache\*",
            "$($p.FullName)\AppData\Local\Microsoft\Edge\User Data\Default\Cache\*",
            "$($p.FullName)\AppData\Local\Mozilla\Firefox\Profiles\*\cache2\*"
        )
    }
}

$deleted = 0
foreach ($pat in $paths | Select-Object -Unique) {
    if (Test-Path $pat) {
        try {
            $count = (Get-ChildItem -LiteralPath $pat -Force -ErrorAction SilentlyContinue | Measure-Object).Count
            Remove-Item -LiteralPath $pat -Recurse -Force -ErrorAction SilentlyContinue
            $deleted += $count
            Write-Host "Limpio: $pat ($count elementos)" -f Green
        } catch { Write-Warning "No se pudo limpiar: $pat - $($_.Exception.Message)" }
    }
}

if ($Deep) {
    Write-Host "Reiniciando servicios de Windows Update (si procede)..." -f Cyan
    $svc = 'wuauserv','bits'
    foreach ($s in $svc) { Stop-Service $s -Force -ErrorAction SilentlyContinue }
    foreach ($s in $svc) { Start-Service $s -ErrorAction SilentlyContinue }
}

Write-Host "Hecho. Elementos eliminados aproximados: $deleted" -f Yellow
