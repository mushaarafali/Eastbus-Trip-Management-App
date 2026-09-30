@echo off
echo Regenerating Flutter Android platform files...
flutter create --platforms=android --org com.eastbus --project-name eastbus_trip_management_app .
flutter pub get
echo Done. Open this folder in Android Studio.
pause
