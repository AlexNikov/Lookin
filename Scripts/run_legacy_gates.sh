#!/usr/bin/env bash
# Static legacy-removal gates (run before verify or in CI).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

section() { echo ""; echo "======== $1 ========"; }

section "Lookin XcodeGen (project.yml)"
bash "$ROOT/Lookin/Scripts/verify_xcodegen_project.sh"

section "LookinClient migration gates"
bash "$ROOT/Lookin/Scripts/verify_lookin_client_migration.sh"

section "LookinServer ObjC exception catch manifest"
bash "$ROOT/LookinServer/Scripts/verify_src_manifest.sh"

section "LookinServer ObjC inventory"
bash "$ROOT/LookinServer/Scripts/count_objc_legacy.sh"

section "Swift @objc / .h inventory (G6/G7)"
bash "$ROOT/LookinServer/Scripts/count_swift_objc.sh"

echo ""
echo "run_legacy_gates: all gates passed"
