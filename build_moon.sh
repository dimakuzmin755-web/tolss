#!/usr/bin/env bash
set -e
echo "=== Moon APK build ==="
command -v flutter >/dev/null 2>&1 || {
  echo "Flutter not found. Install Flutter and Android Studio first."
  exit 1
}
flutter pub get
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk moon.apk
echo
echo "READY: $(pwd)/moon.apk"
