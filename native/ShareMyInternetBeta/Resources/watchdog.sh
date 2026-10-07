#!/bin/bash
# Share My Internet — background keep-alive.
# Started (nohup, detached) by core.sh's watchdog-start and stopped by
# watchdog-stop. Keeps the Mac awake and quietly reconnects Tailscale /
# re-enables exit-node sharing if it ever drops, until this process is killed.

APP="/Applications/Tailscale.app"
TS="$APP/Contents/MacOS/Tailscale"

# caffeinate exits on its own once this script's process ($$) exits —
# no separate PID bookkeeping needed for it.
caffeinate -dims -w $$ &

while true; do
  sleep 30
  S="$("$TS" status --json 2>/dev/null | sed -n 's/.*"BackendState": *"\([A-Za-z]*\)".*/\1/p' | head -1)"
  if [ "$S" != "Running" ]; then
    "$TS" up >/dev/null 2>&1
    "$TS" set --exit-node= --advertise-exit-node >/dev/null 2>&1
  fi
done
