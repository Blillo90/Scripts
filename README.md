# Unified Service Desk Toolkit (Básico + Avanzado)

## Estructura
- **00_unified_launcher.ps1** — Launcher con dos menús:
  - **Básico**: Windows & Office (L2).
  - **Avanzado**: VPN Cisco, Docks, SCCM, Purga Registro, WMI, Event Logs.

## Logging
- Cada sesión guarda traza en `C:\SDToolLogs\UnifiedToolkit_*.txt` mediante `Start-Transcript`.

## ExecutionPolicy
- Al arrancar aplica **Bypass (Process)** y muestra el estado actual.

## Scripts incluidos (principales)
- Básico: `01_cleanup.ps1`, `06_quick_diag.ps1`, `09_office_teams_cleanup.ps1`, `10_onedrive_reset.ps1`.
- Avanzado: `03_fix_cisco_secure_client.ps1`, `04_reset_dock.ps1`, `05_mecm_softwarecenter_kick.ps1`, `07_purge_app_registry.ps1`, `11_repair_wmi.ps1`, `08_clear_eventlogs.ps1`.

> Ejecutar SIEMPRE como Administrador.
