# MDless

MDless is a Telegram client concept built around two ideas: a calm, expressive Material 3 interface and a plugin runtime that can grow with the user. This first slice is a dependency-light browser client shell, so it runs without a build step and is easy to extend.

## What is included

- Expressive Material 3-inspired design tokens, dynamic-ish color surfaces, springy motion, adaptive navigation, dark mode, and reduced-motion support.
- Telegram-shaped chat list, conversation view, message composer, reply affordance, search, details panel, and a plugin directory.
- A small plugin runtime with registration, enable/disable state, commands, settings, and UI actions.
- Built-in example plugins: Focus Mode, Quick Translate, Link Inspector, and Emoji Reactions.
- A clean boundary for a real Telegram transport: replace the mock `TelegramGateway` with an MTProto-backed adapter without rewriting the UI or plugin API.

## Run it

Requires Python 3.10+ (or any static file server).

```bash
npm run dev
```

Open <http://localhost:4173>.

## Project shape

```text
MDless/
├─ index.html
├─ src/
│  ├─ main.js       # app state, plugin runtime, UI event wiring
│  └─ styles.css    # MD3 Expressive visual system
├─ package.json
└─ README.md
```

## Plugin API

Plugins are intentionally small objects. A plugin can add commands, settings, and actions without reaching into the renderer:

```js
pluginManager.register({
  id: 'my-plugin',
  name: 'My plugin',
  description: 'Does something useful.',
  version: '0.1.0',
  icon: '✦',
  enabled: true,
  commands: [{ id: 'hello', label: 'Say hello', run: (context) => {} }],
  settings: [{ id: 'enabled', label: 'Enabled', type: 'boolean', value: true }],
  actions: [{ id: 'open', label: 'Open', run: (context) => {} }]
});
```

The runtime persists enable/disable choices in `localStorage` and exposes a `context` containing the current user, active chat, messages, toast helper, and render request.

## Telegram transport roadmap

The browser shell currently uses `TelegramGateway` mock data so the UI is immediately usable. A production build should add an MTProto service boundary with encrypted session storage, rate-limit handling, media caching, and explicit permission prompts. The renderer and plugins should consume gateway events rather than calling Telegram directly.

## License

MIT
