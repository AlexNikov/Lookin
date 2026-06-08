#!/usr/bin/env bash
# Source of truth: LookinWireFormat.version in LookinServerShared.
# Usage: source Lookin/Scripts/lookin_wire_version.sh
set -euo pipefail

if [[ -n "${LOOKIN_WIRE_VERSION:-}" ]]; then
  export LOOKIN_WIRE_VERSION
  return 0 2>/dev/null || exit 0
fi

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
_ROOT="$(cd "$_SCRIPT_DIR/../.." && pwd)"
_FORMAT="$_ROOT/LookinServer/Sources/LookinServerShared/Wire/LookinWireFormat.swift"

if [[ ! -f "$_FORMAT" ]]; then
  echo "lookin_wire_version: missing $_FORMAT" >&2
  exit 1
fi

LOOKIN_WIRE_VERSION="$(grep -E 'public static let version = [0-9]+' "$_FORMAT" | sed -E 's/.*= ([0-9]+)/\1/' | head -1)"
if [[ -z "$LOOKIN_WIRE_VERSION" ]]; then
  echo "lookin_wire_version: failed to parse version from $_FORMAT" >&2
  exit 1
fi

export LOOKIN_WIRE_VERSION
