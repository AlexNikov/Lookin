#!/usr/bin/env bash
# Wire v2 ping: JSON decode on iOS (LookinPTData + WireRequestEnvelope) and LKJS response shape.
# Optional Peertalk E2E: Swift Lookin connects to LookinCustomInfoDemo; iOS must not log JSON decode failures.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_DIR="$ROOT/lookin-verify-logs"
export LOOKIN_VERIFY_LOG_DIR="$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
SELFTEST_LOG="$LOG_DIR/wire-v2-selftest-$STAMP.txt"
PEERTALK_LOG="$LOG_DIR/wire-v2-peertalk-$STAMP.txt"
RESULT_FILE="$LOG_DIR/wire-v2-ping-result-$STAMP.txt"
# shellcheck source=lookin_write_latest_summary.sh
source "$ROOT/Lookin/Scripts/lookin_write_latest_summary.sh"
# shellcheck source=lookin_dismiss_dialogs.sh
source "$ROOT/Lookin/Scripts/lookin_dismiss_dialogs.sh"
# shellcheck source=lookin_wire_version.sh
source "$ROOT/Lookin/Scripts/lookin_wire_version.sh"

_wire_ping_write_summary() {
  local files=()
  [[ -f "$RESULT_FILE" ]] && files+=("$RESULT_FILE")
  [[ -f "$SELFTEST_LOG" ]] && files+=("$SELFTEST_LOG")
  [[ -f "$PEERTALK_LOG" ]] && files+=("$PEERTALK_LOG")
  ((${#files[@]} > 0)) && lookin_write_latest_summary "verify_wire_v2_ping" "${files[@]}" || true
}
trap _wire_ping_write_summary EXIT

section() { echo "" >&2; echo "======== $1 ========" >&2; }
fail() { echo "RESULT: FAIL — $1" | tee -a "$RESULT_FILE"; echo "verify_wire_v2_ping: FAIL — $1" >&2; exit 1; }
pass() { echo "RESULT: PASS — $1" | tee -a "$RESULT_FILE"; echo "verify_wire_v2_ping: PASS — $1"; }

# Swift-only wire v2 — iOS demo always from LookinServer/ (not baseline).
DD_DEMO="$LOG_DIR/DerivedData-CustomInfoDemo-Swift"
DD_REFACTOR="$LOG_DIR/DerivedData-LookinRefactor"
DEMO_APP="$(find "$DD_DEMO" -name 'LookinCustomInfoDemo.app' -type d 2>/dev/null | head -1 || true)"
REFACTOR_APP="$DD_REFACTOR/Build/Products/Debug/Lookin.app"
SIM_NAME="${SIM_NAME:-iPhone 17 Pro}"
# CustomInfoDemo binds 127.0.0.1:47190 (IPv4). MCPSample uses [::1] — do not mix without terminating the other app.
IOS_MCP_URL="${IOS_MCP_URL:-http://127.0.0.1:47190}"
RUN_PEERTALK_E2E="${RUN_PEERTALK_E2E:-1}"

mcp_curl() {
  local path="$1"
  curl -sf --max-time 15 "${IOS_MCP_URL}${path}" 2>/dev/null \
    || curl -sf --max-time 15 "http://127.0.0.1:47190${path}" 2>/dev/null \
    || true
}

free_mcp_port_47190() {
  local pids
  pids="$(lsof -ti tcp:47190 2>/dev/null || true)"
  if [[ -n "$pids" ]]; then
    echo "  terminating stale listeners on :47190 ($pids)" >&2
    # shellcheck disable=SC2086
    kill -9 $pids 2>/dev/null || true
    sleep 1
  fi
}

section "1. Codable roundtrip (no device)"
if ! bash "$ROOT/LookinServer/Scripts/verify_wire_v2_roundtrip.sh" >>"$SELFTEST_LOG" 2>&1; then
  fail "verify_wire_v2_roundtrip.sh failed (see $SELFTEST_LOG)"
fi
echo "RESULT: PASS — inline Codable roundtrip" >>"$SELFTEST_LOG"

section "2. Build LookinCustomInfoDemo (iOS + MCP subspec)"
cd "$ROOT/LookinServer/LookinDemo/LookinCustomInfoDemo"
pod install --silent 2>/dev/null || pod install
if [[ ! -d "$DEMO_APP" ]]; then
  xcodebuild -workspace LookinCustomInfoDemo.xcworkspace -scheme LookinCustomInfoDemo \
    -configuration Debug \
    -destination "platform=iOS Simulator,name=${SIM_NAME}" \
    -derivedDataPath "$DD_DEMO" build -quiet
  DEMO_APP="$(find "$DD_DEMO" -name 'LookinCustomInfoDemo.app' -type d | head -1)"
else
  xcodebuild -workspace LookinCustomInfoDemo.xcworkspace -scheme LookinCustomInfoDemo \
    -configuration Debug \
    -destination "platform=iOS Simulator,name=${SIM_NAME}" \
    -derivedDataPath "$DD_DEMO" build -quiet
fi
DEMO_APP="$(find "$DD_DEMO" -name 'LookinCustomInfoDemo.app' -type d | head -1)"
[[ -d "$DEMO_APP" ]] || fail "Missing LookinCustomInfoDemo.app"

SIM_UDID="$(xcrun simctl list devices available -j | python3 -c "
import json,sys,os
name=os.environ.get('SIM_NAME','iPhone 17 Pro')
for d in json.load(sys.stdin).get('devices',{}).values():
  for dev in d:
    if dev.get('isAvailable') and name in dev.get('name','') and 'iPhone' in dev.get('name',''):
      print(dev['udid']); sys.exit(0)
sys.exit(1)
" 2>/dev/null || true)"
[[ -n "$SIM_UDID" ]] || fail "Simulator not found: $SIM_NAME"

xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID "$SIM_UDID" 2>/dev/null || true

section "3. Launch demo and GET /wire-v2-selftest"
free_mcp_port_47190
xcrun simctl terminate "$SIM_UDID" Lookin.LookinMCPSample 2>/dev/null || true
pkill -f LookinMCPSample 2>/dev/null || true
lookin_prepare_custom_info_demo "$SIM_UDID" "$DEMO_APP"
sleep 6

wait_ios_mcp() {
  local json i
  for ((i=1; i<=60; i++)); do
    json="$(mcp_curl "/status")"
    if [[ -n "$json" ]] && python3 -c "import json,sys; d=json.loads(sys.argv[1]); sys.exit(0 if d.get('success') else 1)" "$json" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

wait_ios_mcp || fail "iOS MCP not reachable at 127.0.0.1:47190/status (Podfile needs subspecs: ['Swift', 'MCP'])"

SELFTEST_JSON="$(mcp_curl "/wire-v2-selftest")"
[[ -n "$SELFTEST_JSON" ]] || SELFTEST_JSON='{}'
echo "$SELFTEST_JSON" >"$SELFTEST_LOG"

python3 - "$SELFTEST_JSON" "$SELFTEST_LOG" "$LOOKIN_WIRE_VERSION" <<'PY' || fail "wire-v2-selftest assertions failed"
import json, sys

raw = sys.argv[1]
_log = sys.argv[2] if len(sys.argv) > 2 else ""
expected_wire_version = int(sys.argv[3])
try:
    doc = json.loads(raw)
except json.JSONDecodeError as e:
    print(f"invalid JSON from MCP: {e}", file=sys.stderr)
    sys.exit(1)

data = doc.get("data") or doc
checks = [
    ("decodeOk", True),
    ("payloadBytesMatch", True),
    ("responseIsJSON", True),
    ("responseHasPingField", True),
    ("lkjsFrameTypeHex", "4C4B4A53"),
]
for key, want in checks:
    got = data.get(key)
    if got != want:
        print(f"FAIL {key}: expected {want!r}, got {got!r}", file=sys.stderr)
        sys.exit(1)

got_wire_version = int(data.get("wireVersionExpected", -1))
if got_wire_version != expected_wire_version:
    print(f"FAIL wireVersionExpected: expected {expected_wire_version}, got {got_wire_version}", file=sys.stderr)
    sys.exit(1)

if int(data.get("lkjsFrameType", 0)) != 0x4C4B4A53:
    print("FAIL lkjsFrameType:", data.get("lkjsFrameType"), file=sys.stderr)
    sys.exit(1)

print("RESULT: PASS — iOS wire-v2-selftest (decode + LKJS envelope)")
PY

echo "RESULT: PASS — iOS /wire-v2-selftest" >>"$RESULT_FILE"

if [[ "$RUN_PEERTALK_E2E" == "0" ]]; then
  pass "wire v2 selftest only (RUN_PEERTALK_E2E=0)"
  exit 0
fi

section "4. Peertalk E2E (Swift Lookin → demo, no JSON decode errors)"
if [[ ! -d "$REFACTOR_APP" ]]; then
  cd "$ROOT/Lookin"
  pod install --silent 2>/dev/null || pod install
  xcodebuild -workspace Lookin.xcworkspace -scheme LookinClient -configuration Debug \
    -derivedDataPath "$DD_REFACTOR" build -quiet
fi
[[ -d "$REFACTOR_APP" ]] || fail "Missing Swift Lookin.app"

LOG_PID=""
if xcrun simctl spawn "$SIM_UDID" log stream --style compact \
  --predicate 'processImagePath CONTAINS "LookinCustomInfoDemo" AND eventMessage CONTAINS "LookinServer"' \
  >"$PEERTALK_LOG" 2>/dev/null &
then
  LOG_PID=$!
  sleep 1
fi

pkill -x Lookin 2>/dev/null || true
sleep 1
open "$REFACTOR_APP"
sleep 3

osascript <<'APPLESCRIPT' 2>/dev/null || true
tell application "Lookin" to activate
delay 1
tell application "System Events"
  if not (exists process "Lookin") then return
  tell process "Lookin"
    set frontmost to true
    try
      click static text "LookinCustomInfoDemo" of window 1
    on error
      try
        click UI element "LookinCustomInfoDemo" of window 1
      end try
    end try
  end tell
end tell
APPLESCRIPT

sleep 12

if [[ -n "$LOG_PID" ]]; then
  kill "$LOG_PID" 2>/dev/null || true
  wait "$LOG_PID" 2>/dev/null || true
fi

xcrun simctl spawn "$SIM_UDID" log show --last 45s 2>/dev/null \
  | rg 'LookinServer' >>"$PEERTALK_LOG" 2>/dev/null || true

if rg -q 'wire request JSON decode failed' "$PEERTALK_LOG" 2>/dev/null; then
  rg 'wire request JSON decode failed' "$PEERTALK_LOG" | head -5 >&2
  fail "iOS logged wire request JSON decode failed during Peertalk connect"
fi

if rg -q 'wire v2 expected JSON request' "$PEERTALK_LOG" 2>/dev/null; then
  rg 'wire v2 expected JSON request' "$PEERTALK_LOG" | head -5 >&2
  fail "server expected JSON after negotiate but got legacy frame"
fi

echo "RESULT: PASS — Peertalk connect without JSON decode errors" >>"$RESULT_FILE"
pass "wire v2 ping selftest + Peertalk (no iOS JSON decode failures)"
