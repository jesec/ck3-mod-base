@echo off
REM CK3 Mod Builder
REM Called from root via thin wrapper: build.bat -> base\scripts\build.bat
REM Delete root build.bat and create your own if you need custom build logic

setlocal enabledelayedexpansion

set OUTPUT_DIR=out

echo.
echo ===========================================================
echo.
echo                  CK3 Mod Builder
echo.
echo ===========================================================
echo.

REM Check Git
git --version >nul 2>&1
if errorlevel 1 (
    echo [X] Git is not installed
    echo.
    echo     Install from: https://git-scm.com/download/win
    pause
    exit /b 1
)

git rev-parse --git-dir >nul 2>&1
if errorlevel 1 (
    echo [X] Not a git repository
    pause
    exit /b 1
)

REM Check for mod/descriptor.mod
if not exist "mod\descriptor.mod" (
    echo [X] mod\descriptor.mod not found
    echo.
    echo     Create mod\descriptor.mod with your mod metadata
    pause
    exit /b 1
)

REM Auto-detect base version
echo [1/5] Detecting base version...

REM Find most recent commit that modified base/.ck3-version.json
for /f "delims=" %%i in ('git log --format^="%%H" -1 -- base/.ck3-version.json 2^>nul') do set BASE_COMMIT=%%i

if "!BASE_COMMIT!"=="" (
    echo [X] No base version found
    echo.
    echo     Make sure you have the full git history
    pause
    exit /b 1
)

REM Read version from .ck3-version.json at that commit
for /f "tokens=2 delims=:," %%a in ('git show !BASE_COMMIT!:base/.ck3-version.json ^| findstr /C:"\"version\""') do (
    set CK3_VERSION=%%a
    set CK3_VERSION=!CK3_VERSION:"=!
    set CK3_VERSION=!CK3_VERSION: =!
)

set BASE_TAG=base/!CK3_VERSION!
set BASE_COMMIT_SHORT=!BASE_COMMIT:~0,8!
echo [+] Found CK3 base: !BASE_TAG! (commit !BASE_COMMIT_SHORT!)
echo.

REM Find mod files
echo [2/5] Finding your mod files...

REM Check for modified/new files in base/game/
git diff --name-only "!BASE_COMMIT!"...HEAD > "%TEMP%\ck3_changed.txt" 2>nul
git ls-files --others --exclude-standard > "%TEMP%\ck3_new.txt" 2>nul

set /a BASE_FILES_COUNT=0
for /f "delims=" %%f in ('type "%TEMP%\ck3_changed.txt" "%TEMP%\ck3_new.txt" 2^>nul ^| findstr /i /c:"base\\game\\" ^| find /c /v ""') do set /a BASE_FILES_COUNT=%%f

REM Check for files in mod/
set /a MOD_FILES_COUNT=0
if exist "mod\" (
    for /f "delims=" %%f in ('dir /s /b /a-d "mod\*" 2^>nul ^| find /c /v ""') do set /a MOD_FILES_COUNT=%%f
)

set /a TOTAL_COUNT=!BASE_FILES_COUNT! + !MOD_FILES_COUNT!

if !TOTAL_COUNT!==0 (
    echo [!] No mod files found
    echo.
    echo     You can do both:
    echo       - Modify vanilla: base\game\common\decisions\00_decisions.txt
    echo       - Add new content: mod\common\decisions\my_decisions.txt
    pause
    exit /b 0
)

echo [+] Found !BASE_FILES_COUNT! file(s) in base/, !MOD_FILES_COUNT! file(s) in mod/
echo.

REM Clean output
echo [3/5] Preparing output...
if exist "!OUTPUT_DIR!" rd /s /q "!OUTPUT_DIR!" >nul 2>&1
mkdir "!OUTPUT_DIR!" >nul 2>&1
echo [+] Created: !OUTPUT_DIR!\
echo.

REM Build mod
echo [4/5] Building mod...

set /a BASE_EXPORTED=0
set /a MOD_EXPORTED=0

REM Step 1: Export changed files from base/game/
for /f "usebackq delims=" %%f in ("%TEMP%\ck3_changed.txt") do call :export_base_file "%%f"
for /f "usebackq delims=" %%f in ("%TEMP%\ck3_new.txt") do call :export_base_file "%%f"

REM Step 2: Copy all files from mod/ (overwrites base/ if conflicts)
if exist "mod\" (
    for /f "delims=" %%f in ('dir /s /b /a-d "mod\*" 2^>nul') do call :copy_mod_file "%%f"
)

echo [+] Exported: !BASE_EXPORTED! from base/, !MOD_EXPORTED! from mod/
echo.

REM Cleanup temp files
del "%TEMP%\ck3_changed.txt" "%TEMP%\ck3_new.txt" 2>nul

REM Finalize
echo [5/5] Finalizing...

REM Build info
(
    echo CK3 Mod - Built %DATE% %TIME%
    echo Base: !CK3_VERSION! ^(commit !BASE_COMMIT_SHORT!^)
    echo Files: !BASE_EXPORTED! from base/, !MOD_EXPORTED! from mod/
) > "!OUTPUT_DIR!\BUILD_INFO.txt"

echo [+] Ready!
echo.

REM Success
echo.
echo ===========================================================
echo.
echo                   BUILD SUCCESSFUL!
echo.
echo ===========================================================
echo.
echo Your mod: %CD%\!OUTPUT_DIR!\
echo.
echo -----------------------------------------------------------
echo  TO INSTALL IN CK3:
echo -----------------------------------------------------------
echo  Quick install:
echo    install.bat
echo.
echo  Manual install:
echo    1. Create your-mod.mod in CK3 mod directory
echo    2. Copy descriptor.mod content + add path field
echo -----------------------------------------------------------
echo.

pause
exit /b 0

REM ═══════════════════════════════════════════════════════════
:export_base_file
set FILE=%~1

REM Only process base/game/ files
echo %FILE% | findstr /i "^base\\game\\" >nul
if errorlevel 1 goto :eof

if not exist "%FILE%" goto :eof

REM Strip base/game/ prefix: base/game/common/... -> common/...
set REL_PATH=!FILE:base\game\=!

REM Output to root: out/common/...
set DST=!OUTPUT_DIR!\!REL_PATH!

REM Create directory and copy
for %%F in ("!DST!") do mkdir "%%~dpF" 2>nul
copy /y "%FILE%" "!DST!" >nul 2>&1
if not errorlevel 1 set /a BASE_EXPORTED+=1
goto :eof

REM ═══════════════════════════════════════════════════════════
:copy_mod_file
set SRC=%~1
set ABS_MOD_DIR=%CD%\mod

REM Strip mod/ prefix: C:\path\mod\common\... -> common\...
set REL_PATH=!SRC:%ABS_MOD_DIR!\=!

REM Output to root: out/common/...
set DST=!OUTPUT_DIR!\!REL_PATH!

REM Create directory and copy
for %%F in ("!DST!") do mkdir "%%~dpF" 2>nul
copy /y "!SRC!" "!DST!" >nul 2>&1
if not errorlevel 1 set /a MOD_EXPORTED+=1
goto :eof
