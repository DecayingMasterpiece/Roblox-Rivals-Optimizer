# ==============================================================================
# Kai Optimizer - GPU & Driver Helper Module
# Detects GPU hardware safely (NVIDIA vs AMD/Intel),
# launches NVIDIA Control Panel, and redirects viewers to the follow-along YouTube guide.
# ==============================================================================

# Import Core module for unified logging
if (-not (Get-Command Write-KaiLog -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot "Core.psm1") -Global
}

function Get-KaiGpuStatus {
    <#
    .SYNOPSIS
        Detects installed display adapters and reports whether NVIDIA hardware is present.
    #>
    try {
        $gpus = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue
        $isNvidia = @($gpus | Where-Object { $_.Name -like "*NVIDIA*" -or $_.Caption -like "*NVIDIA*" }).Count -gt 0
        $isAmd    = @($gpus | Where-Object { $_.Name -like "*AMD*" -or $_.Name -like "*Radeon*" }).Count -gt 0
        $isIntel  = @($gpus | Where-Object { $_.Name -like "*Intel*" }).Count -gt 0

        $gpuName = if ($gpus.Count -gt 0) { $gpus[0].Name } else { "Unknown Display Adapter" }

        [PSCustomObject]@{
            PrimaryGpu = $gpuName
            IsNvidia   = $isNvidia
            IsAmd      = $isAmd
            IsIntel    = $isIntel
            AllGpus    = $gpus
        }
    }
    catch {
        Write-KaiLog "Could not detect GPU status: $($_.Exception.Message)" -Level WARN
        [PSCustomObject]@{
            PrimaryGpu = "Generic Display Adapter"
            IsNvidia   = $false
            IsAmd      = $false
            IsIntel    = $false
            AllGpus    = @()
        }
    }
}

function Open-KaiNvidiaControlPanel {
    <#
    .SYNOPSIS
        Attempts to launch the NVIDIA Control Panel application,
        falling back to Microsoft Store / NVIDIA download page if missing.
    #>
    Write-KaiLog "Attempting to open NVIDIA Control Panel..." -Level INFO

    $nvcplPath = "C:\Program Files\NVIDIA Corporation\Control Panel Client\nvcplui.exe"

    if (Test-Path $nvcplPath) {
        Start-Process -FilePath $nvcplPath
        Write-KaiLog "NVIDIA Control Panel launched." -Level SUCCESS
        return $true
    }

    # Attempt UWP Windows Store app launch
    try {
        Start-Process "shell:AppsFolder\NVIDIACorp.NVIDIAControlPanel_56jybvy8sckqj!NVIDIACpc" -ErrorAction Stop
        Write-KaiLog "NVIDIA Control Panel (Appx) launched." -Level SUCCESS
        return $true
    }
    catch {
        # Fallback to Store link if missing
        Write-KaiLog "NVIDIA Control Panel not found locally. Opening Microsoft Store page..." -Level WARN
        Start-Process "ms-windows-store://pdp/?productid=9NF8H0H7WMLT"
        return $false
    }
}

function Open-KaiNvidiaVideoGuide {
    <#
    .SYNOPSIS
        Opens Kaiser's YouTube video guide for NVIDIA 3D settings follow-along.
    #>
    param(
        [string]$VideoUrl = "https://www.youtube.com/watch?v=haOdSePyE74&t=330s"
    )

    Write-KaiLog "Opening NVIDIA 3D Best Settings video guide on YouTube (5:30)..." -Level INFO
    Start-Process -FilePath $VideoUrl
}

Export-ModuleMember -Function Get-KaiGpuStatus, Open-KaiNvidiaControlPanel, Open-KaiNvidiaVideoGuide

