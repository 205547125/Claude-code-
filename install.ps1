param(
    [switch]$SkipOpenCcSwitch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Repo = "205547125/Claude-code-"
$ReleaseTag = "v1.0.0"
$GitAssetName = "Git-2.53.0.2-64-bit.exe"
$CcSwitchZipName = "CC-Switch-v3.13.0-Windows.msi.zip"
$CcSwitchMsiName = "CC-Switch-v3.13.0-Windows.msi"
$ReleaseBaseUrl = "https://github.com/$Repo/releases/download/$ReleaseTag"
$WorkDir = Join-Path $env:TEMP "claude-code-onekey"
$GitInstallerPath = Join-Path $WorkDir $GitAssetName
$CcSwitchZipPath = Join-Path $WorkDir $CcSwitchZipName
$CcSwitchExtractDir = Join-Path $WorkDir "cc-switch"
$CcSwitchMsiPath = Join-Path $CcSwitchExtractDir $CcSwitchMsiName
$UserBinDir = Join-Path $env:USERPROFILE ".local\bin"
$ClaudeExePath = Join-Path $UserBinDir "claude.exe"
$CcAliasPath = Join-Path $UserBinDir "cc.cmd"
$GitCmdPath = "C:\Program Files\Git\cmd"

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

function Assert-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Fail "Administrator PowerShell is required." "Right-click Windows PowerShell and choose 'Run as administrator', then rerun: irm https://raw.githubusercontent.com/$Repo/main/install.ps1 | iex"
    }
}

function Assert-Windows64 {
    if ($env:OS -ne "Windows_NT") {
        Fail "This installer only supports Windows." "Use this script on Windows 64-bit."
    }
    if (-not [Environment]::Is64BitOperatingSystem) {
        Fail "This installer only supports Windows 64-bit." "Use a 64-bit Windows device."
    }
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Fail "PowerShell 5.1 or newer is required." "Open Windows PowerShell 5.1+ or PowerShell 7+ as administrator."
    }
}

function Enable-Tls12 {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    catch {
        Fail "Cannot enable TLS 1.2." "Open a newer PowerShell window as administrator and retry."
    }
}

function Download-File {
    param(
        [string]$Url,
        [string]$OutputPath
    )

    Write-Info "Downloading: $Url"
    try {
        if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
            & curl.exe -fL --ssl-no-revoke --http1.1 --retry 5 --retry-delay 2 -o $OutputPath $Url
            if ($LASTEXITCODE -ne 0) {
                throw "curl.exe failed with exit code $LASTEXITCODE"
            }
            return
        }

        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Fail "Failed to download $Url" "Check GitHub network access, then rerun the installer. Detail: $_"
    }
}

function Run-ProcessChecked {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$FailureHint
    )

    $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Wait -PassThru -WindowStyle Hidden
    if ($process.ExitCode -ne 0) {
        Fail "Command failed: $FilePath $($ArgumentList -join ' ')" "$FailureHint Exit code: $($process.ExitCode)"
    }
}

function Add-UserPath {
    param([string]$PathToAdd)

    if (-not (Test-Path -LiteralPath $PathToAdd)) {
        Write-Info "PATH target does not exist yet, skipping: $PathToAdd"
        return
    }

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $userPath) {
        $userPath = ""
    }

    $entries = $userPath -split ";" | Where-Object { $_ -and $_.Trim() }
    $exists = $false
    foreach ($entry in $entries) {
        if ($entry.TrimEnd("\") -ieq $PathToAdd.TrimEnd("\")) {
            $exists = $true
            break
        }
    }

    if (-not $exists) {
        $newPath = if ($userPath.Trim()) { "$userPath;$PathToAdd" } else { $PathToAdd }
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Info "Added to user PATH: $PathToAdd"
    }
    else {
        Write-Info "User PATH already contains: $PathToAdd"
    }

    $processEntries = $env:Path -split ";" | Where-Object { $_ -and $_.Trim() }
    $processExists = $false
    foreach ($entry in $processEntries) {
        if ($entry.TrimEnd("\") -ieq $PathToAdd.TrimEnd("\")) {
            $processExists = $true
            break
        }
    }
    if (-not $processExists) {
        $env:Path = "$PathToAdd;$env:Path"
    }
}

function Write-CcAlias {
    New-Item -ItemType Directory -Force -Path $UserBinDir | Out-Null
    $content = @"
@echo off
"$ClaudeExePath" %*
"@
    Set-Content -Path $CcAliasPath -Value $content -Encoding ASCII
    Write-Info "Created shortcut command: $CcAliasPath"
}

function Test-CommandVersion {
    param(
        [string]$Command,
        [string[]]$Arguments,
        [string]$Name
    )

    try {
        $output = & $Command @Arguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw ($output | Out-String)
        }
        Write-Host "[OK] ${Name}: $output" -ForegroundColor Green
    }
    catch {
        Fail "$Name verification failed." "Close and reopen administrator PowerShell, then rerun the installer. Detail: $_"
    }
}

function Install-Git {
    Write-Step "Installing Git"
    Download-File -Url "$ReleaseBaseUrl/$GitAssetName" -OutputPath $GitInstallerPath
    Run-ProcessChecked -FilePath $GitInstallerPath -ArgumentList @("/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-") -FailureHint "Git installation failed."

    if (Test-Path -LiteralPath $GitCmdPath) {
        Add-UserPath -PathToAdd $GitCmdPath
    }

    Test-CommandVersion -Command "git" -Arguments @("--version") -Name "Git"
}

function Install-ClaudeCode {
    Write-Step "Installing Claude Code through daheiai.com installer"
    try {
        Invoke-Expression (Invoke-RestMethod -Uri "https://daheiai.com/cc.ps1" -ErrorAction Stop)
    }
    catch {
        Fail "Claude Code installer failed." "Check access to https://daheiai.com/cc.ps1 and its downstream download sources, then rerun. Detail: $_"
    }

    if (-not (Test-Path -LiteralPath $ClaudeExePath)) {
        Fail "Claude Code was not found at $ClaudeExePath after installation." "Rerun the installer and check the visible error from the daheiai.com installer."
    }

    Add-UserPath -PathToAdd $UserBinDir
    Write-CcAlias
    Test-CommandVersion -Command $ClaudeExePath -Arguments @("--version") -Name "Claude Code"
    Test-CommandVersion -Command $CcAliasPath -Arguments @("--version") -Name "cc shortcut"
}

function Install-CcSwitch {
    Write-Step "Installing CC-Switch"
    Download-File -Url "$ReleaseBaseUrl/$CcSwitchZipName" -OutputPath $CcSwitchZipPath

    if (Test-Path -LiteralPath $CcSwitchExtractDir) {
        Remove-Item -LiteralPath $CcSwitchExtractDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $CcSwitchExtractDir | Out-Null

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($CcSwitchZipPath, $CcSwitchExtractDir)

    if (-not (Test-Path -LiteralPath $CcSwitchMsiPath)) {
        Fail "CC-Switch MSI was not found after extracting $CcSwitchZipName." "Confirm the release asset contains $CcSwitchMsiName."
    }

    Run-ProcessChecked -FilePath "msiexec.exe" -ArgumentList @("/i", $CcSwitchMsiPath, "/qn", "/norestart") -FailureHint "CC-Switch MSI installation failed. Rerun from administrator PowerShell."
}

function Start-CcSwitch {
    if ($SkipOpenCcSwitch) {
        return
    }

    Write-Step "Opening CC-Switch for local API setup"
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\CC-Switch\CC-Switch.exe",
        "$env:ProgramFiles\CC-Switch\CC-Switch.exe",
        "${env:ProgramFiles(x86)}\CC-Switch\CC-Switch.exe"
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    if ($candidates.Count -gt 0) {
        Start-Process -FilePath $candidates[0]
        Write-Host ""
        Write-Host "CC-Switch is open. Choose your provider and enter your API key locally in CC-Switch." -ForegroundColor Green
        Write-Host "This script does not read, save, upload, or send your API key." -ForegroundColor Green
        return
    }

    Write-Host ""
    Write-Host "CC-Switch installed, but the executable path was not detected automatically." -ForegroundColor Yellow
    Write-Host "Open the Start menu, search for 'CC-Switch', then add your API provider and key in the CC-Switch UI." -ForegroundColor Yellow
    Write-Host "Do not send your API key to anyone." -ForegroundColor Yellow
}

Write-Host "Claude Code one-click installer for Windows" -ForegroundColor Cyan
Write-Host "Repository: https://github.com/$Repo"

Assert-Windows64
Assert-Admin
Enable-Tls12

Write-Step "Preparing installer workspace"
if (Test-Path -LiteralPath $WorkDir) {
    Remove-Item -LiteralPath $WorkDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
Write-Info "Workspace: $WorkDir"

Install-Git
Install-ClaudeCode
Install-CcSwitch
Start-CcSwitch

Write-Host ""
Write-Host "[DONE] Installation flow completed." -ForegroundColor Green
Write-Host "Open a new PowerShell window and verify:" -ForegroundColor Green
Write-Host "  git --version"
Write-Host "  claude --version"
Write-Host "  cc --version"
