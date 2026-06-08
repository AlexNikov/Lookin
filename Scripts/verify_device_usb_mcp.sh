#!/usr/bin/env bash
# E2E verify: CollLayout demo on physical iPhone over USB (Lookin :47192 MCP).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEVICE="${DEVICE_UDID:-00008030-001014891AE1802E}"
DD_IOS="${DD_IOS:-$ROOT/lookin-verify-logs/DerivedData-CollLayoutDevice}"
DD_MAC="${DD_MAC:-$ROOT/lookin-verify-logs/DerivedData-LookinRefactor}"
DEMO_WS="$ROOT/LookinServer/LookinDemo/LookinCollectionLayoutDemo/LookinCollectionLayoutDemo.xcworkspace"
MAC_WS="$ROOT/Lookin/Lookin.xcworkspace"
IOS_APP="$DD_IOS/Build/Products/Debug-iphoneos/LookinCollectionLayoutDemo.app"
MAC_APP="$DD_MAC/Build/Products/Debug/Lookin.app"
PORT=47192
STAMP="$(date +%Y%m%d-%H%M%S)"
RESULT="$ROOT/lookin-verify-logs/device-usb-$STAMP.txt"

fail() { echo "RESULT: FAIL — $1" | tee -a "$RESULT"; exit 1; }
pass() { echo "RESULT: PASS — $1" | tee -a "$RESULT"; }

wait_inspector() {
  local max="$1"
  for _ in $(seq 1 "$max"); do
    local ui
    ui=$(curl -sf --max-time 3 "http://127.0.0.1:$PORT/status" 2>/dev/null \
      | python3 -c "import json,sys; print(json.load(sys.stdin).get('data',{}).get('client',{}).get('uiMode',''))" 2>/dev/null || echo "")
    [[ "$ui" == "inspector" ]] && return 0
    sleep 1
  done
  return 1
}

assert_usb_session() {
  curl -sf "http://127.0.0.1:$PORT/status" | python3 -c "
import json,sys
c=json.load(sys.stdin)['data']['client']
assert c.get('uiMode')=='inspector', c.get('uiMode')
assert c.get('inspectingBundleId')=='Lookin.LookinCollectionLayoutDemo', c.get('inspectingBundleId')
assert c.get('channelTargetPort')==47175, c.get('channelTargetPort')
print('usb session ok')
"
}

section() { echo ""; echo "======== $1 ========" | tee -a "$RESULT"; }

section "build iOS demo + Mac Lookin"
(cd "$ROOT/LookinServer/LookinDemo/LookinCollectionLayoutDemo" && pod install --silent)
xcodebuild -workspace "$DEMO_WS" -scheme LookinCollectionLayoutDemo -configuration Debug \
  -destination "id=$DEVICE" -derivedDataPath "$DD_IOS" build -quiet
xcodebuild -workspace "$MAC_WS" -scheme LookinClient -configuration Debug \
  -derivedDataPath "$DD_MAC" build -quiet
[[ -d "$IOS_APP" && -d "$MAC_APP" ]] || fail "missing build products"

section "install demo on device"
killall Lookin 2>/dev/null || true
pid=$(xcrun devicectl device info processes --device "$DEVICE" 2>/dev/null \
  | rg LookinCollectionLayoutDemo | awk '{print $1}' | head -1 || true)
[[ -n "${pid:-}" ]] && xcrun devicectl device process terminate --device "$DEVICE" --pid "$pid" 2>/dev/null || true
sleep 1
xcrun devicectl device install app --device "$DEVICE" "$IOS_APP" >/dev/null
xcrun devicectl device process launch --device "$DEVICE" Lookin.LookinCollectionLayoutDemo >/dev/null
sleep 3

section "auto-enter USB inspector"
open -a "$MAC_APP" --args -ApplePersistenceIgnoreState YES
wait_inspector 45 || fail "auto-enter timeout"
assert_usb_session || fail "not USB CollLayout session"
pass "auto-enter CollLayout on USB :47175"

section "cold start (Lookin before demo)"
curl -sf -X POST "http://127.0.0.1:$PORT/action/end-inspect-session" -d '{}' >/dev/null 2>&1 || true
killall Lookin 2>/dev/null || true
pid=$(xcrun devicectl device info processes --device "$DEVICE" 2>/dev/null \
  | rg LookinCollectionLayoutDemo | awk '{print $1}' | head -1 || true)
[[ -n "${pid:-}" ]] && xcrun devicectl device process terminate --device "$DEVICE" --pid "$pid" 2>/dev/null || true
sleep 1
open -a "$MAC_APP" --args -ApplePersistenceIgnoreState YES
sleep 4
xcrun devicectl device process launch --device "$DEVICE" Lookin.LookinCollectionLayoutDemo >/dev/null
wait_inspector 60 || fail "cold start timeout"
assert_usb_session || fail "cold start wrong session"
pass "cold start USB connect"

section "relaunch Lookin (demo stays running)"
killall Lookin 2>/dev/null || true
sleep 2
# Foreground demo so iOS Peertalk re-listens after Mac quit (watchdog / willEnterForeground).
xcrun devicectl device process launch --device "$DEVICE" Lookin.LookinCollectionLayoutDemo >/dev/null
sleep 3
open -a "$MAC_APP" --args -ApplePersistenceIgnoreState YES
wait_inspector 40 || fail "relaunch Lookin timeout"
assert_usb_session || fail "relaunch wrong session"
pass "Lookin relaunch after killall"

section "reload hierarchy"
curl -sf -X POST "http://127.0.0.1:$PORT/action/reload-hierarchy" -d '{}' >/dev/null 2>&1 || true
sleep 8
assert_usb_session || fail "reload lost USB session"
curl -sf "http://127.0.0.1:$PORT/status" | python3 -c "
import json,sys
assert json.load(sys.stdin)['data']['client']['hasHierarchy']
print('hierarchy ok')
" || fail "no hierarchy after reload"
pass "reload keeps USB session"

pass "device USB E2E complete"
echo "log: $RESULT"
