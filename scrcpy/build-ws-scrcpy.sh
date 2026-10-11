#!/usr/bin/env bash
# Build ws-scrcpy at a pinned commit, apply SkyDroid patches, produce /opt/ws-scrcpy.
set -euo pipefail

# Pinned commit of NetrisTV/ws-scrcpy (master as verified 2026-10-11).
# All patches in patch-ws-scrcpy.py are written against this exact tree.
WS_COMMIT="cd6cea6ebde17af6685c2b325183fc24bef9d52b"
SRC="/opt/ws-src"
OUT="/opt/ws-scrcpy"

echo "[build] cloning ws-scrcpy..."
rm -rf "$SRC"
git clone --quiet https://github.com/NetrisTV/ws-scrcpy.git "$SRC"
cd "$SRC"
git checkout --quiet "$WS_COMMIT"

echo "[build] removing appium postinstall (iOS not built)..."
npm pkg delete scripts.postinstall >/dev/null

echo "[build] applying SkyDroid patches..."
python3 /opt/patch-ws-scrcpy.py

echo "[build] npm install (this takes a few minutes)..."
npm install --omit=optional --no-audit --no-fund

echo "[build] npm run dist..."
npm run dist

echo "[build] collecting dist -> $OUT ..."
rm -rf "$OUT"
cp -r "$SRC/dist" "$OUT"

# sanity: server entry + device-side scrcpy jar must exist
test -f "$OUT/index.js" || { echo "[build] FAIL: dist/index.js missing"; exit 1; }
test -f "$OUT/vendor/Genymobile/scrcpy/scrcpy-server.jar" \
  || { echo "[build] FAIL: scrcpy-server.jar missing"; exit 1; }

echo "[build] OK"
