#!/usr/bin/env bash
# Stop every process started by start.sh (feed first, tickerplant last).
set -uo pipefail
cd "$(dirname "$0")/.."

for name in feed gw rte rdb hdb tp; do
  pidfile="logs/$name.pid"
  [[ -f "$pidfile" ]] || continue
  pid=$(cat "$pidfile")
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" && echo "  stopped $name (pid $pid)"
  fi
  rm -f "$pidfile"
done
