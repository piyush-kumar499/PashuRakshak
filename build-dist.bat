@echo off
REM ============================================================
REM  PashuRakshak - build installable APKs and publish them
REM  to dist\v<version>\ (double-click friendly).
REM ============================================================
setlocal

cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build-dist.ps1" %*
set EXITCODE=%errorlevel%

echo.
if not "%EXITCODE%"=="0" (
    echo BUILD FAILED - see the messages above.
) else (
    echo Done. APKs are in the dist folder.
)
echo.
pause
exit /b %EXITCODE%
