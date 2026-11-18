#!/usr/bin/env bash
# Start a virtual X desktop reachable from the browser through noVNC:
#
#   Xvfb (:1)  ->  openbox (window manager, right-click menu)  ->  x11vnc (:5900)  ->  noVNC (:6080)
#
# Open http://localhost:6080/vnc.html?autoconnect=1&resize=remote (port 6080 is forwarded by
# devcontainer.json) and right-click the desktop to launch the OpenROAD GUI.
#
# Safe to run more than once: components that are already running are left alone. Everything is
# started with `setsid -f` so it survives the devcontainer's postStartCommand exiting.

set -euo pipefail

WORKSPACE="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export DISPLAY=:1
RESOLUTION="${DESKTOP_RESOLUTION:-1920x1080x24}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
VNC_PORT=5900
LOG_DIR=/tmp/desktop-logs
mkdir -p "$LOG_DIR"

running() { pgrep -u "$(id -u)" -f "$1" >/dev/null; }

# right-click menu, pointing at this checkout
mkdir -p ~/.config/openbox
sed "s|@WORKSPACE@|$WORKSPACE|g" "$WORKSPACE/.devcontainer/desktop/menu.xml" > ~/.config/openbox/menu.xml

if ! running "Xvfb $DISPLAY"; then
  setsid -f Xvfb "$DISPLAY" -screen 0 "$RESOLUTION" -nolisten tcp > "$LOG_DIR/xvfb.log" 2>&1
  for _ in $(seq 50); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.1; done
fi

if ! running "^openbox"; then
  xsetroot -solid "#2b2b2b"
  setsid -f openbox > "$LOG_DIR/openbox.log" 2>&1
else
  openbox --reconfigure
fi

if ! running "x11vnc .*-rfbport $VNC_PORT"; then
  # only reachable from inside the container (noVNC below); no password needed
  setsid -f x11vnc -display "$DISPLAY" -rfbport "$VNC_PORT" -localhost -nopw -forever -shared -quiet \
    > "$LOG_DIR/x11vnc.log" 2>&1
fi

if ! running "websockify .*$NOVNC_PORT"; then
  setsid -f websockify --web /usr/share/novnc "localhost:$NOVNC_PORT" "localhost:$VNC_PORT" \
    > "$LOG_DIR/novnc.log" 2>&1
fi

echo "✅ noVNC desktop: http://localhost:$NOVNC_PORT/vnc.html?autoconnect=1&resize=remote"
echo "   (right-click the desktop for the OpenROAD GUI; logs in $LOG_DIR)"
