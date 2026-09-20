# MDless

MDless is a native Android Telegram client with an expressive Material 3 interface, a local plugin engine, and per-chat appearance settings.

The product is the Flutter app in [`mobile/`](mobile/). MDless does not deploy an online demo or GitHub Pages site.

## Native mobile build

The app uses TDLib directly on the device for Telegram authorization, local storage, chat history, updates, and sending. It includes native navigation, settings, plugins, dark mode, and per-chat customization. See [`mobile/README.md`](mobile/README.md).

## What works

- Native Android chat list, message view, composer, search, dark mode, and live TDLib updates.
- Phone login, login code, optional 2FA password, local session storage, dialogs, history, and sending.
- Persistent settings-based plugin enable/disable state.
- Per-chat accent colors, compact messages, dot wallpaper, and appearance preferences.

## Quick start

Requirements: Flutter 3.29+ and Android Studio.

1. Create Telegram API credentials at <https://my.telegram.org>.
2. Run the native client:

```bash
cd mobile
flutter pub get
flutter run --dart-define=TELEGRAM_API_ID=123456 --dart-define=TELEGRAM_API_HASH=your_hash
```

API credentials can also be entered in the app Settings screen. Never commit real credentials or a TDLib database directory.

## Architecture

```text
Flutter Android app
  ├─ mobile/lib/main.dart                 Material 3 mobile UI
  ├─ mobile/lib/core/tdlib_gateway.dart   TDLib auth, chats, history, sending
  ├─ mobile/lib/core/plugin_engine.dart   settings-based plugin registry
  └─ mobile/lib/core/chat_customizations.dart
```

Plugins are compiled Flutter modules registered with the native settings engine. Arbitrary downloaded code is not executed on-device. Plugin enable/disable state is persisted locally with Android preferences.

The old web/gateway source remains in the repository as unbuilt legacy code, but it is not deployed, linked as the product, or required by the native client.

## License

MIT
