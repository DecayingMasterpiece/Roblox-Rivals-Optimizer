<#
.SYNOPSIS
    Roblox Rivals Optimizer - Main Application
    Author: Kaiser (@KaiserEverhart-Adaptation on YouTube)
    Description: High-performance, safe, universal gaming optimizer for Windows 10 & 11.
#>

# Requires Administrator privileges
#Requires -RunAsAdministrator

# Set ErrorActionPreference
$ErrorActionPreference = "Continue"

# Determine script root dynamically
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
if (-not $ScriptDir) {
    $ScriptDir = (Get-Location).Path
}

# Add required WPF & Forms assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# Import Custom Modules Globally
Import-Module (Join-Path $ScriptDir "Modules\Core.psm1") -Global -Force
Import-Module (Join-Path $ScriptDir "Modules\Debloat.psm1") -Global -Force
Import-Module (Join-Path $ScriptDir "Modules\Gaming.psm1") -Global -Force
Import-Module (Join-Path $ScriptDir "Modules\FastFlags.psm1") -Global -Force
Import-Module (Join-Path $ScriptDir "Modules\Network.psm1") -Global -Force
Import-Module (Join-Path $ScriptDir "Modules\GpuHelper.psm1") -Global -Force

# Load XAML
$XamlPath = Join-Path $ScriptDir "UI\MainWindow.xaml"
if (-not (Test-Path $XamlPath)) {
    Write-Error "Cannot locate MainWindow.xaml at $XamlPath"
    Exit
}

[xml]$XamlContent = Get-Content -Path $XamlPath -Raw -Encoding UTF8
$StringReader = New-Object System.IO.StringReader($XamlContent.OuterXml)
$XmlReader    = [System.Xml.XmlReader]::Create($StringReader)
$Window       = [System.Windows.Markup.XamlReader]::Load($XmlReader)

# Extract UI Elements by x:Name
$ImgAppLogo             = $Window.FindName("ImgAppLogo")
$BtnMinimize            = $Window.FindName("BtnMinimize")
$BtnClose               = $Window.FindName("BtnClose")

# Load and Bind Custom Application Logo & Window Icon
$LogoPath = Join-Path $ScriptDir "UI\Assets\logo.png"
if (Test-Path $LogoPath) {
    try {
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.UriSource = [System.Uri]::new($LogoPath, [System.UriKind]::Absolute)
        $bitmap.EndInit()
        if ($ImgAppLogo) { $ImgAppLogo.Source = $bitmap }
        $Window.Icon = $bitmap
    } catch {
        # Fallback gracefully if image cannot be parsed
    }
}
$BtnModeSimple          = $Window.FindName("BtnModeSimple")
$BtnModeAdvanced        = $Window.FindName("BtnModeAdvanced")
$ViewSimple             = $Window.FindName("ViewSimple")
$ViewAdvanced           = $Window.FindName("ViewAdvanced")

$BtnStartQuickOptimize  = $Window.FindName("BtnStartQuickOptimize")
$ProgressSimple         = $Window.FindName("ProgressSimple")
$TxtSimpleStatus        = $Window.FindName("TxtSimpleStatus")
$TxtDiagOs              = $Window.FindName("TxtDiagOs")
$TxtDiagGpu             = $Window.FindName("TxtDiagGpu")
$TxtDiagRam             = $Window.FindName("TxtDiagRam")
$TxtDiagRoblox          = $Window.FindName("TxtDiagRoblox")

$BtnTab1                = $Window.FindName("BtnTab1")
$BtnTab2                = $Window.FindName("BtnTab2")
$BtnTab3                = $Window.FindName("BtnTab3")
$BtnTab4                = $Window.FindName("BtnTab4")
$PanelStep1             = $Window.FindName("PanelStep1")
$PanelStep2             = $Window.FindName("PanelStep2")
$PanelStep3             = $Window.FindName("PanelStep3")
$PanelStep4             = $Window.FindName("PanelStep4")

$ChkGameMode            = $Window.FindName("ChkGameMode")
$ChkRawMouse            = $Window.FindName("ChkRawMouse")
$ChkCpuPriority         = $Window.FindName("ChkCpuPriority")
$ChkDirectXFlip         = $Window.FindName("ChkDirectXFlip")
$ChkTelemetry           = $Window.FindName("ChkTelemetry")
$ChkMenuDelay           = $Window.FindName("ChkMenuDelay")
$ChkCleanBloat          = $Window.FindName("ChkCleanBloat")
$ChkTempClean           = $Window.FindName("ChkTempClean")
$BtnApplyStep1          = $Window.FindName("BtnApplyStep1")
$BtnCleanJunkNow        = $Window.FindName("BtnCleanJunkNow")
$BtnCreateRestorePoint  = $Window.FindName("BtnCreateRestorePoint")

$RadioPresetKaiser      = $Window.FindName("RadioPresetKaiser")
$RadioPresetSafe        = $Window.FindName("RadioPresetSafe")
$BtnInjectFastFlags     = $Window.FindName("BtnInjectFastFlags")
$BtnCopyFlagsJson       = $Window.FindName("BtnCopyFlagsJson")
$BtnOpenRobloxDir       = $Window.FindName("BtnOpenRobloxDir")
$BtnRevertVanillaFlags  = $Window.FindName("BtnRevertVanillaFlags")

$ChkNagle               = $Window.FindName("ChkNagle")
$ChkWifiScan            = $Window.FindName("ChkWifiScan")
$CmbDnsPreset           = $Window.FindName("CmbDnsPreset")
$BtnApplyNetwork        = $Window.FindName("BtnApplyNetwork")
$BtnFlushDns            = $Window.FindName("BtnFlushDns")
$BtnWatchEthernetVideo  = $Window.FindName("BtnWatchEthernetVideo")

$TxtGpuDetectStatus     = $Window.FindName("TxtGpuDetectStatus")
$BtnOpenNvcpl           = $Window.FindName("BtnOpenNvcpl")
$BtnWatchNvidiaVideo    = $Window.FindName("BtnWatchNvidiaVideo")

$TxtConsoleLog          = $Window.FindName("TxtConsoleLog")
$LogScrollViewer        = $Window.FindName("LogScrollViewer")
$BtnRevertAll           = $Window.FindName("BtnRevertAll")

# UI Logging Helper
function Add-UiLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = (Get-Date).ToString("HH:mm:ss")
    $prefix = switch ($Level) {
        "SUCCESS" { "[+]" }
        "WARN"    { "[!]" }
        "ERROR"   { "[X]" }
        Default   { "[*]" }
    }
    $line = "$prefix [$timestamp] $Message`r`n"
    $TxtConsoleLog.AppendText($line)
    $LogScrollViewer.ScrollToEnd()
    try {
        [System.Windows.Forms.Application]::DoEvents()
    } catch {}
}

# Window Draggable Handler
$Window.Add_MouseLeftButtonDown({
    $Window.DragMove()
})

# Window Controls
$BtnClose.Add_Click({
    $Window.Close()
})

$BtnMinimize.Add_Click({
    $Window.WindowState = [System.Windows.WindowState]::Minimized
})

# Mode Switching (Simple vs Advanced)
$PinkBrush  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF2A85")
$MutedBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#A5A5BA")
$TransBrush = [System.Windows.Media.Brushes]::Transparent

$BtnModeSimple.Add_Click({
    $ViewSimple.Visibility = [System.Windows.Visibility]::Visible
    $ViewAdvanced.Visibility = [System.Windows.Visibility]::Collapsed
    $BtnModeSimple.Background = $PinkBrush
    $BtnModeSimple.Foreground = [System.Windows.Media.Brushes]::White
    $BtnModeAdvanced.Background = $TransBrush
    $BtnModeAdvanced.Foreground = $MutedBrush
})

$BtnModeAdvanced.Add_Click({
    $ViewSimple.Visibility = [System.Windows.Visibility]::Collapsed
    $ViewAdvanced.Visibility = [System.Windows.Visibility]::Visible
    $BtnModeAdvanced.Background = $PinkBrush
    $BtnModeAdvanced.Foreground = [System.Windows.Media.Brushes]::White
    $BtnModeSimple.Background = $TransBrush
    $BtnModeSimple.Foreground = $MutedBrush
})

# Stepper Navigation (Advanced Mode)
function Switch-StepPanel {
    param([int]$StepNumber)
    $PanelStep1.Visibility = [System.Windows.Visibility]::Collapsed
    $PanelStep2.Visibility = [System.Windows.Visibility]::Collapsed
    $PanelStep3.Visibility = [System.Windows.Visibility]::Collapsed
    $PanelStep4.Visibility = [System.Windows.Visibility]::Collapsed

    $BtnTab1.Foreground = $MutedBrush; $BtnTab1.FontWeight = [System.Windows.FontWeights]::SemiBold
    $BtnTab2.Foreground = $MutedBrush; $BtnTab2.FontWeight = [System.Windows.FontWeights]::SemiBold
    $BtnTab3.Foreground = $MutedBrush; $BtnTab3.FontWeight = [System.Windows.FontWeights]::SemiBold
    $BtnTab4.Foreground = $MutedBrush; $BtnTab4.FontWeight = [System.Windows.FontWeights]::SemiBold

    switch ($StepNumber) {
        1 {
            $PanelStep1.Visibility = [System.Windows.Visibility]::Visible
            $BtnTab1.Foreground = $PinkBrush; $BtnTab1.FontWeight = [System.Windows.FontWeights]::Bold
        }
        2 {
            $PanelStep2.Visibility = [System.Windows.Visibility]::Visible
            $BtnTab2.Foreground = $PinkBrush; $BtnTab2.FontWeight = [System.Windows.FontWeights]::Bold
        }
        3 {
            $PanelStep3.Visibility = [System.Windows.Visibility]::Visible
            $BtnTab3.Foreground = $PinkBrush; $BtnTab3.FontWeight = [System.Windows.FontWeights]::Bold
        }
        4 {
            $PanelStep4.Visibility = [System.Windows.Visibility]::Visible
            $BtnTab4.Foreground = $PinkBrush; $BtnTab4.FontWeight = [System.Windows.FontWeights]::Bold
        }
    }
}

$BtnTab1.Add_Click({ Switch-StepPanel -StepNumber 1 })
$BtnTab2.Add_Click({ Switch-StepPanel -StepNumber 2 })
$BtnTab3.Add_Click({ Switch-StepPanel -StepNumber 3 })
$BtnTab4.Add_Click({ Switch-StepPanel -StepNumber 4 })

# Hardware Diagnostics Initialization
$Diagnostics = Get-SystemDiagnostics
$TxtDiagOs.Text  = "OS: $($Diagnostics.OSName) (Build $($Diagnostics.OSBuild))"
$TxtDiagGpu.Text = "GPU: $($Diagnostics.GpuNames)"
$TxtDiagRam.Text = "RAM: $($Diagnostics.TotalRAM)"

# Roblox Installations Check
$RobloxTargets = Find-RobloxInstallations
if (@($RobloxTargets).Count -gt 0) {
    $targetNames = ($RobloxTargets | Select-Object -ExpandProperty Type) -join ", "
    $TxtDiagRoblox.Text = "Roblox: Found ($targetNames)"
} else {
    $TxtDiagRoblox.Text = "Roblox: Standard Client (Ready for injection)"
}

# GPU Status Banner
if ($Diagnostics.IsNvidia) {
    $TxtGpuDetectStatus.Text = "[OK] NVIDIA GeForce GPU Detected"
    $TxtGpuDetectStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4ADE80")
} else {
    $TxtGpuDetectStatus.Text = "[INFO] Non-NVIDIA GPU Detected (AMD / Intel)"
    $TxtGpuDetectStatus.Foreground = $PinkBrush
}

Add-UiLog "Roblox Rivals Optimizer initialized successfully." "SUCCESS"
Add-UiLog "System: $($Diagnostics.OSName) | GPU: $($Diagnostics.GpuNames)" "INFO"

# ------------------------------------------------------------------------------
# Action: Simple 1-Click Optimize
# ------------------------------------------------------------------------------
$BtnStartQuickOptimize.Add_Click({
    $BtnStartQuickOptimize.IsEnabled = $false
    $ProgressSimple.Visibility = [System.Windows.Visibility]::Visible
    $ProgressSimple.Value = 10
    $TxtSimpleStatus.Text = "Creating System Restore Point..."
    Add-UiLog "Starting Quick 1-Click Optimization..." "INFO"

    # Step 1: Restore Point
    New-KaiRestorePoint | Out-Null
    $ProgressSimple.Value = 30
    $TxtSimpleStatus.Text = "Optimizing Windows & Minimizing Telemetry..."
    Add-UiLog "System Restore Point initiated." "SUCCESS"

    # Step 2: Debloat, Telemetry & Junk Cleanup
    Invoke-KaiTelemetryDebloat
    Invoke-KaiSafeUwpRemoval
    Invoke-KaiTempCleanup
    $ProgressSimple.Value = 50
    $TxtSimpleStatus.Text = "Applying Gaming & Mouse Precision Tweaks..."
    Add-UiLog "Windows telemetry, bloat & junk files cleared." "SUCCESS"

    # Step 3: Gaming & Raw Aim
    Invoke-KaiAllGamingTweaks
    $ProgressSimple.Value = 70
    $TxtSimpleStatus.Text = "Injecting Kaiser's Potato Mode FastFlags..."
    Add-UiLog "Game Mode enabled & mouse acceleration eliminated." "SUCCESS"

    # Step 4: FastFlags
    Install-KaiFastFlags -PresetName 'KaiserPotato' | Out-Null
    $ProgressSimple.Value = 85
    $TxtSimpleStatus.Text = "Optimizing Network & Nagle's Algorithm..."
    Add-UiLog "FastFlags (Potato Mode 361 FPS) injected into Roblox." "SUCCESS"

    # Step 5: Network & DNS
    Invoke-KaiNagleAlgorithmOptimization
    Set-KaiDnsServers -DnsPreset 'Cloudflare'
    Invoke-KaiFlushDnsCache
    $ProgressSimple.Value = 100
    $TxtSimpleStatus.Text = "Done! Please restart your PC and launch Rivals."

    Add-UiLog "Quick Optimization Complete! Restart your computer for maximum FPS." "SUCCESS"
    $BtnStartQuickOptimize.Content = "FULLY OPTIMIZED!"
    $BtnStartQuickOptimize.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#22C55E")
})

# ------------------------------------------------------------------------------
# Advanced Mode: Step 1 (Windows & Debloat)
# ------------------------------------------------------------------------------
$BtnCreateRestorePoint.Add_Click({
    Add-UiLog "Manual Restore Point requested..." "INFO"
    $res = New-KaiRestorePoint
    if ($res) {
        Add-UiLog "System Restore Point created successfully." "SUCCESS"
    } else {
        Add-UiLog "Restore point could not be created directly; file backup active." "WARN"
    }
})

$BtnApplyStep1.Add_Click({
    Add-UiLog "Applying selected Windows & Debloat tweaks..." "INFO"
    if ($ChkGameMode.IsChecked)    { Invoke-KaiGameModeOptimization; Add-UiLog "Game Mode configured." "SUCCESS" }
    if ($ChkRawMouse.IsChecked)    { Invoke-KaiRawMouseAimFix; Add-UiLog "Mouse acceleration disabled." "SUCCESS" }
    if ($ChkCpuPriority.IsChecked) { Invoke-KaiCpuSchedulingOptimization; Add-UiLog "CPU foreground priority tuned." "SUCCESS" }
    if ($ChkDirectXFlip.IsChecked) { Invoke-KaiWindowedGameOptimization; Add-UiLog "DirectX Flip model enabled." "SUCCESS" }
    if ($ChkTelemetry.IsChecked)   { Invoke-KaiTelemetryDebloat; Add-UiLog "Telemetry disabled." "SUCCESS" }
    if ($ChkMenuDelay.IsChecked)   { Invoke-KaiUiSnappinessOptimization; Add-UiLog "Menu delay removed." "SUCCESS" }
    if ($ChkCleanBloat.IsChecked)  { Invoke-KaiSafeUwpRemoval; Add-UiLog "Sponsored bloat cleaned." "SUCCESS" }
    if ($ChkTempClean.IsChecked)   { Invoke-KaiTempCleanup; Add-UiLog "Prefetch, temp and cache files purged." "SUCCESS" }
    Add-UiLog "Step 1 Tweaks applied successfully!" "SUCCESS"
})

$BtnCleanJunkNow.Add_Click({
    Add-UiLog "Scanning and purging system junk, prefetch, and cache files..." "INFO"
    Invoke-KaiTempCleanup
    Add-UiLog "Weekly system clutter cleanup finished!" "SUCCESS"
})

# ------------------------------------------------------------------------------
# Advanced Mode: Step 2 (FastFlags & Bootstrapper)
# ------------------------------------------------------------------------------
$BtnInjectFastFlags.Add_Click({
    $preset = if ($RadioPresetSafe.IsChecked) { 'SafeLow' } else { 'KaiserPotato' }
    Add-UiLog "Injecting FastFlag Preset: $preset..." "INFO"
    $count = Install-KaiFastFlags -PresetName $preset
    Add-UiLog "FastFlags written to $count directory location(s)." "SUCCESS"
})

$BtnCopyFlagsJson.Add_Click({
    $preset = if ($RadioPresetSafe.IsChecked) { 'SafeLow' } else { 'KaiserPotato' }
    Copy-KaiFastFlagToClipboard -PresetName $preset
    Add-UiLog "FastFlag JSON copied to Clipboard! Paste into Bloxstrap or ClientAppSettings.json." "SUCCESS"
})

$BtnOpenRobloxDir.Add_Click({
    Open-KaiRobloxFolder
    Add-UiLog "Opened Roblox ClientSettings folder in Explorer." "INFO"
})

$BtnRevertVanillaFlags.Add_Click({
    Remove-KaiFastFlags
    Add-UiLog "FastFlags removed. Roblox reverted to vanilla client settings." "SUCCESS"
})

# ------------------------------------------------------------------------------
# Advanced Mode: Step 3 (Network & Wi-Fi)
# ------------------------------------------------------------------------------
$BtnApplyNetwork.Add_Click({
    Add-UiLog "Applying network & latency optimizations..." "INFO"
    if ($ChkNagle.IsChecked) {
        Invoke-KaiNagleAlgorithmOptimization
        Add-UiLog "Nagle's Algorithm packet delay disabled." "SUCCESS"
    }
    if ($ChkWifiScan.IsChecked) {
        Set-KaiWlanAutoConfig -Action 'DisableScan'
        Add-UiLog "Wi-Fi 60-second background scanning paused." "SUCCESS"
    }

    $selectedDns = switch ($CmbDnsPreset.SelectedIndex) {
        0 { 'Cloudflare' }
        1 { 'Google' }
        2 { 'Quad9' }
        3 { 'DHCP' }
        Default { 'Cloudflare' }
    }
    Set-KaiDnsServers -DnsPreset $selectedDns
    Add-UiLog "DNS configured to $selectedDns preset." "SUCCESS"
})

$BtnFlushDns.Add_Click({
    Invoke-KaiFlushDnsCache
    Add-UiLog "DNS cache flushed." "SUCCESS"
})

$BtnWatchEthernetVideo.Add_Click({
    Open-KaiEthernetVideoGuide
    Add-UiLog "Opening Ethernet & Ping video guide on YouTube..." "INFO"
})

# ------------------------------------------------------------------------------
# Advanced Mode: Step 4 (NVIDIA & GPU)
# ------------------------------------------------------------------------------
$BtnOpenNvcpl.Add_Click({
    Open-KaiNvidiaControlPanel | Out-Null
    Add-UiLog "Opening NVIDIA Control Panel..." "INFO"
})

$BtnWatchNvidiaVideo.Add_Click({
    Open-KaiNvidiaVideoGuide
    Add-UiLog "Opening NVIDIA 3D Best Settings video guide on YouTube..." "INFO"
})

# ------------------------------------------------------------------------------
# Footer: Revert All Settings
# ------------------------------------------------------------------------------
$BtnRevertAll.Add_Click({
    Add-UiLog "Revert All Settings requested..." "WARN"
    $reverted = Restore-KaiPreviousState
    if ($reverted) {
        Add-UiLog "All modified registry keys reverted to pre-optimization state!" "SUCCESS"
    } else {
        Add-UiLog "No prior backup snapshot found to revert." "WARN"
    }
})

# Show the Window
$Window.ShowDialog() | Out-Null

