#!/usr/bin/env bash
# Verify LookinOsAppMCP GET /ui/tap-targets + POST /ui/tap (Swift client only).
# For ObjC+Swift use: bash Lookin/Scripts/verify_ui_tap_mcp.sh
set -euo pipefail
export SKIP_OBJC_BASELINE=1
export PORT="${PORT:-47192}"
exec "$(cd "$(dirname "$0")" && pwd)/verify_ui_tap_mcp.sh" "$@"
