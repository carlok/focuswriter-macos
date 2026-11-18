#!/bin/bash
# Package the signed app into a compressed DMG with an Applications link,
# the license and a ReadMe (same contents as upstream's mac_deploy.sh), and
# write SHA256SUMS next to it.
#
# Usage: scripts/dmg.sh [revision]      e.g. scripts/dmg.sh 1
# Output: dist/FocusWriter-<version>-macOS-universal[-rN].dmg, dist/SHA256SUMS
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../config.env
source "$ROOT/config.env"
WORK=${WORK:-$ROOT/work}
SRC=$WORK/src
APP=$WORK/stage/FocusWriter.app
DIST=${DIST:-$ROOT/dist}
REVISION=${1:-}

VERSION=$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString)
NAME="FocusWriter-$VERSION-macOS-universal${REVISION:+-r$REVISION}"
DISK=$WORK/disk/FocusWriter

echo "==> Preparing disk folder"
rm -rf "$WORK/disk"
mkdir -p "$DISK" "$DIST"
ditto "$APP" "$DISK/FocusWriter.app"
ln -s /Applications "$DISK/Applications"
cp "$SRC/COPYING" "$DISK/License.txt"
{
	cat "$SRC/README"
	printf '\n\nCREDITS\n=======\n\n'
	cat "$SRC/CREDITS"
	printf '\n\nNEWS\n====\n\n'
	cat "$SRC/ChangeLog"
} >"$DISK/Read Me.txt"

# The bundle ships Qt and FFmpeg as shared libraries (LGPL). Include their
# license texts and say where the corresponding source is.
QTDIR=$WORK/qt/$QT_VERSION/macos
FFMPEG_VERSION=$(python3 -c '
import json, sys
for p in json.load(open(sys.argv[1])).get("packages", []):
    if p.get("name") == "FFmpeg":
        print(p.get("versionInfo")); break
' "$QTDIR/sbom/qtmultimedia-$QT_VERSION.spdx.json" 2>/dev/null || true)
LICENSES="$DISK/Third-Party Licenses"
mkdir -p "$LICENSES"
cp "$ROOT/licenses/LGPL-3.0.txt" "$ROOT/licenses/LGPL-2.1.txt" "$LICENSES/"
cat >"$LICENSES/Notice.txt" <<EOF
FocusWriter.app contains these libraries, unmodified, as separate shared
libraries in Contents/Frameworks and Contents/PlugIns. You may replace them
with your own builds of the same versions.

Qt $QT_VERSION (The Qt Company), LGPL-3.0 (LGPL-3.0.txt; GPL-3.0 in License.txt)
  Source: https://download.qt.io/official_releases/qt/${QT_VERSION%.*}/$QT_VERSION/

FFmpeg ${FFMPEG_VERSION:-(as bundled with Qt $QT_VERSION)}, LGPL-2.1-or-later (LGPL-2.1.txt)
  Source: https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION:-}.tar.xz
  (Qt's FFmpeg build is described in the SBOM files of the Qt $QT_VERSION
  install, directory sbom/.)

Packaging scripts: $(git -C "$ROOT" remote get-url origin 2>/dev/null || echo 'see the release page')
EOF

echo "==> Creating $NAME.dmg"
rm -f "$DIST/$NAME.dmg"
hdiutil create -quiet -volname FocusWriter -srcfolder "$DISK" \
	-fs HFS+ -format UDZO -imagekey zlib-level=9 "$DIST/$NAME.dmg"

# The bundle inside the image must still verify after packaging.
MNT=$(mktemp -d)
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$MNT" "$DIST/$NAME.dmg"
codesign --verify --deep --strict "$MNT/FocusWriter.app"
hdiutil detach -quiet "$MNT"
rmdir "$MNT"

(cd "$DIST" && shasum -a 256 "$NAME.dmg" >SHA256SUMS)
cat "$DIST/SHA256SUMS"
