# Fix raylib installation issues
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  Fixing raylib Installation" -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Clean problematic files
Write-Host "[1/4] Cleaning problematic files..." -ForegroundColor Green

if (Test-Path "nimble.develop") {
    Write-Host "  Removing nimble.develop..." -ForegroundColor Yellow
    Remove-Item "nimble.develop" -Force
}

if (Test-Path "vendor") {
    Write-Host "  Removing vendor directory..." -ForegroundColor Yellow
    Remove-Item "vendor" -Recurse -Force
}

if (Test-Path "nimble.lock") {
    Write-Host "  Removing nimble.lock..." -ForegroundColor Yellow
    Remove-Item "nimble.lock" -Force
}

Write-Host "  ✓ Cleanup complete" -ForegroundColor Green
Write-Host ""

# Step 2: Refresh nimble package list
Write-Host "[2/4] Refreshing nimble package list..." -ForegroundColor Green
nimble refresh -y
Write-Host "  ✓ Package list refreshed" -ForegroundColor Green
Write-Host ""

# Step 3: Install raylib directly
Write-Host "[3/4] Installing raylib..." -ForegroundColor Green
$output = nimble install raylib -y 2>&1
Write-Host $output

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ raylib installed" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Trying alternative installation method..." -ForegroundColor Yellow
    nimble install raylib@#head -y
}
Write-Host ""

# Step 4: Verify installation
Write-Host "[4/4] Verifying installation..." -ForegroundColor Green

$raylibPath = nimble path raylib 2>&1

if ($raylibPath -match "raylib") {
    Write-Host "  ✓ raylib is correctly installed at:" -ForegroundColor Green
    Write-Host "    $raylibPath" -ForegroundColor White
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "  Installation Fixed! ✓" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Now you can compile:" -ForegroundColor Yellow
    Write-Host "  nim c -r src\main.nim" -ForegroundColor White
} else {
    Write-Host "  ✗ raylib installation issue persists" -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual fix required:" -ForegroundColor Yellow
    Write-Host "1. Try: nimble install https://github.com/planetis-m/raylib" -ForegroundColor White
    Write-Host "2. Or check: nimble list -i" -ForegroundColor White
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")