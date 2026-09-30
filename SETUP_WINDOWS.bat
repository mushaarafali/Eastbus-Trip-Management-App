@echo off
echo =============================================
echo EastBus Trip Management App - Flutter Setup
echo =============================================
flutter --version
if errorlevel 1 (
 echo Flutter is not available in PATH. Install Flutter and add it to PATH first.
 pause
 exit /b 1
)
flutter pub get
flutter doctor
flutter devices
echo.
echo Setup complete. Open the project ROOT folder in Android Studio.
pause
