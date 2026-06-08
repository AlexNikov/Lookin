#!/usr/bin/env bash
# Compare iOS 3D preview (SceneKit) via GET /ui/preview/state and /ui/preview/screenshot.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_DIR="$ROOT/lookin-verify-logs"
export LOOKIN_VERIFY_LOG_DIR="$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
OBJC_DIR="$LOG_DIR/objc-preview"
SWIFT_DIR="$LOG_DIR/swift-preview"
mkdir -p "$OBJC_DIR" "$SWIFT_DIR"
# shellcheck source=lookin_write_latest_summary.sh
source "$ROOT/Lookin/Scripts/lookin_write_latest_summary.sh"
RESULT_FILE=""
SHOTS_DIFF_FILE=""

DD_SWIFT="$LOG_DIR/DerivedData-LookinRefactor"
DD_OBJC="$LOG_DIR/DerivedData-LookinBaseline"
SWIFT_APP="$DD_SWIFT/Build/Products/Debug/Lookin.app"
OBJC_APP="$DD_OBJC/Build/Products/Debug/Lookin.app"
COMPARE_PY="$ROOT/Lookin/Scripts/compare_ui_preview.py"
PREVIEW_GOLDEN="$ROOT/Lookin/Scripts/fixtures/ui-preview-state-golden.norm"
HIER_PY="$ROOT/Lookin/Scripts/mcp_ui_helpers.py"
# shellcheck source=lookin_dismiss_dialogs.sh
source "$ROOT/Lookin/Scripts/lookin_dismiss_dialogs.sh"
# shellcheck source=lookin_verify_ios_demo.sh
source "$ROOT/Lookin/Scripts/lookin_verify_ios_demo.sh"

SKIP_OBJC_BASELINE="${SKIP_OBJC_BASELINE:-1}"
PREVIEW_WAIT_SEC="${PREVIEW_WAIT_SEC:-90}"

section() { echo ""; echo "======== $1 ========"; }

_preview_write_summary() {
  local files=()
  [[ -n "$RESULT_FILE" && -f "$RESULT_FILE" ]] && files+=("$RESULT_FILE")
  [[ -n "$SHOTS_DIFF_FILE" && -f "$SHOTS_DIFF_FILE" ]] && files+=("$SHOTS_DIFF_FILE")
  if [[ ${#files[@]} -gt 0 ]]; then
    lookin_write_latest_summary "verify_ui_preview_mcp" "${files[@]}" || true
  else
    lookin_write_latest_summary "verify_ui_preview_mcp" || true
  fi
}
trap _preview_write_summary EXIT

fail() { echo "verify_ui_preview_mcp: FAIL — $1" >&2; exit 1; }
pass() { echo "verify_ui_preview_mcp: PASS — $1"; }

wait_mcp_port() {
  local port="$1"
  local i
  for ((i=1; i<=60; i++)); do
    dismiss_lookin_system_dialogs
    if curl -sf --max-time 2 "http://127.0.0.1:${port}/status" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

SIM_NAME="${SIM_NAME:-iPhone 17 Pro}"

if [[ "${RUN_LEGACY_GATES:-1}" == "1" ]]; then
  bash "$ROOT/Lookin/Scripts/run_legacy_gates.sh"
fi

section "0. Preconditions"
if [[ ! -d "$SWIFT_APP" ]]; then
  cd "$ROOT/Lookin"
  pod install --silent 2>/dev/null || pod install
  xcodebuild -workspace Lookin.xcworkspace -scheme LookinClient -configuration Debug \
    -derivedDataPath "$DD_SWIFT" build -quiet
fi
[[ -d "$SWIFT_APP" ]] || fail "Missing Swift Lookin.app"
if [[ "$SKIP_OBJC_BASELINE" != "1" ]]; then
  if [[ ! -d "$OBJC_APP" ]]; then
    cd "$ROOT/Lookin-baseline+mcp"
    pod install --silent 2>/dev/null || pod install
    xcodebuild -workspace Lookin.xcworkspace -scheme LookinClient -configuration Debug \
      -derivedDataPath "$DD_OBJC" build -quiet
  fi
  [[ -d "$OBJC_APP" ]] || fail "Missing ObjC Lookin.app"
fi

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

mcp_open_inspector() {
  curl -sf --max-time 30 -X POST "http://127.0.0.1:$1/ui/open-inspector" \
    -H "Content-Type: application/json" -d '{}' >/dev/null || true
  sleep 1
}

open_inspector_if_needed() {
  local port="$1" state_file="$2"
  curl -sf --max-time 10 "http://127.0.0.1:${port}/ui/state" -o "$state_file" 2>/dev/null || true
  local ui_mode
  ui_mode="$(python3 -c "import json; print(json.load(open('$state_file')).get('data',{}).get('uiMode',''))" 2>/dev/null || echo "")"
  [[ "$ui_mode" == "inspector" ]] && return 0
  if [[ "$port" == "47191" ]]; then
    lookin_enter_mac_inspector "$port" "$HIER_PY"
    lookin_click_lookin_launch_tile "LookinMCPSample"
    return 0
  fi
  mcp_open_inspector "$port"
  lookin_click_lookin_launch_tile "LookinMCPSample"
}

wait_for_preview_ready() {
  local port="$1" state_file="$2" max_wait="${3:-120}"
  local i
  for ((i=1; i<=max_wait; i++)); do
    dismiss_lookin_system_dialogs
    if (( i == 1 || i % 10 == 0 )); then
      open_inspector_if_needed "$port" "${state_file%.json}-ui.json"
    fi
    local cs
    cs="$(curl -sf --max-time 10 "http://127.0.0.1:${port}/ui/client-state" 2>/dev/null || echo '{}')"
    local fetching nodes preview_ep
    fetching="$(echo "$cs" | python3 -c "import json,sys; print(json.load(sys.stdin).get('data',{}).get('isFetchingDetails',True))" 2>/dev/null || echo True)"
    nodes="$(echo "$cs" | python3 -c "import json,sys; d=json.load(sys.stdin).get('data',{}); print((d.get('preview') or {}).get('displayItemNodesCount',0))" 2>/dev/null || echo 0)"
    preview_ep="$(curl -sf --max-time 2 -o /dev/null -w '%{http_code}' "http://127.0.0.1:${port}/ui/preview/state" 2>/dev/null || echo 000)"
    echo "  preview poll ${i}/${max_wait}s: fetching=${fetching} nodes=${nodes} preview_http=${preview_ep}"
    if [[ "$preview_ep" == "200" && "$fetching" == "False" && "${nodes:-0}" -gt 0 ]]; then
      return 0
    fi
    sleep 1
  done
  return 1
}

capture_preview_client() {
  local label="$1" app_path="$2" port="$3" out_dir="$4"
  local ios_flavor=swift
  [[ "$port" == "47191" ]] && ios_flavor=baseline

  section "Capture preview $label (port $port)"
  lookin_install_ios_demo "$SIM_UDID" mcp_sample "$ios_flavor" \
    || fail "Install LookinMCPSample ($ios_flavor) failed"
  sleep 5
  lookin_prepare_clean_launch
  launchctl setenv LOOKIN_VERIFY 1
  sleep 2
  local dismiss_pid
  dismiss_pid="$(dismiss_lookin_dialogs_watch_start 120)"
  "$app_path/Contents/MacOS/Lookin" >/dev/null 2>&1 &
  sleep 2
  dismiss_lookin_system_dialogs
  osascript -e 'tell application "Lookin" to activate' 2>/dev/null || true
  wait_mcp_port "$port" || {
    dismiss_lookin_dialogs_watch_stop "$dismiss_pid"
    fail "MCP port $port not ready"
  }
  sleep 2
  lookin_click_lookin_launch_tile "LookinMCPSample"
  echo "Waiting ${PREVIEW_WAIT_SEC}s for iOS connection..."
  sleep "$PREVIEW_WAIT_SEC"

  local state_file="$out_dir/preview_state-$STAMP.json"
  local shot_file="$out_dir/preview_screenshot-$STAMP.json"
  if ! wait_for_preview_ready "$port" "$state_file" 120; then
    dismiss_lookin_dialogs_watch_stop "$dismiss_pid"
    fail "Preview not ready on port $port ($label)"
  fi

  curl -sf --max-time 30 "http://127.0.0.1:${port}/ui/preview/state" -o "$state_file" \
    || fail "GET /ui/preview/state failed ($label)"
  if ! curl -sf --max-time 60 "http://127.0.0.1:${port}/ui/preview/screenshot" -o "$shot_file"; then
    echo "  warning: GET /ui/preview/screenshot failed ($label) — state-only compare"
    echo '{"success":false,"error":"screenshot unavailable"}' >"$shot_file"
  fi
  cp "$state_file" "$out_dir/preview_state.json"
  cp "$shot_file" "$out_dir/preview_screenshot.json"
  python3 -c "import json; d=json.load(open('$state_file')); print('planes:', len(d.get('data',{}).get('planes',[])))"

  local layers_dir="$out_dir/preview-layers-$STAMP"
  section "Export per-layer screenshots ($label)"
  EXPORT_BODY=$(OUT="$layers_dir" python3 -c 'import json, os; print(json.dumps({"directory": os.environ["OUT"]}))')
  if curl -sf --max-time 120 -X POST "http://127.0.0.1:${port}/ui/preview/export-screenshots" \
    -H "Content-Type: application/json" -d "$EXPORT_BODY" -o "$out_dir/export-layers-$STAMP.json"; then
    python3 -c "import json; d=json.load(open('$out_dir/export-layers-$STAMP.json')); print('  exported:', d.get('data',{}).get('exportedCount',0), 'dir:', d.get('data',{}).get('directory',''))"
  else
    echo "  warning: POST /ui/preview/export-screenshots failed ($label)"
  fi

  dismiss_lookin_dialogs_watch_stop "$dismiss_pid"
  launchctl unsetenv LOOKIN_VERIFY 2>/dev/null || true
  killall Lookin 2>/dev/null || true
  for ((k=1; k<=15; k++)); do
    if ! curl -sf --max-time 1 "http://127.0.0.1:${port}/status" >/dev/null 2>&1; then
      break
    fi
    killall Lookin 2>/dev/null || true
    sleep 1
  done
  sleep 2
}

if [[ "$SKIP_OBJC_BASELINE" == "1" ]]; then
  echo "  SKIP_OBJC_BASELINE=1 — Swift preview vs golden"
  if [[ ! -f "$PREVIEW_GOLDEN" ]]; then
    echo "  No golden fixture — capturing bootstrap for $PREVIEW_GOLDEN"
    capture_preview_client "Swift" "$SWIFT_APP" 47192 "$SWIFT_DIR"
    mkdir -p "$(dirname "$PREVIEW_GOLDEN")"
    python3 "$COMPARE_PY" golden export "$SWIFT_DIR/preview_state.json" > "$PREVIEW_GOLDEN"
    pass "Bootstrapped preview golden ($(wc -l < "$PREVIEW_GOLDEN" | tr -d ' ') lines) — commit $PREVIEW_GOLDEN"
    exit 0
  fi
  capture_preview_client "Swift" "$SWIFT_APP" 47192 "$SWIFT_DIR"
  RESULT_FILE="$LOG_DIR/ui_preview-golden-diff-$STAMP.txt"
  python3 "$COMPARE_PY" golden compare \
    "$SWIFT_DIR/preview_state.json" "$PREVIEW_GOLDEN" \
    | tee "$RESULT_FILE" || fail "Swift preview state differs from golden"
  grep -q '^RESULT: PASS' "$RESULT_FILE" || fail "Golden preview compare failed"
  pass "Swift iOS preview state matches golden"
  exit 0
fi

capture_preview_client "ObjC" "$OBJC_APP" 47191 "$OBJC_DIR"
capture_preview_client "Swift" "$SWIFT_APP" 47192 "$SWIFT_DIR"

RESULT_FILE="$LOG_DIR/ui_preview-diff-$STAMP.txt"
SHOTS_DIFF_FILE="$LOG_DIR/ui_preview-screenshots-diff-$STAMP.txt"
ST_OK=1
SH_OK=1
python3 "$COMPARE_PY" compare \
  "$OBJC_DIR/preview_state.json" "$SWIFT_DIR/preview_state.json" \
  "$OBJC_DIR/preview_screenshot.json" "$SWIFT_DIR/preview_screenshot.json" \
  --threshold 0.12 \
  | tee "$RESULT_FILE" || ST_OK=0
grep -q '^RESULT: PASS — preview state and screenshots match' "$RESULT_FILE" || ST_OK=0

if [[ "$ST_OK" -eq 1 ]]; then
  pass "iOS 3D preview ObjC vs Swift parity"
  exit 0
fi
fail "Preview parity failed — see $RESULT_FILE"
