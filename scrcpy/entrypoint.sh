#!/usr/bin/env bash
# SkyDroid scrcpy container entrypoint.
# - keeps adb connected to the redroid container
# - applies one-time Android speed tweaks after boot
# - starts the patched ws-scrcpy server (:8000) and the tiny api (:8001)
# - supervises the on-device scrcpy-server session (restart; give up after
#   3 consecutive failures so Docker restarts the whole container)
set -u

ADB_SERIAL="${ADB_SERIAL:-android:5555}"
WS_DIR="/opt/ws-scrcpy"
API_JS="/opt/api.js"
JAR="$WS_DIR/vendor/Genymobile/scrcpy/scrcpy-server.jar"
DEVICE_JAR="/data/local/tmp/scrcpy-server.jar"
# Keep in sync with ws-scrcpy src/common/Constants.ts
SERVER_ARGS="1.19-ws8 web ERROR 8886 false"
SERVER_PKG="com.genymobile.scrcpy.Server"
RESTART_FLAG="/tmp/skydroid-restart-scrcpy"
FAIL_COUNT=0

log() { echo "[entrypoint] $*"; }

adb start-server >/dev/null 2>&1 || true

# --- background: (re)connect adb every 5s ---
(
  while true; do
    adb connect "$ADB_SERIAL" >/dev/null 2>&1 || true
    sleep 5
  done
) &

# --- wait for Android boot ---
log "waiting for android ($ADB_SERIAL)..."
for i in $(seq 1 72); do
  BOOT="$(adb -s "$ADB_SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  if [ "$BOOT" = "1" ]; then
    log "android booted"
    break
  fi
  sleep 5
  if [ "$i" -eq 72 ]; then
    log "WARNING: boot wait timed out, continuing anyway"
  fi
done

# --- one-time Android speed tweaks ---
log "applying android speed tweaks..."
adb -s "$ADB_SERIAL" shell settings put global window_animation_scale 0 >/dev/null 2>&1 || true
adb -s "$ADB_SERIAL" shell settings put global transition_animation_scale 0 >/dev/null 2>&1 || true
adb -s "$ADB_SERIAL" shell settings put global animator_duration_scale 0 >/dev/null 2>&1 || true
adb -s "$ADB_SERIAL" shell settings put system screen_off_timeout 2147483647 >/dev/null 2>&1 || true
# Conservative bloat disable — safe, non-critical packages only.
# Never touches Play Services / System UI / launcher.
for pkg in com.android.stk com.android.printspooler com.android.dreams.basic \
           com.android.wallpaper.livepicker com.android.traceur; do
  adb -s "$ADB_SERIAL" shell pm disable-user --user 0 "$pkg" >/dev/null 2>&1 || true
done
log "tweaks applied"

# --- node services ---
log "starting ws-scrcpy server on :8000 ..."
WS_SCRCPY_PATHNAME=/s node "$WS_DIR/index.js" >>/var/log/ws-scrcpy.log 2>&1 &
log "starting device api on :8001 ..."
node "$API_JS" >>/var/log/api.log 2>&1 &

# --- scrcpy-server (on-device) supervisor ---
scrcpy_running() {
  adb -s "$ADB_SERIAL" shell \
    'for p in $(pidof app_process 2>/dev/null); do tr "\0" " " < /proc/$p/cmdline 2>/dev/null; echo; done' \
    2>/dev/null | grep -q "$SERVER_PKG"
}

start_scrcpy() {
  if ! adb -s "$ADB_SERIAL" shell "test -f $DEVICE_JAR" >/dev/null 2>&1; then
    log "pushing scrcpy-server.jar ..."
    adb -s "$ADB_SERIAL" push "$JAR" "$DEVICE_JAR" >/dev/null 2>&1 || true
  fi
  log "starting scrcpy-server on device ..."
  adb -s "$ADB_SERIAL" shell \
    "nohup sh -c 'CLASSPATH=$DEVICE_JAR app_process / $SERVER_PKG $SERVER_ARGS' >/dev/null 2>&1 &" \
    >/dev/null 2>&1 || true
  sleep 3
}

stop_scrcpy() {
  adb -s "$ADB_SERIAL" shell \
    'for p in $(pidof app_process 2>/dev/null); do if tr "\0" " " < /proc/$p/cmdline 2>/dev/null | grep -q "com.genymobile.scrcpy"; then kill $p; fi; done' \
    >/dev/null 2>&1 || true
}

start_scrcpy

while true; do
  sleep 15

  if [ -f "$RESTART_FLAG" ]; then
    log "restart requested via api"
    rm -f "$RESTART_FLAG"
    stop_scrcpy
    sleep 1
    start_scrcpy
    continue
  fi

  if scrcpy_running; then
    FAIL_COUNT=0
    continue
  fi

  log "scrcpy-server not running — restarting session"
  start_scrcpy
  if scrcpy_running; then
    FAIL_COUNT=0
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    log "restart failed ($FAIL_COUNT/3)"
    if [ "$FAIL_COUNT" -ge 3 ]; then
      log "3 consecutive failures — exiting so Docker restarts the container"
      exit 1
    fi
  fi
done
