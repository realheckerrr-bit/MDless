# MDless native mobile client

This directory is the native Flutter client. It targets Android first and uses TDLib directly through the Flutter binding, so Telegram authentication, local encrypted data, ordered updates, chat history, and sending happen on the device instead of inside a browser.

## Run on Android

Install Flutter and Android Studio, then from this directory:

```bash
flutter pub get
flutter run --dart-define=TELEGRAM_API_ID=123456 --dart-define=TELEGRAM_API_HASH=your_hash
```

You can also enter API credentials in Settings. Never commit real credentials or a TDLib database directory.

The app contains the Material 3 Expressive-style shell, TDLib gateway, settings-based plugin registry, and per-chat appearance controls. Flutter plugins are compiled into the app; arbitrary downloaded Dart code is intentionally not executed on-device. This keeps plugin permissions reviewable and compatible with Android app sandboxing.

TDLib is Telegram's official cross-platform client library and handles encryption, local storage, asynchronous requests, and ordered updates. The Flutter binding currently needs native TDLib packaging for iOS, so Android is the first native target in this repository; iOS packaging is the next platform task.
