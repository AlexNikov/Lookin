#!/usr/bin/env bash
# Dismiss macOS crash recovery / Problem Report / alert sheets blocking Lookin automation.

lookin_bundle_ids() {
  # ObjC and Swift builds share the same bundle id in this repo.
  echo "hughkli.Lookin"
}

# Demo bundle IDs — keep in sync with LKDemoBundleID.swift.
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lookin_demo_bundle_ids.env
source "$_SCRIPT_DIR/lookin_demo_bundle_ids.env"

lookin_free_ios_mcp_port_47190() {
  local pids
  pids="$(lsof -ti tcp:47190 2>/dev/null || true)"
  if [[ -n "$pids" ]]; then
    echo "  terminating stale listeners on :47190 ($pids)" >&2
    # shellcheck disable=SC2086
    kill -9 $pids 2>/dev/null || true
    sleep 1
  fi
}

lookin_prepare_mcp_sample_demo() {
  local sim_udid="$1"
  local mcp_app="$2"
  lookin_free_ios_mcp_port_47190
  xcrun simctl install "$sim_udid" "$mcp_app"
  xcrun simctl terminate "$sim_udid" "$LEGACY_DEMO_BUNDLE_ID" 2>/dev/null || true
  xcrun simctl terminate "$sim_udid" "$DEMO_BUNDLE_ID" 2>/dev/null || true
  xcrun simctl terminate "$sim_udid" "$MCP_SAMPLE_BUNDLE_ID" 2>/dev/null || true
  xcrun simctl terminate "$sim_udid" "$COLLECTION_LAYOUT_SWIFT_BUNDLE_ID" 2>/dev/null || true
  xcrun simctl terminate "$sim_udid" "$COLLECTION_LAYOUT_OBJC_BUNDLE_ID" 2>/dev/null || true
  pkill -f LookinMCPSample 2>/dev/null || true
  pkill -f LookinCollectionLayoutDemo 2>/dev/null || true
  sleep 1
  xcrun simctl launch "$sim_udid" "$MCP_SAMPLE_BUNDLE_ID"
}

lookin_relaunch_mcp_sample_demo() {
  local sim_udid="$1"
  xcrun simctl terminate "$sim_udid" "$LEGACY_DEMO_BUNDLE_ID" 2>/dev/null || true
  xcrun simctl terminate "$sim_udid" "$DEMO_BUNDLE_ID" 2>/dev/null || true
  xcrun simctl terminate "$sim_udid" "$MCP_SAMPLE_BUNDLE_ID" 2>/dev/null || true
  sleep 1
  xcrun simctl launch "$sim_udid" "$MCP_SAMPLE_BUNDLE_ID"
}

lookin_prepare_collection_layout_demo() {
  local sim_udid="$1"
  local demo_app="$2"
  local bundle_id="$3"
  lookin_free_ios_mcp_port_47190
  xcrun simctl install "$sim_udid" "$demo_app"
  xcrun simctl terminate "$sim_udid" "$LEGACY_DEMO_BUNDLE_ID" 2>/dev/null || true
  xcrun simctl terminate "$sim_udid" "$DEMO_BUNDLE_ID" 2>/dev/null || true
  xcrun simctl terminate "$sim_udid" "$MCP_SAMPLE_BUNDLE_ID" 2>/dev/null || true
  xcrun simctl terminate "$sim_udid" "$COLLECTION_LAYOUT_SWIFT_BUNDLE_ID" 2>/dev/null || true
  xcrun simctl terminate "$sim_udid" "$COLLECTION_LAYOUT_OBJC_BUNDLE_ID" 2>/dev/null || true
  pkill -f LookinMCPSample 2>/dev/null || true
  pkill -f LookinCollectionLayoutDemo 2>/dev/null || true
  sleep 1
  xcrun simctl launch "$sim_udid" "$bundle_id"
}

lookin_ios_mcp_curl() {
  local path="$1" out="${2:-}"
  if [[ -n "$out" ]]; then
    curl -sf --max-time 15 "http://127.0.0.1:47190${path}" -o "$out" 2>/dev/null \
      || curl -g -sf --max-time 15 "http://[::1]:47190${path}" -o "$out" 2>/dev/null
  else
    curl -sf --max-time 15 "http://127.0.0.1:47190${path}" 2>/dev/null \
      || curl -g -sf --max-time 15 "http://[::1]:47190${path}" 2>/dev/null
  fi
}

lookin_wait_ios_mcp() {
  local i tmp
  tmp="$(mktemp -t lookin-ios-mcp-status.XXXXXX.json)"
  for ((i=1; i<=60; i++)); do
    if lookin_ios_mcp_curl "/status" "$tmp"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

lookin_mac_ui_tap_oid() {
  local port="$1" oid="$2"
  curl -sf --max-time 10 -X POST "http://127.0.0.1:${port}/ui/tap" \
    -H "Content-Type: application/json" -d "{\"oid\": ${oid}}" >/dev/null 2>&1 || true
}

lookin_mac_select_inspect_channel() {
  local port="$1" channel="$2"
  curl -sf --max-time 90 -X POST "http://127.0.0.1:${port}/action/select-inspect-target" \
    -H "Content-Type: application/json" \
    -d "{\"channel\":\"${channel}\",\"timeout\":45}" >/dev/null 2>&1 || true
}

lookin_mac_ui_tap_channel() {
  local port="$1" channel="$2"
  curl -sf --max-time 90 -X POST "http://127.0.0.1:${port}/ui/tap" \
    -H "Content-Type: application/json" \
    -d "{\"channel\":\"${channel}\",\"timeout\":45}" >/dev/null 2>&1 || true
}

# Enter inspector from launch screen (tap-targets openInspector, launch card, or POST /ui/open-inspector).
lookin_enter_mac_inspector() {
  local port="$1" helpers_py="$2"
  local tt hier launch_oid
  tt="$(mktemp -t lookin-mac-tap-targets-enter.XXXXXX.json)"
  hier="$(mktemp -t lookin-mac-hierarchy-enter.XXXXXX.json)"
  if curl -sf --max-time 10 "http://127.0.0.1:${port}/ui/tap-targets" -o "$tt" 2>/dev/null; then
    launch_oid="$(python3 "$helpers_py" tap_target_oid_by_action "$tt" openInspector 0 2>/dev/null || true)"
    echo "  enter inspector: openInspector oid=$launch_oid" >&2
    if [[ -n "$launch_oid" && "$launch_oid" != "0" ]]; then
      lookin_mac_ui_tap_oid "$port" "$launch_oid"
      sleep 3
      return 0
    fi
  fi
  if curl -sf --max-time 10 "http://127.0.0.1:${port}/ui/hierarchy" -o "$hier" 2>/dev/null; then
    launch_oid="$(python3 "$helpers_py" launch_app_view_oid "$hier" 2>/dev/null || true)"
    echo "  enter inspector: LKLaunchAppView oid=$launch_oid" >&2
    if [[ -n "$launch_oid" && "$launch_oid" != "0" ]]; then
      lookin_mac_ui_tap_oid "$port" "$launch_oid"
      sleep 3
      return 0
    fi
  fi
  curl -sf --max-time 30 -X POST "http://127.0.0.1:${port}/ui/open-inspector" \
    -H "Content-Type: application/json" -d '{}' >/dev/null 2>&1 || true
  sleep 2
}

# Poll GET /hierarchy (iOS tree in mac inspector) and /ui/state until loaded.
# ObjC baseline has no /ui/client-state; use this for port 47191 automation.
wait_for_mac_ios_hierarchy() {
  local port="$1" out_file="$2" helpers_py="$3"
  local min_items="${4:-20}" max_wait="${5:-90}"
  local tile_label="${6:-${SIM_NAME:-LookinMCPSample}}"
  local i state_file item_count rows ui_mode
  state_file="${out_file%.json}-ui-state.json"
  for ((i=1; i<=max_wait; i++)); do
    dismiss_lookin_system_dialogs
    if (( i == 1 || i % 8 == 0 )); then
      lookin_enter_mac_inspector "$port" "$helpers_py"
      lookin_click_lookin_launch_tile "$tile_label"
      curl -sf --max-time 30 -X POST "http://127.0.0.1:${port}/ui/open-inspector" \
        -H "Content-Type: application/json" -d '{}' >/dev/null 2>&1 || true
    fi
    if (( i % 16 == 0 )); then
      curl -sf --max-time 15 -X POST "http://127.0.0.1:${port}/action/reload" \
        -H "Content-Type: application/json" -d '{}' >/dev/null 2>&1 || true
    fi
    if curl -sf --max-time 15 "http://127.0.0.1:${port}/hierarchy" -o "$out_file" 2>/dev/null; then
      item_count="$(python3 -c "
import json, sys

def count_nodes(items):
    n = 0
    for it in items or []:
        n += 1
        n += count_nodes(it.get('children') or it.get('subitems') or [])
    return n

d = json.load(open(sys.argv[1]))
items = (d.get('data') or {}).get('items') or []
print(count_nodes(items))
" "$out_file" 2>/dev/null || echo 0)"
      if [[ "${item_count:-0}" -ge "$min_items" ]]; then
        echo "  iOS hierarchy ready: ${item_count} root items (poll ${i}/${max_wait}s)" >&2
        return 0
      fi
    fi
    curl -sf --max-time 10 "http://127.0.0.1:${port}/ui/state" -o "$state_file" 2>/dev/null || true
    ui_mode="$(python3 -c "import json; print(json.load(open('$state_file')).get('data',{}).get('uiMode',''))" 2>/dev/null || echo "")"
    rows="$(python3 -c "import json; print(json.load(open('$state_file')).get('data',{}).get('hierarchyRows',0))" 2>/dev/null || echo 0)"
    echo "  poll ${i}/${max_wait}s: uiMode=${ui_mode} hierarchyRows=${rows} iosItems=${item_count:-0}" >&2
    if [[ "$ui_mode" == "inspector" && "${rows:-0}" -ge "$min_items" ]]; then
      curl -sf --max-time 15 "http://127.0.0.1:${port}/hierarchy" -o "$out_file" 2>/dev/null || true
      return 0
    fi
    sleep 1
  done
  return 1
}

lookin_prepare_custom_info_demo() {
  local sim_udid="$1"
  local demo_app="$2"
  local launch_bundle="${3:-$DEMO_BUNDLE_ID}"
  lookin_free_ios_mcp_port_47190
  xcrun simctl terminate "$sim_udid" "$MCP_SAMPLE_BUNDLE_ID" 2>/dev/null || true
  xcrun simctl install "$sim_udid" "$demo_app"
  xcrun simctl terminate "$sim_udid" "$LEGACY_DEMO_BUNDLE_ID" 2>/dev/null || true
  xcrun simctl terminate "$sim_udid" "$DEMO_BUNDLE_ID" 2>/dev/null || true
  if [[ "$launch_bundle" != "$LEGACY_DEMO_BUNDLE_ID" ]]; then
    xcrun simctl terminate "$sim_udid" "$LEGACY_DEMO_BUNDLE_ID" 2>/dev/null || true
  fi
  if [[ "$launch_bundle" != "$DEMO_BUNDLE_ID" ]]; then
    xcrun simctl terminate "$sim_udid" "$DEMO_BUNDLE_ID" 2>/dev/null || true
  fi
  xcrun simctl uninstall "$sim_udid" "$LEGACY_DEMO_BUNDLE_ID" 2>/dev/null || true
  sleep 1
  LOOKIN_LAST_CUSTOM_INFO_BUNDLE="$launch_bundle"
  xcrun simctl launch "$sim_udid" "$launch_bundle"
}

lookin_relaunch_custom_info_demo() {
  local sim_udid="$1"
  local launch_bundle="${2:-${LOOKIN_LAST_CUSTOM_INFO_BUNDLE:-$DEMO_BUNDLE_ID}}"
  xcrun simctl terminate "$sim_udid" "$LEGACY_DEMO_BUNDLE_ID" 2>/dev/null || true
  xcrun simctl terminate "$sim_udid" "$DEMO_BUNDLE_ID" 2>/dev/null || true
  xcrun simctl terminate "$sim_udid" "$MCP_SAMPLE_BUNDLE_ID" 2>/dev/null || true
  sleep 1
  xcrun simctl launch "$sim_udid" "$launch_bundle"
}

lookin_prepare_clean_launch() {
  local bundle
  bundle="$(lookin_bundle_ids)"
  killall Lookin 2>/dev/null || true
  killall "Problem Reporter" 2>/dev/null || true
  rm -rf "${HOME}/Library/Saved Application State/${bundle}.savedState" 2>/dev/null || true
  find "${HOME}/Library/Saved Application State" -maxdepth 1 -name '*Lookin*.savedState' -exec rm -rf {} + 2>/dev/null || true
  defaults write "${bundle}" NSQuitAlwaysKeepsWindows -bool false 2>/dev/null || true
}

# Click "Don't Reopen" / OK on crash recovery, sheets, and Problem Reporter.
dismiss_lookin_system_dialogs() {
  osascript <<'APPLESCRIPT' 2>/dev/null || true
on clickButtonNamed(btnName)
  try
    click button btnName
    return true
  end try
  return false
end clickButtonNamed

on dismissButtonsInWindow(w)
  set dismissed to false
  repeat with btnName in {"Don't Reopen", "Don’t Reopen", "Не открывать", "OK", "Ok", "Close", "Закрыть"}
    try
      if exists button btnName of w then
        click button btnName of w
        set dismissed to true
      end if
    end try
  end repeat
  return dismissed
end dismissButtonsInWindow

tell application "System Events"
  -- Problem Report / crash reporter window (separate process).
  if exists process "Problem Reporter" then
    tell process "Problem Reporter"
      set frontmost to true
      repeat with w in windows
        dismissButtonsInWindow(w)
      end repeat
      try
        click button "OK" of window 1
      end try
      try
        keystroke "w" using command down
      end try
    end tell
  end if

  if not (exists process "Lookin") then return
  tell process "Lookin"
    set frontmost to true
    repeat with w in windows
      -- Crash recovery prompt can appear as a normal window, not only AXSystemDialog.
      try
        if (w's name as text) contains "unexpectedly quit while reopening windows" then
          dismissButtonsInWindow(w)
        end if
      end try
      try
        if w's subrole is "AXSystemDialog" then
          dismissButtonsInWindow(w)
        else
          dismissButtonsInWindow(w)
        end if
      end try
      try
        repeat with s in sheets of w
          dismissButtonsInWindow(s)
        end repeat
      end try
    end repeat
    repeat 4 times
      try
        if (count of windows whose subrole is "AXSystemDialog") > 0 then
          set dlg to first window whose subrole is "AXSystemDialog"
          dismissButtonsInWindow(dlg)
        end if
      end try
      delay 0.25
    end repeat
  end tell
end tell
APPLESCRIPT
}

# Background loop: call before long waits, then kill $! when done.
dismiss_lookin_dialogs_watch_start() {
  local seconds="${1:-120}"
  (
    local end=$((SECONDS + seconds))
    while (( SECONDS < end )); do
      dismiss_lookin_system_dialogs
      sleep 0.6
    done
  ) &
  echo $!
}

dismiss_lookin_dialogs_watch_stop() {
  local pid="${1:-}"
  [[ -n "$pid" ]] || return 0
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  dismiss_lookin_system_dialogs
}

# Count _NSAlertContentView in MCP /ui/hierarchy JSON (0 = clean).
lookin_count_alert_views() {
  local json_file="$1"
  python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
def walk(n):
    c = 0
    if 'NSAlertContentView' in (n.get('className') or ''):
        c += 1
    for ch in n.get('children', []):
        c += walk(ch)
    if 'contentView' in n:
        c += walk(n['contentView'])
    return c
total = 0
for w in d.get('data', {}).get('windows', []):
    total += walk(w)
print(total)
" "$json_file" 2>/dev/null || echo 0
}
