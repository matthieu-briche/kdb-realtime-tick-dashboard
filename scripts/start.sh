#!/usr/bin/env bash
# Start the full stack: tickerplant, HDB, RDB, real-time engine, gateway, feed.
# Override any setting with environment variables, e.g.  GW_PORT=8080 ./scripts/start.sh
set -euo pipefail
cd "$(dirname "$0")/.."

Q="${Q:-q}"
TP_PORT="${TP_PORT:-5010}"
RDB_PORT="${RDB_PORT:-5011}"
HDB_PORT="${HDB_PORT:-5012}"
RTE_PORT="${RTE_PORT:-5013}"
GW_PORT="${GW_PORT:-5020}"
FEED_RATE="${FEED_RATE:-100}"     # ms between feed batches
HDB_DIR="${HDB_DIR:-db}"

command -v "$Q" >/dev/null 2>&1 || { echo "error: '$Q' not found. Install kdb+/KDB-X and put q on your PATH (or set Q=/path/to/q)."; exit 1; }
mkdir -p logs "$HDB_DIR" tplogs

start() {
  local name=$1; shift
  if [[ -f "logs/$name.pid" ]] && kill -0 "$(cat "logs/$name.pid")" 2>/dev/null; then
    echo "  $name already running (pid $(cat "logs/$name.pid"))"; return
  fi
  nohup "$Q" "$@" < /dev/null > "logs/$name.log" 2>&1 &
  echo $! > "logs/$name.pid"
  printf "  %-5s pid %-7s %s\n" "$name" "$!" "logs/$name.log"
}

echo "Starting kdb-realtime-tick-dashboard"
start tp   src/tp.q  -p "$TP_PORT" -schema schema/sym.q -logdir tplogs
sleep 1
start hdb  src/hdb.q -p "$HDB_PORT" -hdbdir "$HDB_DIR"
start rdb  src/rdb.q -p "$RDB_PORT" -tp "$TP_PORT" -hdb "$HDB_PORT" -hdbdir "$HDB_DIR"
start rte  src/rte.q -p "$RTE_PORT" -tp "$TP_PORT"
sleep 1
start gw   src/gw.q  -p "$GW_PORT" -rdb "$RDB_PORT" -rte "$RTE_PORT" -hdb "$HDB_PORT" -web web
start feed src/feed.q -tp "$TP_PORT" -rate "$FEED_RATE"

echo
echo "Dashboard:  http://localhost:$GW_PORT/index.html"
echo "Logs:       tail -f logs/*.log"
echo "Stop:       ./scripts/stop.sh"
