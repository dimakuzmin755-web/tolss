@echo off
setlocal
echo === Moon APK build ===
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter not found.
  echo Install Flutter and Android Studio, then run this script again.
  pause
  exit /b 1
)
flutter pub get
if errorlevel 1 exit /b 1
flutter build apk --release
if errorlevel 1 exit /b 1
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "moon.apk" >nul
echo.
echo READY: %CD%\moon.apk
pause
