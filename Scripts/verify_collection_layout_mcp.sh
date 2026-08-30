#!/usr/bin/env bash
# MCP verify: LookinCollectionLayoutDemo (Swift + ObjC iOS) — hierarchy left pane + 3D preview.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_DIR="$ROOT/lookin-verify-logs"
export LOOKIN_VERIFY_LOG_DIR="$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$LOG_DIR/collection-layout-$STAMP"
mkdir -p "$OUT_DIR"
RESULT_FILE="$OUT_DIR/RESULT-collection-layout-$STAMP.txt"
# shellcheck source=lookin_write_latest_summary.sh
source "$ROOT/Lookin/Scripts/lookin_write_latest_summary.sh"
# shellcheck source=lookin_dismiss_dialogs.sh
source "$ROOT/Lookin/Scripts/lookin_dismiss_dialogs.sh"
# shellcheck source=lookin_verify_ios_demo.sh
source "$ROOT/Lookin/Scripts/lookin_verify_ios_demo.sh"

DD_SWIFT="$LOG_DIR/DerivedData-LookinRefactor"
DD_OBJC="$LOG_DIR/DerivedData-LookinBaseline"
SWIFT_APP="$DD_SWIFT/Build/Products/Debug/Lookin.app"
OBJC_APP="$DD_OBJC/Build/Products/Debug/Lookin.app"
HIER_PY="$ROOT/Lookin/Scripts/mcp_ui_helpers.py"

MIN_FLAT="${COLLECTION_MIN_FLAT:-20}"
MIN_PREVIEW_NODES="${COLLECTION_MIN_PREVIEW_NODES:-12}"
MIN_INSPECTOR_PATHS="${HIER_MIN_INSPECTOR_PATHS:-80}"
WAIT_SEC="${COLLECTION_WAIT_SEC:-75}"
BUILD_IOS_DEMO="${BUILD_IOS_DEMO:-1}"
export BUILD_IOS_DEMO

section() { echo ""; echo "======== $1 ========"; }

_write_summary() {
  lookin_write_latest_summary "verify_collection_layout_mcp" "$RESULT_FILE" || true
}
trap _write_summary EXIT

fail() {
  echo "RESULT: FAIL — $1" | tee -a "$RESULT_FILE"
  echo "verify_collection_layout_mcp: FAIL — $1" >&2
  exit 1
}
pass() {
  echo "RESULT: PASS — $1" | tee -a "$RESULT_FILE"
  echo "verify_collection_layout_mcp: PASS — $1"
}

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

validate_client_state() {
  local cs_file="$1" label="$2"
  python3 - "$cs_file" "$label" "$MIN_FLAT" "$MIN_PREVIEW_NODES" <<'PY' || return 1
import json, sys
path, label, min_flat, min_preview = sys.argv[1:5]
min_flat, min_preview = int(min_flat), int(min_preview)
with open(path) as f:
    data = json.load(f).get("data") or {}
items = data.get("items") or []
titles = [(it.get("title") or "") for it in items]
text = " ".join(titles).lower()
needles = {
    "uicollectionview": "uicollectionview" in text,
    "left_rail": any("leftrailview" in (t or "").lower() for t in titles),
    "demo_cell": any(
        k in (t or "").lower()
        for t in titles
        for k in (
            "democonstraintcollectioncell",
            "demoframecollectioncell",
            "demomixedcollectioncell",
            "lkdemoconstraintcollectioncell",
            "lkdemoframecollectioncell",
            "lkdemomixedcollectioncell",
            "uicollectionviewcell",
        )
    ) or "uicollectionview" in text,
}
flat = int(data.get("flatItemsCount") or 0)
preview = data.get("preview") or {}
nodes = int(preview.get("displayItemNodesCount") or 0)
print(f"  [{label}] flatItems={flat} previewNodes={nodes} needles={needles}")
if flat < min_flat:
    raise SystemExit(f"flatItems {flat} < {min_flat}")
if nodes < min_preview:
    raise SystemExit(f"preview nodes {nodes} < {min_preview}")
if not needles["uicollectionview"]:
    raise SystemExit("UICollectionView not found in hierarchy titles")
if not needles["left_rail"]:
    raise SystemExit("left rail view not found in hierarchy titles")
if not needles["demo_cell"]:
    raise SystemExit("collection demo cells not found in hierarchy titles")
PY
}

validate_mac_hierarchy_json() {
  local hier_file="$1" label="$2"
  python3 - "$hier_file" "$label" "$MIN_FLAT" <<'PY' || return 1
import json, sys

def walk_nodes(items):
    for it in items or []:
        yield it
        yield from walk_nodes(it.get("children") or it.get("subitems") or [])

path, label, min_flat = sys.argv[1:4]
min_flat = int(min_flat)
with open(path) as f:
    doc = json.load(f)
data = doc.get("data") or {}
items = data.get("items") or []
nodes = list(walk_nodes(items))
classes = [(n.get("className") or n.get("title") or "") for n in nodes]
text = " ".join(classes).lower()
needles = {
    "uicollectionview": "uicollectionview" in text,
    "left_rail": any("leftrailview" in (c or "").lower() for c in classes),
    "demo_cell": any(
        k in (c or "").lower()
        for c in classes
        for k in (
            "democonstraintcollectioncell",
            "demoframecollectioncell",
            "demomixedcollectioncell",
            "lkdemoconstraintcollectioncell",
            "lkdemoframecollectioncell",
            "lkdemomixedcollectioncell",
            "uicollectionviewcell",
        )
    ) or "uicollectionview" in text,
}
flat = len(nodes)
print(f"  [{label}] mac /hierarchy nodes={flat} needles={needles}")
if flat < min_flat:
    raise SystemExit(f"nodes {flat} < {min_flat}")
if not needles["uicollectionview"]:
    raise SystemExit("UICollectionView not found in mac /hierarchy")
if not needles["left_rail"]:
    raise SystemExit("left rail view not found in mac /hierarchy")
if not needles["demo_cell"]:
    raise SystemExit("collection demo cells not found in mac /hierarchy")
PY
}

capture_flavor() {
  local label="$1" ios_flavor="$2"
  local port=47192 mac_app="$SWIFT_APP" tile_label="${SIM_NAME:-iPhone 17 Pro}"
  [[ "$ios_flavor" == "baseline" ]] && port=47191 && mac_app="$OBJC_APP"
  local cs_file="$OUT_DIR/client-state-${ios_flavor}-$STAMP.json"
  local ios_hier_file="$OUT_DIR/ios_hierarchy-${ios_flavor}-$STAMP.json"
  local hier_file="$OUT_DIR/ui_hierarchy-${ios_flavor}-$STAMP.json"

  section "Capture $label (iOS $ios_flavor, mac :$port, tile $tile_label)"
  lookin_install_ios_demo "$SIM_UDID" collection_layout "$ios_flavor" \
    || fail "install collection_layout ($ios_flavor)"
  sleep 4

  lookin_prepare_clean_launch
  launchctl setenv LOOKIN_VERIFY 1
  sleep 2
  local dismiss_pid
  dismiss_pid="$(dismiss_lookin_dialogs_watch_start 150)"
  "$mac_app/Contents/MacOS/Lookin" >/dev/null 2>&1 &
  sleep 2
  dismiss_lookin_system_dialogs
  export LOOKIN_APP="$mac_app"
  lookin_activate_mac_client "$mac_app"
  wait_mcp_port "$port" || {
    dismiss_lookin_dialogs_watch_stop "$dismiss_pid"
    fail "MCP :$port not ready ($label)"
  }
  echo "  waiting ${WAIT_SEC}s for Peertalk discovery..."
  sleep "$WAIT_SEC"

  if [[ "$ios_flavor" == "baseline" ]]; then
    if ! wait_for_mac_ios_hierarchy "$port" "$ios_hier_file" "$HIER_PY" "$MIN_FLAT" 90 "$tile_label"; then
      dismiss_lookin_dialogs_watch_stop "$dismiss_pid"
      fail "mac /hierarchy not ready ($label)"
    fi
    validate_mac_hierarchy_json "$ios_hier_file" "$label" \
      || fail "mac /hierarchy validation ($label)"
  else
    curl -sf --max-time 30 -X POST "http://127.0.0.1:${port}/ui/open-inspector" \
      -H "Content-Type: application/json" -d '{}' >/dev/null || true
    sleep 1
    lookin_click_lookin_launch_tile "$tile_label"
    curl -sf --max-time 30 -X POST "http://127.0.0.1:${port}/ui/open-inspector" \
      -H "Content-Type: application/json" -d '{}' >/dev/null || true
    sleep 5

    local i
    for ((i=1; i<=90; i++)); do
      dismiss_lookin_system_dialogs
      curl -sf --max-time 15 "http://127.0.0.1:${port}/ui/client-state" -o "$cs_file" 2>/dev/null || true
      if [[ -f "$cs_file" ]]; then
        if validate_client_state "$cs_file" "$label" 2>/dev/null; then
          break
        fi
      fi
      if [[ "$i" -eq 90 ]]; then
        dismiss_lookin_dialogs_watch_stop "$dismiss_pid"
        fail "client-state validation timeout ($label)"
      fi
      sleep 1
    done
  fi

  curl -sf --max-time 30 "http://127.0.0.1:${port}/ui/hierarchy" -o "$hier_file" \
    || fail "GET /ui/hierarchy ($label)"
  local inspector_paths
  inspector_paths="$(python3 -c "
import json, sys
def walk(node, prefix=''):
    if not isinstance(node, dict):
        return 0
    cls = node.get('className') or node.get('class') or ''
    path = f'{prefix}/{cls}' if prefix else cls
    n = 1 if any(k in path for k in ('LKSplitView', 'LKHierarchyView', 'LKDashboard', 'LKPreviewView')) else 0
    for ch in node.get('children') or node.get('subviews') or []:
        n += walk(ch, path)
    return n
d = json.load(open(sys.argv[1]))
data = d.get('data', d)
total = 0
for w in data.get('windows', []):
    root = w.get('contentView') or w.get('root') or w
    total += walk(root, '')
print(total)
" "$hier_file" 2>/dev/null || echo 0)"
  echo "  mac inspector paths=$inspector_paths (min $MIN_INSPECTOR_PATHS)"
  if [[ "${inspector_paths:-0}" -lt "$MIN_INSPECTOR_PATHS" ]]; then
    dismiss_lookin_dialogs_watch_stop "$dismiss_pid"
    fail "inspector shell too small ($label)"
  fi

  local parity_file="$OUT_DIR/inspector-parity-${ios_flavor}-$STAMP.json"
  curl -sf --max-time 30 "http://127.0.0.1:${port}/ui/inspector-parity" -o "$parity_file" \
    || fail "GET /ui/inspector-parity ($label)"
  if [[ "$ios_flavor" == "swift" ]]; then
    curl -sf --max-time 30 "http://127.0.0.1:${port}/ui/preview/state" -o "$OUT_DIR/preview-state-${ios_flavor}-$STAMP.json" \
      || fail "GET /ui/preview/state ($label)"
    python3 "$ROOT/Lookin/Scripts/mcp_ui_helpers.py" validate_inspector_parity "$parity_file" "$label" \
      || fail "inspector-parity validation ($label)"
  else
    python3 "$ROOT/Lookin/Scripts/mcp_ui_helpers.py" inspector_parity_summary "$parity_file" \
      | tee -a "$RESULT_FILE" >/dev/null \
      || fail "inspector-parity summary ($label)"
  fi

  dismiss_lookin_dialogs_watch_stop "$dismiss_pid"
  pkill -x Lookin 2>/dev/null || true
  sleep 2
  echo "  OK $label" >>"$RESULT_FILE"
}

if [[ "${RUN_LEGACY_GATES:-1}" == "1" ]]; then
  bash "$ROOT/Lookin/Scripts/run_legacy_gates.sh"
fi

section "0. Build Lookin.app (Swift + ObjC baseline)"
if [[ ! -d "$SWIFT_APP" ]]; then
  cd "$ROOT/Lookin"
  pod install --silent 2>/dev/null || pod install
  xcodebuild -workspace Lookin.xcworkspace -scheme LookinClient -configuration Debug \
    -derivedDataPath "$DD_SWIFT" build -quiet
fi
[[ -d "$SWIFT_APP" ]] || fail "Missing Swift Lookin.app"
if [[ ! -d "$OBJC_APP" ]]; then
  cd "$ROOT/Lookin-baseline+mcp"
  pod install --silent 2>/dev/null || pod install
  xcodebuild -workspace Lookin.xcworkspace -scheme LookinClient -configuration Debug \
    -derivedDataPath "$DD_OBJC" build -quiet
fi
[[ -d "$OBJC_APP" ]] || fail "Missing ObjC baseline Lookin.app"

SIM_NAME="${SIM_NAME:-iPhone 17 Pro}"
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

: >"$RESULT_FILE"
capture_flavor "CollLayout Swift" swift
capture_flavor "CollLayout ObjC" baseline

section "Compare inspector parity (ObjC :47191 vs Swift :47192)"
PARITY_OBJC="$OUT_DIR/inspector-parity-baseline-$STAMP.json"
PARITY_SWIFT="$OUT_DIR/inspector-parity-swift-$STAMP.json"
[[ -f "$PARITY_OBJC" && -f "$PARITY_SWIFT" ]] \
  || fail "missing inspector-parity captures for compare"
python3 "$HIER_PY" compare_inspector_parity "$PARITY_OBJC" "$PARITY_SWIFT" \
  | tee -a "$RESULT_FILE" \
  || fail "inspector-parity ObjC vs Swift compare"

pass "Swift + ObjC collection layout demos: hierarchy (UICollectionView, cells) + preview nodes + inspector shell"
exit 0
