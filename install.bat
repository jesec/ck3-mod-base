@echo off
REM CK3 Mod Installer - Shim
REM This is a thin wrapper. Real logic is in base\scripts\install.bat
REM Feel free to customize this file for your mod.

call "%~dp0base\scripts\install.bat" %*
