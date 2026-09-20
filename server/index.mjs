import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import { TelegramService } from './telegram-service.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const port = Number(process.env.PORT || 8787);
const gatewayToken = process.env.MDLESS_GATEWAY_TOKEN || '';
const service = new TelegramService({
  apiId: process.env.TELEGRAM_API_ID,
  apiHash: process.env.TELEGRAM_API_HASH,
  sessionFile: path.resolve(process.env.MDLESS_SESSION_FILE || path.join(root, '.data', 'telegram.session')),
});
const clients = new Set();

const json = (response, status, payload) => {
  response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'Content-Type', 'Access-Control-Allow-Methods': 'GET,POST,OPTIONS' });
  response.end(JSON.stringify(payload));
};
const body = async (request) => { let data = ''; for await (const chunk of request) data += chunk; return data ? JSON.parse(data) : {}; };
const authorized = (request, url) => !gatewayToken || request.headers.authorization === `Bearer ${gatewayToken}` || url.searchParams.get('token') === gatewayToken;
const publicFile = async (request, response) => {
  const requestPath = new URL(request.url, `http://${request.headers.host}`).pathname;
  const relative = requestPath === '/' ? 'index.html' : requestPath.replace(/^\//, '');
  const filePath = path.resolve(root, relative);
  if (!filePath.startsWith(root)) return json(response, 403, { error: 'Forbidden' });
  try {
    const data = await fs.readFile(filePath);
    const contentType = filePath.endsWith('.html') ? 'text/html' : filePath.endsWith('.js') ? 'text/javascript' : filePath.endsWith('.css') ? 'text/css' : filePath.endsWith('.svg') ? 'image/svg+xml' : filePath.endsWith('.json') || filePath.endsWith('.webmanifest') ? 'application/manifest+json' : 'application/octet-stream';
    response.writeHead(200, { 'Content-Type': `${contentType}; charset=utf-8` }); response.end(data);
  } catch { json(response, 404, { error: 'Not found' }); }
};

service.on('update', (update) => { const data = `event: update\ndata: ${JSON.stringify(update)}\n\n`; for (const client of clients) client.write(data); });

const server = http.createServer(async (request, response) => {
  if (request.method === 'OPTIONS') return json(response, 204, {});
  const url = new URL(request.url, `http://${request.headers.host}`);
  try {
    if (url.pathname === '/api/health') return json(response, 200, { name: 'MDless Telegram Gateway', ...service.auth });
    if (url.pathname.startsWith('/api/') && !authorized(request, url)) return json(response, 401, { error: 'Gateway token required.' });
    if (url.pathname === '/api/auth/status') return json(response, 200, service.auth);
    if (url.pathname === '/api/auth/start' && request.method === 'POST') return json(response, 200, await service.beginAuth((await body(request)).phone));
    if (url.pathname === '/api/auth/code' && request.method === 'POST') return json(response, 200, service.provideCode((await body(request)).code));
    if (url.pathname === '/api/auth/password' && request.method === 'POST') return json(response, 200, service.providePassword((await body(request)).password));
    if (url.pathname === '/api/auth/logout' && request.method === 'POST') { await service.logout(); return json(response, 200, service.auth); }
    if (url.pathname === '/api/dialogs') return json(response, 200, { dialogs: await service.getDialogs(url.searchParams.get('limit') || 50) });
    if (url.pathname === '/api/messages' && request.method === 'GET') return json(response, 200, { messages: await service.getMessages(url.searchParams.get('peer'), url.searchParams.get('limit') || 50) });
    if (url.pathname === '/api/messages' && request.method === 'POST') { const data = await body(request); return json(response, 200, await service.sendMessage(data.peer, data.message, data.replyTo)); }
    if (url.pathname === '/api/read' && request.method === 'POST') { const data = await body(request); return json(response, 200, await service.markRead(data.peer, data.maxId)); }
    if (url.pathname === '/api/invoke' && request.method === 'POST') { const data = await body(request); return json(response, 200, await service.invoke(data.method, data.params)); }
    if (url.pathname === '/api/events') { response.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive', 'Access-Control-Allow-Origin': '*' }); response.write(': connected\n\n'); clients.add(response); request.on('close', () => clients.delete(response)); return; }
    return publicFile(request, response);
  } catch (error) { return json(response, 500, { error: error.message }); }
});

await service.init();
server.listen(port, () => console.log(`MDless gateway listening at http://localhost:${port}`));
