# MDless

MDless is a mobile-first Telegram client with an expressive Material 3 interface, a local plugin engine, per-chat appearance settings, and an optional self-hosted MTProto gateway.

## What works

- PWA shell that can be installed on Android, iOS, and desktop browsers.
- Responsive chat list, message view, composer, search, dark mode, offline shell cache, and live update subscription.
- Per-chat accent colors, message density, wallpaper, and local appearance preferences.
- Settings-based plugin engine with persistent enable/disable state and plugin actions.
- Real Telegram user authorization through the gateway using GramJS: phone login, login code, optional 2FA password, session persistence, dialogs, message history, sending messages, read markers, and an MTProto constructor escape hatch through `/api/invoke`.
- Server-Sent Events for incoming new-message updates.
- Demo mode remains available when the gateway is offline.

## Quick start

Requirements: Node.js 20 or newer.

1. Create Telegram API credentials at <https://my.telegram.org>.
2. Copy `.env.example` to `.env` and set `TELEGRAM_API_ID`, `TELEGRAM_API_HASH`, and a long random `MDLESS_GATEWAY_TOKEN`.
3. Install dependencies:

```bash
npm install
```

4. Start the MTProto gateway and PWA:

```bash
npm start
```

Open <http://localhost:8787>. The client also works in demo mode with `npm run dev` through Vite.

For a mobile client outside your home network, deploy the gateway with the included `Dockerfile`, expose it through HTTPS, set the gateway token in `.env`, and enter that HTTPS URL plus token in Settings > Account. GitHub Pages hosts only the static PWA; it cannot run the private MTProto session service.

Never commit `.env`, `.data/`, or a `.session` file. The gateway stores the authenticated GramJS session at `.data/telegram.session` with restrictive file permissions. The token protects REST and SSE access. For a public deployment, put the gateway behind HTTPS, authentication, rate limiting, and a private network; do not expose the raw gateway to the internet.

## Architecture

```text
Browser / installed PWA
  ├─ src/main.js                 UI state, plugins, chat customization
  ├─ src/core/api-client.js      REST + SSE gateway client
  └─ sw.js                       offline app shell

Node gateway
  ├─ server/index.mjs            HTTP API, static hosting, SSE
  └─ server/telegram-service.mjs GramJS MTProto session and updates
```

The gateway exposes common chat operations and `/api/invoke`, which maps a GramJS `Api.*` constructor by name. That keeps the full Telegram API available without hard-coding every Telegram method into the UI.

## Plugin API

Plugins are local JavaScript modules registered with the runtime. They can expose actions and commands without directly touching Telegram credentials:

```js
pluginManager.register({
  id: 'my-plugin',
  name: 'My plugin',
  description: 'Does something useful.',
  version: '0.1.0',
  icon: '✦',
  enabled: true,
  settings: [{ id: 'enabled', label: 'Enabled', type: 'boolean', value: true }],
  actions: [{ id: 'open', label: 'Open', run: (context) => {} }]
});
```

The runtime persists plugin state in `localStorage` and passes the active user, chat, messages, toast helper, and render callback through its context.

## GitHub Pages

The repository includes a Pages workflow for the PWA shell. GitHub Pages can run the demo shell, but a real Telegram account requires the private Node gateway; keep that gateway on a secured server and point the Settings > Account gateway URL at it.

## License

MIT
