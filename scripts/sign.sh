#!/bin/bash
# Ad-hoc sign an app bundle inside-out: loose dylibs and plugins, then
# frameworks, then the app. Apple Silicon refuses to run unsigned arm64
# code, and install_name_tool/strip invalidate existing signatures.
#
# Ad-hoc means no identity: Gatekeeper will still reject the app on first
# launch (see README). No hardened runtime: with ad-hoc signatures there is
# no Team ID, so library validation would refuse to load our own frameworks.
#
# Usage: scripts/sign.sh path/to/FocusWriter.app
set -euo pipefail

APP=$(cd "${1:?usage: sign.sh App.app}" && pwd)
MAIN_EXE=$(defaults read "$APP/Contents/Info.plist" CFBundleExecutable)
sign() { codesign --force --sign - --timestamp=none "$1"; }

is_macho() { file -b "$1" | grep -q 'Mach-O'; }

echo "==> Signing nested code"
# 1. Every Mach-O that is not inside a framework and is not the main
#    executable (plugins, loose dylibs such as FFmpeg).
while IFS= read -r -d '' f; do
	case "$f" in */Contents/MacOS/*) continue ;; esac
	is_macho "$f" && sign "$f"
done < <(find "$APP/Contents" -type f -not -path '*.framework/*' -print0)

# 2. Frameworks, signed as bundles (their Versions/A).
while IFS= read -r -d '' fw; do
	sign "$fw/Versions/A"
done < <(find "$APP/Contents/Frameworks" -maxdepth 1 -name '*.framework' -print0)

# 3. Any extra executables, then the app itself (seals Resources).
while IFS= read -r -d '' f; do
	[ "$(basename "$f")" = "$MAIN_EXE" ] && continue
	is_macho "$f" && sign "$f"
done < <(find "$APP/Contents/MacOS" -type f -print0)
sign "$APP"

echo "==> Verifying"
codesign --verify --deep --strict --verbose=2 "$APP"
echo "==> Gatekeeper assessment (expected to be rejected for ad-hoc code):"
spctl -a -vv -t exec "$APP" 2>&1 || true
