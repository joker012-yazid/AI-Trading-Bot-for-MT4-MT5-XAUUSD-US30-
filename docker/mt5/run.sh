#!/usr/bin/env bash
set -euo pipefail

export DISPLAY=:0
export WINEPREFIX=/opt/wine64
export WINEARCH=win64
MT5_DIR="/opt/mt5"
MT5_TERMINAL="$MT5_DIR/terminal64.exe"

mkdir -p "$WINEPREFIX" "$MT5_DIR" /srv/botdata/logs

if [ ! -f "$MT5_TERMINAL" ]; then
  echo "[run-mt5] Installing MetaTrader 5 terminal..."
  wineboot --init || true
  winetricks -q corefonts || true
  wine /tmp/mt5setup.exe /auto /silent /dir="C:\\mt5" || true
  if [ -d "$WINEPREFIX/drive_c/Program Files/MetaTrader 5" ]; then
    cp -r "$WINEPREFIX/drive_c/Program Files/MetaTrader 5"/* "$MT5_DIR"/
  fi
fi

Xvfb :0 -screen 0 1280x720x24 &
XVFB_PID=$!

fluxbox &

x11vnc -display :0 -forever -shared -rfbport 5900 -passwd "" &
X11VNC_PID=$!

/usr/share/novnc/utils/launch.sh --vnc localhost:5900 --listen 6080 &
NOVNC_PID=$!

trap "kill $NOVNC_PID $X11VNC_PID $XVFB_PID" EXIT

if [ -f "$MT5_TERMINAL" ]; then
  echo "[run-mt5] Launching terminal64.exe"
  wine "$MT5_TERMINAL" &
else
  echo "[run-mt5] WARNING: terminal64.exe not found. Keeping services alive for manual installation." >&2
fi

wait
