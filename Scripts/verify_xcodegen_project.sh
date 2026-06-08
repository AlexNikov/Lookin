#!/usr/bin/env bash
# Ensures Lookin.xcodeproj Sources match project.yml (CocoaPods [CP] phases ignored).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPEC="$ROOT/project.yml"
COMMITTED="$ROOT/Lookin.xcodeproj/project.pbxproj"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "verify_xcodegen_project: FAIL — $1" >&2
  exit 1
}

pass() {
  echo "verify_xcodegen_project: PASS — $1"
}

if [[ ! -f "$SPEC" ]]; then
  fail "missing $SPEC"
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  fail "xcodegen not installed (brew install xcodegen)"
fi

PODS_XCCONFIG="$ROOT/Pods/Target Support Files/Pods-LookinClient"
if [[ ! -d "$PODS_XCCONFIG" ]]; then
  fail "Pods xcconfigs missing — run: cd Lookin && pod install"
fi

rsync -a \
  --exclude 'Lookin.xcodeproj' \
  --exclude 'Lookin.xcworkspace' \
  --exclude 'Pods' \
  --exclude 'DerivedData' \
  --exclude '.build' \
  "$ROOT/" "$TMP/Lookin/"

mkdir -p "$TMP/Lookin/Pods/Target Support Files/Pods-LookinClient"
rsync -a "$PODS_XCCONFIG/" "$TMP/Lookin/Pods/Target Support Files/Pods-LookinClient/"

(
  cd "$TMP/Lookin"
  xcodegen generate >/dev/null
)

python3 - "$COMMITTED" "$TMP/Lookin/Lookin.xcodeproj/project.pbxproj" <<'PY'
import re
import sys

def sources_in_pbx(path: str) -> set[str]:
    text = open(path, encoding="utf-8", errors="replace").read()
    refs: dict[str, str] = {}
    for m in re.finditer(
        r"\t\t([A-F0-9]+) /\* (.+?) \*/ = \{isa = PBXFileReference;[^}]*path = ([^;]+);",
        text,
    ):
        refs[m.group(1)] = m.group(3).strip().strip('"')
    builds = re.findall(
        r"\t\t([A-F0-9]+) /\* (.+?) in Sources \*/ = \{isa = PBXBuildFile; fileRef = ([A-F0-9]+)",
        text,
    )
    out: set[str] = set()
    for _, _, ref in builds:
        p = refs.get(ref, "")
        if p.endswith((".swift", ".m", ".mm", ".c", ".cpp")):
            out.add(p)
    return out

committed, generated = map(sources_in_pbx, sys.argv[1:3])
only_committed = sorted(committed - generated)
only_generated = sorted(generated - committed)
if only_committed or only_generated:
    print("verify_xcodegen_project: Sources drift between committed pbxproj and project.yml", file=sys.stderr)
    if only_committed:
        print("  only in committed:", file=sys.stderr)
        for p in only_committed[:20]:
            print(f"    - {p}", file=sys.stderr)
        if len(only_committed) > 20:
            print(f"    ... +{len(only_committed) - 20} more", file=sys.stderr)
    if only_generated:
        print("  only after xcodegen:", file=sys.stderr)
        for p in only_generated[:20]:
            print(f"    + {p}", file=sys.stderr)
        if len(only_generated) > 20:
            print(f"    ... +{len(only_generated) - 20} more", file=sys.stderr)
    print("  fix: edit Lookin/project.yml then bash Lookin/Scripts/generate_xcode_project.sh", file=sys.stderr)
    sys.exit(1)
if len(committed) == 0:
    print("verify_xcodegen_project: could not parse Sources from pbxproj", file=sys.stderr)
    sys.exit(1)
print(f"verify_xcodegen_project: {len(committed)} source files match project.yml")
PY

pass "Lookin.xcodeproj in sync with project.yml"
