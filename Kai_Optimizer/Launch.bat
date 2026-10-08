@echo off
chcp 65001 >nul
:: ==============================================================================
:: Roblox Rivals Optimizer - 1-Click Elevated Launcher
:: Author: Kaiser (@KaiserEverhart-Adaptation on YouTube)
:: ==============================================================================
setlocal EnableDelayedExpansion
title Roblox Rivals Optimizer - Kaiser

:: Check for Administrator privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Administrator privileges required. Requesting elevation...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Run the Optimizer with ExecutionPolicy Bypass
echo [*] Starting Roblox Rivals Optimizer...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0KaiOptimizer.ps1"
if %errorlevel% neq 0 (
    echo [!] An error occurred while launching. Press any key to exit.
    pause >nul
)

