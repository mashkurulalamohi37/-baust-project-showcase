@echo off
REM PWA Build and Deploy Script for Windows
REM This script builds your Flutter web app and prepares it for deployment

echo ========================================
echo BAUST Project Showcase - PWA Builder
echo ========================================
echo.

REM Step 1: Clean previous builds
echo [1/5] Cleaning previous builds...
call flutter clean
if %errorlevel% neq 0 (
    echo ERROR: Flutter clean failed!
    pause
    exit /b 1
)
echo ✓ Clean complete
echo.

REM Step 2: Get dependencies
echo [2/5] Getting dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Failed to get dependencies!
    pause
    exit /b 1
)
echo ✓ Dependencies updated
echo.

REM Step 3: Build for web
echo [3/5] Building for web (this may take a few minutes)...
call flutter build web --release
if %errorlevel% neq 0 (
    echo ERROR: Web build failed!
    pause
    exit /b 1
)
echo ✓ Web build complete
echo.

REM Step 4: Show build info
echo [4/5] Build Information:
echo Build location: build\web
dir build\web /b
echo.

REM Step 5: Deployment options
echo [5/5] Deployment Options:
echo.
echo Choose your deployment method:
echo   1. Firebase Hosting (Recommended)
echo   2. Test locally
echo   3. Exit
echo.
set /p choice="Enter your choice (1-3): "

if "%choice%"=="1" goto firebase
if "%choice%"=="2" goto local
if "%choice%"=="3" goto end

:firebase
echo.
echo Deploying to Firebase Hosting...
echo Make sure you're logged in: firebase login
echo.
set /p confirm="Continue with deployment? (Y/N): "
if /i "%confirm%"=="Y" (
    call firebase deploy --only hosting
    if %errorlevel% neq 0 (
        echo ERROR: Firebase deployment failed!
        echo Make sure Firebase CLI is installed and you're logged in.
        pause
        exit /b 1
    )
    echo.
    echo ✓ Deployment complete!
    echo Your app is now live!
) else (
    echo Deployment cancelled.
)
goto end

:local
echo.
echo Starting local server...
echo Open your browser to: http://localhost:8000
echo Press Ctrl+C to stop the server
echo.
cd build\web
python -m http.server 8000
goto end

:end
echo.
echo ========================================
echo Build process complete!
echo ========================================
echo.
echo Next steps:
echo   - Test your app locally
echo   - Deploy to Firebase Hosting
echo   - Share the URL with users
echo.
echo For detailed instructions, see PWA_DEPLOYMENT_GUIDE.md
echo.
pause
