# Moon — инструкция по сборке APK

## Вариант 1: Windows-компьютер (рекомендуется)

1. Установи Flutter SDK: https://docs.flutter.dev/get-started/install
2. Установи Android Studio: https://developer.android.com/studio
3. В Android Studio установи Android SDK и Android SDK Command-line Tools.
4. Открой PowerShell/CMD и выполни:
   `flutter doctor`
5. Исправь пункты, которые `flutter doctor` помечает как обязательные.
6. Распакуй этот проект.
7. Запусти `build_moon_windows.bat`.
8. Готовый файл появится в корне проекта как `moon.apk`.

## Вариант 2: macOS/Linux

Установи Flutter и Android SDK, затем из папки проекта:

```bash
flutter doctor
flutter pub get
flutter build apk --release
```

Готовый APK:
`build/app/outputs/flutter-apk/app-release.apk`

Или запусти `./build_moon.sh`.

## Вариант 3: Android-телефон

Самый простой способ — использовать приложение/среду, которая умеет запускать Flutter/Gradle-проект с Android SDK. На обычном Android без полноценного SDK сборка Flutter-проекта существенно сложнее.

Если телефон поддерживает Termux, потребуется отдельно настроить Java/Android SDK/Flutter. Для первого раза лучше использовать Windows/macOS/Linux.

## Установка APK

После сборки перенеси `moon.apk` на телефон и открой его через файловый менеджер. Android попросит разрешить установку из неизвестного источника для используемого файлового менеджера/браузера.

## Важно про подпись

Эта сборка использует обычную release-конфигурацию проекта. Для личного тестирования этого достаточно. Для выпуска обновлений приложения желательно один раз создать постоянный keystore и использовать его для всех будущих релизов, иначе Android не сможет установить новую версию поверх старой как обновление.
