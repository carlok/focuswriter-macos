#!/bin/bash
# Fetch the upstream tag, install official Qt, and build a universal
# FocusWriter.app. Nothing in the upstream source tree is modified.
#
# Usage: scripts/build.sh            (reads config.env)
# Output: work/build/FocusWriter.app
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../config.env
source "$ROOT/config.env"
WORK=${WORK:-$ROOT/work}
SRC=$WORK/src
QT_ROOT=$WORK/qt
QTDIR=$QT_ROOT/$QT_VERSION/macos
mkdir -p "$WORK"

aqt() {
	if command -v uvx >/dev/null; then
		uvx --from "aqtinstall==$AQT_VERSION" aqt "$@"
	else
		# A private venv avoids PEP 668 "externally managed" errors.
		[ -x "$WORK/venv/bin/aqt" ] || {
			python3 -m venv "$WORK/venv"
			"$WORK/venv/bin/pip" install --quiet "aqtinstall==$AQT_VERSION"
		}
		"$WORK/venv/bin/aqt" "$@"
	fi
}

# 1. Qt (official universal binaries). Pin the base URL: aqt's default
#    mirror rotation has served broken TLS certificates.
if [ ! -x "$QTDIR/bin/macdeployqt" ]; then
	echo "==> Installing Qt $QT_VERSION"
	# shellcheck disable=SC2086
	aqt install-qt mac desktop "$QT_VERSION" clang_64 -m $QT_MODULES \
		-O "$QT_ROOT" -b https://download.qt.io/
fi

# 2. Upstream source at the exact tag.
if [ ! -d "$SRC/.git" ] || [ "$(git -C "$SRC" describe --tags --exact-match 2>/dev/null)" != "$UPSTREAM_TAG" ]; then
	echo "==> Fetching $UPSTREAM_TAG"
	rm -rf "$SRC"
	git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$UPSTREAM_TAG" "$UPSTREAM_REPO" "$SRC"
fi
git -C "$SRC" rev-parse HEAD >"$WORK/upstream-commit.txt"
echo "    upstream commit $(cat "$WORK/upstream-commit.txt")"

# 3. Configure and build. FocusWriter calls project() before
#    find_package(Qt6), so Qt's own deployment target never reaches the
#    compiler; read it from Qt and pass it explicitly (it also fills
#    LSMinimumSystemVersion in Info.plist).
DEPLOYMENT_TARGET=$(sed -n 's/^set(CMAKE_OSX_DEPLOYMENT_TARGET "\([0-9.]*\)".*/\1/p' \
	"$QTDIR/lib/cmake/Qt6/qt.toolchain.cmake" "$QTDIR"/lib/cmake/Qt6/*.cmake 2>/dev/null | head -n 1)
: "${DEPLOYMENT_TARGET:?could not read Qt deployment target}"
echo "==> Building (macOS $DEPLOYMENT_TARGET+, arm64 + x86_64)"

cmake -S "$SRC" -B "$WORK/build" \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_PREFIX_PATH="$QTDIR" \
	-DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
	-DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
	-DCMAKE_IGNORE_PREFIX_PATH="/opt/homebrew;/usr/local" \
	>"$WORK/configure.log"
cmake --build "$WORK/build" --parallel "$(sysctl -n hw.ncpu)" >"$WORK/build.log"

echo "==> Built $WORK/build/FocusWriter.app"
