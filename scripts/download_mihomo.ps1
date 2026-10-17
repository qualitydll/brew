# Script to download mihomo core for Windows
# Usage: .\scripts\download_mihomo.ps1

$coreDir = "core"
$coreUrl = "https://github.com/MetaCubeX/mihomo/releases/download/v1.18.7/mihomo-windows-amd64-v1.18.7.zip"
$coreZip = "$coreDir\mihomo.zip"
$coreExe = "$coreDir\mihomo.exe"

# Create core directory if it doesn't exist
if (-not (Test-Path $coreDir)) {
    New-Item -ItemType Directory -Path $coreDir -Force
}

Write-Host "Downloading mihomo v1.18.7..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $coreUrl -OutFile $coreZip -UseBasicParsing

Write-Host "Extracting..." -ForegroundColor Cyan
Expand-Archive -Path $coreZip -DestinationPath $coreDir -Force

# Rename and cleanup
$tempExe = "$coreDir\mihomo-windows-amd64.exe"
if (Test-Path $tempExe) {
    Rename-Item -Path $tempExe -NewName "mihomo.exe" -Force
}

Remove-Item $coreZip -Force

if (Test-Path $coreExe) {
    Write-Host "mihomo.exe downloaded successfully to $coreExe" -ForegroundColor Green
} else {
    Write-Host "Failed to download mihomo.exe" -ForegroundColor Red
    exit 1
}
