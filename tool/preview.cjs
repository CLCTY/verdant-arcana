const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../build/web');
const endpoints = {
  deepseek: 'https://api.deepseek.com/chat/completions',
  opencode: 'https://opencode.ai/zen/go/v1/chat/completions',
};
const types = {'.html':'text/html; charset=utf-8','.js':'application/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.ttf':'font/ttf','.otf':'font/otf'};
function createPreviewServer({fetchUpstream = fetch} = {}) {
return http.createServer(async (req,res) => {
  const port = req.socket.localPort;
  const host = req.headers.host;
  if (host !== `127.0.0.1:${port}` && host !== `localhost:${port}`) {
    res.writeHead(403); res.end(); return;
  }
  let pathname;
  try { pathname = decodeURIComponent(new URL(req.url,'http://localhost').pathname); }
  catch { res.writeHead(400); res.end(); return; }
  if (pathname.startsWith('/api/ai/')) {
    const reply = (status, body) => {
      res.writeHead(status, {'Content-Type':'application/json', 'Cache-Control':'no-store'});
      res.end(JSON.stringify(body));
    };
    if (pathname === '/api/ai/status' && req.method === 'GET') {
      reply(200, {relay:'verdant-local-v1'}); return;
    }
    const provider = pathname.slice('/api/ai/'.length);
    if (!Object.hasOwn(endpoints, provider)) { reply(404, {error:'Unknown provider'}); return; }
    // Loopback only, same-origin JSON only; never an arbitrary URL proxy.
    if (req.method !== 'POST') { reply(405, {error:'POST required'}); return; }
    if (req.headers.origin !== `http://${host}`) { reply(403, {error:'Same origin required'}); return; }
    if (!/^application\/json(?:;|$)/i.test(req.headers['content-type'] || '')) {
      reply(415, {error:'JSON required'}); return;
    }
    if (!/^Bearer [^\r\n]+$/.test(req.headers.authorization || '')) {
      reply(401, {error:'API key required'}); return;
    }
    try {
      let size = 0;
      const chunks = [];
      for await (const chunk of req) {
        size += chunk.length;
        if (size > 128 * 1024) { reply(413, {error:'Request too large'}); return; }
        chunks.push(chunk);
      }
      const body = Buffer.concat(chunks).toString('utf8');
      try { JSON.parse(body); } catch { reply(400, {error:'Invalid JSON'}); return; }
      const headers = {
        'Content-Type':'application/json',
        Authorization:req.headers.authorization,
        'User-Agent':'VerdantArcana/0.3',
      };
      if (provider === 'opencode' && req.headers['x-opencode-session']) {
        headers['x-opencode-session'] = req.headers['x-opencode-session'];
      }
      const response = await fetchUpstream(endpoints[provider], {
        method:'POST', headers, body, redirect:'error',
        signal:AbortSignal.timeout(85000),
      });
      res.writeHead(response.status, {'Content-Type':'application/json', 'Cache-Control':'no-store'});
      res.end(Buffer.from(await response.arrayBuffer()));
    } catch (error) {
      // Never log credentials, request content, or raw upstream errors.
      if (!res.headersSent) reply(error.name === 'TimeoutError' ? 504 : 502, {error:'Upstream unavailable'});
      else res.end();
    }
    return;
  }
  if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405); res.end(); return; }
  const file = path.resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname));
  if (!file.startsWith(root + path.sep)) { res.writeHead(403); res.end(); return; }
  fs.stat(file,(error,stat) => {
    if (error || !stat.isFile()) { res.writeHead(404); res.end(); return; }
    res.writeHead(200,{'Content-Type':types[path.extname(file)] || 'application/octet-stream','Cache-Control':'no-store'});
    fs.createReadStream(file).pipe(res);
  });
});
}
module.exports = {createPreviewServer};
if (require.main === module) {
  createPreviewServer().listen(4180,'127.0.0.1',() => console.log('Verdant Arcana: http://127.0.0.1:4180'));
}
