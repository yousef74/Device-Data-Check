#requires -Version 5.1

# ================================================================
# Kaspersky Endpoint Security Diagnostic Tool
# ================================================================
# Requires Administrator privileges
# Designed for Kaspersky Endpoint Security + Network Agent
# ================================================================

$ErrorActionPreference = "SilentlyContinue"

# ------------------------------------------------
# ADMINISTRATOR CHECK / AUTO ELEVATION
# ------------------------------------------------

$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)

if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Write-Host ""
    Write-Host "Administrator privileges are required." -ForegroundColor Yellow
    Write-Host "Requesting Administrator access..." -ForegroundColor Yellow
    Write-Host ""

    $ScriptPath = $PSCommandPath
    if (-not $ScriptPath) { $ScriptPath = $MyInvocation.MyCommand.Definition }

    try {
        Start-Process powershell.exe `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" `
            -Verb RunAs
    }
    catch {
        Write-Host "Unable to request Administrator privileges." -ForegroundColor Red
        Read-Host "Press ENTER to exit"
    }

    exit
}

# ------------------------------------------------
# HELPERS
# ------------------------------------------------

Clear-Host

$StartTime = Get-Date

# Program Files (x86) must be wrapped in braces, otherwise
# "$env:ProgramFiles(x86)" is parsed as $env:ProgramFiles + "(x86)".
$PF64 = ${env:ProgramFiles}
$PF32 = ${env:ProgramFiles(x86)}

function Show-Result {
    param(
        [string]$Name,
        [string]$Value,
        [string]$Color = "White"
    )

    Write-Host ("{0,-34}: " -f $Name) -NoNewline
    Write-Host $Value -ForegroundColor $Color
}

function Get-ColorForService {
    param($Service)

    if ($null -eq $Service) { return "Red" }
    if ($Service.Status -eq "Running") { return "Green" }
    return "Red"
}

function Get-KasperskyFolders {

    $Folders = @()

    $PossibleRoots = @($PF64, $PF32, ${env:ProgramData})

    foreach ($Root in $PossibleRoots) {

        if (-not $Root) { continue }

        $KasperskyRoot = Join-Path $Root "Kaspersky Lab"

        if (Test-Path $KasperskyRoot) {
            $Folders += $KasperskyRoot
        }
    }

    return $Folders | Select-Object -Unique
}

# Returns the installed-program entry (same source as Programs and
# Features / the KES "About" version) with the highest DisplayVersion.
function Get-InstalledProduct {
    param(
        [string]$Include,
        [string]$Exclude
    )

    $UninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $Found = Get-ItemProperty $UninstallPaths -ErrorAction SilentlyContinue |
        Where-Object {
            $_.DisplayName -and
            $_.DisplayVersion -and
            $_.DisplayName -match $Include -and
            ((-not $Exclude) -or ($_.DisplayName -notmatch $Exclude))
        }

    $Found |
        Sort-Object {
            try { [version]$_.DisplayVersion } catch { [version]"0.0" }
        } -Descending |
        Select-Object -First 1
}

# Returns the full 4-part version (e.g. 14.1.0.1234) of an executable.
function Get-FullFileVersion {
    param([string]$Path)

    if (-not $Path -or -not (Test-Path $Path)) { return $null }

    $Info = (Get-Item $Path).VersionInfo

    if ($Info.FileMajorPart -gt 0) {
        return ("{0}.{1}.{2}.{3}" -f `
            $Info.FileMajorPart, $Info.FileMinorPart,
            $Info.FileBuildPart, $Info.FilePrivatePart)
    }

    if ($Info.ProductVersion) { return $Info.ProductVersion }
    return $Info.FileVersion
}

# Extracts the executable path from a service's PathName.
function Get-ServiceExePath {
    param([string]$ServiceName)

    if (-not $ServiceName) { return $null }

    $Cim = Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue

    if (-not $Cim -or -not $Cim.PathName) { return $null }

    $Path = $Cim.PathName.Trim()

    if ($Path -match '^"([^"]+)"') {
        return $Matches[1]
    }

    if ($Path -match '^(.+?\.exe)') {
        return $Matches[1]
    }

    return $Path
}

# ================================================================
# HEADER
# ================================================================

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "          KASPERSKY ENDPOINT SECURITY CHECK" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

Show-Result "Check Started" $StartTime.ToString("yyyy-MM-dd HH:mm:ss")

# ================================================================
# DEVICE
# ================================================================

Write-Host ""
Write-Host "DEVICE INFORMATION" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------"

Show-Result "Computer Name" $env:COMPUTERNAME
Show-Result "User" $env:USERNAME

# ================================================================
# KASPERSKY SERVICES (detected first so versions can use them)
# ================================================================

$KasperskyFolders = Get-KasperskyFolders

$AllKasperskyServices = Get-Service -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -match "kaspersky|klnagent|avp" -or
        $_.DisplayName -match "Kaspersky|Network Agent|Endpoint Security"
    }

$KESService = $AllKasperskyServices |
    Where-Object {
        $_.Name -eq "AVP" -or
        $_.DisplayName -match "Kaspersky Endpoint Security"
    } |
    Select-Object -First 1

$AgentService = $AllKasperskyServices |
    Where-Object {
        $_.Name -eq "klnagent" -or
        $_.DisplayName -match "Kaspersky.*Network Agent|Network Agent"
    } |
    Select-Object -First 1

# ================================================================
# KASPERSKY INSTALLATION DETECTION
# ================================================================

Write-Host ""
Write-Host "KASPERSKY INSTALLATION" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------"

$AvpCandidates = @()

foreach ($Folder in $KasperskyFolders) {
    $AvpCandidates += Get-ChildItem `
        -Path $Folder `
        -Filter "avp.com" `
        -File `
        -Recurse `
        -ErrorAction SilentlyContinue
}

$AvpPath = $AvpCandidates | Select-Object -First 1 -ExpandProperty FullName

$CommonAvpPaths = @(
    "$PF64\Kaspersky Lab\Kaspersky Endpoint Security for Windows\avp.com",
    "$PF32\Kaspersky Lab\Kaspersky Endpoint Security for Windows\avp.com",
    "$PF64\Kaspersky Lab\Kaspersky Endpoint Security 12\avp.com",
    "$PF32\Kaspersky Lab\Kaspersky Endpoint Security 12\avp.com",
    "$PF64\Kaspersky Lab\Kaspersky Endpoint Security 11\avp.com",
    "$PF32\Kaspersky Lab\Kaspersky Endpoint Security 11\avp.com"
)

foreach ($Path in $CommonAvpPaths) {
    if ((-not $AvpPath) -and (Test-Path $Path)) {
        $AvpPath = $Path
    }
}

# Prefer the folder of the running AVP service if we can find it
$KESServiceExe = if ($KESService) { Get-ServiceExePath $KESService.Name } else { $null }

if ($AvpPath) {
    Show-Result "Endpoint Security" "INSTALLED" "Green"
    Show-Result "AVP.COM Path" $AvpPath "DarkGray"
}
elseif ($KESServiceExe) {
    Show-Result "Endpoint Security" "INSTALLED" "Green"
    Show-Result "AVP Service Path" $KESServiceExe "DarkGray"
}
else {
    Show-Result "Endpoint Security" "NOT DETECTED" "Red"
}

# ================================================================
# KES VERSION  (full 4-part: running avp.exe -> avp.com -> registry)
# ================================================================

$KESVersion = $null
$KESVersionSource = $null

# 1) Running AVP service executable - full 4-part version (14.1.x.x)
$V = Get-FullFileVersion $KESServiceExe
if ($V) {
    $KESVersion = $V
    $KESVersionSource = "Running service executable (avp.exe)"
}

# 2) avp.exe / avp.com in the install folder
if (-not $KESVersion -and $AvpPath) {
    $AvpExe = Join-Path (Split-Path $AvpPath -Parent) "avp.exe"

    foreach ($Candidate in @($AvpExe, $AvpPath)) {
        $V = Get-FullFileVersion $Candidate
        if ($V) {
            $KESVersion = $V
            $KESVersionSource = "File version: $(Split-Path $Candidate -Leaf)"
            break
        }
    }
}

# 3) Installed programs entry (may be short, e.g. 14.1)
if (-not $KESVersion) {
    $KESProduct = Get-InstalledProduct `
        -Include "Kaspersky Endpoint Security" `
        -Exclude "Network Agent|Security Center|Administration|Light Agent"

    if ($KESProduct) {
        $KESVersion = $KESProduct.DisplayVersion
        $KESVersionSource = "Installed programs: $($KESProduct.DisplayName)"
    }
}

if ($KESVersion) {
    Show-Result "KES Version" $KESVersion "Green"
    Show-Result "Version Source" $KESVersionSource "DarkGray"
}
else {
    Show-Result "KES Version" "NOT DETECTED" "Yellow"
}

# ================================================================
# KASPERSKY SERVICES
# ================================================================

Write-Host ""
Write-Host "KASPERSKY SERVICES" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------"

if ($KESService) {
    Show-Result "Endpoint Security Service" `
        "$($KESService.Status.ToString().ToUpper()) [$($KESService.Name)]" `
        (Get-ColorForService $KESService)
}
else {
    Show-Result "Endpoint Security Service" "NOT FOUND" "Red"
}

if ($AgentService) {
    Show-Result "Network Agent Service" `
        "$($AgentService.Status.ToString().ToUpper()) [$($AgentService.Name)]" `
        (Get-ColorForService $AgentService)
}
else {
    Show-Result "Network Agent Service" "NOT FOUND" "Red"
}

# ================================================================
# NETWORK AGENT EXECUTABLE
# ================================================================

Write-Host ""
Write-Host "NETWORK AGENT" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------"

$KlnagchkCandidates = @()

foreach ($Folder in $KasperskyFolders) {
    $KlnagchkCandidates += Get-ChildItem `
        -Path $Folder `
        -Filter "klnagchk.exe" `
        -File `
        -Recurse `
        -ErrorAction SilentlyContinue
}

$KlnagchkPath = $KlnagchkCandidates | Select-Object -First 1 -ExpandProperty FullName

$CommonKlnagchkPaths = @(
    "$PF32\Kaspersky Lab\NetworkAgent\klnagchk.exe",
    "$PF64\Kaspersky Lab\NetworkAgent\klnagchk.exe",
    "$PF32\Kaspersky Lab\NetworkAgent\Binaries\klnagchk.exe",
    "$PF64\Kaspersky Lab\NetworkAgent\Binaries\klnagchk.exe"
)

foreach ($Path in $CommonKlnagchkPaths) {
    if ((-not $KlnagchkPath) -and (Test-Path $Path)) {
        $KlnagchkPath = $Path
    }
}

if ($KlnagchkPath) {
    Show-Result "klnagchk.exe" "FOUND" "Green"
    Show-Result "Utility Path" $KlnagchkPath "DarkGray"
}
else {
    Show-Result "klnagchk.exe" "NOT FOUND" "Red"
}

# ================================================================
# NETWORK AGENT VERSION  (registry -> service exe -> klnagchk)
# ================================================================

$AgentVersion = $null
$AgentVersionSource = $null

$AgentProduct = Get-InstalledProduct -Include "Network Agent"

if ($AgentProduct) {
    $AgentVersion = $AgentProduct.DisplayVersion
    $AgentVersionSource = "Installed programs: $($AgentProduct.DisplayName)"
}

if (-not $AgentVersion -and $AgentService) {
    $AgentExe = Get-ServiceExePath $AgentService.Name

    if ($AgentExe -and (Test-Path $AgentExe)) {
        $Info = (Get-Item $AgentExe).VersionInfo
        $AgentVersion = $Info.ProductVersion
        if (-not $AgentVersion) { $AgentVersion = $Info.FileVersion }
        if ($AgentVersion) { $AgentVersionSource = "Running service executable" }
    }
}

if (-not $AgentVersion -and $KlnagchkPath) {
    $Info = (Get-Item $KlnagchkPath).VersionInfo
    $AgentVersion = $Info.ProductVersion
    if (-not $AgentVersion) { $AgentVersion = $Info.FileVersion }
    if ($AgentVersion) { $AgentVersionSource = "klnagchk.exe file version" }
}

if ($AgentVersion) {
    Show-Result "Network Agent Version" $AgentVersion "Green"
    Show-Result "Version Source" $AgentVersionSource "DarkGray"
}
else {
    Show-Result "Network Agent Version" "NOT DETECTED" "Yellow"
}

# ================================================================
# KASPERSKY SECURITY CENTER CONNECTION
# ================================================================

Write-Host ""
Write-Host "KASPERSKY SECURITY CENTER CONNECTION" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------"

$ServerConnected = $false
$AdminServer = $null
$LastConnection = $null
$KlnagOutput = $null

if ($KlnagchkPath -and $AgentService) {

    try {
        $KlnagOutput = & $KlnagchkPath -sendhb 2>&1 | Out-String
    }
    catch {
        $KlnagOutput = ""
    }

    if ($KlnagOutput) {

        $Patterns = @(
            "(?im)Administration Server address\s*[:=]\s*(.+)",
            "(?im)Administration Server\s*[:=]\s*(.+)"
        )

        foreach ($Pattern in $Patterns) {
            $Match = [regex]::Match($KlnagOutput, $Pattern)
            if ($Match.Success) {
                $AdminServer = $Match.Groups[1].Value.Trim()
                break
            }
        }

        if ($AdminServer) {
            Show-Result "Administration Server" $AdminServer
        }
        else {
            Show-Result "Administration Server" "NOT DETECTED" "Yellow"
        }

        if (
            $KlnagOutput -match "(?i)connection.*established" -or
            $KlnagOutput -match "(?i)connection.*successful" -or
            $KlnagOutput -match "(?i)successfully connected" -or
            $KlnagOutput -match "(?i)connection.*OK" -or
            $KlnagOutput -match "(?i)connected.*Administration Server"
        ) {
            $ServerConnected = $true
        }

        $TimePatterns = @(
            "(?im)Date/time of the last request for synchronization\s*[:=]\s*(.+)",
            "(?im)last request for synchronization\s*[:=]\s*(.+)",
            "(?im)last synchronization\s*[:=]\s*(.+)",
            "(?im)last connection\s*[:=]\s*(.+)"
        )

        foreach ($Pattern in $TimePatterns) {
            $Match = [regex]::Match($KlnagOutput, $Pattern)
            if ($Match.Success) {
                $LastConnection = $Match.Groups[1].Value.Trim()
                break
            }
        }

        if ($ServerConnected) {
            Show-Result "KSC Server Connection" "CONNECTED" "Green"
        }
        else {
            Show-Result "KSC Server Connection" "NOT CONNECTED" "Red"
        }

        if ($LastConnection) {

            Show-Result "Last Synchronization" $LastConnection "Green"

            try {
                $ParsedTime = $null

                if (
                    [DateTime]::TryParse(
                        $LastConnection,
                        [Globalization.CultureInfo]::CurrentCulture,
                        [Globalization.DateTimeStyles]::None,
                        [ref]$ParsedTime
                    )
                ) {
                    $Age = (Get-Date) - $ParsedTime

                    if ($Age.TotalSeconds -ge 0) {
                        $AgeText = "{0:dd\.hh\:mm\:ss}" -f $Age
                        Show-Result "Time Since Connection" $AgeText
                    }
                }
            }
            catch {}
        }
        else {
            Show-Result "Last Synchronization" "NOT REPORTED" "Yellow"
        }
    }
    else {
        Show-Result "KSC Server Connection" "NO RESPONSE FROM UTILITY" "Red"
    }

}
elseif (-not $AgentService) {
    Show-Result "KSC Server Connection" "NETWORK AGENT NOT RUNNING" "Red"
}
else {
    Show-Result "KSC Server Connection" "klnagchk NOT FOUND" "Yellow"
}

# ================================================================
# FALLBACK: NETWORK AGENT REGISTRY INFORMATION
# ================================================================

if (-not $AdminServer) {

    $AgentRegistryPaths = @(
        "HKLM:\SOFTWARE\WOW6432Node\KasperskyLab\Components\34",
        "HKLM:\SOFTWARE\KasperskyLab\Components\34",
        "HKLM:\SOFTWARE\WOW6432Node\KasperskyLab\Components",
        "HKLM:\SOFTWARE\KasperskyLab\Components"
    )

    foreach ($RegPath in $AgentRegistryPaths) {

        if (Test-Path $RegPath) {

            $RegValues = Get-ItemProperty $RegPath -ErrorAction SilentlyContinue

            foreach ($Property in $RegValues.PSObject.Properties) {

                if ($Property.Name -match "Server" -and $Property.Value -is [string]) {

                    if ($Property.Value -notmatch "^Microsoft") {
                        $AdminServer = $Property.Value
                        break
                    }
                }
            }
        }

        if ($AdminServer) { break }
    }
}

# ================================================================
# LICENSE
# ================================================================

Write-Host ""
Write-Host "KASPERSKY LICENSE" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------"

$LicenseFound = $false
$LicenseStatus = "UNKNOWN"

if ($AvpPath) {

    # We deliberately do NOT use "license /check" here.
    # That command is not a reliable read-only information
    # command across KES versions.

    $LicenseRegistryPaths = @(
        "HKLM:\SOFTWARE\KasperskyLab",
        "HKLM:\SOFTWARE\WOW6432Node\KasperskyLab"
    )

    $LicenseKeys = @()

    foreach ($Root in $LicenseRegistryPaths) {

        if (Test-Path $Root) {
            $LicenseKeys += Get-ChildItem `
                -Path $Root `
                -Recurse `
                -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match "License|Licensing|Activation" }
        }
    }

    if ($LicenseKeys.Count -gt 0) {
        $LicenseFound = $true
    }

    try {
        $LicenseOutput = & $AvpPath license 2>&1 | Out-String

        if ($LicenseOutput -match "(?i)commercial|trial|subscription|license") {
            $LicenseFound = $true
        }

        if ($LicenseOutput -match "(?i)expired") {
            $LicenseStatus = "EXPIRED"
        }
        elseif ($LicenseOutput -match "(?i)active|valid") {
            $LicenseStatus = "ACTIVE / VALID"
        }
    }
    catch {}
}

if ($LicenseStatus -eq "EXPIRED") {
    Show-Result "License Status" $LicenseStatus "Red"
}
elseif ($LicenseStatus -eq "ACTIVE / VALID") {
    Show-Result "License Status" $LicenseStatus "Green"
}
elseif ($LicenseFound) {
    Show-Result "License Status" "INSTALLED / INFORMATION AVAILABLE" "Green"
}
else {
    Show-Result "License Status" "NOT AVAILABLE LOCALLY" "Yellow"
}

# ================================================================
# INTERNET / KASPERSKY CONNECTIVITY
# ================================================================

Write-Host ""
Write-Host "NETWORK CONNECTIVITY" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------"

$InternetTest = Test-NetConnection `
    -ComputerName "activation-v2.kaspersky.com" `
    -Port 443 `
    -WarningAction SilentlyContinue

if ($InternetTest.TcpTestSucceeded) {
    Show-Result "Kaspersky Internet Access" "AVAILABLE" "Green"
}
else {
    Show-Result "Kaspersky Internet Access" "NOT AVAILABLE" "Red"
}

# ================================================================
# FINAL STATUS
# ================================================================

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "                       FINAL STATUS" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

$KESOK = ($KESService -and $KESService.Status -eq "Running")
$AgentOK = ($AgentService -and $AgentService.Status -eq "Running")
$ServerOK = $ServerConnected

if ($KESOK -and $AgentOK -and $ServerOK) {

    Write-Host "  KASPERSKY STATUS : HEALTHY" -ForegroundColor Green
    Write-Host ""
    Write-Host "  [OK] Endpoint Security     : RUNNING" -ForegroundColor Green
    Write-Host "  [OK] Network Agent         : RUNNING" -ForegroundColor Green
    Write-Host "  [OK] KSC Server            : CONNECTED" -ForegroundColor Green
}
else {

    Write-Host "  KASPERSKY STATUS : CHECK REQUIRED" -ForegroundColor Yellow
    Write-Host ""

    if ($KESOK) {
        Write-Host "  [OK] Endpoint Security     : RUNNING" -ForegroundColor Green
    }
    else {
        Write-Host "  [!!] Endpoint Security     : PROBLEM" -ForegroundColor Red
    }

    if ($AgentOK) {
        Write-Host "  [OK] Network Agent         : RUNNING" -ForegroundColor Green
    }
    else {
        Write-Host "  [!!] Network Agent         : PROBLEM" -ForegroundColor Red
    }

    if ($ServerOK) {
        Write-Host "  [OK] KSC Server            : CONNECTED" -ForegroundColor Green
    }
    else {
        Write-Host "  [!!] KSC Server            : NOT CONNECTED" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

$EndTime = Get-Date
Show-Result "Check Finished" $EndTime.ToString("yyyy-MM-dd HH:mm:ss")

Write-Host ""
Read-Host "Press ENTER to exit"