#!/usr/bin/env bash
# Two headless processes on localhost: the client's scripted bot must kill an enemy and both
# peers must see 2 players. Usage: tests/net_smoke.sh   (needs `godot` on PATH, project imported)
set -u
cd "$(dirname "$0")/.."
LOG=$(mktemp -d)
godot --headless --path . -- --host --autotest > "$LOG/host.log" 2>&1 &
HOST=$!
sleep 4
godot --headless --path . -- --join=127.0.0.1 --autotest > "$LOG/client.log" 2>&1 &
CLIENT=$!
wait $CLIENT; C=$?
wait $HOST; H=$?
grep -h "TEST_\|autotest" "$LOG/host.log" "$LOG/client.log"
if [ $C -eq 0 ] && [ $H -eq 0 ]; then echo "NET_SMOKE_OK"; exit 0; fi
echo "NET_SMOKE_FAIL (host=$H client=$C) logs in $LOG"; tail -20 "$LOG/host.log" "$LOG/client.log"; exit 1
