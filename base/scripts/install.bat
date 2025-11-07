@echo off
REM CK3 Mod Installer
REM Called from root via thin wrapper: install.bat -> base\scripts\install.bat
REM Delete root install.bat and create your own if you need custom install logic
REM Usage: install.bat [copy|link|uninstall]

setlocal enabledelayedexpansion

echo.
echo ===========================================================
echo.
echo                  CK3 Mod Installer
echo.
echo ===========================================================
echo.

REM Check for out\ directory
if not exist "out\" (
    echo [X] out\ directory not found
    echo.
    echo     Run: build.bat
    pause
    exit /b 1
)

REM Check for mod\descriptor.mod
if not exist "mod\descriptor.mod" (
    echo [X] mod\descriptor.mod not found
    pause
    exit /b 1
)

REM Detect CK3 mod directory
set CK3_MOD_DIR=%USERPROFILE%\Documents\Paradox Interactive\Crusader Kings III\mod

if not exist "!CK3_MOD_DIR!" (
    echo [!] CK3 mod directory not found: !CK3_MOD_DIR!
    set /p CK3_MOD_DIR="Enter CK3 mod directory: "

    if not exist "!CK3_MOD_DIR!" (
        echo [?] Directory does not exist. Create it? (Y/N)
        choice /c YN /n
        if errorlevel 2 exit /b 1
        mkdir "!CK3_MOD_DIR!"
        echo [+] Created: !CK3_MOD_DIR!
    )
)

REM Get mod name from descriptor.mod
set MOD_NAME=
for /f "tokens=2 delims==" %%a in ('findstr /c:"name=" mod\descriptor.mod') do (
    set MOD_NAME=%%a
    set MOD_NAME=!MOD_NAME:"=!
)

if "!MOD_NAME!"=="" (
    set MOD_NAME=my-mod
    echo [!] Could not detect mod name, using: !MOD_NAME!
    goto :skip_sanitize
)

REM Convert to lowercase
for %%L in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    set MOD_NAME=!MOD_NAME:%%L=%%L!
)

REM Replace all non-alphanumeric with hyphen, then clean up
set MOD_NAME=!MOD_NAME: =-!
set MOD_NAME=!MOD_NAME:'=-!
set MOD_NAME=!MOD_NAME:`=-!
set MOD_NAME=!MOD_NAME::=-!
set MOD_NAME=!MOD_NAME:;=-!
set MOD_NAME=!MOD_NAME:[=-!
set MOD_NAME=!MOD_NAME:]=-!
set MOD_NAME=!MOD_NAME:(=-!
set MOD_NAME=!MOD_NAME:)=-!
set MOD_NAME=!MOD_NAME:{=-!
set MOD_NAME=!MOD_NAME:}=-!
set MOD_NAME=!MOD_NAME:+=-!
set MOD_NAME=!MOD_NAME:==-!
set MOD_NAME=!MOD_NAME:/=-!
set MOD_NAME=!MOD_NAME:\=-!
set MOD_NAME=!MOD_NAME:|=-!
set MOD_NAME=!MOD_NAME:*=-!
set MOD_NAME=!MOD_NAME:?=-!
set MOD_NAME=!MOD_NAME:"=-!
set MOD_NAME=!MOD_NAME:<=-!
set MOD_NAME=!MOD_NAME:>=-!
set MOD_NAME=!MOD_NAME:,=-!
set MOD_NAME=!MOD_NAME:.=-!

REM Clean up multiple hyphens and trim edges
:cleanup_hyphens
set MOD_NAME=!MOD_NAME:--=-!
echo !MOD_NAME! | findstr "--" >nul && goto :cleanup_hyphens

REM Remove leading/trailing hyphens
if "!MOD_NAME:~0,1!"=="-" set MOD_NAME=!MOD_NAME:~1!
if "!MOD_NAME:~-1!"=="-" set MOD_NAME=!MOD_NAME:~0,-1!

:skip_sanitize

REM Determine install mode
set INSTALL_MODE=%1

if "!INSTALL_MODE!"=="" (
    REM Interactive mode
    echo.
    echo [?] Choose action:
    echo.
    echo     1. Copy install
    echo        Copies files to CK3 mod folder
    echo        Use for: final testing, sharing with others
    echo.
    echo     2. Link install (faster for active development^)
    echo        Points to your build output directly
    echo        Use for: rapid iteration, just rebuild and reload
    echo.
    echo     3. Uninstall
    echo        Removes mod from CK3
    echo.
    choice /c 123 /n /m "Mode (1/2/3): "

    if errorlevel 3 (
        set INSTALL_MODE=uninstall
    ) else if errorlevel 2 (
        set INSTALL_MODE=link
    ) else (
        set INSTALL_MODE=copy
    )
)

REM Validate mode
if not "!INSTALL_MODE!"=="copy" if not "!INSTALL_MODE!"=="link" if not "!INSTALL_MODE!"=="uninstall" (
    echo [X] Invalid mode: !INSTALL_MODE!
    echo     Usage: install.bat [copy^|link^|uninstall]
    pause
    exit /b 1
)

set MOD_FILE=!CK3_MOD_DIR!\!MOD_NAME!.mod
set MOD_CONTENT_DIR=!CK3_MOD_DIR!\!MOD_NAME!

REM Perform action based on mode
if "!INSTALL_MODE!"=="uninstall" (
    REM Uninstall
    echo.
    echo Uninstalling: !MOD_NAME!
    echo     Target: !CK3_MOD_DIR!
    echo.

    set REMOVED_COUNT=0

    if exist "!MOD_FILE!" (
        del "!MOD_FILE!"
        echo [+] Removed: !MOD_FILE!
        set /a REMOVED_COUNT+=1
    )

    if exist "!MOD_CONTENT_DIR!" (
        rd /s /q "!MOD_CONTENT_DIR!"
        echo [+] Removed: !MOD_CONTENT_DIR!
        set /a REMOVED_COUNT+=1
    )

    if !REMOVED_COUNT!==0 (
        echo [!] Mod not found (already uninstalled^)
    ) else (
        echo.
        echo ===========================================================
        echo.
        echo                UNINSTALL SUCCESSFUL!
        echo.
        echo ===========================================================
        echo.
    )
) else (
    REM Install
    echo.
    echo Installing: !MOD_NAME!
    echo     Mode: !INSTALL_MODE!
    echo     Target: !CK3_MOD_DIR!
    echo.

    if "!INSTALL_MODE!"=="copy" (
        REM Copy install
        echo Installing (copy mode^)...

        REM Create/update .mod file with relative path
        copy /y mod\descriptor.mod "!MOD_FILE!" >nul
        echo path="mod/!MOD_NAME!" >> "!MOD_FILE!"
        echo [+] Created: !MOD_FILE!

        REM Copy out\ contents
        if exist "!MOD_CONTENT_DIR!" rd /s /q "!MOD_CONTENT_DIR!"
        mkdir "!MOD_CONTENT_DIR!"
        xcopy /e /i /q /y out "!MOD_CONTENT_DIR!" >nul

        for /f %%A in ('dir /s /b /a-d "!MOD_CONTENT_DIR!\*" ^| find /c /v ""') do set FILE_COUNT=%%A
        echo [+] Copied !FILE_COUNT! file(s^) to: !MOD_CONTENT_DIR!

    ) else (
        REM Link install
        echo Installing (link mode^)...

        REM Create/update .mod file with absolute path
        copy /y mod\descriptor.mod "!MOD_FILE!" >nul
        echo path="%CD%\out" >> "!MOD_FILE!"
        echo [+] Created: !MOD_FILE!

        echo     Pointing to: %CD%\out
        echo [!] Remember to run 'build.bat' after making changes
    )

    echo.
    echo ===========================================================
    echo.
    echo                 INSTALL SUCCESSFUL!
    echo.
    echo ===========================================================
    echo.
    echo     Launch CK3 and enable '!MOD_NAME!' in the launcher
    echo.
)

pause
exit /b 0
