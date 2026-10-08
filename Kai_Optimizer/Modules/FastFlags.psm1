# ==============================================================================
# Kai Optimizer - FastFlags Module
# Detects Roblox & Bootstrappers (Bloxstrap, Fishstrap, Vanilla),
# Injects curated ClientAppSettings.json presets, supports 1-click clipboard copy,
# and provides folder navigation for manual configurations.
# ==============================================================================

# Import Core module for unified logging
if (-not (Get-Command Write-KaiLog -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot "Core.psm1") -Global
}

$Global:ConfigDir = Join-Path (Split-Path $PSScriptRoot -Parent) "Config"

function Find-RobloxInstallations {
    <#
    .SYNOPSIS
        Scans standard user directories for Vanilla Roblox, Bloxstrap, and Fishstrap installations.
    #>
    $targets = [System.Collections.Generic.List[PSCustomObject]]::new()

    # 1. Bloxstrap
    $bloxstrapBase = Join-Path $env:LOCALAPPDATA "Bloxstrap"
    if (Test-Path $bloxstrapBase) {
        $settingsDir = Join-Path $bloxstrapBase "Modifications\ClientSettings"
        $targets.Add([PSCustomObject]@{
            Type        = "Bloxstrap"
            SettingsDir = $settingsDir
            Exists      = $true
        })
    }

    # 2. Fishstrap
    $fishstrapBase = Join-Path $env:LOCALAPPDATA "Fishstrap"
    if (Test-Path $fishstrapBase) {
        $settingsDir = Join-Path $fishstrapBase "Modifications\ClientSettings"
        $targets.Add([PSCustomObject]@{
            Type        = "Fishstrap"
            SettingsDir = $settingsDir
            Exists      = $true
        })
    }

    # 3. Vanilla Roblox Player
    $robloxBase = Join-Path $env:LOCALAPPDATA "Roblox"
    if (Test-Path $robloxBase) {
        # Check general ClientSettings
        $generalDir = Join-Path $robloxBase "ClientSettings"
        $targets.Add([PSCustomObject]@{
            Type        = "Vanilla Roblox (General)"
            SettingsDir = $generalDir
            Exists      = $true
        })

        # Scan active version directories (e.g., Versions\version-abcdef)
        $versionsDir = Join-Path $robloxBase "Versions"
        if (Test-Path $versionsDir) {
            Get-ChildItem -Path $versionsDir -Directory -Filter "version-*" -ErrorAction SilentlyContinue | ForEach-Object {
                $verSettings = Join-Path $_.FullName "ClientSettings"
                $targets.Add([PSCustomObject]@{
                    Type        = "Vanilla Roblox ($($_.Name))"
                    SettingsDir = $verSettings
                    Exists      = $true
                })
            }
        }
    }

    return $targets
}

function Get-KaiFastFlagJson {
    <#
    .SYNOPSIS
        Retrieves the raw JSON string for the requested preset.
    #>
    param(
        [ValidateSet('KaiserPotato', 'SafeLow')]
        [string]$PresetName = 'KaiserPotato'
    )

    $fileName = if ($PresetName -eq 'KaiserPotato') { "KaiserPotatoFlags.json" } else { "SafeLowFlags.json" }
    $filePath = Join-Path $Global:ConfigDir $fileName

    if (Test-Path $filePath) {
        return (Get-Content -Path $filePath -Raw)
    }
    else {
        Write-KaiLog "Could not locate flag config file: $filePath" -Level ERROR
        return "{}"
    }
}

function Install-KaiFastFlags {
    <#
    .SYNOPSIS
        Injects the selected FastFlag preset into all detected Roblox & Bootstrapper directories.
    #>
    param(
        [ValidateSet('KaiserPotato', 'SafeLow')]
        [string]$PresetName = 'KaiserPotato'
    )

    Write-KaiLog "Injecting FastFlag preset [$PresetName] into Roblox installations..." -Level INFO
    $jsonContent = Get-KaiFastFlagJson -PresetName $PresetName

    $installations = Find-RobloxInstallations
    if ($installations.Count -eq 0) {
        # If not installed yet in standard paths, prepare the default Vanilla Roblox folder
        $defaultDir = Join-Path $env:LOCALAPPDATA "Roblox\ClientSettings"
        $installations = @([PSCustomObject]@{
            Type        = "Vanilla Roblox (Default Target)"
            SettingsDir = $defaultDir
            Exists      = $false
        })
    }

    $injectedCount = 0
    foreach ($inst in $installations) {
        try {
            $targetDir = $inst.SettingsDir
            if (-not (Test-Path $targetDir)) {
                New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            }

            $targetFile = Join-Path $targetDir "ClientAppSettings.json"

            # Create backup if file already exists
            if (Test-Path $targetFile) {
                $backupFile = Join-Path $Global:KaiBackupDir "ClientAppSettings.backup.json"
                Copy-Item -Path $targetFile -Destination $backupFile -Force -ErrorAction SilentlyContinue
            }

            Set-Content -Path $targetFile -Value $jsonContent -Encoding UTF8 -Force
            Write-KaiLog "Injected ClientAppSettings.json -> $($inst.Type) at: $targetDir" -Level SUCCESS
            $injectedCount++
        }
        catch {
            Write-KaiLog "Failed to inject into $($inst.Type): $($_.Exception.Message)" -Level WARN
        }
    }

    Write-KaiLog "FastFlags successfully applied to $injectedCount target location(s)." -Level SUCCESS
    return $injectedCount
}

function Remove-KaiFastFlags {
    <#
    .SYNOPSIS
        Removes ClientAppSettings.json from all detected Roblox & Bootstrapper directories (reverting to Vanilla).
    #>
    Write-KaiLog "Reverting Roblox FastFlags to Vanilla..." -Level INFO
    $installations = Find-RobloxInstallations

    $removedCount = 0
    foreach ($inst in $installations) {
        $targetFile = Join-Path $inst.SettingsDir "ClientAppSettings.json"
        if (Test-Path $targetFile) {
            Remove-Item -Path $targetFile -Force -ErrorAction SilentlyContinue
            Write-KaiLog "Removed ClientAppSettings.json from $($inst.Type)" -Level SUCCESS
            $removedCount++
        }
    }

    Write-KaiLog "Revert complete! Removed FastFlags from $removedCount location(s)." -Level SUCCESS
    return $removedCount
}

function Copy-KaiFastFlagToClipboard {
    <#
    .SYNOPSIS
        Copies the chosen FastFlag preset JSON to Windows Clipboard for manual pasting.
    #>
    param(
        [ValidateSet('KaiserPotato', 'SafeLow')]
        [string]$PresetName = 'KaiserPotato'
    )

    $jsonContent = Get-KaiFastFlagJson -PresetName $PresetName
    Set-Clipboard -Value $jsonContent
    Write-KaiLog "FastFlag JSON [$PresetName] copied to clipboard!" -Level SUCCESS
}

function Open-KaiRobloxFolder {
    <#
    .SYNOPSIS
        Opens the primary Roblox or Bloxstrap ClientSettings folder in File Explorer.
    #>
    $installations = Find-RobloxInstallations
    $targetDir = $null

    if ($installations.Count -gt 0) {
        $targetDir = $installations[0].SettingsDir
    }
    else {
        $targetDir = Join-Path $env:LOCALAPPDATA "Roblox\ClientSettings"
    }

    if (-not (Test-Path $targetDir)) {
        New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
    }

    Start-Process -FilePath "explorer.exe" -ArgumentList "`"$targetDir`""
    Write-KaiLog "Opened folder in Explorer: $targetDir" -Level INFO
}

Export-ModuleMember -Function Find-RobloxInstallations, Get-KaiFastFlagJson, Install-KaiFastFlags, Remove-KaiFastFlags, Copy-KaiFastFlagToClipboard, Open-KaiRobloxFolder
