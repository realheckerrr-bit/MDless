# MDless native mobile client

This directory is the native Flutter client. It targets Android first and uses TDLib directly through the Flutter binding, so Telegram authentication, local encrypted data, ordered updates, chat history, and sending happen on the device instead of inside a browser.

## Run on Android

Install Flutter and Android Studio, then from this directory:

```bash
flutter pub get
flutter run --dart-define=TELEGRAM_API_ID=123456 --dart-define=TELEGRAM_API_HASH=your_hash
```

You can also enter API credentials in Settings. Never commit real credentials or a TDLib database directory.

For a release build that starts already configured for Telegram, add `TELEGRAM_API_ID` and `TELEGRAM_API_HASH` as repository secrets. The Android workflow passes them only as masked build-time defines; the values are never committed to the repository. If the secrets are absent, use Advanced client setup on the login screen.

The app contains the Material 3 Expressive shell, bundled Google Sans Flex typography, TDLib gateway, native Telegram login, settings-based plugin registry, per-chat appearance controls, Telegram audio playback, and TDLib private-call signaling. Flutter plugins are compiled into the app; arbitrary downloaded Dart code is intentionally not executed on-device. This keeps plugin permissions reviewable and compatible with Android app sandboxing. The native Telegram calls media engine is not bundled yet, so the call surface reports signaling state instead of claiming that microphone audio is connected.

## Local plugin manifests

Settings can install a JSON manifest from the device. Manifests declare metadata, permissions, and allowlisted UI actions; they do not execute downloaded code or receive raw network access.

```json
{
  "id": "reading-mode",
  "name": "Reading mode",
  "description": "Add a reading action to chats.",
  "version": "1.0.0",
  "author": "Your name",
  "icon": "R",
  "accent": "#FF6750A4",
  "permissions": ["messages"],
  "actions": [
    {"id": "read-chat", "label": "Focus this chat", "icon": "focus", "surface": "chat", "command": "focusChat"}
  ]
}
```

Manifest commands are allowlisted native operations: `focusChat`, `clearFocus`, `translateMessage`, `inspectLink`, `addReaction`, `downloadMedia`, `markRead`, `muteChat`, and `copyMessage`. Unknown commands are shown as status-only actions; downloaded code is never executed.

TDLib is Telegram's official cross-platform client library and handles encryption, local storage, asynchronous requests, and ordered updates. The Flutter binding currently needs native TDLib packaging for iOS, so Android is the first native target in this repository; iOS packaging is the next platform task.
