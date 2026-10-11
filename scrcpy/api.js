// SkyDroid tiny device API (port 8001).
// No auth here — Caddy guards it with basic auth. ADB never leaves the
// compose network.
const http = require('http');
const fs = require('fs');
const { execFile, spawn } = require('child_process');

const ADB_SERIAL = process.env.ADB_SERIAL || 'android:5555';
const PORT = parseInt(process.env.API_PORT || '8001', 10);
const RESTART_FLAG = '/tmp/skydroid-restart-scrcpy';

function adb(args, timeoutMs) {
  return new Promise((resolve, reject) => {
    execFile(
      'adb',
      ['-s', ADB_SERIAL, ...args],
      { timeout: timeoutMs || 30000, maxBuffer: 16 * 1024 * 1024 },
      (err, stdout, stderr) => {
        if (err) reject(new Error((stderr || err.message || '').trim()));
        else resolve(stdout);
      }
    );
  });
}

const server = http.createServer(async (req, res) => {
  // No Nagle batching: key/touch events go out immediately.
  req.socket.setNoDelay(true);
  const url = new URL(req.url || '/', 'http://127.0.0.1');
  const p = url.pathname;
  try {
    if (req.method === 'GET' && p === '/api/ping') {
      // RTT probe used by the /play/ client's adaptive quality loop.
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true, t: Date.now() }));
      return;
    }
    if (req.method === 'POST' && p.startsWith('/api/key/')) {
      const code = parseInt(p.split('/').pop(), 10);
      if (!Number.isInteger(code) || code < 0) throw new Error('bad keycode');
      await adb(['shell', 'input', 'keyevent', String(code)]);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true, code }));
      return;
    }
    if (req.method === 'GET' && p === '/api/screenshot') {
      const child = spawn('adb', ['-s', ADB_SERIAL, 'exec-out', 'screencap', '-p']);
      res.writeHead(200, { 'Content-Type': 'image/png' });
      child.stdout.pipe(res);
      child.on('error', () => {
        try {
          res.end();
        } catch (e) {}
      });
      return;
    }
    if (req.method === 'POST' && p === '/api/stream/restart') {
      // Asks entrypoint.sh's supervisor to restart the scrcpy-server session.
      fs.writeFileSync(RESTART_FLAG, '1');
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true }));
      return;
    }
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('not found');
  } catch (e) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: false, error: String((e && e.message) || e) }));
  }
});

// No Nagle on accepted sockets either.
server.on('connection', (socket) => socket.setNoDelay(true));

server.listen(PORT, () => console.log(`[api] listening on :${PORT}`));
