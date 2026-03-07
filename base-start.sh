#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-8080}"
VNC_PASSWORD="${VNC_PASSWORD:-123456}"
RESOLUTION="${RESOLUTION:-1280x720}"
DISPLAY="${DISPLAY:-:0}"

export HOME=/home/vncuser
export USER=vncuser
export TMPDIR=/home/vncuser/tmp
export DBUS_SESSION_BUS_ADDRESS=unix:path=/var/run/dbus/system_bus_socket

mkdir -p /home/vncuser/.vnc
mkdir -p /home/vncuser/.fluxbox
mkdir -p /home/vncuser/tmp
mkdir -p /tmp/.X11-unix
mkdir -p /home/vncuser/.mozilla/firefox/default
mkdir -p /var/run/dbus

chmod 700 /home/vncuser/.vnc
chmod 1777 /tmp/.X11-unix
chmod 700 /home/vncuser/tmp
chmod 755 /var/run/dbus
chown -R vncuser:vncuser /home/vncuser

echo "$VNC_PASSWORD" | x11vnc -storepasswd - > /home/vncuser/.vnc/passwd
chmod 600 /home/vncuser/.vnc/passwd

rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 /home/vncuser/.Xauthority || true

IFS='x' read -ra RES <<< "$RESOLUTION"
VNC_WIDTH="${RES[0]:-1280}"
VNC_HEIGHT="${RES[1]:-720}"
VNC_DEPTH="24"

cat > /home/vncuser/.mozilla/firefox/profiles.ini <<'EOF'
[General]
StartWithLastProfile=1

[Profile0]
Name=default
IsRelative=1
Path=default
Default=1
EOF

cat > /home/vncuser/.fluxbox/init <<'EOF'
session.screen0.workspaces: 1
session.screen0.workspacewarping: false
session.screen0.toolbar.visible: false
session.screen0.fullMaximization: true
session.screen0.maxDisableMove: false
session.screen0.maxDisableResize: false
session.screen0.defaultDeco: NONE
EOF

cat > /home/vncuser/.fluxbox/startup <<EOF
#!/usr/bin/env bash
sleep 2
firefox --width=${VNC_WIDTH} --height=${VNC_HEIGHT} https://nav.eooce.com &
EOF

chmod +x /home/vncuser/.fluxbox/startup
chown -R vncuser:vncuser /home/vncuser/.fluxbox /home/vncuser/.mozilla

Xvfb "$DISPLAY" -screen 0 "${VNC_WIDTH}x${VNC_HEIGHT}x${VNC_DEPTH}" -ac +extension RANDR -nolisten tcp -noreset &
XVFB_PID=$!
sleep 3

if ! kill -0 "$XVFB_PID" 2>/dev/null; then
    echo "[error] Xvfb failed to start"
    exit 1
fi

fluxbox -display "$DISPLAY" &
FLUXBOX_PID=$!
sleep 2

x11vnc -display "$DISPLAY" -forever -shared -passwd "$VNC_PASSWORD" -rfbport 5900 -localhost -noxdamage -xrandr &
X11VNC_PID=$!
sleep 2

websockify --web /usr/share/novnc "$PORT" localhost:5900 &
NOVNC_PID=$!
sleep 2

while true; do
    if ! kill -0 "$XVFB_PID" 2>/dev/null; then
        echo "[error] Xvfb stopped"
        exit 1
    fi
    if ! kill -0 "$X11VNC_PID" 2>/dev/null; then
        echo "[error] x11vnc stopped"
        exit 1
    fi
    if ! pgrep -f firefox >/dev/null; then
        firefox --display="$DISPLAY" --width="${VNC_WIDTH}" --height="${VNC_HEIGHT}" >/dev/null 2>&1 &
    fi
    sleep 120
done
