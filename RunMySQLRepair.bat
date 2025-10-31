@echo off
:: =============================================
:: MySQL Auto Repair Launcher
:: By: Unknownplanet40 (because we learn the hard way 😅)
:: =============================================

set "SCRIPT_PATH=%~dp0MySQLRepair.ps1"
set "POWERSHELL_EXE=powershell.exe"

color 0A
title MySQL Auto Repair Launcher

echo [===== MySQL Auto Repair Launcher =====]
echo.
echo This will attempt to fix MySQL corruption issues safely.
echo Make sure XAMPP and MySQL are installed and closed.
echo.
echo Running with admin privileges is REQUIRED.
echo --------------------------------------------
echo.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
) 

echo Select mode:
echo [1] Normal Mode
:: echo [2] WhatIf (Test only)
echo [2] Verbose (Detailed output)
:: echo [4] WhatIf + Verbose
echo.
:: set /p mode="Enter choice (1-4): "
set /p mode="Enter choice (1 or 2): "

::  if "%mode%"=="2" set "PS_ARGS=-WhatIf"
if "%mode%"=="2" set "PS_ARGS=-Verbose"
::  if "%mode%"=="4" set "PS_ARGS=-WhatIf -Verbose"

echo.
echo Launching PowerShell script...
echo --------------------------------------------
%POWERSHELL_EXE% -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" %PS_ARGS%

echo.
echo --------------------------------------------
echo MySQL Repair Script has finished running.
pause
exit /b