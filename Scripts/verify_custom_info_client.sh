#!/usr/bin/env bash
# Compare LookinVerify custom-info logs between Lookin-baseline+mcp (ObjC) and refactored Lookin (Swift).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_DIR="$ROOT/lookin-verify-logs"
export LOOKIN_VERIFY_LOG_DIR="$LOG_DIR"
mkdir -p "$LOG_DIR"
# shellcheck source=lookin_dismiss_dialogs.sh
source "$ROOT/Lookin/Scripts/lookin_dismiss_dialogs.sh"
# shellcheck source=lookin_verify_ios_demo.sh
source "$ROOT/Lookin/Scripts/lookin_verify_ios_demo.sh"
# shellcheck source=lookin_verify_mcp_helpers.sh
source "$ROOT/Lookin/Scripts/lookin_verify_mcp_helpers.sh"
STAMP="$(date +%Y%m%d-%H%M%S)"
MAIN_LOG="$LOG_DIR/custominfo-client-$STAMP.log"
DIFF_LOG=""
CUSTOMINFO_RESULT=""
# shellcheck source=lookin_write_latest_summary.sh
source "$ROOT/Lookin/Scripts/lookin_write_latest_summary.sh"
_custominfo_write_summary() {
  local files=()
  [[ -n "$DIFF_LOG" && -f "$DIFF_LOG" ]] && files+=("$DIFF_LOG")
  [[ -n "$CUSTOMINFO_RESULT" && -f "$CUSTOMINFO_RESULT" ]] && files+=("$CUSTOMINFO_RESULT")
  if ((${#files[@]} > 0)); then
    lookin_write_latest_summary "verify_custom_info_client" "${files[@]}" || true
  elif [[ -f "$MAIN_LOG" ]]; then
    lookin_write_latest_summary "verify_custom_info_client" "$MAIN_LOG" || true
  fi
}
trap _custominfo_write_summary EXIT

exec > >(tee -a "$MAIN_LOG") 2>&1

section() { echo ""; echo "======== $1 ========"; }
fail() { echo "verify_custom_info_client: FAIL — $1" >&2; exit 1; }

wait_mcp_port() {
  local port="$1"
  local i
  for ((i=1; i<=60; i++)); do
    lookin_pump_system_dialogs
    if curl -sf --max-time 2 "http://127.0.0.1:${port}/status" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

mcp_open_inspector() {
  local port="$1"
  echo "  POST /ui/open-inspector (port $port)"
  curl -sf --max-time 30 -X POST "http://127.0.0.1:${port}/ui/open-inspector" \
    -H "Content-Type: application/json" -d '{}' >/dev/null || true
  sleep 1
}

ui_tap_oid() {
  local port="$1"
  local oid="$2"
  curl -sf --max-time 10 -X POST "http://127.0.0.1:${port}/ui/tap" \
    -H "Content-Type: application/json" -d "{\"oid\":${oid}}" >/dev/null 2>&1 || true
}

find_oid_in_client_state() {
  local port="$1"
  local needle="$2"
  lookin_mcp_find_oid_in_client_state "$port" "$needle"
}

SIM_NAME="${SIM_NAME:-iPhone 17 Pro}"
DD_REFACTOR="$LOG_DIR/DerivedData-LookinRefactor"
SKIP_OBJC_BASELINE="${SKIP_OBJC_BASELINE:-1}"
GOLDEN_NORM="$ROOT/Lookin/Scripts/fixtures/custominfo-baseline-golden.norm"

if [[ "$SKIP_OBJC_BASELINE" != "1" ]]; then
  DD_BASELINE="$LOG_DIR/DerivedData-LookinBaseline"
  section "1. Build Lookin-baseline (mac client)"
  cd "$ROOT/Lookin-baseline+mcp"
  pod install --silent 2>/dev/null || pod install
  xcodebuild -workspace Lookin.xcworkspace -scheme LookinClient -configuration Debug \
    -derivedDataPath "$DD_BASELINE" build -quiet
  BASELINE_APP="$DD_BASELINE/Build/Products/Debug/Lookin.app"
  echo "Baseline Lookin.app: $BASELINE_APP"
else
  section "1. Baseline mocked (golden)"
  [[ -f "$GOLDEN_NORM" ]] || fail "Missing golden baseline at $GOLDEN_NORM"
  echo "  SKIP_OBJC_BASELINE=1 — using golden baseline: $GOLDEN_NORM"
fi

section "2. Build Lookin refactored (mac client)"
cd "$ROOT/Lookin"
pod install --silent 2>/dev/null || pod install
xcodebuild -workspace Lookin.xcworkspace -scheme LookinClient -configuration Debug \
  -derivedDataPath "$DD_REFACTOR" build -quiet
REFACTOR_APP="$DD_REFACTOR/Build/Products/Debug/Lookin.app"
echo "Refactored Lookin.app: $REFACTOR_APP"

section "3. Simulator (iOS demo installed per capture: baseline vs Swift)"
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

capture_lookin_verify() {
  local label="$1"
  local app_path="$2"
  local port="$3"
  local out_file="$4"
  local wait_sec="${5:-80}"
  local ios_flavor="${6:-swift}"

  section "Capture $label (MCP $port, iOS $ios_flavor LookinCustomInfoDemo, ${wait_sec}s)"
  killall Lookin 2>/dev/null || true
  sleep 1
  lookin_terminate_all_ios_demos "$SIM_UDID"
  lookin_uninstall_collection_layout_demos "$SIM_UDID"
  xcrun simctl terminate "$SIM_UDID" "$MCP_SAMPLE_BUNDLE_ID" 2>/dev/null || true
  lookin_install_ios_demo "$SIM_UDID" custom_info "$ios_flavor" \
    || fail "Install LookinCustomInfoDemo ($ios_flavor) failed"
  sleep 5

  lookin_prepare_clean_launch
  sleep 2

  : > "$out_file"

  local dismiss_pid
  dismiss_pid="$(dismiss_lookin_dialogs_watch_start $((wait_sec + 60)))"
  local exe="$app_path/Contents/MacOS/Lookin"
  [[ -x "$exe" ]] || fail "Missing Lookin executable at $exe"
  LOOKIN_VERIFY_LOG="$out_file" "$exe" >/dev/null 2>&1 &
  sleep 2
  dismiss_lookin_system_dialogs
  lookin_activate_mac_client "$app_path"

  wait_mcp_port "$port" || {
    dismiss_lookin_dialogs_watch_stop "$dismiss_pid"
    fail "MCP port $port not ready ($label)"
  }

  echo "Waiting for iOS Peertalk connection + hierarchy + inspector..."
  local connected=0
  local mode=""
  local flat=0
  local have_lines=0
  local did_tap=0
  for ((i=1; i<=wait_sec; i++)); do
    dismiss_lookin_system_dialogs
    # Keep nudging the app into inspector via MCP; avoid flaky UI clicking + crash recovery prompts.
    if (( i == 1 || i % 8 == 0 )); then
      if [[ "$mode" == "launch" || "${connected:-0}" == "0" ]]; then
        lookin_click_lookin_launch_tile "LookinCustomInfoDemo"
      fi
      mcp_open_inspector "$port"
      lookin_ensure_custom_info_inspector "$port" "$DEMO_BUNDLE_ID" || true
      curl -sf --max-time 10 -X POST "http://127.0.0.1:${port}/action/reload" -d '{}' >/dev/null 2>&1 || true
    fi

    connected="$(
      curl -sf --max-time 2 "http://127.0.0.1:${port}/status" 2>/dev/null \
        | python3 -c "import json,sys; print((json.load(sys.stdin).get('data',{}) or {}).get('connected',0))" 2>/dev/null \
        || echo 0
    )"
    mode="$(
      curl -sf --max-time 2 "http://127.0.0.1:${port}/ui/state" 2>/dev/null \
        | python3 -c "import json,sys; print((json.load(sys.stdin).get('data',{}) or {}).get('uiMode',''))" 2>/dev/null \
        || echo ''
    )"
    flat="$(
      curl -sf --max-time 2 "http://127.0.0.1:${port}/ui/client-state" 2>/dev/null \
        | python3 -c "import json,sys; print((json.load(sys.stdin).get('data',{}) or {}).get('flatItemsCount',0))" 2>/dev/null \
        || echo 0
    )"

    # Once we're in inspector with hierarchy loaded, tap a target row to trigger detail fetch (custom attrs live in details).
    # Note: /status.connected can be 0 even when hierarchy is loaded (appInfo not yet populated). Use flatItems as the signal.
    if [[ "$did_tap" == "0" && "${flat:-0}" -ge 18 && "$mode" == "inspector" ]]; then
      local target_oid=""
      target_oid="$(find_oid_in_client_state "$port" "birdview")"
      if [[ -z "${target_oid:-}" || "${target_oid:-0}" -le 0 ]]; then
        target_oid="$(find_oid_in_client_state "$port" "doglayer")"
      fi
      if [[ -n "${target_oid:-}" && "${target_oid:-0}" -gt 0 ]]; then
        echo "  tapping oid=${target_oid} to trigger details"
        ui_tap_oid "$port" "$target_oid"
        did_tap=1
      fi
    fi

    if rg -q '^LookinVerify' "$out_file" 2>/dev/null; then
      have_lines=1
    fi
    echo "  poll $i/${wait_sec}s: connected=${connected} uiMode=${mode} flat=${flat} hasLines=${have_lines}"
    local demo_ok=0
    if lookin_mcp_client_has_subtitle "$port" "BirdView" || lookin_mcp_client_has_subtitle "$port" "DogLayer"; then
      demo_ok=1
    elif lookin_assert_inspecting_bundle "$port" "$DEMO_BUNDLE_ID"; then
      demo_ok=1
    fi
    if [[ "${connected:-0}" == "1" && "${flat:-0}" -ge 18 && "$demo_ok" == "1" && "$mode" == "inspector" && "$have_lines" == "1" ]]; then
      break
    fi
    sleep 1
  done

  dismiss_lookin_dialogs_watch_stop "$dismiss_pid"
  dismiss_lookin_system_dialogs
  killall "Problem Reporter" 2>/dev/null || true

  rg '^LookinVerify' "$out_file" 2>/dev/null | sort -u > "${out_file}.sorted" || true
  mv "${out_file}.sorted" "$out_file"
  echo "Lines captured: $(wc -l < "$out_file" | tr -d ' ')"
  head -40 "$out_file" || echo "(empty)"

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

relaunch_demo() {
  lookin_relaunch_custom_info_demo "$SIM_UDID" "${LOOKIN_LAST_CUSTOM_INFO_BUNDLE:-$DEMO_BUNDLE_ID}"
  sleep 4
}

BASELINE_LOG="$LOG_DIR/custominfo-baseline-$STAMP.log"
REFACTOR_LOG="$LOG_DIR/custominfo-refactor-$STAMP.log"
DIFF_LOG="$LOG_DIR/custominfo-diff-$STAMP.log"
CUSTOMINFO_RESULT="$LOG_DIR/custominfo-client-result-$STAMP.txt"

if [[ "$SKIP_OBJC_BASELINE" != "1" ]]; then
  capture_lookin_verify "baseline Lookin.app" "$BASELINE_APP" 47191 "$BASELINE_LOG" 50 baseline
  relaunch_demo
else
  : > "$BASELINE_LOG"
fi
capture_lookin_verify "refactored Lookin.app" "$REFACTOR_APP" 47192 "$REFACTOR_LOG" 90 swift

section "4. Compare normalized LookinVerify lines"
BASELINE_LINES="$(wc -l < "$BASELINE_LOG" | tr -d ' ')"
REFACTOR_LINES="$(wc -l < "$REFACTOR_LOG" | tr -d ' ')"
if [[ "$REFACTOR_LINES" == "0" ]]; then
  echo "RESULT: FAIL — refactored capture empty"
  echo "FAIL" > "$CUSTOMINFO_RESULT"
  exit 1
fi

normalize_log() {
  rg '^LookinVerify' "$1" 2>/dev/null \
    | rg -v 'detail modify:.*customGroups=0 builtinGroups=0 subitems=0$' \
    | rg -v 'customAttr:.* attr=SkinJson ' \
    | rg -v 'customAttr:.* attr=DogJson ' \
    | rg -v '^LookinVerify - asyncUpdate:' \
    | perl -pe 's/NSEdgeInsets:/UIEdgeInsets:/g; if (/attr=(SkinColor|SkinShadow|DogInsets|DogShadow) /) { s/\bvalue=.*/value=<normalized>/ } if (/customSubview: / && / validFrame=0 /) { s/\bframe=\{\{.*\}\}$ /frame=<invalid>/; s/\bframe=\{\{.*\}\}$/frame=<invalid>/ }' \
    | sort -u
}

if [[ "$BASELINE_LINES" == "0" ]]; then
  echo "  baseline empty — using golden: $GOLDEN_NORM"
  normalize_log "$GOLDEN_NORM" > "${BASELINE_LOG}.norm"
else
  normalize_log "$BASELINE_LOG" > "${BASELINE_LOG}.norm"
fi
normalize_log "$REFACTOR_LOG" > "${REFACTOR_LOG}.norm"

if diff -u "${BASELINE_LOG}.norm" "${REFACTOR_LOG}.norm" > "$DIFF_LOG" 2>&1; then
  echo "RESULT: PASS — custom info client parity (baseline == refactored)"
  echo "LookinVerify - PASS custom info client parity (baseline == refactored)"
  echo "PASS" > "$CUSTOMINFO_RESULT"
else
  echo "RESULT: FAIL — custom info client parity"
  echo "LookinVerify - FAIL custom info client parity — see diff:"
  cat "$DIFF_LOG"
  echo "FAIL" > "$CUSTOMINFO_RESULT"
  exit 1
fi

section "Summary files"
echo "baseline:  $BASELINE_LOG"
echo "refactor:  $REFACTOR_LOG"
echo "diff:      $DIFF_LOG"
echo "main log:  $MAIN_LOG"
