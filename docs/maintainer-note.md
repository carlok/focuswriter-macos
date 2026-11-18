# Note to the FocusWriter maintainer (draft, not sent)

Upstream bans LLM-generated contributions, so this is a heads-up rather than
a contribution or a request. Rewrite it in your own words before sending, and
send it the way he asks to be contacted (check gottcode.org for current contact details). The
disclosure in the second paragraph should stay in some form.

---

Subject: Unofficial macOS builds of FocusWriter

Hi Graeme,

I've started publishing unofficial universal (Apple Silicon + Intel) macOS
DMGs of FocusWriter at
https://github.com/carlok/focuswriter-macos, built by GitHub Actions from your release tags
with no source changes. They are ad-hoc signed and not notarized, and the page
says clearly that they're not affiliated with you.

To be upfront: the packaging scripts in that repository were written with
help from an AI assistant. I know your policy, which is why I'm not offering
any of it as a contribution. Feel free to ignore this, link to the builds,
or ask me to rename or take them down.

The only finding that might interest you: macdeployqt skips
imageformats/libqsvg unless the executable itself links QtSvg, so a plain
mac_deploy.sh run produces an app that can't load SVG backgrounds. That's
qtbase's macdeployqt `deployPlugins()`, if you want to look yourself.

Thanks for FocusWriter.

<your name>
