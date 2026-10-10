const {test} = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const {createPreviewServer} = require('./preview.cjs');

test('local relay forwards official request once and preserves upstream errors', async () => {
  const calls = [];
  const server = createPreviewServer({fetchUpstream: async (url, options) => {
    calls.push({url, options});
    return new Response(JSON.stringify({error:'quota'}), {status:429});
  }});
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const origin = `http://127.0.0.1:${server.address().port}`;
  try {
    assert.equal((await (await fetch(`${origin}/api/ai/status`)).json()).relay, 'verdant-local-v1');
    const response = await fetch(`${origin}/api/ai/opencode`, {
      method:'POST', headers:{Origin:origin, 'Content-Type':'application/json',
        Authorization:'Bearer test-only', 'x-opencode-session':'reading-1'},
      body:JSON.stringify({model:'deepseek-v4.1-flash', messages:[]}),
    });
    assert.equal(response.status,429);
    assert.equal(calls.length,1);
    assert.equal(calls[0].url,'https://opencode.ai/zen/go/v1/chat/completions');
    assert.equal(calls[0].options.headers.Authorization,'Bearer test-only');
    assert.equal(calls[0].options.headers['x-opencode-session'],'reading-1');
    assert.equal(calls[0].options.headers['User-Agent'],'VerdantArcana/0.3');
    for (const badOrigin of ['https://evil.example', 'null', '']) {
      const denied = await fetch(`${origin}/api/ai/opencode`, {
        method:'POST', headers:{Origin:badOrigin, 'Content-Type':'application/json', Authorization:'Bearer test-only'}, body:'{}',
      });
      assert.equal(denied.status,403);
    }
    assert.equal((await fetch(`${origin}/api/ai/https://evil.example`)).status,404);
    const badHostStatus = await new Promise((resolve, reject) => {
      http.get(`${origin}/api/ai/status`, {headers:{Host:'evil.example'}}, response => {
        response.resume(); resolve(response.statusCode);
      }).on('error', reject);
    });
    assert.equal(badHostStatus,403);
    assert.equal(calls.length,1);
  } finally { await new Promise(resolve => server.close(resolve)); }
});

test('relay returns a safe error for network failure without exposing a key', async () => {
  const server = createPreviewServer({fetchUpstream:async () => {throw new Error('secret-test-key');}});
  await new Promise(resolve => server.listen(0,'127.0.0.1',resolve));
  const origin = `http://127.0.0.1:${server.address().port}`;
  try {
    const response = await fetch(`${origin}/api/ai/deepseek`, {
      method:'POST',headers:{Origin:origin,'Content-Type':'application/json',Authorization:'Bearer secret-test-key'},body:'{}',
    });
    assert.equal(response.status,502);
    assert.equal((await response.text()).includes('secret-test-key'),false);
  } finally { await new Promise(resolve => server.close(resolve)); }
});
