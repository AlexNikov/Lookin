#!/usr/bin/env bash
# Verify repeated connect: demo stays running; only Lookin.app restarts between rounds.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SIM_UDID="${SIM_UDID:-$(xcrun simctl list devices booted -j | python3 -c "
import json,sys
for d in json.load(sys.stdin).get('devices',{}).values():
  for x in d:
    if x.get('state')=='Booted':
      print(x['udid']); sys.exit(0)
sys.exit(1)
")}"
DEMO_APP="${DEMO_APP:-$ROOT/lookin-verify-logs/DerivedData-CustomInfoDemo-Swift/Build/Products/Debug-iphonesimulator/LookinCustomInfoDemo.app}"
LOOKIN_APP="${LOOKIN_APP:-$ROOT/lookin-verify-logs/DerivedData-LookinRefactor/Build/Products/Debug/Lookin.app}"
BUNDLE="${DEMO_BUNDLE:-Lookin.LookinCustomInfoDemoSwift}"
PORT=47192
ROUNDS="${RECONNECT_ROUNDS:-2}"
RESULT="$ROOT/lookin-verify-logs/client-reconnect-$(date +%Y%m%d-%H%M%S).txt"

fail() { echo "RESULT: FAIL — $1" | tee -a "$RESULT"; exit 1; }
pass() { echo "RESULT: PASS — $1" | tee -a "$RESULT"; }

[[ -d "$DEMO_APP" ]] || fail "Missing demo app: $DEMO_APP"
[[ -d "$LOOKIN_APP" ]] || fail "Missing Lookin.app: $LOOKIN_APP"

xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
# shellcheck source=lookin_dismiss_dialogs.sh
source "$ROOT/Lookin/Scripts/lookin_dismiss_dialogs.sh"
HIER_PY="$ROOT/Lookin/Scripts/mcp_ui_helpers.py"
lookin_prepare_custom_info_demo "$SIM_UDID" "$DEMO_APP" "$BUNDLE"
osascript -e 'tell application "Simulator" to activate' 2>/dev/null || true
sleep 4

wait_peertalk_listen() {
  local i
  for ((i=1; i<=60; i++)); do
    if /usr/sbin/lsof -nP -iTCP:47164-47169 -sTCP:LISTEN 2>/dev/null | grep -qE '127\.0\.0\.1:4716[0-9]'; then
      return 0
    fi
    if /usr/sbin/lsof -nP -iTCP:47164-47169 2>/dev/null | grep -qE 'LookinCus.*4716[0-9].*ESTABLISHED'; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}
wait_peertalk_listen || fail "Demo Peertalk not listening (47164-47169)"

restart_lookin_client() {
  if curl -sf --max-time 5 -X POST "http://127.0.0.1:${PORT}/action/end-inspect-session" \
    -H 'Content-Type: application/json' -d '{}' >/dev/null 2>&1; then
    sleep 2
  fi
  killall Lookin 2>/dev/null || true
  sleep 2
  osascript -e 'tell application "Simulator" to activate' 2>/dev/null || true
  sleep 2
  curl -sf --max-time 5 -X POST "http://127.0.0.1:47190/relisten-peertalk" >/dev/null 2>&1 || true
  sleep 1
  lookin_prepare_clean_launch
  open -a "$LOOKIN_APP" --args -ApplePersistenceIgnoreState YES
  local i
  for ((i=1; i<=30; i++)); do
    if curl -sf --max-time 2 "http://127.0.0.1:${PORT}/status" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

mcp_status_client() {
  curl -sf --max-time 10 "http://127.0.0.1:${PORT}/status" | python3 -c "
import json,sys
c=json.load(sys.stdin).get('data',{}).get('client',{})
print(c.get('hasInspectingApp', False))
print(c.get('channelIsConnected', False))
print(c.get('inspectingBundleId',''))
print(c.get('channelCount', c.get('lastConnect',{}).get('channelCount',0)))
"
}

echo "======== client reconnect (demo once, restart Lookin) ========" | tee "$RESULT"

restart_lookin_client || fail "Lookin MCP :$PORT not up (initial)"
osascript -e 'tell application "Simulator" to activate' 2>/dev/null || true
wait_peertalk_listen || fail "demo not listening before round 1"

for round in $(seq 1 "$ROUNDS"); do
  echo "--- round $round (demo not restarted) ---" | tee -a "$RESULT"
  osascript -e 'tell application "Simulator" to activate' 2>/dev/null || true
  wait_peertalk_listen || fail "round $round: demo not listening"
  lookin_enter_mac_inspector "$PORT" "$HIER_PY"
  for ((i=1; i<=60; i++)); do
    _st="$(mcp_status_client)"
    ST_INSPECTING="$(echo "$_st" | awk 'NR==1')"
    [[ "$ST_INSPECTING" == "True" ]] && break
    if [[ "$i" == 10 || "$i" == 25 ]]; then
      lookin_enter_mac_inspector "$PORT" "$HIER_PY"
    fi
    sleep 1
  done
  _st="$(mcp_status_client)"
  ST_INSPECTING="$(echo "$_st" | awk 'NR==1')"
  ST_CHANNEL="$(echo "$_st" | awk 'NR==2')"
  ST_BUNDLE="$(echo "$_st" | awk 'NR==3')"
  ST_COUNT="$(echo "$_st" | awk 'NR==4')"
  echo "status: inspecting=$ST_INSPECTING channel=$ST_CHANNEL bundle=$ST_BUNDLE count=$ST_COUNT" | tee -a "$RESULT"
  [[ "$ST_INSPECTING" == "True" ]] || fail "round $round: hasInspectingApp=false"
  [[ "$ST_CHANNEL" == "True" ]] || fail "round $round: channelIsConnected=false"
  [[ "$ST_BUNDLE" == "$BUNDLE" ]] || fail "round $round: bundle=$ST_BUNDLE expected $BUNDLE"
  if [[ "$round" -lt "$ROUNDS" ]]; then
    restart_lookin_client || fail "round $round: Lookin MCP down after client restart"
    osascript -e 'tell application "Simulator" to activate' 2>/dev/null || true
    wait_peertalk_listen || fail "round $round: demo not listening after Lookin quit (iOS must re-listen)"
    sleep 2
  fi
done

DIAG="$(curl -sf --max-time 10 "http://127.0.0.1:${PORT}/ui/diag-log?tail=12")"
echo "diag tail: $DIAG" | tee -a "$RESULT"
pass "${ROUNDS}x connect after Lookin client restart only (demo kept running)"
