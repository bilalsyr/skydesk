#!/usr/bin/env bash
# SkyDroid APK/XAPK installer.
# Runs INSIDE the scrcpy container (adb is local there).
# Usage: install-apk.sh <file.apk | file.xapk | http(s)://...apk|xapk>
set -u

ADB_SERIAL="${ADB_SERIAL:-android:5555}"
SRC="${1:?usage: install-apk.sh <file.apk|file.xapk|url>}"
WORK="/tmp/apkinstall"
mkdir -p "$WORK"

if [[ "$SRC" =~ ^https?:// ]]; then
  echo "downloading: $SRC"
  EXT="apk"
  [[ "$SRC" =~ \.[Xx][Aa][Pp][Kk](\?|$) ]] && EXT="xapk"
  DST="$WORK/dl.$EXT"
  curl -fSL --retry 3 -o "$DST" "$SRC" || { echo "FAIL: download failed"; exit 1; }
  SRC="$DST"
fi

if [ ! -f "$SRC" ]; then
  echo "FAIL: file not found: $SRC"
  exit 1
fi

case "$SRC" in
  *.[Aa][Pp][Kk])
    echo "installing apk: $SRC"
    if adb -s "$ADB_SERIAL" install -r "$SRC"; then
      echo "OK: apk installed"
    else
      echo "FAIL: adb install failed"
      exit 1
    fi
    ;;
  *.[Xx][Aa][Pp][Kk])
    TMPD="$(mktemp -d)"
    echo "unpacking xapk ..."
    unzip -q -o "$SRC" -d "$TMPD" || { echo "FAIL: unzip failed"; rm -rf "$TMPD"; exit 1; }
    mapfile -t APKS < <(find "$TMPD" -iname '*.apk' | sort)
    if [ "${#APKS[@]}" -eq 0 ]; then
      echo "FAIL: no .apk files inside xapk"
      rm -rf "$TMPD"
      exit 1
    fi
    echo "installing ${#APKS[@]} apk(s) ..."
    if ! adb -s "$ADB_SERIAL" install-multiple -r "${APKS[@]}"; then
      echo "FAIL: install-multiple failed"
      rm -rf "$TMPD"
      exit 1
    fi
    # OBB payloads: <tmp>/obb/<package>/... or <tmp>/Android/obb/<package>/...
    for OBROOT in "$TMPD/obb" "$TMPD/Obb" "$TMPD/OBB" "$TMPD/Android/obb"; do
      [ -d "$OBROOT" ] || continue
      for d in "$OBROOT"/*; do
        [ -d "$d" ] || continue
        PKG="$(basename "$d")"
        echo "pushing obb for $PKG ..."
        adb -s "$ADB_SERIAL" push "$d" "/sdcard/Android/obb/$PKG" \
          || echo "WARN: obb push failed for $PKG"
      done
    done
    rm -rf "$TMPD"
    echo "OK: xapk installed"
    ;;
  *)
    echo "FAIL: unsupported file type: $SRC (need .apk or .xapk)"
    exit 1
    ;;
esac
