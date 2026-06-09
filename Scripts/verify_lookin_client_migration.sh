#!/usr/bin/env bash
# Static migration gates for LookinClient stage 2 (post-.m cleanup).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT="$ROOT/LookinClient"
PBXPROJ="$ROOT/Lookin.xcodeproj/project.pbxproj"
PODFILE="$ROOT/Podfile"
BRIDGING="$CLIENT/Base/LookinClient-Bridging-Header.h"

fail() {
  echo "verify_lookin_client_migration: FAIL — $1" >&2
  exit 1
}

pass() {
  echo "verify_lookin_client_migration: PASS — $1"
}

# G0: 0 .m fileRef in Sources LookinClient
g0_no_m_in_sources() {
  local count
  count="$(python3 - "$PBXPROJ" <<'PY'
import re, sys
p = sys.argv[1]
text = open(p).read()
refs = {}
for m in re.finditer(
    r'\t\t([A-F0-9]+) /\* (.+?) \*/ = \{isa = PBXFileReference;.*?path = ([^;]+);',
    text,
    re.S,
):
    refs[m.group(1)] = m.group(3).strip().strip('"')
builds = re.findall(
    r'\t\t([A-F0-9]+) /\* (.+?) in Sources \*/ = \{isa = PBXBuildFile; fileRef = ([A-F0-9]+)',
    text,
)
m_count = 0
for _, _, ref in builds:
    path = refs.get(ref, "")
    if path.endswith(".m"):
        m_count += 1
print(m_count)
PY
)"
  if [[ "$count" != "0" ]]; then
    fail "G0: found $count .m fileRef in Sources (expected 0)"
  fi
  pass "G0: 0 .m fileRef in Sources"
}

# G1: Connection layer free of RACSubject
g1_connection_rx() {
  local rac_subject_count reactive_count
  rac_subject_count="$(rg -c 'RACSubject\s*<' "$CLIENT/Connection" --glob '*.swift' 2>/dev/null | awk -F: '{s+=$2} END {print s+0}' || true)"
  reactive_count="$(rg -c '^import ReactiveObjC' "$CLIENT" --glob '*.swift' 2>/dev/null | awk -F: '{s+=$2} END {print s+0}' || true)"
  if [[ "${rac_subject_count:-0}" != "0" ]]; then
    fail "G1: Connection still uses RACSubject ($rac_subject_count occurrences)"
  fi
  pass "G1: Connection layer without RACSubject (ReactiveObjC imports remaining: ${reactive_count:-0})"
}

# G2: no import Combine
g2_no_combine() {
  local count
  count="$(rg -l '^import Combine' "$CLIENT" --glob '*.swift' 2>/dev/null | wc -l | tr -d ' ' || true)"
  if [[ "${count:-0}" != "0" ]]; then
    fail "G2: found $count files with 'import Combine' (expected 0)"
  fi
  pass "G2: 0 import Combine"
}

# G3: ReactiveObjC removed from Podfile and bridging
g3_no_rac_pod() {
  if rg -q "ReactiveObjC" "$PODFILE" 2>/dev/null; then
    fail "G3: Podfile still references ReactiveObjC"
  fi
  pass "G3: ReactiveObjC absent from Podfile"
}

# G4: no ObjC bridging header (removed; Swift imports LookinShared)
g4_no_bridging_header() {
  local pbx_import_count
  pbx_import_count="$(rg -c 'SWIFT_OBJC_BRIDGING_HEADER = "[^"]+"' "$PBXPROJ" 2>/dev/null | wc -l | tr -d ' ' || true)"
  if [[ "${pbx_import_count:-0}" != "0" ]]; then
    fail "G4: SWIFT_OBJC_BRIDGING_HEADER still set in project.pbxproj (expected empty)"
  fi
  if [[ -f "$BRIDGING" ]]; then
    local import_count
    import_count="$(grep -c '^#import' "$BRIDGING" 2>/dev/null || true)"
    import_count="${import_count:-0}"
    if [[ "$import_count" != "0" ]]; then
      fail "G4: bridging has $import_count #import line(s) (expected 0)"
    fi
    fail "G4: bridging header file still exists at $BRIDGING (expected removed)"
  fi
  pass "G4: no ObjC bridging header"
}

# G5: no orphan .m under LookinClient/
g5_no_orphan_m() {
  local count
  count="$(find "$CLIENT" -name '*.m' 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "${count:-0}" != "0" ]]; then
    fail "G5: found $count orphan .m file(s) under LookinClient/"
  fi
  pass "G5: 0 orphan .m under LookinClient/"
}

# G6: @objc( ceiling outside AppKit UI + ShortCocoa + Connection (no growth)
g6_non_ui_objc_ceiling() {
  local count baseline baseline_file
  baseline_file="$(cd "$(dirname "$0")/../.." && pwd)/LookinServer/Scripts/objc_legacy_baseline.env"
  if [[ ! -f "$baseline_file" ]]; then
    fail "G6: missing baseline $baseline_file"
  fi
  # shellcheck source=/dev/null
  source "$baseline_file"
  baseline="${LOOKINCLIENT_NON_UI_OBJC_ATOBJC:-95}"
  count="$( { rg -c '@objc\(' "$CLIENT" --glob '*.swift' 2>/dev/null || true; } | awk -F: '
{
  f = $1; c = $2
  if (f ~ /\/Base\// || f ~ /\/Dashboard\// || f ~ /\/Static\// || f ~ /\/Connection\//) next
  s += c
}
END { print s+0 }')"
  if [[ "$count" -gt "$baseline" ]]; then
    fail "G6: non-UI @objc( count $count exceeds baseline $baseline"
  fi
  pass "G6: non-UI @objc( count $count (baseline <= $baseline)"
}

# G7: RACObserve ceiling (migration to RxRelay)
g7_rac_observe_ceiling() {
  local count baseline baseline_file
  baseline_file="$(dirname "$0")/rx_relay_migration_baseline.env"
  if [[ ! -f "$baseline_file" ]]; then
    fail "G7: missing baseline $baseline_file"
  fi
  # shellcheck source=/dev/null
  source "$baseline_file"
  baseline="${LOOKINCLIENT_RACOBSERVE:-35}"
  count="$( { rg -c '\bRACObserve\(' "$CLIENT" --glob '*.swift' 2>/dev/null || true; } | awk -F: '{s+=$2} END {print s+0}')"
  if [[ "$count" -gt "$baseline" ]]; then
    fail "G7: RACObserve count $count exceeds baseline $baseline"
  fi
  pass "G7: RACObserve count $count (baseline <= $baseline)"
}

# G8: @objc dynamic ceiling
g8_objc_dynamic_ceiling() {
  local count baseline baseline_file
  baseline_file="$(dirname "$0")/rx_relay_migration_baseline.env"
  if [[ ! -f "$baseline_file" ]]; then
    fail "G8: missing baseline $baseline_file"
  fi
  # shellcheck source=/dev/null
  source "$baseline_file"
  baseline="${LOOKINCLIENT_OBJC_DYNAMIC:-11}"
  count="$( { rg -c '@objc dynamic' "$CLIENT" --glob '*.swift' 2>/dev/null || true; } | awk -F: '{s+=$2} END {print s+0}')"
  if [[ "$count" -gt "$baseline" ]]; then
    fail "G8: @objc dynamic count $count exceeds baseline $baseline"
  fi
  pass "G8: @objc dynamic count $count (baseline <= $baseline)"
}

# G9: @objc(ShortCocoa) ceiling
g9_shortcocoa_objc_ceiling() {
  local count baseline baseline_file
  baseline_file="$(dirname "$0")/rx_relay_migration_baseline.env"
  if [[ ! -f "$baseline_file" ]]; then
    fail "G9: missing baseline $baseline_file"
  fi
  # shellcheck source=/dev/null
  source "$baseline_file"
  baseline="${LOOKINCLIENT_OBJC_SHORTCOCOA:-2}"
  count="$( { rg -c '@objc\(ShortCocoa' "$CLIENT" --glob '*.swift' 2>/dev/null || true; } | awk -F: '{s+=$2} END {print s+0}')"
  if [[ "$count" -gt "$baseline" ]]; then
    fail "G9: @objc(ShortCocoa) count $count exceeds baseline $baseline"
  fi
  pass "G9: @objc(ShortCocoa) count $count (baseline <= $baseline)"
}

# G10: no ShortCocoa / SC( in LookinClient
g10_no_shortcocoa() {
  local sc_count shortcocoa_count
  sc_count="$( { rg -c '\bSC\(' "$CLIENT" --glob '*.swift' 2>/dev/null || true; } | awk -F: '{s+=$2} END {print s+0}')"
  shortcocoa_count="$( { rg -c 'ShortCocoa' "$CLIENT" --glob '*.swift' 2>/dev/null || true; } | awk -F: '{s+=$2} END {print s+0}')"
  if [[ "${sc_count:-0}" != "0" ]]; then
    fail "G10: found $sc_count SC( call(s) under LookinClient"
  fi
  if [[ "${shortcocoa_count:-0}" != "0" ]]; then
    fail "G10: found $shortcocoa_count ShortCocoa reference(s) under LookinClient"
  fi
  pass "G10: 0 SC( and 0 ShortCocoa under LookinClient"
}

# G11: no import Cocoa in LookinClient (use import AppKit)
g11_no_import_cocoa() {
  local count
  count="$( { rg -c '^import Cocoa$' "$CLIENT" --glob '*.swift' 2>/dev/null || true; } | awk -F: '{s+=$2} END {print s+0}')"
  if [[ "${count:-0}" != "0" ]]; then
    fail "G11: found $count 'import Cocoa' (expected 0; use import AppKit)"
  fi
  pass "G11: 0 import Cocoa"
}

# G12: total @objc( ceiling in LookinClient (Phase F cleanup — no growth)
g12_total_objc_ceiling() {
  local count baseline baseline_file
  baseline_file="$(cd "$(dirname "$0")/../.." && pwd)/LookinServer/Scripts/objc_legacy_baseline.env"
  if [[ ! -f "$baseline_file" ]]; then
    fail "G12: missing baseline $baseline_file"
  fi
  # shellcheck source=/dev/null
  source "$baseline_file"
  baseline="${LOOKINCLIENT_TOTAL_OBJC_ATOBJC:-297}"
  count="$( { rg -c '@objc\(' "$CLIENT" --glob '*.swift' 2>/dev/null || true; } | awk -F: '{s+=$2} END {print s+0}')"
  if [[ "$count" -gt "$baseline" ]]; then
    fail "G12: total @objc( count $count exceeds baseline $baseline"
  fi
  pass "G12: total @objc( count $count (baseline <= $baseline)"
}

g0_no_m_in_sources
g1_connection_rx
g2_no_combine
g3_no_rac_pod
g4_no_bridging_header
g5_no_orphan_m
g6_non_ui_objc_ceiling
g7_rac_observe_ceiling
g8_objc_dynamic_ceiling
g9_shortcocoa_objc_ceiling
g10_no_shortcocoa
g11_no_import_cocoa
g12_total_objc_ceiling

echo "verify_lookin_client_migration: all gates passed"
