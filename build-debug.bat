@echo off
REM ============================================================
REM  PashuRakshak - Build Debug APKs
REM  Debug APKs are for testing only. They are signed with the
REM  debug key and cannot update a release install.
REM ============================================================
setlocal

echo ========================================
echo Building Debug APKs...
echo ========================================
echo.

cd /d "%~dp0"

if not exist "gradlew" (
    echo ERROR: gradlew script not found!
    exit /b 1
)

REM Find a JDK: use JAVA_HOME only when it really contains java.exe,
REM otherwise fall back to Android Studio's bundled JBR.
set "JAVA_BIN=%JAVA_HOME%\bin\java.exe"
if not exist "%JAVA_BIN%" (
    if exist "C:\Program Files\Android\Android Studio\jbr\bin\java.exe" (
        set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
        set "JAVA_BIN=%JAVA_HOME%\bin\java.exe"
    )
)
if not exist "%JAVA_BIN%" (
    echo ERROR: No Java JDK found.
    echo Install Android Studio or a JDK 17+ and set JAVA_HOME.
    exit /b 1
)
set "PATH=%JAVA_HOME%\bin;%PATH%"

echo Using JAVA_HOME=%JAVA_HOME%

REM Gradle needs the Android SDK. local.properties is committed without sdk.dir
REM (so the repo stays portable), therefore pass the detected SDK through
REM ANDROID_HOME.
set "ANDROID_SDK="
if defined ANDROID_HOME if exist "%ANDROID_HOME%" set "ANDROID_SDK=%ANDROID_HOME%"
if not defined ANDROID_SDK if defined ANDROID_SDK_ROOT if exist "%ANDROID_SDK_ROOT%" set "ANDROID_SDK=%ANDROID_SDK_ROOT%"
if not defined ANDROID_SDK if exist "%LOCALAPPDATA%\Android\Sdk" set "ANDROID_SDK=%LOCALAPPDATA%\Android\Sdk"
if not defined ANDROID_SDK (
    echo ERROR: Android SDK not found. Install it with Android Studio.
    exit /b 1
)
set "ANDROID_HOME=%ANDROID_SDK%"
set "ANDROID_SDK_ROOT=%ANDROID_SDK%"
echo Using ANDROID_HOME=%ANDROID_HOME%
echo.

echo [Step 1/2] Cleaning previous builds...
call gradlew.bat clean --console=plain
if errorlevel 1 goto :failed
echo.

echo [Step 2/2] Building debug APKs...
call gradlew.bat :app-farmer:assembleDebug :app-vet:assembleDebug --console=plain
if errorlevel 1 goto :failed
echo.

echo ========================================
echo Build Complete!
echo ========================================
echo.
echo Debug APKs (testing only):
echo   Farmer: app-farmer\build\outputs\apk\debug\
echo   Vet:    app-vet\build\outputs\apk\debug\
echo.
pause
exit /b 0

:failed
echo.
echo BUILD FAILED - see the messages above.
echo.
pause
exit /b 1
