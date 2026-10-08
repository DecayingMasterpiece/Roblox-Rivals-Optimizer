# ==============================================================================
# Kai Optimizer - Debloat Module
# Safe Windows 10 & 11 cleanup, telemetry reduction, and background bloat removal.
# ==============================================================================

# Import Core module for unified logging and registry handling
if (-not (Get-Command Write-KaiLog -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot "Core.psm1") -Global
}

function Invoke-KaiTelemetryDebloat {
    <#
    .SYNOPSIS
        Disables DiagTrack service, sets diagnostic data to minimal,
        turns off background customer experience improvement telemetry.
    #>
    Write-KaiLog "Applying safe telemetry optimizations..." -Level INFO

    # 1. Stop and disable Connected User Experiences and Telemetry (DiagTrack)
    try {
        $diagTrack = Get-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
        if ($diagTrack) {
            Stop-Service -Name "DiagTrack" -Force -ErrorAction SilentlyContinue
            Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
            Write-KaiLog "Disabled DiagTrack (Connected User Experiences) service." -Level SUCCESS
        }
    }
    catch {
        Write-KaiLog "Could not disable DiagTrack: $($_.Exception.Message)" -Level WARN
    }

    # 2. Set Diagnostic Data Level to Minimal (Security / Required)
    Set-KaiRegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -PropertyType DWord | Out-Null
    Set-KaiRegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0 -PropertyType DWord | Out-Null

    # 3. Disable Feedback Frequency
    Set-KaiRegistryValue -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0 -PropertyType DWord | Out-Null

    # 4. Disable Advertising ID
    Set-KaiRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -PropertyType DWord | Out-Null

    # 5. Disable Bing Search in Start Menu & Windows Copilot
    Set-KaiRegistryValue -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1 -PropertyType DWord | Out-Null
    Set-KaiRegistryValue -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1 -PropertyType DWord | Out-Null

    Write-KaiLog "Telemetry and background data collection minimized successfully." -Level SUCCESS
}

function Invoke-KaiSafeUwpRemoval {
    <#
    .SYNOPSIS
        Removes preinstalled sponsored bloatware (TikTok, Spotify, Bing News, etc.)
        while strictly preserving Store, Xbox Identity, Paint, Photos, and Calculator.
    #>
    Write-KaiLog "Scanning for sponsored bloatware packages..." -Level INFO

    # Safe removal blacklist: Only remove third-party and sponsored Microsoft clutter
    $junkPackages = @(
        "*Microsoft.BingNews*",
        "*Microsoft.BingWeather*",
        "*Microsoft.GetHelp*",
        "*Microsoft.Getstarted*",
        "*Microsoft.MicrosoftSolitaireCollection*",
        "*Microsoft.People*",
        "*Microsoft.Todos*",
        "*Microsoft.WindowsFeedbackHub*",
        "*Clipchamp.Clipchamp*",
        "*SpotifyAB.SpotifyMusic*",
        "*TikTok*",
        "*Facebook*",
        "*Instagram*",
        "*Disney*"
    )

    $removedCount = 0
    $prevProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        foreach ($pattern in $junkPackages) {
            $packages = Get-AppxPackage -Name $pattern -ErrorAction SilentlyContinue
            foreach ($pkg in $packages) {
                try {
                    Write-KaiLog "Removing bloatware: $($pkg.Name)..." -Level INFO
                    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
                    $removedCount++
                }
                catch {
                    Write-KaiLog "Could not remove $($pkg.Name): $($_.Exception.Message)" -Level WARN
                }
            }
        }
    }
    finally {
        $ProgressPreference = $prevProgress
    }

    if ($removedCount -gt 0) {
        Write-KaiLog "Cleaned $removedCount bloatware packages safely." -Level SUCCESS
    }
    else {
        Write-KaiLog "System is already clean of known bloatware packages." -Level INFO
    }
}

function Invoke-KaiTempCleanup {
    <#
    .SYNOPSIS
        Safely clears user temporary files, Windows Prefetch, DirectX/NVIDIA shader cache,
        crash dumps, WER queues, Delivery Optimization, and Roblox session logs.
    #>
    Write-KaiLog "Scanning and purging system junk, prefetch, and cache files..." -Level INFO

    $cleanupTargets = @(
        @{ Name = "User Temp"; Path = $env:TEMP },
        @{ Name = "Windows Temp"; Path = "C:\Windows\Temp" },
        @{ Name = "Windows Prefetch"; Path = "C:\Windows\Prefetch" },
        @{ Name = "DirectX Shader Cache"; Path = "$env:LOCALAPPDATA\D3DSCache" },
        @{ Name = "NVIDIA DirectX Cache"; Path = "$env:LOCALAPPDATA\NVIDIA\DXCache" },
        @{ Name = "NVIDIA OpenGL Cache"; Path = "$env:LOCALAPPDATA\NVIDIA\GLCache" },
        @{ Name = "Crash Dumps"; Path = "$env:LOCALAPPDATA\CrashDumps" },
        @{ Name = "Windows Error Reports"; Path = "C:\ProgramData\Microsoft\Windows\WER\ReportArchive" },
        @{ Name = "Windows Error Queue"; Path = "C:\ProgramData\Microsoft\Windows\WER\ReportQueue" },
        @{ Name = "Roblox Match Logs"; Path = "$env:LOCALAPPDATA\Roblox\logs" },
        @{ Name = "Roblox HTTP Cache"; Path = "$env:LOCALAPPDATA\Roblox\httpCache" },
        @{ Name = "Bloxstrap Logs"; Path = "$env:LOCALAPPDATA\Bloxstrap\Logs" },
        @{ Name = "Delivery Optimization"; Path = "C:\Windows\SoftwareDistribution\DeliveryOptimization" }
    )

    $clearedBytes = 0
    $clearedFiles = 0

    foreach ($target in $cleanupTargets) {
        $folder = $target.Path
        if (Test-Path -Path $folder) {
            # Delete leaf files safely
            $items = Get-ChildItem -Path $folder -Recurse -File -Force -ErrorAction SilentlyContinue
            foreach ($file in $items) {
                try {
                    $fileSize = $file.Length
                    Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                    $clearedBytes += $fileSize
                    $clearedFiles++
                }
                catch {
                    # Files actively open by running Windows processes are safely preserved
                }
            }

            # Clean empty subdirectories inside target
            Get-ChildItem -Path $folder -Recurse -Directory -Force -ErrorAction SilentlyContinue |
                Where-Object { (Get-ChildItem -Path $_.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0 } |
                ForEach-Object {
                    try { Remove-Item -Path $_.FullName -Force -Recurse -ErrorAction SilentlyContinue } catch {}
                }
        }
    }

    $clearedMB = [math]::Round(($clearedBytes / 1MB), 1)
    $clearedGB = [math]::Round(($clearedBytes / 1GB), 2)
    $formattedSize = if ($clearedMB -ge 1024) { "$clearedGB GB" } else { "$clearedMB MB" }

    if ($clearedFiles -gt 0) {
        Write-KaiLog "Purged $clearedFiles junk files, freeing approximately $formattedSize of disk space!" -Level SUCCESS
    } else {
        Write-KaiLog "System is already clean; no stale temp or cache files found." -Level INFO
    }
}

Export-ModuleMember -Function Invoke-KaiTelemetryDebloat, Invoke-KaiSafeUwpRemoval, Invoke-KaiTempCleanup
