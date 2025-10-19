@echo off
:: --- Unified Service Desk Toolkit Launcher (by malaguita) ---
:: Ejecuta PowerShell con permisos de administrador y ExecutionPolicy Bypass
PowerShell -NoProfile -ExecutionPolicy Bypass -Command ^
"Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp000_unified_launcher.ps1""' -Verb RunAs"
