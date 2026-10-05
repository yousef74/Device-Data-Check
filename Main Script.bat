```bat
@echo off
setlocal EnableExtensions

REM ================================================================
REM ADMINISTRATOR CHECK
REM ================================================================

net session >nul 2>&1

if %errorlevel% neq 0 (
    echo.
    echo ================================================================
    echo                 ADMINISTRATOR ACCESS REQUIRED
    echo ================================================================
    echo.
    echo LaptobCheck needs Administrator access to perform
    echo complete hardware and Windows diagnostics.
    echo.
    echo Requesting Administrator permission...
    echo.

    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"

    exit /b
)

REM ================================================================
REM START APPLICATION
REM ================================================================

title LaptobCheck - IT Diagnostic Tool
color 0B
cls

echo.
echo ================================================================
echo                         LAPTOBCHECK
echo                    IT DIAGNOSTIC TOOL
echo ================================================================
echo.
echo Running as Administrator
echo Computer: %COMPUTERNAME%
echo User    : %USERNAME%
echo ================================================================
echo.


REM ================================================================
REM DEVICE
REM ================================================================

echo [ DEVICE ]
echo ----------------------------------------------------------------

powershell -NoProfile -Command "$c=Get-CimInstance Win32_ComputerSystem; $p=Get-CimInstance Win32_ComputerSystemProduct; $b=Get-CimInstance Win32_BIOS; Write-Host ('Device Name    : ' + $env:COMPUTERNAME); Write-Host ('Brand          : ' + $c.Manufacturer); Write-Host ('Model Name     : ' + $p.Version); Write-Host ('Model Number   : ' + $c.Model); Write-Host ('Product Name   : ' + $p.Name); Write-Host ('Serial Number  : ' + $b.SerialNumber); Write-Host ('BIOS           : ' + $b.SMBIOSBIOSVersion)"

echo.


REM ================================================================
REM WINDOWS
REM ================================================================

echo [ WINDOWS ]
echo ----------------------------------------------------------------

powershell -NoProfile -Command "$o=Get-CimInstance Win32_OperatingSystem; Write-Host ('Edition        : ' + $o.Caption); Write-Host ('Version        : ' + $o.Version); Write-Host ('Build          : ' + $o.BuildNumber); Write-Host ('Architecture   : ' + $o.OSArchitecture)"

echo.


REM ================================================================
REM WINDOWS LICENSE
REM ================================================================

echo [ WINDOWS LICENSE ]
echo ----------------------------------------------------------------

powershell -NoProfile -Command "$x=Get-CimInstance SoftwareLicensingProduct -ErrorAction SilentlyContinue | Where-Object {$_.PartialProductKey -and $_.Name -like 'Windows*'} | Select-Object -First 1; if($x){Write-Host ('License        : ' + $x.Description); Write-Host ('Partial Key    : ' + $x.PartialProductKey); if($x.LicenseStatus -eq 1){Write-Host 'Status         : ACTIVATED'}else{Write-Host 'Status         : NOT ACTIVATED'}}else{Write-Host 'License        : Not detected'}"

echo.


REM ================================================================
REM PRODUCT KEYS
REM ================================================================

echo [ WINDOWS PRODUCT KEYS ]
echo ----------------------------------------------------------------

powershell -NoProfile -Command "$r='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform'; $k=(Get-ItemProperty $r -ErrorAction SilentlyContinue).BackupProductKeyDefault; if($k){Write-Host ('Registry Key   : ' + $k)}else{Write-Host 'Registry Key   : Not available'}; $o=(Get-CimInstance SoftwareLicensingService -ErrorAction SilentlyContinue).OA3OriginalProductKey; if($o){Write-Host ('BIOS Key       : ' + $o)}else{Write-Host 'BIOS Key       : Not available'}"

echo.


REM ================================================================
REM PROCESSOR
REM ================================================================

echo [ PROCESSOR ]
echo ----------------------------------------------------------------

powershell -NoProfile -Command "$p=Get-CimInstance Win32_Processor | Select-Object -First 1; Write-Host ('CPU            : ' + $p.Name); Write-Host ('Cores          : ' + $p.NumberOfCores); Write-Host ('Threads        : ' + $p.NumberOfLogicalProcessors); Write-Host ('Max Speed      : ' + $p.MaxClockSpeed + ' MHz')"

echo.


REM ================================================================
REM RAM
REM ================================================================

echo [ RAM ]
echo ----------------------------------------------------------------

powershell -NoProfile -Command "$c=Get-CimInstance Win32_ComputerSystem; Write-Host ('Total RAM      : ' + [math]::Round($c.TotalPhysicalMemory/1GB,2) + ' GB'); Get-CimInstance Win32_PhysicalMemory | ForEach-Object {Write-Host ('RAM Module     : ' + [math]::Round($_.Capacity/1GB,2) + ' GB | Speed: ' + $_.Speed + ' MHz | Manufacturer: ' + $_.Manufacturer)}"

echo.


REM ================================================================
REM GRAPHICS
REM ================================================================

echo [ GRAPHICS ]
echo ----------------------------------------------------------------

powershell -NoProfile -Command "Get-CimInstance Win32_VideoController | ForEach-Object {Write-Host ('GPU            : ' + $_.Name); Write-Host ('Driver         : ' + $_.DriverVersion); Write-Host ''}"

echo.


REM ================================================================
REM STORAGE
REM ================================================================

echo [ STORAGE ]
echo ----------------------------------------------------------------

powershell -NoProfile -Command "Get-CimInstance Win32_DiskDrive | ForEach-Object {Write-Host ('Disk           : ' + $_.Model); Write-Host ('Size           : ' + [math]::Round($_.Size/1GB,2) + ' GB'); Write-Host ''}; Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {Write-Host ($_.DeviceID + ' Total: ' + [math]::Round($_.Size/1GB,2) + ' GB | Free: ' + [math]::Round($_.FreeSpace/1GB,2) + ' GB')}"

echo.


REM ================================================================
REM NETWORK - WIFI
REM ================================================================

echo [ NETWORK - WIFI ]
echo ----------------------------------------------------------------

powershell -NoProfile -Command "$a=Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {$_.Name -match 'Wi-Fi|Wireless'}; if($a){foreach($n in $a){$ip=Get-NetIPAddress -InterfaceIndex $n.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress -notlike '169.254*'} | Select-Object -First 1; $gw=(Get-NetIPConfiguration -InterfaceIndex $n.ifIndex -ErrorAction SilentlyContinue).IPv4DefaultGateway.NextHop; Write-Host ('Adapter        : ' + $n.Name); Write-Host ('Status         : ' + $n.Status); Write-Host ('MAC Address    : ' + $n.MacAddress); if($ip){Write-Host ('IPv4 Address   : ' + $ip.IPAddress)}else{Write-Host 'IPv4 Address   : Not connected'}; if($gw){Write-Host ('Gateway        : ' + $gw)}else{Write-Host 'Gateway        : Not connected'}}}else{Write-Host 'Wi-Fi          : Not detected'}"

echo.


REM ================================================================
REM NETWORK - LAN / ETHERNET
REM ================================================================

echo [ NETWORK - LAN / ETHERNET ]
echo ----------------------------------------------------------------

powershell -NoProfile -Command "$a=Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object {$_.Name -notmatch 'Wi-Fi|Wireless|Bluetooth'}; if($a){foreach($n in $a){$ip=Get-NetIPAddress -InterfaceIndex $n.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress -notlike '169.254*'} | Select-Object -First 1; $gw=(Get-NetIPConfiguration -InterfaceIndex $n.ifIndex -ErrorAction SilentlyContinue).IPv4DefaultGateway.NextHop; Write-Host ('Adapter        : ' + $n.Name); Write-Host ('Status         : ' + $n.Status); Write-Host ('MAC Address    : ' + $n.MacAddress); if($ip){Write-Host ('IPv4 Address   : ' + $ip.IPAddress)}else{Write-Host 'IPv4 Address   : Not connected'}; if($gw){Write-Host ('Gateway        : ' + $gw)}else{Write-Host 'Gateway        : Not connected'}}}else{Write-Host 'Ethernet       : Not detected'}"

echo.


REM ================================================================
REM DOMAIN
REM ================================================================

echo [ DOMAIN ]
echo ----------------------------------------------------------------

powershell -NoProfile -Command "$c=Get-CimInstance Win32_ComputerSystem; Write-Host ('Domain         : ' + $c.Domain); Write-Host ('Domain Joined  : ' + $c.PartOfDomain)"

echo.


REM ================================================================
REM MICROSOFT OFFICE
REM ================================================================

echo [ MICROSOFT OFFICE ]
echo ----------------------------------------------------------------

powershell -NoProfile -Command "$p=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'); $x=Get-ItemProperty $p -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName -match 'Microsoft 365|Microsoft Office|Office LTSC'}; if($x){foreach($o in $x){Write-Host ('Office         : ' + $o.DisplayName); Write-Host ('Version        : ' + $o.DisplayVersion)}}else{Write-Host 'Office         : Not detected'}"

echo.


REM ================================================================
REM ADMIN DIAGNOSTIC CHECKS
REM ================================================================

echo [ ADMIN DIAGNOSTICS ]
echo ----------------------------------------------------------------

echo Checking TPM...

powershell -NoProfile -Command "$t=Get-Tpm -ErrorAction SilentlyContinue; if($t){Write-Host ('TPM Present    : ' + $t.TpmPresent); Write-Host ('TPM Ready      : ' + $t.TpmReady)}else{Write-Host 'TPM            : Unable to detect'}"

echo.

echo Checking Secure Boot...

powershell -NoProfile -Command "try{Write-Host ('Secure Boot    : ' + (Confirm-SecureBootUEFI -ErrorAction Stop))}catch{Write-Host 'Secure Boot    : Not supported / Legacy BIOS'}"

echo.

echo Checking Windows Defender...

powershell -NoProfile -Command "$d=Get-MpComputerStatus -ErrorAction SilentlyContinue; if($d){Write-Host ('Defender       : ' + $d.AMServiceEnabled); Write-Host ('Real-Time      : ' + $d.RealTimeProtectionEnabled)}else{Write-Host 'Defender       : Unable to detect'}"

echo.

echo Checking physical disks...

powershell -NoProfile -Command "$d=Get-PhysicalDisk -ErrorAction SilentlyContinue; if($d){$d | ForEach-Object {Write-Host ('Disk           : ' + $_.FriendlyName + ' | Health: ' + $_.HealthStatus + ' | Type: ' + $_.MediaType)}}else{Write-Host 'Disk           : Unable to detect'}"

echo.


REM ================================================================
REM COMPLETE
REM ================================================================

echo.
echo ================================================================
echo                    INFORMATION COMPLETE
echo ================================================================
echo.
echo LaptobCheck was executed with Administrator privileges.
echo.
echo ================================================================
echo.
pause

endlocal
```
