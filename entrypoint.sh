#!/bin/bash
set -e
export HOME=/home/ubuntu USER=ubuntu
PORT="${PORT:-6080}"

if [ -z "$VNC_PASSWORD" ]; then
  VNC_PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 10)"
  echo "======================================================"
  echo " No VNC_PASSWORD set. Generated password: $VNC_PASSWORD"
  echo "======================================================"
fi

mkdir -p "$HOME/.vnc"
echo "$VNC_PASSWORD" | vncpasswd -f > "$HOME/.vnc/passwd"
chmod 600 "$HOME/.vnc/passwd"

cat > "$HOME/.vnc/xstartup" <<'XS'
#!/bin/sh
unset SESSION_MANAGER DBUS_SESSION_BUS_ADDRESS
xsetroot -solid "#1f2937"
exec dbus-launch --exit-with-session startxfce4
XS
chmod +x "$HOME/.vnc/xstartup"

rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true
vncserver :1 -geometry "$RESOLUTION" -depth "$DEPTH" -localhost yes \
  -rfbauth "$HOME/.vnc/passwd" -xstartup "$HOME/.vnc/xstartup" \
  -AlwaysShared -FrameRate=15 -fg &
VNC_PID=$!

websockify --web /usr/share/novnc "0.0.0.0:${PORT}" localhost:5901 &
WS_PID=$!

trap 'kill -TERM $VNC_PID $WS_PID 2>/dev/null; exit 0' TERM INT
echo "SkyDesk is running on port $PORT"

# If either process dies, exit so the platform restarts the container cleanly
wait -n $VNC_PID $WS_PID
echo "A core process stopped, restarting container..."
exit 1
