#!/usr/bin/env bash
# Export the HTML5 build and serve it on your LAN so a tablet/phone on the same Wi-Fi can open it.
# usage: aurelia/tools/serve_web.sh [port]     (needs Godot 4.4 + its Web export templates installed)
set -e
cd "$(dirname "$0")/.."
PORT=${1:-8060}
mkdir -p build/web
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --export-release Web build/web/index.html
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo
echo "Open on the tablet:  http://${IP:-<this-computer-ip>}:${PORT}/"
python3 -m http.server "$PORT" --bind 0.0.0.0 --directory build/web
