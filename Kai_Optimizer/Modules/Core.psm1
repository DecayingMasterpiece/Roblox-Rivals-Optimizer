# ==============================================================================
# Kai Optimizer - Core Module
# Provides foundational utilities: Elevation, System Diagnostics,
# Safe Restore Point creation, State Snapshots, Registry Modification & Revert.
# ==============================================================================

$Global:KaiBackupDir  = Join-Path -Path $env:APPDATA -ChildPath "KaiOptimizer"
$Global:KaiBackupFile = Join-Path -Path $Global:KaiBackupDir -ChildPath "backup.json"
$Global:KaiLogBuffer  = [System.Collections.ArrayList]::new()

# Ensure backup directory exists
if (-not (Test-Path -Path $Global:KaiBackupDir)) {
    New-Item -Path $Global:KaiBackupDir -ItemType Directory -Force | Out-Null
}

function Write-KaiLog {
    <#
    .SYNOPSIS
        Outputs timestamped message to console and internal log buffer for UI.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet('INFO', 'SUCCESS', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = (Get-Date).ToString("HH:mm:ss")
    $logLine = "[$timestamp] [$Level] $Message"
    $Global:KaiLogBuffer.Add($logLine) | Out-Null

    switch ($Level) {
        'SUCCESS' { Write-Host $logLine -ForegroundColor Green }
        'WARN'    { Write-Host $logLine -ForegroundColor Yellow }
        'ERROR'   { Write-Host $logLine -ForegroundColor Red }
        Default   { Write-Host $logLine -ForegroundColor Cyan }
    }
}

function Test-IsAdmin {
    <#
    .SYNOPSIS
        Returns $true if the current PowerShell session has Administrator privileges.
    #>
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-RequireElevation {
    <#
    .SYNOPSIS
        Relaunches the current script as Administrator if not already elevated.
    #>
    if (-not (Test-IsAdmin)) {
        Write-KaiLog "Administrator privileges required. Requesting elevation..." -Level WARN
        $scriptPath = $MyInvocation.PSCommandPath
        if (-not $scriptPath -and $Global:KaiScriptEntry) {
            $scriptPath = $Global:KaiScriptEntry
        }
        if ($scriptPath) {
            Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
            Exit
        }
    }
}

function Get-SystemDiagnostics {
    <#
    .SYNOPSIS
        Queries system hardware, OS version, GPU vendor, and active network adapters.
    #>
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        $gpus = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue
        $networkAdapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }

        $gpuNames = ($gpus | ForEach-Object { $_.Name }) -join ", "
        $isNvidia = @($gpus | Where-Object { $_.Name -like "*NVIDIA*" -or $_.Caption -like "*NVIDIA*" }).Count -gt 0
        $isAmd    = @($gpus | Where-Object { $_.Name -like "*AMD*" -or $_.Name -like "*Radeon*" }).Count -gt 0
        $isIntel  = @($gpus | Where-Object { $_.Name -like "*Intel*" }).Count -gt 0

        $totalRamGB = [math]::Round(($os.TotalVisibleMemorySize / 1MB), 1)

        [PSCustomObject]@{
            OSName         = $os.Caption
            OSVersion      = $os.Version
            OSBuild        = $os.BuildNumber
            TotalRAM       = "$totalRamGB GB"
            GpuNames       = $gpuNames
            IsNvidia       = $isNvidia
            IsAmd          = $isAmd
            IsIntel        = $isIntel
            ActiveAdapters = $networkAdapters
        }
    }
    catch {
        Write-KaiLog "Diagnostics query encountered partial failure: $($_.Exception.Message)" -Level WARN
        [PSCustomObject]@{
            OSName         = "Windows"
            OSVersion      = [System.Environment]::OSVersion.Version.ToString()
            OSBuild        = "Unknown"
            TotalRAM       = "N/A"
            GpuNames       = "Generic Video Adapter"
            IsNvidia       = $false
            IsAmd          = $false
            IsIntel        = $false
            ActiveAdapters = @()
        }
    }
}

function New-KaiRestorePoint {
    <#
    .SYNOPSIS
        Safely creates a Windows System Restore Point labeled 'Kai_Optimizer_Backup'.
    #>
    Write-KaiLog "Attempting to create System Restore Point..." -Level INFO

    try {
        # Ensure System Restore is enabled on system drive
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue

        # Windows restricts creating more than 1 restore point within 24h by default unless registry is unlocked
        $sysRestoreReg = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
        if (Test-Path $sysRestoreReg) {
            Set-ItemProperty -Path $sysRestoreReg -Name "SystemRestorePointCreationFrequency" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        }

        Checkpoint-Computer -Description "Kai_Optimizer_Backup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-KaiLog "System Restore Point 'Kai_Optimizer_Backup' created successfully!" -Level SUCCESS
        return $true
    }
    catch {
        Write-KaiLog "Notice: Restore point creation skipped or not allowed on this edition ($($_.Exception.Message)). Proceeding with file-based snapshot backup." -Level WARN
        return $false
    }
}

function Set-KaiRegistryValue {
    <#
    .SYNOPSIS
        DRY helper to set registry values while backing up the original state.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        $Value,
        [ValidateSet('DWord', 'QWord', 'String', 'ExpandString', 'Binary', 'MultiString')]
        [string]$PropertyType = 'DWord'
    )

    try {
        # Normalize registry path
        $cleanPath = $Path -replace '^.*Registry::', ''
        $cleanPath = $cleanPath -replace '^HKEY_LOCAL_MACHINE\\?', 'HKLM:\'
        $cleanPath = $cleanPath -replace '^HKEY_CURRENT_USER\\?', 'HKCU:\'
        if ($cleanPath -match '^(HKLM|HKCU):([^\\].*)$') {
            $cleanPath = "$($Matches[1]):\$($Matches[2])"
        }

        # Create key if it doesn't exist
        if (-not (Test-Path -Path $cleanPath)) {
            New-Item -Path $cleanPath -Force | Out-Null
        }

        # Read existing value for backup
        $oldValue = $null
        $valueExists = $false
        if (Test-Path -Path $cleanPath) {
            $item = Get-ItemProperty -Path $cleanPath -Name $Name -ErrorAction SilentlyContinue
            if ($null -ne $item -and $null -ne $item.$Name) {
                $oldValue = $item.$Name
                $valueExists = $true
            }
        }

        # Save to backup dictionary
        $backupDict = @{}
        if (Test-Path -Path $Global:KaiBackupFile) {
            try {
                $rawJson = Get-Content -Path $Global:KaiBackupFile -Raw
                if ($rawJson) {
                    $backupDict = $rawJson | ConvertFrom-Json -AsHashtable
                }
            }
            catch {}
        }

        $backupKey = "$($cleanPath)__$($Name)"
        if (-not $backupDict.ContainsKey($backupKey)) {
            $backupDict[$backupKey] = @{
                Path         = $cleanPath
                Name         = $Name
                ExistsBefore = $valueExists
                OldValue     = $oldValue
                PropertyType = $PropertyType
            }
            $backupDict | ConvertTo-Json -Depth 5 | Set-Content -Path $Global:KaiBackupFile -Force
        }

        # Apply new value
        Set-ItemProperty -Path $cleanPath -Name $Name -Value $Value -Type $PropertyType -Force
        Write-KaiLog "Updated registry: $cleanPath -> $Name = $Value" -Level INFO
        return $true
    }
    catch {
        Write-KaiLog "Failed to set registry: $cleanPath -> $($Name): $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Restore-KaiPreviousState {
    <#
    .SYNOPSIS
        Reverts all settings recorded in backup.json back to their original states.
    #>
    Write-KaiLog "Starting full rollback of all modified settings..." -Level INFO

    if (-not (Test-Path -Path $Global:KaiBackupFile)) {
        Write-KaiLog "No backup history found. Nothing to restore." -Level WARN
        return $false
    }

    try {
        $backupDict = (Get-Content -Path $Global:KaiBackupFile -Raw) | ConvertFrom-Json -AsHashtable
        $revertedCount = 0

        foreach ($key in $backupDict.Keys) {
            $entry = $backupDict[$key]
            $rawPath      = $entry["Path"]
            $path         = $rawPath -replace '^.*Registry::', '' -replace '^HKEY_LOCAL_MACHINE\\?', 'HKLM:\' -replace '^HKEY_CURRENT_USER\\?', 'HKCU:\'
            if ($path -match '^(HKLM|HKCU):([^\\].*)$') { $path = "$($Matches[1]):\$($Matches[2])" }
            $name         = $entry["Name"]
            $existsBefore = $entry["ExistsBefore"]
            $oldValue     = $entry["OldValue"]
            $propType     = $entry["PropertyType"]

            if (Test-Path -Path $path) {
                if ($existsBefore -and $null -ne $oldValue) {
                    Set-ItemProperty -Path $path -Name $name -Value $oldValue -Type $propType -Force -ErrorAction SilentlyContinue
                    Write-KaiLog "Restored: $path -> $name to $oldValue" -Level INFO
                }
                else {
                    Remove-ItemProperty -Path $path -Name $name -Force -ErrorAction SilentlyContinue
                    Write-KaiLog "Removed added setting: $path -> $name" -Level INFO
                }
                $revertedCount++
            }
        }

        # Clear backup file once restored
        Remove-Item -Path $Global:KaiBackupFile -Force -ErrorAction SilentlyContinue
        Write-KaiLog "Rollback complete! Successfully reverted $revertedCount settings." -Level SUCCESS
        return $true
    }
    catch {
        Write-KaiLog "Error restoring settings: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

Export-ModuleMember -Function Write-KaiLog, Test-IsAdmin, Invoke-RequireElevation, Get-SystemDiagnostics, New-KaiRestorePoint, Set-KaiRegistryValue, Restore-KaiPreviousState
