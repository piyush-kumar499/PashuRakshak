@echo off
REM ============================================================
REM  PashuRakshak - Build Release APKs
REM  Builds the signed release APKs for the farmer and vet apps
REM  and publishes them to dist\v<version>\.
REM
REM  For a quick build without the dist verification/publishing
REM  step use:  gradlew :app-farmer:assembleRelease :app-vet:assembleRelease
REM ============================================================
setlocal

cd /d "%~dp0"

if not exist "gradlew" (
    echo ERROR: gradlew script not found!
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build-dist.ps1" %*
set EXITCODE=%errorlevel%

echo.
if not "%EXITCODE%"=="0" (
    echo BUILD FAILED - see the messages above.
) else (
    echo Release build complete. APKs are in the dist folder.
)
echo.
pause
exit /b %EXITCODE%
