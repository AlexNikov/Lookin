#!/usr/bin/env bash
# Run after changes to LookinShared wire models or LookinClient connection layer.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
bash "$ROOT/Lookin/Scripts/verify_lookin_client_migration.sh"
bash "$ROOT/LookinServer/Scripts/verify_lookin_integration.sh"
