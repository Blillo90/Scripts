[CmdletBinding()]
param()

function GB($b){ [Math]::Round($b/1GB,2) }

$cpu = Get-CimInstance Win32_Processor | Select-Object Name, LoadPercentage
$mem = Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory
$disk = Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Name -eq 'C'} | Select-Object Used, Free

Write-Host "CPU: $($cpu.Name) | Carga: $($cpu.LoadPercentage)%" -f Cyan
$totalGB = [math]::Round(($mem.TotalVisibleMemorySize*1KB)/1GB,2)
$freeGB  = [math]::Round(($mem.FreePhysicalMemory*1KB)/1GB,2)
Write-Host "RAM Total: $totalGB GB | Libre: $freeGB GB" -f Cyan
Write-Host "C: Libre $(GB $disk.Free) GB / Usado $(GB $disk.Used) GB" -f Cyan

Write-Host "`nTop 10 procesos por RAM:" -f Yellow
Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 Name, @{n='RAM(GB)';e={ [math]::Round($_.WorkingSet/1GB,2) }} | Format-Table -AutoSize

Write-Host "`nAplicaciones en Inicio (usuario actual):" -f Yellow
Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location | Format-Table -AutoSize
