const icon = (value, label = '') => `<span class="icon" aria-hidden="true">${value}</span>${label ? `<span>${label}</span>` : ''}`;

const seedChats = [
  { id: 'design', name: 'MD3 Design Club', initials: 'MD', color: 'coral', kind: 'group', online: true, unread: 4, preview: 'Mira: the new motion spec is feeling ✨', time: '09:42', pinned: true },
  { id: 'sasha', name: 'Sasha Volkov', initials: 'SV', color: 'violet', kind: 'person', online: true, unread: 0, preview: 'You: Sounds perfect — see you there!', time: '09:17', pinned: true },
  { id: 'night', name: 'Night Owls', initials: 'NO', color: 'blue', kind: 'group', online: false, unread: 12, preview: 'Lena shared a voice message', time: 'Yesterday', pinned: false },
  { id: 'notes', name: 'Saved Messages', initials: '✦', color: 'mint', kind: 'saved', online: false, unread: 0, preview: 'A quiet place for your thoughts', time: 'Mon', pinned: false },
  { id: 'mira', name: 'Mira Chen', initials: 'MC', color: 'amber', kind: 'person', online: false, unread: 0, preview: 'Can you send me that link?', time: 'Sun', pinned: false },
  { id: 'release', name: 'Release Radar', initials: 'RR', color: 'teal', kind: 'channel', online: false, unread: 0, preview: 'MDless 0.1 is almost ready', time: 'Sat', pinned: false },
];

const seedMessages = {
  design: [
    { id: 1, author: 'Mira Chen', initials: 'MC', color: 'amber', text: 'Good morning, makers. I dropped the updated motion board in the files tab.', time: '09:31', incoming: true, reactions: ['✨ 8', '❤️ 3'] },
    { id: 2, author: 'You', initials: 'YO', color: 'violet', text: 'The little spring on the navigation rail is *so* good. It makes the whole thing feel alive.', time: '09:34', incoming: false, reactions: ['👏 5'] },
    { id: 3, author: 'Sasha Volkov', initials: 'SV', color: 'violet', text: 'I’m voting for expressive corners everywhere. Let the cards breathe a little.', time: '09:37', incoming: true, reactions: ['💜 6'] },
    { id: 4, author: 'Mira Chen', initials: 'MC', color: 'amber', text: 'Exactly. Less dashboard, more room to think. I’ll polish the empty states next.', time: '09:42', incoming: true, reactions: [] },
  ],
  sasha: [
    { id: 1, author: 'Sasha Volkov', initials: 'SV', color: 'violet', text: 'Hey! Are we still on for the tiny gallery opening?', time: '09:12', incoming: true, reactions: [] },
    { id: 2, author: 'You', initials: 'YO', color: 'violet', text: 'Absolutely. I booked us a table around the corner for after.', time: '09:15', incoming: false, reactions: ['❤️ 1'] },
    { id: 3, author: 'Sasha Volkov', initials: 'SV', color: 'violet', text: 'Sounds perfect — see you there!', time: '09:17', incoming: true, reactions: [] },
  ],
  night: [
    { id: 1, author: 'Lena Ortiz', initials: 'LO', color: 'coral', text: 'Anyone awake? I found a beautiful late-night playlist.', time: '23:48', incoming: true, reactions: ['🎧 12'] },
    { id: 2, author: 'You', initials: 'YO', color: 'violet', text: 'Always. Send it over.', time: '23:51', incoming: false, reactions: [] },
    { id: 3, author: 'Lena Ortiz', initials: 'LO', color: 'coral', text: 'Voice message · 0:42', time: '23:53', incoming: true, voice: true, reactions: ['🌙 4'] },
  ],
  notes: [{ id: 1, author: 'You', initials: '✦', color: 'mint', text: 'A quiet place for your thoughts.', time: 'Mon', incoming: false, reactions: [] }],
  mira: [{ id: 1, author: 'Mira Chen', initials: 'MC', color: 'amber', text: 'Can you send me that link when you have a second?', time: 'Sun', incoming: true, reactions: [] }],
  release: [{ id: 1, author: 'Release Radar', initials: 'RR', color: 'teal', text: 'MDless 0.1 is almost ready. Follow along for the first public build.', time: 'Sat', incoming: true, reactions: ['🚀 9'] }],
};

class TelegramGateway {
  constructor() {
    this.connected = true;
  }

  async sendMessage(chatId, text) {
    await new Promise((resolve) => setTimeout(resolve, 260));
    return { id: Date.now(), author: 'You', initials: 'YO', color: 'violet', text, time: 'now', incoming: false, reactions: [] };
  }
}

class PluginManager {
  constructor() {
    this.plugins = new Map();
    this.storageKey = 'mdless:plugins';
    this.persisted = JSON.parse(localStorage.getItem(this.storageKey) || '{}');
  }

  register(plugin) {
    this.plugins.set(plugin.id, { ...plugin, enabled: this.persisted[plugin.id] ?? plugin.enabled ?? true });
    return this;
  }

  all() { return [...this.plugins.values()]; }
  enabled() { return this.all().filter((plugin) => plugin.enabled); }

  toggle(id) {
    const plugin = this.plugins.get(id);
    if (!plugin) return;
    plugin.enabled = !plugin.enabled;
    this.persisted[id] = plugin.enabled;
    localStorage.setItem(this.storageKey, JSON.stringify(this.persisted));
  }

  dispatch(pluginId, actionId, context) {
    const plugin = this.plugins.get(pluginId);
    const action = plugin?.actions?.find((entry) => entry.id === actionId);
    if (plugin?.enabled && action?.run) action.run(context);
  }
}

const gateway = new TelegramGateway();
const pluginManager = new PluginManager();
const state = {
  chats: seedChats,
  messages: structuredClone(seedMessages),
  activeChat: 'design',
  query: '',
  detailsOpen: false,
  pluginsOpen: false,
  theme: localStorage.getItem('mdless:theme') || 'light',
  focusMode: false,
  composer: '',
  replyTo: null,
};

const context = () => ({
  user: { name: 'Alex Morgan', username: '@alexm', initials: 'AM' },
  chat: state.chats.find((chat) => chat.id === state.activeChat),
  messages: state.messages[state.activeChat],
  toast,
  requestRender: render,
});

pluginManager
  .register({ id: 'focus-mode', name: 'Focus Mode', description: 'Tuck away the noise and keep one conversation in view.', version: '0.4.0', icon: '◒', accent: 'violet', enabled: true, actions: [{ id: 'toggle', label: 'Toggle', run: () => { state.focusMode = !state.focusMode; toast(state.focusMode ? 'Focus mode on' : 'Focus mode off'); render(); } }] })
  .register({ id: 'quick-translate', name: 'Quick Translate', description: 'Translate selected messages inline with one tap.', version: '0.2.1', icon: '文', accent: 'blue', enabled: true, actions: [{ id: 'translate', label: 'Translate', run: () => toast('Translation preview ready') }] })
  .register({ id: 'link-inspector', name: 'Link Inspector', description: 'Preview links before you open them.', version: '1.0.0', icon: '↗', accent: 'mint', enabled: true, actions: [{ id: 'inspect', label: 'Inspect', run: () => toast('No links in this message') }] })
  .register({ id: 'emoji-reactions', name: 'Emoji Reactions', description: 'Add a little more feeling to every conversation.', version: '0.8.2', icon: '☺', accent: 'amber', enabled: true, actions: [{ id: 'react', label: 'React', run: () => toast('Reaction picker opened') }] });

function toast(message) {
  const region = document.querySelector('#toast-region');
  const item = document.createElement('div');
  item.className = 'toast';
  item.innerHTML = `${icon('✦')}<span>${message}</span>`;
  region.append(item);
  setTimeout(() => item.remove(), 2600);
}

function initialsAvatar(initials, color, extra = '') {
  return `<span class="avatar avatar-${color} ${extra}">${initials}</span>`;
}

function render() {
  document.documentElement.dataset.theme = state.theme;
  document.documentElement.dataset.focus = state.focusMode ? 'true' : 'false';
  const chat = state.chats.find((entry) => entry.id === state.activeChat);
  const messages = state.messages[state.activeChat] || [];
  const visibleChats = state.chats.filter((entry) => `${entry.name} ${entry.preview}`.toLowerCase().includes(state.query.toLowerCase()));

  document.querySelector('#app').innerHTML = `
    <nav class="rail" aria-label="Main navigation">
      <button class="brand-mark" data-action="home" aria-label="MDless home">M<span>D</span></button>
      <div class="rail-main">
        <button class="rail-button active" data-action="chats" aria-label="Chats">${icon('▰')}<span>Chats</span><b>${state.chats.reduce((total, item) => total + item.unread, 0)}</b></button>
        <button class="rail-button" data-action="contacts" aria-label="Contacts">${icon('♧')}<span>People</span></button>
        <button class="rail-button" data-action="saved" aria-label="Saved messages">${icon('✦')}<span>Saved</span></button>
      </div>
      <div class="rail-bottom">
        <button class="rail-button" data-action="plugins" aria-label="Open plugins">${icon('⌘')}<span>Plugins</span></button>
        <button class="rail-button" data-action="theme" aria-label="Toggle theme">${icon(state.theme === 'light' ? '☾' : '☀')}<span>${state.theme === 'light' ? 'Night' : 'Day'}</span></button>
        <button class="avatar avatar-violet profile-button" data-action="profile" aria-label="Open profile">AM</button>
      </div>
    </nav>

    <aside class="inbox-panel">
      <header class="inbox-header">
        <div><p class="eyebrow">Your space</p><h1>Messages <span class="count-pill">${state.chats.filter((entry) => entry.unread).length}</span></h1></div>
        <button class="round-button filled" data-action="new-chat" aria-label="New message">${icon('+')}</button>
      </header>
      <label class="search-box">${icon('⌕')}<input id="search-input" value="${state.query}" placeholder="Search conversations" aria-label="Search conversations" /><kbd>⌘ K</kbd></label>
      <div class="filter-row"><button class="filter-chip selected">All <span>${state.chats.length}</span></button><button class="filter-chip">Unread <span>${state.chats.filter((entry) => entry.unread).length}</span></button><button class="filter-chip">Groups</button></div>
      <div class="chat-list" aria-label="Conversations">${visibleChats.map(chatRow).join('') || `<div class="empty-state"><span class="empty-orbit">⌕</span><h3>No messages here</h3><p>Try a different search.</p></div>`}</div>
      <footer class="inbox-footer"><span class="status-dot"></span><span>Synced just now</span><button data-action="settings" aria-label="Settings">${icon('⚙')}</button></footer>
    </aside>

    <main class="conversation ${state.detailsOpen ? 'details-visible' : ''}">
      <header class="conversation-header">
        <div class="conversation-person">${initialsAvatar(chat.initials, chat.color)}<div><h2>${chat.name}</h2><p>${chat.kind === 'group' ? '8,240 members' : chat.online ? 'online now' : 'last seen recently'}</p></div></div>
        <div class="conversation-actions"><button class="icon-button" data-action="search-chat" aria-label="Search in chat">${icon('⌕')}</button><button class="icon-button" data-action="call" aria-label="Start call">${icon('⌁')}</button><button class="icon-button ${state.detailsOpen ? 'selected' : ''}" data-action="details" aria-label="Show details">${icon('ⓘ')}</button></div>
      </header>
      <section class="message-stage" id="message-stage"><div class="day-divider"><span>Today</span></div>${messages.map(messageBubble).join('')}</section>
      ${state.replyTo ? `<div class="reply-preview"><div><span class="eyebrow">Replying to ${state.replyTo.author}</span><p>${state.replyTo.text}</p></div><button class="icon-button" data-action="cancel-reply" aria-label="Cancel reply">×</button></div>` : ''}
      <form class="composer" id="composer-form"><button type="button" class="icon-button attach-button" data-action="attach" aria-label="Attach file">${icon('＋')}</button><input id="composer-input" value="${escapeHtml(state.composer)}" autocomplete="off" placeholder="Write a message…" aria-label="Message" /><button type="button" class="icon-button composer-emoji" data-action="emoji" aria-label="Add emoji">☺</button><button class="send-button" type="submit" aria-label="Send message">${icon('↑')}</button></form>
    </main>
    ${state.detailsOpen ? detailsPanel(chat) : ''}
    ${state.pluginsOpen ? pluginsPanel() : ''}
  `;
  bindEvents();
  document.querySelector('#message-stage')?.scrollTo({ top: 99999 });
}

function chatRow(chat) {
  return `<button class="chat-row ${chat.id === state.activeChat ? 'active' : ''}" data-chat="${chat.id}">${initialsAvatar(chat.initials, chat.color)}<span class="chat-copy"><span class="chat-title"><strong>${chat.name}</strong><time>${chat.time}</time></span><span class="chat-preview">${chat.preview}</span></span>${chat.unread ? `<span class="unread-badge">${chat.unread > 9 ? '9+' : chat.unread}</span>` : ''}${chat.pinned ? `<span class="pin-mark">⌖</span>` : ''}</button>`;
}

function messageBubble(message) {
  return `<article class="message-row ${message.incoming ? 'incoming' : 'outgoing'}" data-message="${message.id}">${message.incoming ? initialsAvatar(message.initials, message.color, 'message-avatar') : ''}<div class="message-stack"><div class="bubble ${message.voice ? 'voice-bubble' : ''}">${message.voice ? `<span class="play-button">▶</span><span class="voice-wave"><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i></span><span class="voice-duration">0:42</span>` : `<p>${formatText(message.text)}</p>`}</div><div class="message-meta"><time>${message.time}</time>${message.reactions?.map((reaction) => `<button class="reaction" data-action="reaction">${reaction}</button>`).join('') || ''}${message.incoming ? `<button class="reply-link" data-action="reply">Reply</button>` : '<span class="read-check">✓✓</span>'}</div></div></article>`;
}

function detailsPanel(chat) {
  return `<aside class="details-panel"><div class="details-top"><span class="eyebrow">Conversation</span><button class="icon-button" data-action="details" aria-label="Close details">×</button></div><div class="details-profile">${initialsAvatar(chat.initials, chat.color, 'large-avatar')}<h2>${chat.name}</h2><p>${chat.online ? 'Active now' : 'Quietly in the background'}</p></div><div class="detail-actions"><button data-action="call">${icon('⌁')}<span>Call</span></button><button data-action="search-chat">${icon('⌕')}<span>Search</span></button><button data-action="mute">${icon('♢')}<span>Mute</span></button></div><div class="detail-section"><p class="eyebrow">Shared media</p><div class="media-grid"><span>◌</span><span>▧</span><span>✧</span></div></div><div class="detail-section"><p class="eyebrow">Permissions</p><div class="permission-row"><span>${icon('⌘')}<span>Plugins can enhance this chat</span></span><span class="toggle on"><i></i></span></div><div class="permission-row"><span>${icon('▱')}<span>Notifications</span></span><span class="toggle on"><i></i></span></div></div></aside>`;
}

function pluginsPanel() {
  return `<aside class="plugins-panel"><div class="details-top"><div><p class="eyebrow">Extend MDless</p><h2>Plugin shelf</h2></div><button class="icon-button" data-action="plugins" aria-label="Close plugins">×</button></div><div class="plugin-hero"><span class="hero-spark">✦</span><div><strong>Make it yours</strong><p>Small tools, thoughtfully placed.</p></div></div><div class="plugin-list">${pluginManager.all().map((plugin) => `<div class="plugin-card"><div class="plugin-icon plugin-${plugin.accent}">${plugin.icon}</div><div class="plugin-card-copy"><div><strong>${plugin.name}</strong><span class="version">v${plugin.version}</span></div><p>${plugin.description}</p><button class="text-button" data-plugin-action="${plugin.id}" data-plugin-command="${plugin.actions?.[0]?.id || ''}">${plugin.actions?.[0]?.label || 'Open'}</button></div><button class="toggle ${plugin.enabled ? 'on' : ''}" data-plugin-toggle="${plugin.id}" aria-label="Toggle ${plugin.name}"><i></i></button></div>`).join('')}</div><button class="browse-button" data-action="browse-plugins">${icon('＋')} Browse plugin directory</button></aside>`;
}

function formatText(text) { return escapeHtml(text).replace(/\*([^*]+)\*/g, '<em>$1</em>'); }
function escapeHtml(value) { return String(value).replace(/[&<>"]/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[char])); }

function bindEvents() {
  document.querySelectorAll('[data-chat]').forEach((button) => button.addEventListener('click', () => { state.activeChat = button.dataset.chat; state.replyTo = null; render(); }));
  document.querySelector('#search-input')?.addEventListener('input', (event) => { state.query = event.target.value; render(); const input = document.querySelector('#search-input'); input.focus(); input.setSelectionRange(input.value.length, input.value.length); });
  document.querySelector('#composer-input')?.addEventListener('input', (event) => { state.composer = event.target.value; });
  document.querySelector('#composer-form')?.addEventListener('submit', async (event) => { event.preventDefault(); const text = state.composer.trim(); if (!text) return; state.composer = ''; const newMessage = await gateway.sendMessage(state.activeChat, text); state.messages[state.activeChat].push(newMessage); state.chats = state.chats.map((chat) => chat.id === state.activeChat ? { ...chat, preview: `You: ${text}`, time: 'now' } : chat); toast('Message sent'); render(); });
  document.querySelectorAll('[data-action]').forEach((button) => button.addEventListener('click', () => handleAction(button.dataset.action, button)));
  document.querySelectorAll('[data-plugin-toggle]').forEach((button) => button.addEventListener('click', () => { pluginManager.toggle(button.dataset.pluginToggle); toast('Plugin settings updated'); render(); }));
  document.querySelectorAll('[data-plugin-action]').forEach((button) => button.addEventListener('click', () => pluginManager.dispatch(button.dataset.pluginAction, button.dataset.pluginCommand, context())));
}

function handleAction(action, source) {
  if (action === 'theme') { state.theme = state.theme === 'light' ? 'dark' : 'light'; localStorage.setItem('mdless:theme', state.theme); render(); }
  if (action === 'details') { state.detailsOpen = !state.detailsOpen; render(); }
  if (action === 'plugins') { state.pluginsOpen = !state.pluginsOpen; state.detailsOpen = false; render(); }
  if (action === 'new-chat') toast('New message flow is ready for the Telegram adapter');
  if (action === 'attach') toast('Attachment picker is ready for the media adapter');
  if (action === 'emoji') { const input = document.querySelector('#composer-input'); if (input) { input.value += ' ✨'; state.composer = input.value; input.focus(); } }
  if (action === 'call') toast('Voice and video calls will connect through the Telegram gateway');
  if (action === 'search-chat') toast('Search this conversation');
  if (action === 'settings') toast('Settings are coming into the plugin surface');
  if (action === 'mute') toast('Notifications muted for this conversation');
  if (action === 'browse-plugins') toast('Plugin directory connection is ready to add');
  if (action === 'reaction') toast('Reaction added');
  if (action === 'reply') { const message = state.messages[state.activeChat].find((entry) => String(entry.id) === source.closest('[data-message]')?.dataset.message); state.replyTo = message; render(); document.querySelector('#composer-input')?.focus(); }
  if (action === 'cancel-reply') { state.replyTo = null; render(); }
  if (action === 'profile') toast('Profile settings');
  if (action === 'home' || action === 'chats') { state.activeChat = 'design'; state.detailsOpen = false; state.pluginsOpen = false; render(); }
  if (action === 'contacts') toast('Contacts will sync through the Telegram gateway');
  if (action === 'saved') { state.activeChat = 'notes'; render(); }
}

render();
