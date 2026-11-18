# FocusWriter for macOS (unofficial builds)

Universal (Apple Silicon + Intel) macOS disk images of
[FocusWriter](https://gottcode.org/focuswriter/), the distraction-free word
processor by Graeme Gott.

- Built from the **unmodified** upstream release tag. This repository holds
  only packaging scripts: no FocusWriter source code, no patches.
- **Not affiliated with or endorsed by the FocusWriter author.** Report app
  bugs to [upstream](https://gottcode.org/focuswriter/); report packaging
  problems (won't open, missing images, crashes on start) here.
- Signed ad-hoc, **not notarized** by Apple. macOS will refuse to open it the
  first time; the one-time fix is below.
- Requires macOS 14.4 or later (set by the Qt version used).

Download the `.dmg` and `SHA256SUMS` from
[Releases](../../releases). Only download from this page: other "FocusWriter
installer" repositories on GitHub are not this project.

## Install

**1. Verify the download (optional, recommended).** In Terminal, in the folder
with both files:

```bash
shasum -a 256 --ignore-missing -c SHA256SUMS
```

It must print `OK`. With the [GitHub CLI](https://cli.github.com) you can also
check that the file was built by this repository's workflow from a public
commit:

```bash
gh attestation verify FocusWriter-*.dmg --repo carlok/focuswriter-macos
```

**2. Copy the app.** Open the `.dmg` and drag **FocusWriter** onto
**Applications**.

**3. Allow it to open (once).** Pick one:

- **System Settings route.** Double-click FocusWriter. macOS says it
  "could not verify" the app: click **Done** (not *Move to Trash*). Open
  **System Settings → Privacy & Security**, scroll to *Security*, click
  **Open Anyway** next to the FocusWriter message, confirm with your password
  or Touch ID, then click **Open Anyway** again. The button appears only for
  about an hour after the blocked attempt.
- **Terminal route.**

  ```bash
  xattr -dr com.apple.quarantine /Applications/FocusWriter.app
  ```

  Then open FocusWriter normally.

Either way you do this once per downloaded version. Control-click → Open no
longer bypasses this check on current macOS.

## Why not notarized?

Notarization needs a paid Apple Developer account. Instead, every release has
a SHA-256 checksum and a
[GitHub build provenance attestation](https://docs.github.com/actions/security-for-github-actions/using-artifact-attestations)
that ties the `.dmg` to the exact workflow run and commit that produced it.

## Building locally

Needs Xcode Command Line Tools, CMake and Python 3 (or `uv`). The Qt download
is about 1 GB.

```bash
scripts/build.sh && scripts/deploy.sh && scripts/sign.sh work/stage/FocusWriter.app && scripts/dmg.sh
```

`scripts/smoke.sh work/stage/FocusWriter.app` checks the result (set `QTDIR`
to `work/qt/<version>/macos` to include the image-plugin test). See
[docs/RUNBOOK.md](docs/RUNBOOK.md) for releases and
[docs/DECISION.md](docs/DECISION.md) for the background.

## License

FocusWriter is © Graeme Gott and licensed under the GNU GPL v3 or later; each
DMG includes its license as `License.txt`, and each release carries the exact
corresponding source as `focuswriter-<version>-source.tar.gz`. The packaging scripts in this
repository are also GPL-3.0-or-later (see `LICENSE`). Qt is used under the
LGPL v3.
