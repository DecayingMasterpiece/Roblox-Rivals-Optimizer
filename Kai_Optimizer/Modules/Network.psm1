# ==============================================================================
# Kai Optimizer - Network & Wi-Fi Module
# Eliminates Nagle's algorithm delay, mitigates 60s Wi-Fi background ping spikes,
# switches low-latency DNS (Cloudflare / Google), flushes DNS caches,
# and provides follow-along guides for Ethernet optimizations.
# ==============================================================================

# Import Core module for unified logging and registry handling
if (-not (Get-Command Write-KaiLog -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot "Core.psm1") -Global
}

function Invoke-KaiNagleAlgorithmOptimization {
    <#
    .SYNOPSIS
        Disables Nagle's algorithm by setting TcpAckFrequency=1 and TCPNoDelay=1
        on all active network adapters to eliminate the 200ms packet buffering latency.
    #>
    Write-KaiLog "Applying Nagle's Algorithm packet latency fix (TcpNoDelay & TcpAckFrequency)..." -Level INFO

    $interfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    $adapterCount = 0

    if (Test-Path $interfacesPath) {
        $keys = Get-ChildItem -Path $interfacesPath -ErrorAction SilentlyContinue
        foreach ($k in $keys) {
            $interfaceKeyPath = Join-Path $interfacesPath $k.PSChildName
            # Only apply to interfaces with IP configuration or active adapter GUIDs
            $hasIp = (Get-ItemProperty -Path $interfaceKeyPath -Name "IPAddress", "DhcpIPAddress" -ErrorAction SilentlyContinue)
            if ($null -ne $hasIp) {
                $r1 = Set-KaiRegistryValue -Path $interfaceKeyPath -Name "TcpAckFrequency" -Value 1 -PropertyType DWord
                $r2 = Set-KaiRegistryValue -Path $interfaceKeyPath -Name "TCPNoDelay" -Value 1 -PropertyType DWord
                if ($r1 -or $r2) { $adapterCount++ }
            }
        }
    }

    Write-KaiLog "Nagle's Algorithm disabled on $adapterCount network adapter interface(s)." -Level SUCCESS
}

function Set-KaiWlanAutoConfig {
    <#
    .SYNOPSIS
        Disables or enables WLAN AutoConfig background scanning.
        Disabling stops the periodic 60-second ping spikes during online gaming.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('DisableScan', 'EnableScan')]
        [string]$Action
    )

    try {
        $wlanInterfaces = netsh wlan show interfaces | Select-String "Name\s*:\s*(.+)"
        if ($wlanInterfaces) {
            foreach ($match in $wlanInterfaces) {
                $ifName = $match.Matches[0].Groups[1].Value.Trim()
                if ($Action -eq 'DisableScan') {
                    netsh wlan set autoconfig enabled=no interface="$ifName" | Out-Null
                    Write-KaiLog "Wi-Fi background scanning PAUSED on '$ifName' (Ping spikes prevented!)." -Level SUCCESS
                }
                else {
                    netsh wlan set autoconfig enabled=yes interface="$ifName" | Out-Null
                    Write-KaiLog "Wi-Fi background scanning RESTORED on '$ifName'." -Level SUCCESS
                }
            }
        }
        else {
            Write-KaiLog "No active Wi-Fi interface detected for WLAN scan toggle." -Level INFO
        }
    }
    catch {
        Write-KaiLog "Could not change WLAN autoconfig: $($_.Exception.Message)" -Level WARN
    }
}

function Set-KaiDnsServers {
    <#
    .SYNOPSIS
        Configures primary and secondary DNS servers on all active network adapters.
    #>
    param(
        [ValidateSet('Cloudflare', 'Google', 'Quad9', 'DHCP')]
        [string]$DnsPreset = 'Cloudflare'
    )

    Write-KaiLog "Configuring DNS servers to preset: [$DnsPreset]..." -Level INFO

    $dnsServers = switch ($DnsPreset) {
        'Cloudflare' { @('1.1.1.1', '1.0.0.1') }
        'Google'     { @('8.8.8.8', '8.8.4.4') }
        'Quad9'      { @('9.9.9.9', '149.112.112.112') }
        'DHCP'       { $null }
    }

    try {
        $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }
        foreach ($adapter in $adapters) {
            if ($DnsPreset -eq 'DHCP') {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue
                Write-KaiLog "Reset DNS on $($adapter.Name) to ISP / Router Default." -Level SUCCESS
            }
            else {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $dnsServers -ErrorAction SilentlyContinue
                Write-KaiLog "Set DNS on $($adapter.Name) -> $($dnsServers -join ', ')" -Level SUCCESS
            }
        }

        # Flush DNS resolver cache
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Write-KaiLog "DNS cache flushed." -Level SUCCESS
    }
    catch {
        Write-KaiLog "Failed to configure DNS: $($_.Exception.Message)" -Level ERROR
    }
}

function Invoke-KaiFlushDnsCache {
    <#
    .SYNOPSIS
        Flushes the local DNS client resolver cache.
    #>
    try {
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        ipconfig /flushdns | Out-Null
        Write-KaiLog "Local DNS cache flushed successfully." -Level SUCCESS
    }
    catch {
        Write-KaiLog "Could not flush DNS cache: $($_.Exception.Message)" -Level WARN
    }
}

function Open-KaiEthernetVideoGuide {
    <#
    .SYNOPSIS
        Opens Kaiser's YouTube video guide for Ethernet adapter optimizations.
    #>
    param(
        [string]$VideoUrl = "https://www.youtube.com/@KaiserEverhart-Adaptation"
    )

    Write-KaiLog "Opening Ethernet & Network Optimization video guide on YouTube..." -Level INFO
    Start-Process -FilePath $VideoUrl
}

Export-ModuleMember -Function Invoke-KaiNagleAlgorithmOptimization, Set-KaiWlanAutoConfig, Set-KaiDnsServers, Invoke-KaiFlushDnsCache, Open-KaiEthernetVideoGuide

