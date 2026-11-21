#Requires -Version 5.1
# Installs neofetch so the command "neofetch" works from anywhere

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$neofetchScript = Join-Path $scriptDir "neofetch.ps1"

if (-not (Test-Path $neofetchScript)) {
    Write-Error "neofetch.ps1 not found next to install.ps1"
    exit 1
}

$installDir = Join-Path $env:LOCALAPPDATA "neofetch"
$targetScript = Join-Path $installDir "neofetch.ps1"
$targetCmd    = Join-Path $installDir "neofetch.cmd"

Write-Host "Installing neofetch..." -ForegroundColor Cyan
Write-Host "  -> $installDir"

New-Item -ItemType Directory -Path $installDir -Force | Out-Null
Copy-Item -Path $neofetchScript -Destination $targetScript -Force

$cmdContent = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0neofetch.ps1`" %*"
Set-Content -Path $targetCmd -Value $cmdContent -Encoding ASCII

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$installDir*") {
    if ([string]::IsNullOrEmpty($userPath)) {
        $newPath = $installDir
    } else {
        $newPath = $userPath + ";" + $installDir
    }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "  -> Added to user PATH" -ForegroundColor Green
} else {
    Write-Host "  -> Already in PATH" -ForegroundColor DarkGray
}

if ($env:Path -notlike "*$installDir*") {
    $env:Path = $env:Path + ";" + $installDir
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
Write-Host ""
Write-Host "Now you can type:" -ForegroundColor White
Write-Host "  neofetch" -ForegroundColor Yellow
Write-Host ""
Write-Host "If command not found - open a NEW terminal window." -ForegroundColor DarkGray
Write-Host ""
