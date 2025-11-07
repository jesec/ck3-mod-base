@echo off
REM CK3 Mod Builder - Shim
REM This is a thin wrapper. Real logic is in base\scripts\build.bat
REM Feel free to customize this file for your mod.

call "%~dp0base\scripts\build.bat" %*
