# ==============================================================================
# Kai Optimizer - Gaming Module
# Windows 10 & 11 gaming optimizations: Game Mode, DVR disabling,
# 1:1 raw mouse precision, CPU foreground scheduling, HAGS, and latency tweaks.
# ==============================================================================

# Import Core module for unified logging and registry handling
if (-not (Get-Command Write-KaiLog -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot "Core.psm1") -Global
}

function Invoke-KaiGameModeOptimization {
    <#
    .SYNOPSIS
        Enables Windows Auto Game Mode and disables Game DVR background recording.
    #>
    Write-KaiLog "Configuring Windows Game Mode and Game DVR..." -Level INFO

    # 1. Enable Windows Auto Game Mode
    Set-KaiRegistryValue -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1 -PropertyType DWord | Out-Null

    # 2. Disable Game DVR and background clip capture (prevents background GPU encoding overhead)
    Set-KaiRegistryValue -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -PropertyType DWord | Out-Null
    Set-KaiRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -PropertyType DWord | Out-Null
    Set-KaiRegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0 -PropertyType DWord | Out-Null

    Write-KaiLog "Game Mode enabled & Game DVR background capture disabled." -Level SUCCESS
}

function Invoke-KaiRawMouseAimFix {
    <#
    .SYNOPSIS
        Disables Windows Enhance Pointer Precision (mouse acceleration)
        for 1:1 true raw mouse aim in competitive shooter games like Rivals.
    #>
    Write-KaiLog "Disabling Windows mouse acceleration for consistent FPS aim..." -Level INFO

    Set-KaiRegistryValue -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0" -PropertyType String | Out-Null
    Set-KaiRegistryValue -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0" -PropertyType String | Out-Null
    Set-KaiRegistryValue -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0" -PropertyType String | Out-Null

    Write-KaiLog "Mouse acceleration disabled (1:1 raw input active)." -Level SUCCESS
}

function Invoke-KaiCpuSchedulingOptimization {
    <#
    .SYNOPSIS
        Tunes CPU time-slice allocation to prioritize active foreground games
        over background background processes (Win32PrioritySeparation = 0x26).
    #>
    Write-KaiLog "Optimizing CPU process priority scheduling for games..." -Level INFO

    # Win32PrioritySeparation = 38 (0x26) -> Prioritize foreground programs
    Set-KaiRegistryValue -Path "HKLM:\System\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38 -PropertyType DWord | Out-Null

    # System Responsiveness: 10 (Allocates 90% CPU reserve to multimedia/games)
    Set-KaiRegistryValue -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 10 -PropertyType DWord | Out-Null

    # Tasks\Games Priority
    $gameTasksPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    Set-KaiRegistryValue -Path $gameTasksPath -Name "Priority" -Value 6 -PropertyType DWord | Out-Null
    Set-KaiRegistryValue -Path $gameTasksPath -Name "GPU Priority" -Value 8 -PropertyType DWord | Out-Null
    Set-KaiRegistryValue -Path $gameTasksPath -Name "Scheduling Category" -Value "High" -PropertyType String | Out-Null

    Write-KaiLog "CPU & GPU scheduling prioritized for foreground games." -Level SUCCESS
}

function Invoke-KaiUiSnappinessOptimization {
    <#
    .SYNOPSIS
        Removes artificial Windows menu delays (MenuShowDelay from 400ms to 0ms).
    #>
    Write-KaiLog "Removing Windows menu hover delays for instant UI reaction..." -Level INFO

    Set-KaiRegistryValue -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0" -PropertyType String | Out-Null

    Write-KaiLog "Menu show delay set to 0ms." -Level SUCCESS
}

function Invoke-KaiGpuScheduling {
    <#
    .SYNOPSIS
        Enables Hardware-Accelerated GPU Scheduling (HAGS) if supported by the driver.
    #>
    Write-KaiLog "Enabling Hardware-Accelerated GPU Scheduling (HAGS)..." -Level INFO

    Set-KaiRegistryValue -Path "HKLM:\System\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -PropertyType DWord | Out-Null

    Write-KaiLog "HAGS enabled (takes full effect after system restart)." -Level SUCCESS
}

function Invoke-KaiWindowedGameOptimization {
    <#
    .SYNOPSIS
        Enables DirectX Flip presentation model for windowed and borderless games.
    #>
    Write-KaiLog "Enabling DirectX Flip presentation model for reduced input lag..." -Level INFO

    Set-KaiRegistryValue -Path "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings" -Value "SwapEffectUpgradeEnable=1;" -PropertyType String | Out-Null

    Write-KaiLog "DirectX Flip optimizations enabled." -Level SUCCESS
}

function Invoke-KaiAllGamingTweaks {
    <#
    .SYNOPSIS
        Runs all safe gaming optimizations in one unified call (used in Simple Mode).
    #>
    Invoke-KaiGameModeOptimization
    Invoke-KaiRawMouseAimFix
    Invoke-KaiCpuSchedulingOptimization
    Invoke-KaiUiSnappinessOptimization
    Invoke-KaiGpuScheduling
    Invoke-KaiWindowedGameOptimization
}

Export-ModuleMember -Function Invoke-KaiGameModeOptimization, Invoke-KaiRawMouseAimFix, Invoke-KaiCpuSchedulingOptimization, Invoke-KaiUiSnappinessOptimization, Invoke-KaiGpuScheduling, Invoke-KaiWindowedGameOptimization, Invoke-KaiAllGamingTweaks
