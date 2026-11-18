# Release runbook (target: under 30 minutes)

You get a GitHub issue "Upstream released vX.Y.Z" from the weekly watcher
workflow, or you notice a new tag at https://github.com/gottcode/focuswriter/tags.

## 1. Bump (2 min)

```bash
cd focuswriter-macos && git pull
```

Edit `config.env`: set `UPSTREAM_TAG=vX.Y.Z`. Leave `QT_VERSION` alone
unless you are doing a planned Qt bump.

## 2. Optional local build (10 min, skip if in a hurry)

```bash
scripts/build.sh && scripts/deploy.sh && scripts/sign.sh work/stage/FocusWriter.app && QTDIR=$PWD/work/qt/$(. ./config.env; echo $QT_VERSION)/macos scripts/smoke.sh work/stage/FocusWriter.app
```

It must end with `AUDIT OK` and `SMOKE OK`. If upstream added a Qt module,
`build.sh` fails at configure time: add the module to `QT_MODULES` in
`config.env`.

## 3. Tag and push (1 min)

```bash
git commit -am "Package vX.Y.Z" && git tag vX.Y.Z-mac1 && git push && git push origin vX.Y.Z-mac1
```

`-mac1` is the package revision. Use `-mac2` for a packaging-only fix of the
same upstream version.

## 4. Wait for CI (~15 min)

```bash
gh run watch
```

The workflow builds, audits, signs, smoke-tests, attests and creates a
**draft** release.

## 5. Check the draft (5 min)

```bash
gh release download vX.Y.Z-mac1 -D /tmp/fw && cd /tmp/fw && shasum -a 256 -c SHA256SUMS && gh attestation verify *.dmg --repo carlok/focuswriter-macos
```

Open the DMG, drag the app somewhere, and open it via the README's
"Open Anyway" route. Then check, in about two minutes:

- A theme with an image background shows the image (Settings → Themes).
- Type `teh` and it gets a red underline.
- Open any `.docx` or `.odt` file and it shows formatted text.

## 6. Publish (1 min)

```bash
gh release edit vX.Y.Z-mac1 --draft=false --latest
```

Close the watcher issue.

## If CI fails

- *aqt download error*: re-run the job (mirror hiccup). If it persists, try
  the latest aqtinstall in `AQT_VERSION`.
- *AUDIT FAILED / MISSING*: a new plugin or library with an unresolved
  dependency. Read the line, then extend `deploy.sh` with another
  `-executable=` or `-libpath=`. Never delete plugins to make it pass.
- *Runner label gone*: update `runs-on` in `.github/workflows/release.yml`.

## Qt bump (about once a year)

Set `QT_VERSION` (and check `aqt list-qt mac desktop`), then run step 2.
Note the new minimum macOS in the README if Qt changed it, and release as
`-macN+1`.
