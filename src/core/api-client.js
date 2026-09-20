const DEFAULT_GATEWAY = 'http://localhost:8787';

export class TelegramApiClient {
  constructor(baseUrl = localStorage.getItem('mdless:gateway') || DEFAULT_GATEWAY) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.token = localStorage.getItem('mdless:gateway-token') || '';
  }

  setBaseUrl(value) {
    this.baseUrl = (value || DEFAULT_GATEWAY).replace(/\/$/, '');
    localStorage.setItem('mdless:gateway', this.baseUrl);
  }

  setToken(value) {
    this.token = value || '';
    if (this.token) localStorage.setItem('mdless:gateway-token', this.token);
    else localStorage.removeItem('mdless:gateway-token');
  }

  async request(path, options = {}) {
    const response = await fetch(`${this.baseUrl}${path}`, { ...options, headers: { 'Content-Type': 'application/json', ...(this.token ? { Authorization: `Bearer ${this.token}` } : {}), ...(options.headers || {}) } });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload.error || `Gateway request failed (${response.status})`);
    return payload;
  }

  health() { return this.request('/api/health'); }
  authStatus() { return this.request('/api/auth/status'); }
  authStart(phone) { return this.request('/api/auth/start', { method: 'POST', body: JSON.stringify({ phone }) }); }
  authCode(code) { return this.request('/api/auth/code', { method: 'POST', body: JSON.stringify({ code }) }); }
  authPassword(password) { return this.request('/api/auth/password', { method: 'POST', body: JSON.stringify({ password }) }); }
  logout() { return this.request('/api/auth/logout', { method: 'POST' }); }
  dialogs(limit = 50) { return this.request(`/api/dialogs?limit=${limit}`); }
  messages(peer, limit = 50) { return this.request(`/api/messages?peer=${encodeURIComponent(peer)}&limit=${limit}`); }
  sendMessage(peer, message, replyTo) { return this.request('/api/messages', { method: 'POST', body: JSON.stringify({ peer, message, replyTo }) }); }
  markRead(peer, maxId) { return this.request('/api/read', { method: 'POST', body: JSON.stringify({ peer, maxId }) }); }
  invoke(method, params = {}) { return this.request('/api/invoke', { method: 'POST', body: JSON.stringify({ method, params }) }); }

  subscribe(onUpdate, onError = () => {}) {
    const tokenQuery = this.token ? `?token=${encodeURIComponent(this.token)}` : '';
    const source = new EventSource(`${this.baseUrl}/api/events${tokenQuery}`);
    source.addEventListener('update', (event) => onUpdate(JSON.parse(event.data)));
    source.onerror = onError;
    return () => source.close();
  }
}
