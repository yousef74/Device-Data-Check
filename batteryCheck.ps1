```powershell
# ============================================
# Battery Health Checker
# ============================================

$ReportPath = "$env:USERPROFILE\Desktop\battery-report.html"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "           BATTERY HEALTH CHECK             " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Generate Windows Battery Report
Write-Host "Generating battery report..." -ForegroundColor Yellow

powercfg /batteryreport /output "$ReportPath" | Out-Null

if (!(Test-Path $ReportPath)) {
    Write-Host ""
    Write-Host "ERROR: Battery report could not be created." -ForegroundColor Red
    exit
}

Write-Host "Report created successfully." -ForegroundColor Green
Write-Host ""

# Read the HTML report
$html = Get-Content $ReportPath -Raw

# Extract Design Capacity
$designMatch = [regex]::Match(
    $html,
    '(?i)DESIGN CAPACITY.*?([0-9,]+)\s*mWh'
)

# Extract Full Charge Capacity
$fullMatch = [regex]::Match(
    $html,
    '(?i)FULL CHARGE CAPACITY.*?([0-9,]+)\s*mWh'
)

if (!$designMatch.Success -or !$fullMatch.Success) {
    Write-Host "ERROR: Could not read battery capacity information." -ForegroundColor Red
    Write-Host ""
    Write-Host "Open the generated report manually:" -ForegroundColor Yellow
    Write-Host $ReportPath
    exit
}

# Convert values to numbers
$DesignCapacity = [double]($designMatch.Groups[1].Value -replace ',', '')
$FullCapacity   = [double]($fullMatch.Groups[1].Value -replace ',', '')

# Calculate actual battery health
$Health = ($FullCapacity / $DesignCapacity) * 100

# Health percentage limited to 100% for user display
$DisplayHealth = [math]::Min($Health, 100)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "              BATTERY RESULT               " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

Write-Host ""
Write-Host ("Design Capacity : {0:N0} mWh" -f $DesignCapacity)
Write-Host ("Full Capacity   : {0:N0} mWh" -f $FullCapacity)
Write-Host ("Actual Health   : {0:N2}%" -f $Health)
Write-Host ("Display Health  : {0:N0}%" -f $DisplayHealth)

Write-Host ""

if ($Health -ge 90) {
    Write-Host "Battery Status   : EXCELLENT" -ForegroundColor Green
}
elseif ($Health -ge 80) {
    Write-Host "Battery Status   : GOOD" -ForegroundColor Green
}
elseif ($Health -ge 60) {
    Write-Host "Battery Status   : FAIR" -ForegroundColor Yellow
}
else {
    Write-Host "Battery Status   : WEAK" -ForegroundColor Red
}

Write-Host ""
Write-Host "Battery report:"
Write-Host $ReportPath
Write-Host ""

Write-Host "============================================" -ForegroundColor Cyan
```
