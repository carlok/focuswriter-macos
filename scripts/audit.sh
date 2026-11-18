#!/bin/bash
# Audit a deployed .app bundle: every Mach-O must only load libraries that
# are either system libraries or present inside the bundle, and (optionally)
# must contain every required architecture.
#
# Usage: audit.sh FocusWriter.app [required-archs...]
# Example: audit.sh FocusWriter.app arm64 x86_64
set -euo pipefail

APP=${1:?usage: audit.sh App.app [archs...]}
shift
REQUIRED_ARCHS=("$@")
APP=$(cd "$APP" && pwd)
FRAMEWORKS="$APP/Contents/Frameworks"
EXE_DIR="$APP/Contents/MacOS"
MAIN_EXE="$EXE_DIR/$(defaults read "$APP/Contents/Info.plist" CFBundleExecutable)"
fail=0

is_macho() { file -b "$1" | grep -q 'Mach-O'; }

# Resolve an install name relative to the binary that loads it.
resolve() {
	local dep=$1 bin=$2 rpath
	case "$dep" in
	/System/* | /usr/lib/*) echo SYSTEM; return ;;
	@executable_path/*) echo "$EXE_DIR/${dep#@executable_path/}"; return ;;
	@loader_path/*) echo "$(dirname "$bin")/${dep#@loader_path/}"; return ;;
	@rpath/*)
		# dyld searches the rpaths of every image in the load chain; the
		# main executable is always in it, so include its rpaths too.
		while read -r rpath; do
			rpath=${rpath/@executable_path/$EXE_DIR}
			rpath=${rpath/@loader_path/$(dirname "$bin")}
			if [ -e "$rpath/${dep#@rpath/}" ]; then
				echo "$rpath/${dep#@rpath/}"
				return
			fi
		done < <({
			otool -l "$bin" | awk '/LC_RPATH/{getline; getline; print $2}'
			otool -l "$MAIN_EXE" | awk '/LC_RPATH/{getline; getline; print $2}' |
				sed "s|@loader_path|@executable_path|"
		})
		echo "UNRESOLVED"
		return
		;;
	*) echo "OUTSIDE:$dep" ;;
	esac
}

checked=0
while IFS= read -r -d '' f; do
	is_macho "$f" || continue
	checked=$((checked + 1))
	rel=${f#"$APP"/}

	if [ ${#REQUIRED_ARCHS[@]} -gt 0 ]; then
		archs=$(lipo -archs "$f" 2>/dev/null || true)
		for a in "${REQUIRED_ARCHS[@]}"; do
			if ! grep -qw "$a" <<<"$archs"; then
				echo "ARCH   $rel: missing $a (has: $archs)"
				fail=1
			fi
		done
	fi

	# Dependency lines are tab-indented; header lines ("path:" or, for
	# universal binaries, "path (architecture x):") are not. A dylib also
	# lists its own install id, which is not a dependency.
	own_id=$(otool -D "$f" | grep -v ':$' | head -n 1 || true)
	otool -L "$f" | grep $'^\t' | awk '{print $1}' | sort -u | while read -r dep; do
		[ "$dep" = "$own_id" ] && continue
		r=$(resolve "$dep" "$f")
		case "$r" in
		SYSTEM) ;;
		UNRESOLVED) echo "MISSING $rel -> $dep" ;;
		OUTSIDE:*) echo "OUTSIDE $rel -> ${r#OUTSIDE:}" ;;
		"$APP"/*) [ -e "$r" ] || echo "MISSING $rel -> $dep" ;;
		# Resolved, but only via a path on the build machine (e.g. a
		# leftover /opt/homebrew/lib rpath): broken on any other Mac.
		*) echo "OUTSIDE $rel -> $dep (found at $r)" ;;
		esac
	done
done < <(find "$APP/Contents" -type f -print0) | tee "${TMPDIR:-/tmp}/audit.$$" || true

if [ -s "${TMPDIR:-/tmp}/audit.$$" ]; then fail=1; fi
rm -f "${TMPDIR:-/tmp}/audit.$$"

# Plugins that macdeployqt copied but whose Qt module is absent are the
# classic failure; list plugin dirs for the log.
echo "Plugin directories: $(ls "$APP/Contents/PlugIns" 2>/dev/null | tr '\n' ' ')"

if [ $fail -ne 0 ]; then
	echo "AUDIT FAILED"
	exit 1
fi
echo "AUDIT OK"
