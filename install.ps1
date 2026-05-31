param(
    [Parameter(Position = 0)]
    [ValidatePattern('^(stable|latest|\d+\.\d+\.\d+(-[^\s]+)?)$')]
    [string]$Target = "latest",

    [switch]$SkipMenu
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$GcsBucket = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"
$DownloadDir = Join-Path $env:USERPROFILE ".claude\downloads"
$InstallBase = Join-Path $env:USERPROFILE ".local\share\claude"
$VersionsDir = Join-Path $InstallBase "versions"
$BinDir = Join-Path $env:USERPROFILE ".local\bin"
$LinkPath = Join-Path $BinDir "claude.exe"
$CcAliasPath = Join-Path $BinDir "cc.cmd"
$ConfigPath = Join-Path $env:USERPROFILE ".claude.json"
$LocksDir = Join-Path $env:USERPROFILE ".local\state\claude\locks"
$CacheDir = Join-Path $env:USERPROFILE ".cache\claude\staging"
$BackupDir = Join-Path $env:USERPROFILE ".claude\backups"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Info {
    param([string]$Message)
    Write-Host "    $Message" -ForegroundColor Gray
}

function Fail {
    param(
        [string]$Message,
        [string]$Hint
    )

    Write-Host ""
    Write-Host "[FAILED] $Message" -ForegroundColor Red
    if ($Hint) {
        Write-Host "How to fix: $Hint" -ForegroundColor Yellow
    }
    exit 1
}

function Enable-Tls12 {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    catch {
        Fail "Cannot enable TLS 1.2 in this PowerShell session." "Open a newer Windows PowerShell or PowerShell 7 window and rerun the command."
    }
}

function Assert-WindowsEnvironment {
    if ($env:OS -ne "Windows_NT") {
        Fail "This installer only supports Windows." "Use the macOS/Linux installer from the Claude Code documentation on non-Windows systems."
    }

    if (-not [Environment]::Is64BitOperatingSystem) {
        Fail "Claude Code does not support 32-bit Windows." "Use a 64-bit Windows device."
    }

    if (-not [Environment]::Is64BitProcess) {
        Fail "You are running 32-bit PowerShell on 64-bit Windows." "Open the normal 64-bit PowerShell from the Start menu and rerun the command."
    }

    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Fail "PowerShell 5.1 or newer is required." "Install PowerShell 7 or run Windows Update, then rerun the command."
    }
}

function Get-PlatformName {
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($env:PROCESSOR_ARCHITEW6432) {
        $arch = $env:PROCESSOR_ARCHITEW6432
    }

    if ($arch -eq "ARM64") {
        return "win32-arm64"
    }

    return "win32-x64"
}

function Get-RemoteText {
    param([string]$Url)

    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        try {
            $result = & curl.exe -fsSL --ssl-no-revoke --http1.1 --retry 5 --retry-delay 2 $Url
            if ($LASTEXITCODE -eq 0) {
                if ($result -is [array]) {
                    return ($result -join "`n")
                }
                return $result
            }
            Write-Info "curl.exe failed with exit code $LASTEXITCODE, falling back to Invoke-RestMethod."
        }
        catch {
            Write-Info "curl.exe failed, falling back to Invoke-RestMethod."
        }
    }

    return Invoke-RestMethod -Uri $Url -ErrorAction Stop
}

function Save-RemoteFile {
    param(
        [string]$Url,
        [string]$OutputPath
    )

    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        & curl.exe -fL --ssl-no-revoke --http1.1 --retry 5 --retry-delay 2 -o $OutputPath $Url
        if ($LASTEXITCODE -eq 0) {
            return
        }
        throw "curl.exe failed with exit code $LASTEXITCODE"
    }

    Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing -ErrorAction Stop
}

function ConvertTo-PlainHashtable {
    param($InputObject)

    $table = @{}
    if ($null -eq $InputObject) {
        return $table
    }

    foreach ($property in $InputObject.PSObject.Properties) {
        $table[$property.Name] = $property.Value
    }
    return $table
}

function Write-ClaudeConfig {
    param(
        [string]$Path,
        [string]$FirstStartTime
    )

    $data = @{}
    if (Test-Path $Path) {
        try {
            $data = ConvertTo-PlainHashtable -InputObject (Get-Content -Raw -Path $Path | ConvertFrom-Json)
        }
        catch {
            Write-Info "Existing .claude.json is not valid JSON. It will be backed up and replaced."
        }
    }

    $data["installMethod"] = "native"
    $data["autoUpdates"] = $false
    $data["autoUpdatesProtectedForNative"] = $true
    if (-not $data.ContainsKey("firstStartTime")) {
        $data["firstStartTime"] = $FirstStartTime
    }

    $json = $data | ConvertTo-Json -Depth 20
    Set-Content -Path $Path -Value $json -Encoding UTF8
}

function Write-CcAlias {
    param(
        [string]$AliasPath,
        [string]$ClaudeExePath
    )

    $content = @"
@echo off
"$ClaudeExePath" %*
"@
    Set-Content -Path $AliasPath -Value $content -Encoding ASCII
}

function Ensure-UserPath {
    param([string]$Directory)

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $userPath) {
        $userPath = ""
    }

    $entries = $userPath -split ";" | Where-Object { $_ -and $_.Trim() }
    $exists = $false
    foreach ($entry in $entries) {
        if ($entry.TrimEnd("\") -ieq $Directory.TrimEnd("\")) {
            $exists = $true
            break
        }
    }

    if (-not $exists) {
        $newPath = if ($userPath.Trim()) { "$userPath;$Directory" } else { $Directory }
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Info "Added to user PATH: $Directory"
    }
    else {
        Write-Info "User PATH already contains: $Directory"
    }

    $processEntries = $env:Path -split ";" | Where-Object { $_ -and $_.Trim() }
    $processHasPath = $false
    foreach ($entry in $processEntries) {
        if ($entry.TrimEnd("\") -ieq $Directory.TrimEnd("\")) {
            $processHasPath = $true
            break
        }
    }

    if (-not $processHasPath) {
        $env:Path = "$Directory;$env:Path"
    }
}

function Install-ClaudeCode {
    Enable-Tls12
    Assert-WindowsEnvironment

    $platform = Get-PlatformName

    Write-Step "Checking download endpoint"
    try {
        $version = (Get-RemoteText -Url "$GcsBucket/latest").ToString().Trim()
        if ($Target -ne "latest" -and $Target -ne "stable") {
            $version = $Target
        }
        Write-Info "Claude Code version: $version"
        Write-Info "Platform: $platform"
    }
    catch {
        Fail "Cannot reach Claude Code release endpoint." "Check your network, proxy, or firewall, then rerun the command. Endpoint: $GcsBucket/latest"
    }

    Write-Step "Reading release manifest"
    try {
        $manifestText = Get-RemoteText -Url "$GcsBucket/$version/manifest.json"
        if ($manifestText -is [string]) {
            $manifest = $manifestText | ConvertFrom-Json
        }
        else {
            $manifest = $manifestText
        }

        $platformInfo = $manifest.platforms.$platform
        $checksum = $platformInfo.checksum
        $expectedSize = $platformInfo.size
        if (-not $checksum) {
            Fail "Claude Code release manifest does not contain platform $platform." "Confirm your Windows architecture is supported, then rerun the installer later."
        }
    }
    catch {
        Fail "Failed to read or parse Claude Code manifest." "Check network stability, then rerun the installer."
    }

    New-Item -ItemType Directory -Force -Path $DownloadDir, $VersionsDir, $BinDir, $LocksDir, $CacheDir, $BackupDir | Out-Null

    $binaryPath = Join-Path $DownloadDir "claude-$version-$platform.exe"
    $finalPath = Join-Path $VersionsDir "$version.exe"
    $downloadUrl = "$GcsBucket/$version/$platform/claude.exe"

    Write-Step "Downloading Claude Code"
    Write-Info "Source: $downloadUrl"
    try {
        Save-RemoteFile -Url $downloadUrl -OutputPath $binaryPath
        if ($expectedSize) {
            $actualSize = (Get-Item -Path $binaryPath).Length
            if ($actualSize -ne [int64]$expectedSize) {
                throw "Downloaded size mismatch. Expected $expectedSize bytes, got $actualSize bytes."
            }
        }
    }
    catch {
        if (Test-Path $binaryPath) {
            Remove-Item -Force $binaryPath -ErrorAction SilentlyContinue
        }
        Fail "Failed to download Claude Code binary." "Check your network or proxy, then rerun the command. Detail: $_"
    }

    Write-Step "Verifying SHA256 checksum"
    $actualChecksum = (Get-FileHash -Path $binaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualChecksum -ne $checksum) {
        Remove-Item -Force $binaryPath -ErrorAction SilentlyContinue
        Fail "Checksum verification failed." "The download may be incomplete or tampered with. Rerun after clearing network/proxy cache."
    }
    Write-Info "Checksum verified."

    Write-Step "Installing Claude Code"
    try {
        if (Test-Path $finalPath) {
            Remove-Item -Force $finalPath
        }
        Move-Item -Force $binaryPath $finalPath
        Copy-Item -Force $finalPath $LinkPath
        Write-CcAlias -AliasPath $CcAliasPath -ClaudeExePath $LinkPath

        if (Test-Path $ConfigPath) {
            $backupPath = Join-Path $BackupDir ".claude.json.backup.$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
            Copy-Item -Force $ConfigPath $backupPath -ErrorAction SilentlyContinue
            Write-Info "Existing config backed up to: $backupPath"
        }

        $firstStartTime = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
        Write-ClaudeConfig -Path $ConfigPath -FirstStartTime $firstStartTime
        Ensure-UserPath -Directory $BinDir
    }
    catch {
        Fail "Failed to install Claude Code." "Close terminals or tools that may be using claude.exe, then rerun the installer. Detail: $_"
    }
    finally {
        if (Test-Path $binaryPath) {
            Remove-Item -Force $binaryPath -ErrorAction SilentlyContinue
        }
    }

    Write-Step "Verifying installation"
    try {
        $versionOutput = & $LinkPath --version 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw ($versionOutput | Out-String)
        }
        Write-Host "[OK] Claude Code installed successfully." -ForegroundColor Green
        Write-Info "Command: claude"
        Write-Info "Shortcut command: cc"
        Write-Info "Location: $LinkPath"
        Write-Info "Shortcut: $CcAliasPath"
        Write-Info "Version output: $versionOutput"
    }
    catch {
        Fail "Claude Code was copied, but verification failed." "Reopen PowerShell and run: claude --version. If it still fails, rerun the installer and send the visible error message to support."
    }
}

function Show-ProviderGuide {
    Write-Step "Third-party model channel guide"
    Write-Host "This installer will not ask for or save your API Key."
    Write-Host "Choose a provider in your local tool and paste the key there only."
    Write-Host ""
    Write-Host "Common provider choices:"
    Write-Host "  1. DeepSeek"
    Write-Host "  2. Kimi"
    Write-Host "  3. Zhipu"
    Write-Host "  4. Your own API service"
    Write-Host ""
    Write-Host "Recommended flow:"
    Write-Host "  1. Install/open cc-switch."
    Write-Host "  2. Add a provider locally."
    Write-Host "  3. Paste your API Key only in the local app or local config."
    Write-Host "  4. Start its local proxy or profile."
    Write-Host "  5. Open a new PowerShell window and run: claude"
}

function Show-CcSwitchGuide {
    Write-Step "cc-switch setup"
    Write-Host "cc-switch is a local desktop tool. For safety, this script does not silently install unknown desktop releases."
    Write-Host "Download page: https://cc-switch.cc/en/download"
    Write-Host "Windows users can usually choose MSI, ZIP, or winget if available."
    Write-Host ""
    Write-Host "After opening cc-switch:"
    Write-Host "  1. Add your provider, such as DeepSeek, Kimi, Zhipu, or your own API service."
    Write-Host "  2. Enter API Key locally in cc-switch."
    Write-Host "  3. Enable the selected profile."
    Write-Host "  4. Reopen PowerShell and run: claude"
    Write-Host ""
    $open = Read-Host "Open cc-switch download page now? [Y/n]"
    if ($open -eq "" -or $open -match "^[Yy]") {
        Start-Process "https://cc-switch.cc/en/download"
    }
}

function Show-NextStepMenu {
    while ($true) {
        Write-Host ""
        Write-Host "Next step menu"
        Write-Host "  1. Finish only"
        Write-Host "  2. Configure cc-switch"
        Write-Host "  3. Show third-party API channel guide"
        $choice = Read-Host "Choose 1-3"

        switch ($choice) {
            "1" { return }
            "2" { Show-CcSwitchGuide }
            "3" { Show-ProviderGuide }
            default { Write-Host "Please enter 1, 2, or 3." -ForegroundColor Yellow }
        }
    }
}

Write-Host "Claude Code Windows one-click installer" -ForegroundColor Cyan
Write-Host "This script installs Claude Code for the current Windows user only."

Install-ClaudeCode

if (-not $SkipMenu) {
    Show-NextStepMenu
}

Write-Host ""
Write-Host "Done. If claude or cc is not found, close and reopen PowerShell, then run: claude --version" -ForegroundColor Green
