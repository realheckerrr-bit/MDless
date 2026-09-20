import { EventEmitter } from 'node:events';
import fs from 'node:fs/promises';
import path from 'node:path';
import { TelegramClient, Api } from 'telegram';
import { StringSession } from 'telegram/sessions/index.js';
import { NewMessage } from 'telegram/events/index.js';

const safeJson = (value) => JSON.parse(JSON.stringify(value, (_, item) => typeof item === 'bigint' ? item.toString() : item));

export class TelegramService extends EventEmitter {
  constructor({ apiId, apiHash, sessionFile }) {
    super();
    this.apiId = Number(apiId || 0);
    this.apiHash = apiHash || '';
    this.sessionFile = sessionFile;
    this.session = new StringSession('');
    this.client = null;
    this.auth = { status: 'offline', phone: '', error: '' };
    this.waiters = new Map();
  }

  async init() {
    if (!this.apiId || !this.apiHash) {
      this.auth = { status: 'needs_config', phone: '', error: 'Set TELEGRAM_API_ID and TELEGRAM_API_HASH in .env.' };
      return this.auth;
    }
    try {
      const saved = await fs.readFile(this.sessionFile, 'utf8').catch(() => '');
      this.session = new StringSession(saved.trim());
      this.client = new TelegramClient(this.session, this.apiId, this.apiHash, { connectionRetries: 5 });
      await this.client.connect();
      if (await this.client.checkAuthorization()) {
        this.auth.status = 'authorized';
        this.attachUpdates();
      } else {
        this.auth.status = 'ready';
      }
    } catch (error) {
      this.auth = { status: 'error', phone: '', error: error.message };
    }
    return this.auth;
  }

  async ensureClient() {
    if (!this.client) await this.init();
    if (!this.client) throw new Error('Telegram gateway is not configured.');
    return this.client;
  }

  async beginAuth(phone) {
    if (!phone) throw new Error('A phone number is required.');
    const client = await this.ensureClient();
    this.auth = { status: 'starting', phone, error: '' };
    this.loginPromise = client.start({
      phoneNumber: async () => phone,
      phoneCode: async () => this.waitFor('code'),
      password: async () => this.waitFor('password'),
      onError: (error) => { this.auth.error = error.message; this.emit('auth', this.auth); },
    }).then(async () => {
      await this.persistSession();
      this.auth = { status: 'authorized', phone, error: '' };
      this.attachUpdates();
      this.emit('auth', this.auth);
      return this.auth;
    }).catch((error) => {
      this.auth = { status: 'error', phone, error: error.message };
      this.emit('auth', this.auth);
      throw error;
    });
    await new Promise((resolve) => setTimeout(resolve, 250));
    if (this.auth.status === 'starting') this.auth.status = 'code_required';
    return this.auth;
  }

  provideCode(code) { this.auth.status = 'verifying_code'; this.resolveWaiter('code', code); return this.auth; }
  providePassword(password) { this.auth.status = 'verifying_password'; this.resolveWaiter('password', password); return this.auth; }

  waitFor(type) {
    this.auth.status = `${type}_required`;
    this.emit('auth', this.auth);
    return new Promise((resolve, reject) => this.waiters.set(type, { resolve, reject }));
  }

  resolveWaiter(type, value) {
    const waiter = this.waiters.get(type);
    if (!waiter) return;
    waiter.resolve(value);
    this.waiters.delete(type);
  }

  async persistSession() {
    await fs.mkdir(path.dirname(this.sessionFile), { recursive: true });
    await fs.writeFile(this.sessionFile, this.client.session.save(), { mode: 0o600 });
  }

  attachUpdates() {
    if (!this.client || this.updatesAttached) return;
    this.updatesAttached = true;
    this.client.addEventHandler((event) => {
      const message = event.message;
      this.emit('update', { type: 'new_message', message: safeJson({ id: message.id, text: message.message, date: message.date, peerId: message.peerId }) });
    }, new NewMessage({}));
  }

  async logout() {
    if (this.client) await this.client.logOut().catch(() => {});
    await fs.rm(this.sessionFile, { force: true });
    this.auth = { status: 'ready', phone: '', error: '' };
  }

  async getDialogs(limit = 50) {
    const dialogs = await (await this.ensureClient()).getDialogs({ limit: Number(limit) });
    return safeJson(dialogs.map((dialog) => ({ id: dialog.id?.toString(), name: dialog.title || dialog.name || 'Unknown chat', unread: dialog.unreadCount || 0, draft: dialog.draft?.message || '' })));
  }

  async getMessages(peer, limit = 50) {
    if (!peer) throw new Error('A peer is required.');
    const messages = await (await this.ensureClient()).getMessages(peer, { limit: Number(limit) });
    return safeJson(messages.map((message) => ({ id: message.id, text: message.message || '', date: message.date, out: message.out, senderId: message.senderId })));
  }

  async sendMessage(peer, message, replyTo) {
    if (!peer || !message) throw new Error('A peer and message are required.');
    const result = await (await this.ensureClient()).sendMessage(peer, { message, replyTo: replyTo || undefined });
    await this.persistSession();
    return safeJson({ id: result.id, text: result.message, date: result.date, out: true });
  }

  async markRead(peer, maxId) { return safeJson(await (await this.ensureClient()).markAsRead(peer, { maxId })); }

  async invoke(method, params) {
    const Constructor = Api[method];
    if (typeof Constructor !== 'function') throw new Error(`Unknown Telegram constructor: ${method}`);
    return safeJson(await (await this.ensureClient()).invoke(new Constructor(params || {})));
  }
}
