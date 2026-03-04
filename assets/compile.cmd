@echo off
setlocal EnableExtensions

echo ========================================
echo   CapsCopyTip v1.0.10 - Compile Script
echo ========================================
echo.

:: Set paths
set "ScriptDir=%~dp0"
set "Compiler=C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"
set "BaseFile=C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"

:: Check if compiler exists
if not exist "%Compiler%" (
    echo [ERROR] Compiler not found: %Compiler%
    echo Please install AutoHotkey v2 with the compiler component.
    goto :end
)

:: ============================================
:: Step 1: Compile language-indicator
:: ============================================
echo [1/2] Compiling language-indicator...
echo.

set "LI_Source=%ScriptDir%language-indicator\language-indicator.ahk"
set "LI_Output=%ScriptDir%language-indicator\language-indicator.exe"
set "LI_Icon=%ScriptDir%language-indicator\img\app-icon.ico"

if not exist "%LI_Source%" (
    echo [ERROR] Source not found: %LI_Source%
    goto :end
)

if exist "%LI_Icon%" (
    "%Compiler%" /in "%LI_Source%" /out "%LI_Output%" /base "%BaseFile%" /icon "%LI_Icon%"
) else (
    "%Compiler%" /in "%LI_Source%" /out "%LI_Output%" /base "%BaseFile%"
)

if exist "%LI_Output%" (
    echo [OK] language-indicator.exe compiled.
    for %%A in ("%LI_Output%") do echo     Size: %%~zA bytes
) else (
    echo [ERROR] language-indicator compilation failed.
    goto :end
)

echo.

:: ============================================
:: Step 2: Compile CapsCopyTip
:: ============================================
echo [2/2] Compiling CapsCopyTip...
echo.

set "CT_Source=%ScriptDir%CapsCopyTip.ahk"
set "CT_Output=%ScriptDir%CapsCopyTip.exe"

if not exist "%CT_Source%" (
    echo [ERROR] Source not found: %CT_Source%
    goto :end
)

"%Compiler%" /in "%CT_Source%" /out "%CT_Output%" /base "%BaseFile%"

if exist "%CT_Output%" (
    echo [OK] CapsCopyTip.exe compiled.
    for %%A in ("%CT_Output%") do echo     Size: %%~zA bytes
) else (
    echo [ERROR] CapsCopyTip compilation failed.
    goto :end
)

echo.
echo ========================================
echo   Compilation Complete!
echo ========================================
echo.
echo Output files:
echo   - %CT_Output%
echo   - %LI_Output%
echo.

:end
pause
endlocal
