#!/bin/bash
# Make a self-contained copy of FocusWriter.app: Qt frameworks, plugins and
# Qt translations, with no plugin removed.
#
# Usage: scripts/deploy.sh            (reads config.env)
# Output: work/stage/FocusWriter.app
#
# Why the extra step for libqsvg: macdeployqt only deploys
# imageformats/libqsvg when the *executable* already links QtSvg
# (qtbase src/tools/macdeployqt/shared/shared.cpp, deployPlugins()).
# FocusWriter reads SVG backgrounds through QImageReader and never links
# QtSvg, so a plain macdeployqt run silently drops SVG support. Placing the
# plugin first and passing it with -executable makes macdeployqt copy QtSvg
# and fix the plugin's install names like any other binary.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../config.env
source "$ROOT/config.env"
WORK=${WORK:-$ROOT/work}
QTDIR=$WORK/qt/$QT_VERSION/macos
STAGE=$WORK/stage
APP=$STAGE/FocusWriter.app

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$WORK/build/FocusWriter.app" "$STAGE/"

echo "==> Copying Qt translations"
TRANSLATIONS=$APP/Contents/Resources/translations
mkdir -p "$TRANSLATIONS"
cp "$QTDIR"/translations/qt_*.qm "$QTDIR"/translations/qtbase_*.qm "$TRANSLATIONS/"
rm -f "$TRANSLATIONS"/qt_help_*

echo "==> Placing SVG image plugin"
mkdir -p "$APP/Contents/PlugIns/imageformats"
cp "$QTDIR/plugins/imageformats/libqsvg.dylib" "$APP/Contents/PlugIns/imageformats/"

echo "==> Running macdeployqt"
"$QTDIR/bin/macdeployqt" "$APP" \
	-executable="$APP/Contents/PlugIns/imageformats/libqsvg.dylib" \
	-verbose=1 >"$WORK/macdeployqt.log" 2>&1
if grep -q '^ERROR' "$WORK/macdeployqt.log"; then
	grep '^ERROR' "$WORK/macdeployqt.log"
	exit 1
fi

# Mark the bundle as an unofficial build where Finder shows it (Get Info).
# Text only: name, bundle id and settings location stay upstream's. The
# bundle is (re)signed after this step.
echo "==> Labelling as unofficial build"
PLIST=$APP/Contents/Info.plist
COPYRIGHT=$(/usr/libexec/PlistBuddy -c 'Print :NSHumanReadableCopyright' "$PLIST")
plutil -replace NSHumanReadableCopyright \
	-string "$COPYRIGHT. Unofficial macOS build: ${PACKAGER_URL#https://}" "$PLIST"

echo "==> Auditing bundle"
"$ROOT/scripts/audit.sh" "$APP" arm64 x86_64

for p in imageformats/libqsvg.dylib iconengines/libqsvgicon.dylib platforms/libqcocoa.dylib; do
	[ -f "$APP/Contents/PlugIns/$p" ] || { echo "Missing plugin $p"; exit 1; }
done
echo "==> Deployed $APP"
