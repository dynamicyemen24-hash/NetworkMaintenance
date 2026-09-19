@echo off
echo ============================================
echo   Elias Pro v4.1 � ????? ???
echo   Maintenance-Only Edition + Shop Integration
echo   IT Network + Mobile/PC/Electronics Repair
echo ============================================
echo.
echo [1] Full Enterprise (IT + Shop Maintenance)  [Full]
echo [2] Network Diagnostics Only                 [diag]
echo [3] Safe Cleaning (SCE)                      [clean]
echo [4] Hardware Diagnostics (HDR)               [hdr]
echo [5] Battery Deep Diagnostics                 [batt]
echo [6] Storage Diagnostics (SMART)              [storage]
echo [7] Stress Test (CPU/RAM)                    [stress]
echo [8] Network Advanced (NETDIAG)               [netdiag]
echo [9] Shop Suite (REPAIR/CRM/PARTS)            [shop]
echo [10] Open Source Toolkit Check               [toolkit]
echo [11] Dashboard (Browser)                     [dash]
echo [12] API Server                              [api]
echo [13] Exit
echo [14] Publish Customer Link (Share Server)
echo.
set /p CHOICE="Select option (1-13): "

if "%CHOICE%"=="1" powershell.exe -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Run.ps1" full
if "%CHOICE%"=="2" powershell.exe -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Run.ps1" diagnostics
if "%CHOICE%"=="3" powershell.exe -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Scripts\Engines\SCE-Engine.ps1" -SafetyLevel Balanced -DryRun
if "%CHOICE%"=="4" powershell.exe -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Scripts\Engines\HDR-Engine.ps1" -DeviceType Auto
if "%CHOICE%"=="5" powershell.exe -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Scripts\Engines\BATT-Engine.ps1" -DeviceType Auto
if "%CHOICE%"=="6" powershell.exe -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Scripts\Engines\STORAGE-Engine.ps1" -Benchmark
if "%CHOICE%"=="7" powershell.exe -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Scripts\Engines\STRESS-Engine.ps1" -TestType Quick -DurationSeconds 30
if "%CHOICE%"=="8" powershell.exe -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Scripts\Engines\NETDIAG-Engine.ps1" -Target 8.8.8.8 -PingCount 20
if "%CHOICE%"=="9" powershell.exe -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Run.ps1" shop
if "%CHOICE%"=="10" powershell.exe -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Scripts\Tools\OpenSourceToolkit.ps1"
if "%CHOICE%"=="11" start "" "C:\NetworkMaintenance\Dashboard\shop.html"
if "%CHOICE%"=="12" powershell.exe -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\API\Server.ps1" -Port 8080
if "%CHOICE%"=="13" exit
if "%CHOICE%"=="14" start "Elias Pro Share Server" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\NetworkMaintenance\Share\Publish-Dashboard.ps1" -Firewall
pause



