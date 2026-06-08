#!/usr/bin/env bash
# Regenerate Lookin.xcodeproj from project.yml and re-integrate CocoaPods.
# Source of truth: Lookin/project.yml (not hand-edited pbxproj).
# Usage: bash Lookin/Scripts/generate_xcode_project.sh
#   OPEN_PROJECT=0  — skip opening Xcode (CI / agents)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "generate_xcode_project: xcodegen is required (brew install xcodegen)" >&2
  exit 1
fi

xcodegen generate

if [[ -f Podfile.lock ]]; then
  pod install
else
  echo "generate_xcode_project: Podfile.lock missing — run 'pod install' after first clone" >&2
fi

if [[ -x "$ROOT/Scripts/verify_xcodegen_project.sh" ]]; then
  bash "$ROOT/Scripts/verify_xcodegen_project.sh"
fi

echo "generate_xcode_project: done"

if [[ "${OPEN_PROJECT:-1}" != "1" ]]; then
  exit 0
fi

if [[ -d "$ROOT/Lookin.xcworkspace" ]]; then
  open "$ROOT/Lookin.xcworkspace"
elif [[ -d "$ROOT/Lookin.xcodeproj" ]]; then
  open "$ROOT/Lookin.xcodeproj"
else
  echo "generate_xcode_project: no Lookin.xcworkspace or Lookin.xcodeproj to open" >&2
  exit 1
fi
