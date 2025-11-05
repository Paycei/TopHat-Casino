# TopHat CASINO - Windows Installation Script
# PowerShell script to install all dependencies

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  TopHat CASINO - Installer" -ForegroundColor Yellow
Write-Host "  Windows Setup Script" -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[WARNING] Not running as Administrator." -ForegroundColor Yellow
    Write-Host "Some installations may require admin privileges." -ForegroundColor Yellow
    Write-Host "Consider running: Right-click > Run as Administrator" -ForegroundColor Yellow
    Write-Host ""
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne "y") {
        exit
    }
}

# Function to check if a command exists
function Test-CommandExists {
    param($command)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    try {
        if (Get-Command $command) {
            return $true
        }
    }
    catch {
        return $false
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }
}

# Step 1: Check/Install Chocolatey
Write-Host "[1/4] Checking for Chocolatey package manager..." -ForegroundColor Green

if (Test-CommandExists choco) {
    Write-Host "  ✓ Chocolatey is already installed" -ForegroundColor Green
} else {
    Write-Host "  ✗ Chocolatey not found. Installing..." -ForegroundColor Yellow
    
    # Install Chocolatey
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    try {
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "  ✓ Chocolatey installed successfully" -ForegroundColor Green
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    catch {
        Write-Host "  ✗ Failed to install Chocolatey" -ForegroundColor Red
        Write-Host "  Please install manually from: https://chocolatey.org/install" -ForegroundColor Yellow
        Write-Host "  Error: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Step 2: Check/Install Nim
Write-Host "[2/4] Checking for Nim language..." -ForegroundColor Green

if (Test-CommandExists nim) {
    $nimVersion = nim --version 2>&1 | Select-String -Pattern "Nim Compiler Version" | Select-Object -First 1
    Write-Host "  ✓ Nim is already installed: $nimVersion" -ForegroundColor Green
} else {
    Write-Host "  ✗ Nim not found. Installing via Chocolatey..." -ForegroundColor Yellow
    
    try {
        choco install nim -y
        Write-Host "  ✓ Nim installed successfully" -ForegroundColor Green
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    catch {
        Write-Host "  ✗ Failed to install Nim via Chocolatey" -ForegroundColor Red
        Write-Host "  Trying alternative method..." -ForegroundColor Yellow
        
        # Download choosenim installer
        $chooseNimUrl = "https://nim-lang.org/choosenim/init.ps1"
        try {
            Invoke-Expression (Invoke-WebRequest -Uri $chooseNimUrl -UseBasicParsing).Content
            Write-Host "  ✓ Nim installed via choosenim" -ForegroundColor Green
        }
        catch {
            Write-Host "  ✗ Failed to install Nim" -ForegroundColor Red
            Write-Host "  Please install manually from: https://nim-lang.org/install_windows.html" -ForegroundColor Yellow
            Write-Host "  Error: $_" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host ""

# Step 3: Check/Install Git (needed for nimble packages)
Write-Host "[3/4] Checking for Git..." -ForegroundColor Green

if (Test-CommandExists git) {
    $gitVersion = git --version
    Write-Host "  ✓ Git is already installed: $gitVersion" -ForegroundColor Green
} else {
    Write-Host "  ✗ Git not found. Installing via Chocolatey..." -ForegroundColor Yellow
    
    try {
        choco install git -y
        Write-Host "  ✓ Git installed successfully" -ForegroundColor Green
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    catch {
        Write-Host "  ✗ Failed to install Git" -ForegroundColor Red
        Write-Host "  Please install manually from: https://git-scm.com/download/win" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""

# Step 4: Install project dependencies via nimble
Write-Host "[4/4] Installing project dependencies (raylib)..." -ForegroundColor Green

if (Test-Path "TopHatCasino.nimble") {
    Write-Host "  ✓ Found TopHatCasino.nimble" -ForegroundColor Green
    
    try {
        # Install dependencies
        Write-Host "  Installing raylib (Raylib bindings)..." -ForegroundColor Yellow
        nimble install -y -d
        
        Write-Host "  ✓ Dependencies installed successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Failed to install nimble dependencies" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Try manually:" -ForegroundColor Yellow
        Write-Host "    nimble install raylib" -ForegroundColor White
        exit 1
    }
} else {
    Write-Host "  ✗ TopHatCasino.nimble not found in current directory" -ForegroundColor Red
    Write-Host "  Please run this script from the project root directory" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  Installation Complete! 🎉" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Close and reopen PowerShell/Terminal" -ForegroundColor White
Write-Host "  2. Run: nim c -r src/main.nim" -ForegroundColor White
Write-Host "  3. Enjoy the casino! 🎰" -ForegroundColor White
Write-Host ""
Write-Host "For optimized build:" -ForegroundColor Yellow
Write-Host "  nim c -d:release --opt:speed src/main.nim" -ForegroundColor White
Write-Host ""

# Verification summary
Write-Host "Installed versions:" -ForegroundColor Cyan
if (Test-CommandExists nim) {
    $nimVer = nim --version 2>&1 | Select-String -Pattern "Nim Compiler Version" | Select-Object -First 1
    Write-Host "  Nim: $nimVer" -ForegroundColor White
}
if (Test-CommandExists git) {
    $gitVer = git --version
    Write-Host "  Git: $gitVer" -ForegroundColor White
}
if (Test-CommandExists choco) {
    $chocoVer = choco --version | Select-Object -First 1
    Write-Host "  Chocolatey: $chocoVer" -ForegroundColor White
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")