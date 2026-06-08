#!/usr/bin/env bash
# Manual / nightly: full ObjC baseline vs Swift parity (requires both Lookin builds + baseline iOS demo).
# Not the default fast path — use verify_* with SKIP_OBJC_BASELINE=1 for day-to-day CI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export SKIP_OBJC_BASELINE=0

section() { echo ""; echo "======== $1 ========"; }

section "Legacy gates"
bash "$ROOT/Lookin/Scripts/run_legacy_gates.sh"

section "Wire v2 ping"
bash "$ROOT/Lookin/Scripts/verify_wire_v2_ping.sh"

section "Custom info (baseline capture)"
bash "$ROOT/Lookin/Scripts/verify_custom_info_client.sh"

section "UI hierarchy (ObjC vs Swift)"
bash "$ROOT/Lookin/Scripts/verify_ui_hierarchy_mcp.sh"

section "UI tap (ObjC vs Swift)"
bash "$ROOT/Lookin/Scripts/verify_ui_tap_mcp.sh"

echo ""
echo "verify_parity_nightly: all parity checks finished"
