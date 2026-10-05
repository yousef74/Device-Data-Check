```bat
@echo off
setlocal

title Device Info - Run All

echo ================================================================
echo                    DEVICE INFO TOOL
echo ================================================================
echo.

REM ================================================================
REM 1. Main Device Info Script
REM ================================================================

echo [1/3] Running Main Script...
echo.

call "%~dp0Main Script.bat"

echo.
echo ================================================================
echo Main Script completed.
echo ================================================================
echo.

REM ================================================================
REM 2. Kaspersky Check
REM ================================================================

echo [2/3] Running Kaspersky Check...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Kaspersky-Check.ps1"

echo.
echo ================================================================
echo Kaspersky Check completed.
echo ================================================================
echo.

REM ================================================================
REM 3. Battery Check
REM ================================================================

echo [3/3] Running Battery Check...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0batteryCheck.ps1"

echo.
echo ================================================================
echo Battery Check completed.
echo ================================================================
echo.

echo ================================================================
echo                 ALL CHECKS COMPLETED
echo ================================================================
echo.

pause
```
