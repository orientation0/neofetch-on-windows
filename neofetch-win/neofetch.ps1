#Requires -Version 5.1
<#
.SYNOPSIS
    neofetch for Windows — красивый вывод информации о системе
.DESCRIPTION
    Аналог Linux neofetch. Работает в Windows PowerShell 5.1+ и PowerShell 7+.
    Поддерживает Windows Terminal, conhost (с VT), Windows 10/11.
#>

[CmdletBinding()]
param(
    [switch]$NoArt,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
neofetch for Windows

Использование:
  neofetch          — полный вывод с логотипом
  neofetch -NoArt   — только информация без ASCII-арта
  neofetch -Help    — эта справка

Установка (чтобы работало из любого места):
  . .\install.ps1
"@
    exit 0
}

# ---------- Цвета (ANSI) ----------
$esc = [char]27
function C([string]$code, [string]$text) { "$esc[$($code)m$text$esc[0m" }

$cReset  = "$esc[0m"
$cBold   = "$esc[1m"
$cDim    = "$esc[2m"
$cRed    = "$esc[31m"
$cGreen  = "$esc[32m"
$cYellow = "$esc[33m"
$cBlue   = "$esc[34m"
$cMagenta= "$esc[35m"
$cCyan   = "$esc[36m"
$cWhite  = "$esc[37m"
$cBrightBlue = "$esc[94m"
$cBrightCyan = "$esc[96m"

# Цвета для лейблов и значений
$labelColor = $cCyan
$valueColor = $cWhite
$titleColor = $cBrightCyan

# ---------- Включение ANSI в старых консолях ----------
function Enable-Ansi {
    try {
        $kernel32 = Add-Type -MemberDefinition @"
[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, int mode);
[DllImport("kernel32.dll", SetLastError=true)]
public static extern IntPtr GetStdHandle(int handle);
[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out int mode);
"@ -Name "Kernel32" -Namespace "Win32" -PassThru -ErrorAction SilentlyContinue

        if ($kernel32) {
            $handle = $kernel32::GetStdHandle(-11) # STD_OUTPUT_HANDLE
            $mode = 0
            if ($kernel32::GetConsoleMode($handle, [ref]$mode)) {
                $mode = $mode -bor 0x0004  # ENABLE_VIRTUAL_TERMINAL_PROCESSING
                [void]$kernel32::SetConsoleMode($handle, $mode)
            }
        }
    } catch {}
}
Enable-Ansi

# ---------- Сбор информации ----------
function Get-OSInfo {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if (-not $os) { return "Windows" }

    $caption = $os.Caption -replace "Microsoft ", ""
    $arch = if ([Environment]::Is64BitOperatingSystem) { "x86_64" } else { "x86" }
    $build = $os.BuildNumber

    # Windows 11 detection
    if ($build -ge 22000 -and $caption -match "Windows 10") {
        $caption = $caption -replace "Windows 10", "Windows 11"
    }

    return "$caption ($build) $arch"
}

function Get-HostName {
    return $env:COMPUTERNAME
}

function Get-UserName {
    return $env:USERNAME
}

function Get-Kernel {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os) {
        return "NT $($os.Version)"
    }
    return "NT $([Environment]::OSVersion.Version.ToString())"
}

function Get-Uptime {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $uptime = (Get-Date) - $os.LastBootUpTime
        $parts = @()
        if ($uptime.Days -gt 0)    { $parts += "$($uptime.Days)d" }
        if ($uptime.Hours -gt 0)   { $parts += "$($uptime.Hours)h" }
        if ($uptime.Minutes -gt 0) { $parts += "$($uptime.Minutes)m" }
        if ($parts.Count -eq 0)    { $parts += "$($uptime.Seconds)s" }
        return ($parts -join " ")
    } catch {
        return "unknown"
    }
}

function Get-Shell {
    $psVer = $PSVersionTable.PSVersion
    if ($psVer.Major -ge 6) {
        return "PowerShell $psVer"
    }
    return "Windows PowerShell $psVer"
}

function Get-Resolution {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $screens = [System.Windows.Forms.Screen]::AllScreens
        $primary = $screens | Where-Object { $_.Primary } | Select-Object -First 1
        if ($primary) {
            $res = "$($primary.Bounds.Width)x$($primary.Bounds.Height)"
            if ($screens.Count -gt 1) {
                $res += " ($($screens.Count) screens)"
            }
            return $res
        }
    } catch {}

    # fallback
    try {
        $v = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
             Where-Object { $_.CurrentHorizontalResolution } |
             Select-Object -First 1
        if ($v) {
            return "$($v.CurrentHorizontalResolution)x$($v.CurrentVerticalResolution)"
        }
    } catch {}
    return "unknown"
}

function Get-DE {
    # На Windows 10/11 это всегда Explorer / DWM
    $build = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).BuildNumber
    if ($build -ge 22000) { return "Fluent (Windows 11)" }
    return "Aero (Windows 10)"
}

function Get-WM {
    return "DWM (Desktop Window Manager)"
}

function Get-Terminal {
    # Пытаемся угадать терминал
    if ($env:WT_SESSION) { return "Windows Terminal" }
    if ($env:TERM_PROGRAM -eq "vscode") { return "VS Code" }
    if ($host.Name -eq "ConsoleHost") {
        if ($PSVersionTable.PSVersion.Major -ge 6) { return "PowerShell Console" }
        return "conhost"
    }
    return $host.Name
}

function Get-CPU {
    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $name = $cpu.Name -replace '\s+', ' ' -replace '\(R\)|\(TM\)', ''
        $name = $name.Trim()
        $cores = $cpu.NumberOfCores
        $threads = $cpu.NumberOfLogicalProcessors
        return "$name ($cores cores / $threads threads)"
    } catch {
        return "unknown"
    }
}

function Get-GPU {
    try {
        $gpus = Get-CimInstance Win32_VideoController -ErrorAction Stop |
                Where-Object { $_.Name -and $_.Name -notmatch "Microsoft Basic|Remote" }
        if (-not $gpus) { return "unknown" }

        $names = $gpus | ForEach-Object {
            ($_.Name -replace '\s+', ' ').Trim()
        } | Select-Object -Unique

        return ($names -join " + ")
    } catch {
        return "unknown"
    }
}

function Get-Memory {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $total = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $free  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        $used  = [math]::Round($total - $free, 1)
        $pct   = [math]::Round(($used / $total) * 100)
        return "${used} GiB / ${total} GiB (${pct}%)"
    } catch {
        return "unknown"
    }
}

function Get-Disk {
    try {
        $sysDrive = $env:SystemDrive
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$sysDrive'" -ErrorAction Stop
        $total = [math]::Round($disk.Size / 1GB, 1)
        $free  = [math]::Round($disk.FreeSpace / 1GB, 1)
        $used  = [math]::Round($total - $free, 1)
        $pct   = [math]::Round(($used / $total) * 100)
        return "${used} GiB / ${total} GiB (${pct}%) [$sysDrive]"
    } catch {
        return "unknown"
    }
}

function Get-Packages {
    # Примерно: количество установленных программ из реестра
    try {
        $paths = @(
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        $count = 0
        foreach ($p in $paths) {
            $count += @(Get-ItemProperty $p -ErrorAction SilentlyContinue).Count
        }
        return "$count (winget/choco/scoop не считаются)"
    } catch {
        return "unknown"
    }
}

function Get-Battery {
    try {
        $batt = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if (-not $batt) { return $null }
        $pct = $batt.EstimatedChargeRemaining
        $status = switch ($batt.BatteryStatus) {
            1 { "Other" }
            2 { "Unknown" }
            3 { "Fully Charged" }
            4 { "Low" }
            5 { "Critical" }
            6 { "Charging" }
            7 { "Charging and High" }
            8 { "Charging and Low" }
            9 { "Charging and Critical" }
            10 { "Undefined" }
            11 { "Partially Charged" }
            default { "Unknown" }
        }
        return "$pct% ($status)"
    } catch {
        return $null
    }
}

# ---------- ASCII-арт Windows ----------
$windowsLogo = @(
    "                                ..,",
    "                    ....,,:;+ccllll",
    "      ...,,+:;  cllllllllllllllllll",
    ",cclllllllllll  lllllllllllllllllll",
    "llllllllllllll  lllllllllllllllllll",
    "llllllllllllll  lllllllllllllllllll",
    "llllllllllllll  lllllllllllllllllll",
    "llllllllllllll  lllllllllllllllllll",
    "llllllllllllll  lllllllllllllllllll",
    "                                   ",
    "llllllllllllll  lllllllllllllllllll",
    "llllllllllllll  lllllllllllllllllll",
    "llllllllllllll  lllllllllllllllllll",
    "llllllllllllll  lllllllllllllllllll",
    "llllllllllllll  lllllllllllllllllll",
    "``'ccllllllllll  lllllllllllllllllll",
    "      ``' \\*::  :ccllllllllllllllll",
    "                       ````````''*::cll",
    "                                 ````"
)

# Более компактный и узнаваемый логотип
$logoCompact = @(
    "${cBlue}             ${cReset}${cBrightBlue}.,,:clool;,${cReset}",
    "${cBlue}          ${cReset}${cBrightBlue}.,odOOOOOOOOOOdl;${cReset}",
    "${cBlue}       ${cReset}${cBrightBlue}.,odOOOOOOOOOOOOOOOOdl;${cReset}",
    "${cBlue}     ${cReset}${cBrightBlue},lkOOOOOOOOOOOOOOOOOOOOOOxl,${cReset}",
    "${cBlue}   ${cReset}${cBrightBlue},lkOOOOOOOOOOOOOOOOOOOOOOOOOOxl,${cReset}",
    "${cBlue}  ${cReset}${cBrightBlue};kOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOk;${cReset}",
    "${cBlue} ${cReset}${cBrightBlue}:kOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOk:${cReset}",
    "${cBlue}${cReset}${cBrightBlue}:kOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOk:${cReset}",
    "${cBlue}${cReset}${cBrightBlue}dOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOd${cReset}",
    "${cBlue}${cReset}${cBrightBlue}dOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOd${cReset}",
    "${cBlue}${cReset}${cBrightBlue}:kOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOk:${cReset}",
    "${cBlue} ${cReset}${cBrightBlue}:kOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOk:${cReset}",
    "${cBlue}  ${cReset}${cBrightBlue};kOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOk;${cReset}",
    "${cBlue}   ${cReset}${cBrightBlue},lkOOOOOOOOOOOOOOOOOOOOOOOOOOxl,${cReset}",
    "${cBlue}     ${cReset}${cBrightBlue},lkOOOOOOOOOOOOOOOOOOOOOOxl,${cReset}",
    "${cBlue}       ${cReset}${cBrightBlue}.,odOOOOOOOOOOOOOOOOdl;${cReset}",
    "${cBlue}          ${cReset}${cBrightBlue}.,odOOOOOOOOOOdl;${cReset}",
    "${cBlue}             ${cReset}${cBrightBlue}.,,:clool;,${cReset}"
)

# Классический 4-цветный логотип Windows (самый узнаваемый в neofetch-портах)
$logoClassic = @(
    "        ${cRed}████████${cReset}  ${cGreen}████████${cReset}",
    "        ${cRed}████████${cReset}  ${cGreen}████████${cReset}",
    "        ${cRed}████████${cReset}  ${cGreen}████████${cReset}",
    "        ${cRed}████████${cReset}  ${cGreen}████████${cReset}",
    "        ${cRed}████████${cReset}  ${cGreen}████████${cReset}",
    "",
    "        ${cBlue}████████${cReset}  ${cYellow}████████${cReset}",
    "        ${cBlue}████████${cReset}  ${cYellow}████████${cReset}",
    "        ${cBlue}████████${cReset}  ${cYellow}████████${cReset}",
    "        ${cBlue}████████${cReset}  ${cYellow}████████${cReset}",
    "        ${cBlue}████████${cReset}  ${cYellow}████████${cReset}"
)

# Более крупный вариант
$logoNeo = @(
    " ${cRed}██████████${cReset}    ${cGreen}██████████${cReset}",
    " ${cRed}██████████${cReset}    ${cGreen}██████████${cReset}",
    " ${cRed}██████████${cReset}    ${cGreen}██████████${cReset}",
    " ${cRed}██████████${cReset}    ${cGreen}██████████${cReset}",
    " ${cRed}██████████${cReset}    ${cGreen}██████████${cReset}",
    " ${cRed}██████████${cReset}    ${cGreen}██████████${cReset}",
    "",
    " ${cBlue}██████████${cReset}    ${cYellow}██████████${cReset}",
    " ${cBlue}██████████${cReset}    ${cYellow}██████████${cReset}",
    " ${cBlue}██████████${cReset}    ${cYellow}██████████${cReset}",
    " ${cBlue}██████████${cReset}    ${cYellow}██████████${cReset}",
    " ${cBlue}██████████${cReset}    ${cYellow}██████████${cReset}",
    " ${cBlue}██████████${cReset}    ${cYellow}██████████${cReset}"
)

# ---------- Сбор всех данных ----------
$user     = Get-UserName
$hostName = Get-HostName
$os       = Get-OSInfo
$kernel   = Get-Kernel
$uptime   = Get-Uptime
$packages = Get-Packages
$shell    = Get-Shell
$res      = Get-Resolution
$de       = Get-DE
$wm       = Get-WM
$term     = Get-Terminal
$cpu      = Get-CPU
$gpu      = Get-GPU
$mem      = Get-Memory
$disk     = Get-Disk
$battery  = Get-Battery

# ---------- Формирование строк информации ----------
$infoLines = [System.Collections.Generic.List[string]]::new()

$infoLines.Add("${titleColor}${cBold}${user}${cReset}${cDim}@${cReset}${titleColor}${cBold}${hostName}${cReset}")
$infoLines.Add("${cDim}$('-' * ($user.Length + $hostName.Length + 1))${cReset}")
$infoLines.Add("${labelColor}${cBold}OS${cReset}: ${valueColor}${os}${cReset}")
$infoLines.Add("${labelColor}${cBold}Host${cReset}: ${valueColor}${hostName}${cReset}")
$infoLines.Add("${labelColor}${cBold}Kernel${cReset}: ${valueColor}${kernel}${cReset}")
$infoLines.Add("${labelColor}${cBold}Uptime${cReset}: ${valueColor}${uptime}${cReset}")
$infoLines.Add("${labelColor}${cBold}Packages${cReset}: ${valueColor}${packages}${cReset}")
$infoLines.Add("${labelColor}${cBold}Shell${cReset}: ${valueColor}${shell}${cReset}")
$infoLines.Add("${labelColor}${cBold}Resolution${cReset}: ${valueColor}${res}${cReset}")
$infoLines.Add("${labelColor}${cBold}DE${cReset}: ${valueColor}${de}${cReset}")
$infoLines.Add("${labelColor}${cBold}WM${cReset}: ${valueColor}${wm}${cReset}")
$infoLines.Add("${labelColor}${cBold}Terminal${cReset}: ${valueColor}${term}${cReset}")
$infoLines.Add("${labelColor}${cBold}CPU${cReset}: ${valueColor}${cpu}${cReset}")
$infoLines.Add("${labelColor}${cBold}GPU${cReset}: ${valueColor}${gpu}${cReset}")
$infoLines.Add("${labelColor}${cBold}Memory${cReset}: ${valueColor}${mem}${cReset}")
$infoLines.Add("${labelColor}${cBold}Disk${cReset}: ${valueColor}${disk}${cReset}")

if ($battery) {
    $infoLines.Add("${labelColor}${cBold}Battery${cReset}: ${valueColor}${battery}${cReset}")
}

# Цветовые блоки (как в настоящем neofetch)
$colorBlocks = "   "
for ($i = 0; $i -le 7; $i++) {
    $colorBlocks += "${esc}[4${i}m   ${cReset}"
}
$infoLines.Add("")
$infoLines.Add($colorBlocks)
$colorBlocksBright = "   "
for ($i = 0; $i -le 7; $i++) {
    $colorBlocksBright += "${esc}[10${i}m   ${cReset}"
}
$infoLines.Add($colorBlocksBright)

# ---------- Вывод ----------
$logo = $logoNeo   # можно заменить на $logoClassic

if ($NoArt) {
    foreach ($line in $infoLines) {
        Write-Host $line
    }
    exit 0
}

# Выравниваем логотип и информацию
$maxLogoWidth = ($logo | ForEach-Object {
    # убираем ANSI для подсчёта длины
    $plain = $_ -replace '\x1b\[[0-9;]*m', ''
    $plain.Length
} | Measure-Object -Maximum).Maximum

$logoHeight = $logo.Count
$infoHeight = $infoLines.Count
$maxHeight = [Math]::Max($logoHeight, $infoHeight)

for ($i = 0; $i -lt $maxHeight; $i++) {
    $left  = if ($i -lt $logoHeight) { $logo[$i] } else { "" }
    $right = if ($i -lt $infoHeight) { $infoLines[$i] } else { "" }

    # паддинг слева
    $plainLeft = $left -replace '\x1b\[[0-9;]*m', ''
    $pad = $maxLogoWidth - $plainLeft.Length + 3
    if ($pad -lt 3) { $pad = 3 }

    Write-Host ("$left" + (" " * $pad) + "$right")
}

Write-Host ""
