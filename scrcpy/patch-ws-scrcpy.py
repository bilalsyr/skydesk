#!/usr/bin/env python3
"""SkyDroid patches for ws-scrcpy (pinned commit).

Applies low-latency / observability changes to the ws-scrcpy source tree
BEFORE `npm run dist`. Every patch asserts an exact single match — the
build fails loudly if upstream source drifted.
"""
import re
import sys

PATCHES = 0


def patch(path, old, new):
    """Exact-string replacement, must occur exactly once."""
    global PATCHES
    with open(path, "r", encoding="utf-8") as f:
        src = f.read()
    n = src.count(old)
    if n != 1:
        print(f"PATCH FAIL: {path}: pattern found {n}x (expected 1x): {old[:70]!r}")
        sys.exit(1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(src.replace(old, new, 1))
    PATCHES += 1
    print(f"  ok: {path} :: {old[:48]!r}...")


def patch_re(path, pattern, replacement):
    """Regex replacement with re.MULTILINE, must match exactly once.

    Convention: pattern starts with ^([ \\t]*) to capture indentation,
    replacement re-emits it via \\1 for every inserted line.
    """
    global PATCHES
    with open(path, "r", encoding="utf-8") as f:
        src = f.read()
    matches = list(re.finditer(pattern, src, re.MULTILINE))
    if len(matches) != 1:
        print(f"PATCH FAIL: {path}: regex matched {len(matches)}x (expected 1x): {pattern[:70]!r}")
        sys.exit(1)
    m = matches[0]
    src = src[: m.start()] + m.expand(replacement) + src[m.end():]
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    PATCHES += 1
    print(f"  ok: {path} :: /{pattern[:48]}.../")


print("[patch] 1/5 default video settings -> 800kbps / 30fps / iframe 2s / 720")
# MsePlayer (default 7Mbps/60fps/10s) -> low-bandwidth defaults
patch("src/app/player/MsePlayer.ts", "bitrate: 7340032,", "bitrate: 800000,")
patch("src/app/player/MsePlayer.ts", "maxFps: 60,", "maxFps: 30,")
patch("src/app/player/MsePlayer.ts", "iFrameInterval: 10,", "iFrameInterval: 2,")
# WebCodecs / Broadway / TinyH264 / BasePlayer (default 512kbps/24fps/5s/480)
for f in [
    "src/app/player/WebCodecsPlayer.ts",
    "src/app/player/BroadwayPlayer.ts",
    "src/app/player/TinyH264Player.ts",
    "src/app/player/BasePlayer.ts",
]:
    patch(f, "bitrate: 524288,", "bitrate: 800000,")
    patch(f, "maxFps: 24,", "maxFps: 30,")
    patch(f, "iFrameInterval: 5,", "iFrameInterval: 2,")
    patch(f, "bounds: new Size(480, 480),", "bounds: new Size(720, 720),")

print("[patch] 2/5 TCP_NODELAY on every accepted socket (no Nagle batching)")
patch_re(
    "src/server/services/HttpServer.ts",
    r"^([ \t]*)server = http\.createServer\(options, currentApp\);\n",
    "\\1server = http.createServer(options, currentApp);\n"
    "\\1// SkyDroid: disable Nagle — input events go out immediately\n"
    "\\1server.on('connection', (socket) => {\n"
    "\\1  socket.setNoDelay(true);\n"
    "\\1});\n",
)

print("[patch] 3/5 WebSocket heartbeat (10s ping/pong, drop dead peers)")
patch_re(
    "src/server/services/WebSocketServer.ts",
    r"^([ \t]*)const wss = new WSServer\(\{ server \}\);\n",
    "\\1const wss = new WSServer({ server });\n"
    "\\1\n"
    "\\1// SkyDroid: heartbeat every 10s, terminate dead connections\n"
    "\\1const heartbeat = setInterval(() => {\n"
    "\\1  wss.clients.forEach((client) => {\n"
    "\\1    const sock = client as WS & { isAlive?: boolean };\n"
    "\\1    if (sock.isAlive === false) {\n"
    "\\1      sock.terminate();\n"
    "\\1      return;\n"
    "\\1    }\n"
    "\\1    sock.isAlive = false;\n"
    "\\1    sock.ping();\n"
    "\\1  });\n"
    "\\1}, 10000);\n"
    "\\1wss.on('close', () => clearInterval(heartbeat));\n",
)
patch_re(
    "src/server/services/WebSocketServer.ts",
    r"^([ \t]*)wss\.on\('connection', async \(ws: WS, request\) => \{\n",
    "\\1wss.on('connection', async (ws: WS, request) => {\n"
    "\\1  // SkyDroid: heartbeat bookkeeping\n"
    "\\1  const skydroidSock = ws as WS & { isAlive?: boolean };\n"
    "\\1  skydroidSock.isAlive = true;\n"
    "\\1  ws.on('pong', () => {\n"
    "\\1    skydroidSock.isAlive = true;\n"
    "\\1  });\n",
)

print("[patch] 4/5 stats reporter -> postMessage to /play/ wrapper (2s)")
patch_re(
    "src/app/player/BasePlayer.ts",
    r"^([ \t]*)private updateQualityStats = \(\): void => \{\n",
    "\\1private skydroidLastReport = 0;\n"
    "\\1\n"
    "\\1// SkyDroid: report fps/bitrate to the embedding /play/ page every 2s\n"
    "\\1protected skydroidReportStats(now: number): void {\n"
    "\\1  if (now - this.skydroidLastReport < 2000) {\n"
    "\\1    return;\n"
    "\\1  }\n"
    "\\1  this.skydroidLastReport = now;\n"
    "\\1  try {\n"
    "\\1    const vs = this.getVideoSettings();\n"
    "\\1    const cut = now - 1000;\n"
    "\\1    let n = 0;\n"
    "\\1    let bytes = 0;\n"
    "\\1    for (const s of this.inputBytes) {\n"
    "\\1      if (s.timestamp >= cut) {\n"
    "\\1        n++;\n"
    "\\1        bytes += s.bytes;\n"
    "\\1      }\n"
    "\\1    }\n"
    "\\1    window.parent.postMessage(\n"
    "\\1      { type: 'skydroid-stats', fps: n, bps: bytes * 8, bitrate: vs.bitrate, ts: now },\n"
    "\\1      '*',\n"
    "\\1    );\n"
    "\\1  } catch (e) {\n"
    "\\1    // ignore\n"
    "\\1  }\n"
    "\\1}\n"
    "\\1\n"
    "\\1private updateQualityStats = (): void => {\n",
)
patch_re(
    "src/app/player/BasePlayer.ts",
    r"^([ \t]*)this\.calculateMomentumStats\(\);\n",
    "\\1this.calculateMomentumStats();\n\\1this.skydroidReportStats(now);\n",
)

print("[patch] 5/5 adaptive-quality listener (parent -> client -> encoder)")
patch_re(
    "src/app/googDevice/client/StreamClientScrcpy.ts",
    r"^([ \t]*)super\(params\);\n",
    "\\1super(params);\n"
    "\\1// SkyDroid: adaptive quality commands from the /play/ wrapper.\n"
    "\\1// Restarts the scrcpy encoder session on-device (no container restart).\n"
    "\\1window.addEventListener('message', (event: MessageEvent) => {\n"
    "\\1  const data = event.data;\n"
    "\\1  if (!data || data.type !== 'skydroid-quality' || !this.player) {\n"
    "\\1    return;\n"
    "\\1  }\n"
    "\\1  const bitrate = typeof data.bitrate === 'number' ? data.bitrate : 0;\n"
    "\\1  const size = typeof data.size === 'number' ? data.size : 0;\n"
    "\\1  if (!bitrate || !size) {\n"
    "\\1    return;\n"
    "\\1  }\n"
    "\\1  const current = this.player.getVideoSettings();\n"
    "\\1  const next = new VideoSettings({\n"
    "\\1    bitrate: bitrate,\n"
    "\\1    bounds: new Size(size, size),\n"
    "\\1    maxFps: 30,\n"
    "\\1    iFrameInterval: 2,\n"
    "\\1    crop: current.crop,\n"
    "\\1    sendFrameMeta: current.sendFrameMeta,\n"
    "\\1    lockedVideoOrientation: current.lockedVideoOrientation,\n"
    "\\1    displayId: current.displayId,\n"
    "\\1    codecOptions: current.codecOptions,\n"
    "\\1    encoderName: current.encoderName,\n"
    "\\1  });\n"
    "\\1  this.player.setVideoSettings(next, false, false);\n"
    "\\1  this.sendNewVideoSetting(next);\n"
    "\\1});\n",
)

print(f"[patch] done: {PATCHES} patches applied")
