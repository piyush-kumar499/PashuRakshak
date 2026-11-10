@echo off
REM ============================================================
REM  PashuRakshak - Java JDK setup
REM  Points JAVA_HOME at Android Studio's bundled JDK so that
REM  command-line Gradle builds work.
REM ============================================================
setlocal EnableDelayedExpansion

echo ========================================
echo Setting up Java JDK...
echo ========================================

set "JBR=C:\Program Files\Android\Android Studio\jbr"
if exist "%JBR%\bin\java.exe" goto :found
set "JBR=C:\Program Files\Android\Android Studio\jre"
if exist "%JBR%\bin\java.exe" goto :found
if exist "%LOCALAPPDATA%\Programs\Android Studio\jbr\bin\java.exe" (
    set "JBR=%LOCALAPPDATA%\Programs\Android Studio\jbr"
    goto :found
)

echo.
echo Current JAVA_HOME: %JAVA_HOME%
if exist "%JAVA_HOME%\bin\java.exe" (
    echo Java is already available at %JAVA_HOME%
    goto :verify
)

echo.
echo ERROR: No Java JDK found.
echo Install Android Studio (recommended) or a JDK 17+ from:
echo   https://adoptium.net/temurin/releases/?version=17
exit /b 1

:found
echo.
echo Found JDK: %JBR%

REM Try the machine-wide variable first (needs an elevated prompt), then fall
REM back to the per-user variable, which does not need administrator rights.
setx /M JAVA_HOME "%JBR%" >nul 2>&1
if not errorlevel 1 (
    echo [OK] JAVA_HOME set for all users.
) else (
    setx JAVA_HOME "%JBR%" >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Could not set JAVA_HOME automatically.
        echo Set it manually: set JAVA_HOME=%JBR%
        exit /b 1
    )
    echo [OK] JAVA_HOME set for the current user.
)
set "JAVA_HOME=%JBR%"

echo.
echo IMPORTANT: close and reopen Android Studio and any terminal windows
echo for the new value to take effect.
echo.
echo (The build scripts - build-dist.bat / build-debug.bat - find Java
echo automatically, so they work even without this.)

:verify
echo.
echo Verifying Java...
"%JAVA_HOME%\bin\java.exe" -version
if errorlevel 1 (
    echo [ERROR] Java is not working.
    exit /b 1
)
echo.
echo [OK] Java is ready.
exit /b 0
