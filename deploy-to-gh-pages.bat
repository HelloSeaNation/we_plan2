@echo off
REM GitHub Pages Deployment Script for Windows
REM Usage: deploy-to-gh-pages.bat [repository-name]

setlocal

REM Get repository name from argument or prompt
if "%~1"=="" (
    set /p REPO_NAME="Enter your GitHub repository name (e.g., we_plan2): "
) else (
    set REPO_NAME=%~1
)

echo.
echo 🚀 Deploying to GitHub Pages...
echo Repository name: %REPO_NAME%
echo.

REM Build the app
echo 📦 Building web app...
flutter build web --release --base-href "/%REPO_NAME%/"

if errorlevel 1 (
    echo ❌ Build failed!
    exit /b 1
)

REM Check if gh-pages branch exists
git show-ref --verify --quiet refs/heads/gh-pages
if errorlevel 1 (
    echo 📝 Creating gh-pages branch...
    git checkout --orphan gh-pages
    
    REM Remove all files
    git rm -rf .
    
    REM Copy build files
    xcopy /E /I /Y build\web\* .
    
    REM Add and commit
    git add .
    git commit -m "Initial GitHub Pages deployment"
    
    REM Push
    git push origin gh-pages
    
    REM Switch back to main
    git checkout main
    
    echo ✅ Initial deployment complete!
    echo 🌐 Your app should be live at: https://your-username.github.io/%REPO_NAME%/
) else (
    echo 📝 Updating gh-pages branch...
    git checkout gh-pages
    
    REM Remove old files (keep .git)
    for /f "delims=" %%i in ('dir /b /a-d') do del /q "%%i"
    for /d /f "delims=" %%i in ('dir /b /ad ^| findstr /v "^\.git$"') do rd /s /q "%%i"
    
    REM Copy new build files
    xcopy /E /I /Y build\web\* .
    
    REM Add and commit
    git add .
    git commit -m "Deploy to GitHub Pages - %date% %time%"
    
    REM Push
    git push origin gh-pages
    
    REM Switch back to main
    git checkout main
    
    echo ✅ Deployment complete!
    echo 🌐 Your app should be live at: https://your-username.github.io/%REPO_NAME%/
)

endlocal




