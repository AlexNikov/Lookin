#!/usr/bin/env bash
# Kill mac Lookin clients, terminate iOS demos, shutdown booted simulators before verify.
#
#   bash Lookin/Scripts/lookin_verify_preflight_clean.sh
#   DEVICE_UDID=00008030-... bash Lookin/Scripts/lookin_verify_preflight_clean.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=lookin_dismiss_dialogs.sh
source "$ROOT/Lookin/Scripts/lookin_dismiss_dialogs.sh"

lookin_verify_preflight_clean "${DEVICE_UDID:-${1:-}}"
