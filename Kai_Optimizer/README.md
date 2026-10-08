# ⚡ Roblox Rivals Optimizer

> **Built for competitive Roblox Rivals players by Kaiser (@KaiserEverhart-Adaptation on YouTube)**
> Maximum FPS • 1:1 Raw Mouse Aim • Lower Ping & No Stutter • Safe & Universal

---

## 🎯 What This Does
- **1-Click Quick Optimize**: Instant one-button optimization for younger players that automatically creates a System Restore Point and applies the safest high-impact gaming tweaks.
- **Advanced 4-Step Pro Wizard**:
  1. **Windows Gaming & Safe Debloat**: Enables Windows Game Mode, disables Game DVR background capture, eliminates Windows pointer acceleration for 1:1 raw aiming, tunes CPU scheduling for foreground games, and removes telemetry bloat.
  2. **Roblox FastFlags & Bootstrappers**: Auto-injects **Kaiser's Potato Mode** (361 FPS cap, RakNet 1240 MTU, disabled shadows, Voxel lighting, zero camera shake) or **Safe Low Mode**. Includes 1-click **"Copy JSON to Clipboard"** and folder navigation for Bloxstrap, Fishstrap, and Vanilla Roblox.
  3. **Wi-Fi & Network Latency**: Disables Nagle's algorithm delay (`TcpNoDelay = 1`, `TcpAckFrequency = 1`), pauses 60-second Wi-Fi background ping spikes, flushes DNS caches, and switches to Cloudflare 1.1.1.1 Gaming DNS. Includes link to Kaiser's YouTube Ethernet guide.
  4. **NVIDIA GPU Follow-Along**: Hardware detection (NVIDIA vs AMD/Intel), 1-click launch for NVIDIA Control Panel, and directs viewers to follow along with Kaiser's YouTube video for the exact 3D settings.

---

## 🚀 How to Run
### Method 1: Double-Click Launcher
1. Right-click `Launch.bat` and select **Run as administrator**.

### Method 2: PowerShell
```powershell
powershell -ExecutionPolicy Bypass -File .\KaiOptimizer.ps1
```

---

## 🛡️ Safety & Reversibility
- **System Restore Point**: The tool offers 1-click System Restore Point creation labeled `Kai_Optimizer_Backup`.
- **1-Click Full Revert**: The **"Revert All Settings"** button automatically restores all modified registry values back to their original state from the backup snapshot file (`%AppData%\KaiOptimizer\backup.json`).
- **No Bricking**: Never touches essential Windows drivers, Windows Update core components, or the Windows Store.

