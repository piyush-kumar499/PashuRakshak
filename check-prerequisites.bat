@echo off
REM ============================================================
REM  PashuRakshak - Prerequisites Check
REM ============================================================
setlocal EnableDelayedExpansion

echo ========================================
echo PashuRakshak Build Prerequisites Check
echo ========================================
echo.

REM ---------------- Java ----------------
echo [1/2] Checking Java (JDK 17 or newer)...
set "FOUND_JAVA="
if defined JAVA_HOME (
    if exist "%JAVA_HOME%\bin\java.exe" (
        set "FOUND_JAVA=%JAVA_HOME%\bin\java.exe"
    )
)
if not defined FOUND_JAVA (
    if exist "C:\Program Files\Android\Android Studio\jbr\bin\java.exe" (
        set "FOUND_JAVA=C:\Program Files\Android\Android Studio\jbr\bin\java.exe"
        set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
    )
)
if not defined FOUND_JAVA (
    for /f "delims=" %%j in ('where java 2^>nul') do (
        if not defined FOUND_JAVA set "FOUND_JAVA=%%j"
    )
)

if defined FOUND_JAVA (
    echo     Found: !FOUND_JAVA!
    "!FOUND_JAVA!" -version 2>&1 | findstr /i "version"
    echo     OK - Java found.
    set HAS_JAVA=true
) else (
    echo     ERROR: No Java JDK found.
    echo     Install Android Studio ^(uses its bundled JDK^) or a JDK 17+.
    set HAS_JAVA=false
)
echo.

REM ---------------- Python ----------------
echo [2/2] Checking Python 3.x (optional, for native lib alignment)...
set "FOUND_PY="
for %%p in (python3 python py) do (
    if not defined FOUND_PY (
        for /f "delims=" %%q in ('where %%p 2^>nul') do (
            if not defined FOUND_PY set "FOUND_PY=%%q"
        )
    )
)
if defined FOUND_PY (
    echo     Found: !FOUND_PY!
    "!FOUND_PY!" --version 2>&1
    echo     OK - Python found.
    set HAS_PYTHON=true
) else (
    echo     WARNING: Python 3.x not found. The build still works, but native
    echo     libraries may not be aligned for 16 KB page-size devices.
    echo     Install from https://www.python.org/downloads/ and tick
    echo     "Add Python to PATH".
    set HAS_PYTHON=false
)
echo.

REM ---------------- Android SDK ----------------
echo [3/3] Checking Android SDK...
set "FOUND_SDK="
if defined ANDROID_HOME if exist "%ANDROID_HOME%" set "FOUND_SDK=%ANDROID_HOME%"
if not defined FOUND_SDK if defined ANDROID_SDK_ROOT if exist "%ANDROID_SDK_ROOT%" set "FOUND_SDK=%ANDROID_SDK_ROOT%"
if not defined FOUND_SDK if exist "%LOCALAPPDATA%\Android\Sdk" set "FOUND_SDK=%LOCALAPPDATA%\Android\Sdk"

if defined FOUND_SDK (
    echo     Found: !FOUND_SDK!
    set HAS_SDK=true
) else (
    echo     ERROR: Android SDK not found. Install it with Android Studio.
    set HAS_SDK=false
)
echo.

echo ========================================
echo Status
echo ========================================
if "%HAS_JAVA%"=="true" (echo [OK]      Java) else (echo [MISSING] Java - REQUIRED)
if "%HAS_SDK%"=="true"  (echo [OK]      Android SDK) else (echo [MISSING] Android SDK - REQUIRED)
if "%HAS_PYTHON%"=="true" (echo [OK]      Python) else (echo [OPTIONAL] Python - not installed)
echo.

if "%HAS_JAVA%"=="true" if "%HAS_SDK%"=="true" (
    echo You can build the apps:
    echo    build-dist.bat          ^(signed release APKs in dist\^)
    echo    build-debug.bat         ^(debug APKs for testing^)
    exit /b 0
)

echo Install the missing requirements and run this check again.
exit /b 1
