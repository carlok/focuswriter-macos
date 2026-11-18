#!/bin/bash
# Headless checks on a finished bundle. Safe to run in CI.
#   - every Mach-O has both slices and only bundle-local dependencies
#   - signature verifies
#   - the app starts natively and under Rosetta, and every Qt plugin it
#     tries to load actually loads (QT_DEBUG_PLUGINS)
#
# Usage: scripts/smoke.sh path/to/FocusWriter.app
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP=$(cd "${1:?usage: smoke.sh App.app}" && pwd)
EXE=$APP/Contents/MacOS/$(defaults read "$APP/Contents/Info.plist" CFBundleExecutable)
LOGDIR=$(mktemp -d)
fail=0

"$ROOT/scripts/audit.sh" "$APP" arm64 x86_64
codesign --verify --deep --strict "$APP"
echo "signature OK"

run() { # arch
	local arch=$1 log=$LOGDIR/run-$1.log pid dir=$LOGDIR/$1
	# Run a copy in FocusWriter's portable mode (a writable "Data" folder
	# next to the .app, see upstream src/main.cpp) so the run never touches
	# the user's real settings or sessions. This opens a window briefly.
	mkdir -p "$dir/Data"
	ditto "$APP" "$dir/FocusWriter.app"
	QT_DEBUG_PLUGINS=1 arch -"$arch" "$dir/FocusWriter.app/Contents/MacOS/$(basename "$EXE")" >"$log" 2>&1 &
	pid=$!
	sleep "${SMOKE_SECONDS:-8}"
	if ! kill -0 "$pid" 2>/dev/null; then
		echo "FAIL [$arch] exited early"; tail -20 "$log"; fail=1; return
	fi
	kill "$pid"; wait "$pid" 2>/dev/null || true
	if grep -E "Cannot load library|not a valid Qt plugin|Library not loaded|could not be loaded" "$log"; then
		echo "FAIL [$arch] plugin load errors"; fail=1; return
	fi
	echo "OK   [$arch] started; plugins loaded: $(grep -c 'loaded library' "$log" || true)"
}

imagecheck() { # arch
	# Build a tiny QImageReader client, drop it into a copy of the bundle so
	# it resolves the bundle's frameworks and plugins (not the build
	# machine's Qt), and load every theme background plus an SVG.
	local arch=$1 dir=$LOGDIR/img-$1 bin
	[ -n "${QTDIR:-}" ] || { echo "SKIP [image] QTDIR not set"; return; }
	mkdir -p "$dir"
	ditto "$APP" "$dir/FocusWriter.app"
	bin=$dir/FocusWriter.app/Contents/MacOS/imagecheck
	clang++ -std=c++17 -arch "$arch" -O1 -mmacosx-version-min=14.4 \
		-F"$QTDIR/lib" -I"$QTDIR/lib/QtCore.framework/Headers" -I"$QTDIR/lib/QtGui.framework/Headers" \
		-framework QtCore -framework QtGui \
		-Wl,-rpath,@executable_path/../Frameworks \
		"$ROOT/scripts/imagecheck.cpp" -o "$bin"
	codesign --force --sign - "$bin" >/dev/null
	cat >"$dir/test.svg" <<-'SVG'
		<svg xmlns="http://www.w3.org/2000/svg" width="64" height="48"><rect width="64" height="48" fill="#3a6"/><circle cx="32" cy="24" r="16" fill="#fff"/></svg>
	SVG
	gzip -c "$dir/test.svg" >"$dir/test.svgz"
	if arch -"$arch" "$bin" "$dir/test.svg" "$dir/test.svgz" "$APP"/Contents/Resources/themes/images/* >"$dir/out.log" 2>&1; then
		echo "OK   [$arch] images: $(grep -c '^OK' "$dir/out.log") loaded, SVG included"
	else
		echo "FAIL [$arch] image loading"; grep -v '^OK' "$dir/out.log"; fail=1
	fi
}

run arm64
imagecheck arm64
if arch -x86_64 /usr/bin/true 2>/dev/null; then
	run x86_64
	imagecheck x86_64
else
	echo "SKIP [x86_64] Rosetta not installed"
fi

echo "Logs: $LOGDIR"
[ $fail -eq 0 ] && echo "SMOKE OK" || { echo "SMOKE FAILED"; exit 1; }
