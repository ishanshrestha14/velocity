# Velocity

![License](https://img.shields.io/github/license/ishanshrestha14/velocity)
![Latest release](https://img.shields.io/github/v/release/ishanshrestha14/velocity)

A native, ultra-lightweight macOS menu-bar app that turns your Git activity into a simple, visual measure of shipping momentum.

> What did I actually ship, how much did it matter, and am I moving toward my target?

Velocity scans the local Git repositories you point it at, picks out commits by your configured author email, scores them by impact, and turns that into a daily/monthly velocity chart against a goal you set. Everything else — quick manual logging for work Git doesn't capture, work/personal scoping, a menu-bar summary of today — exists in service of that one number.

It's a personal tool that grew into something worth sharing, not a team analytics product. There's no server, no account, no telemetry — it's a single-user Mac app that reads your commits and writes one JSON file.

## Install

Grab the latest DMG from [Releases](https://github.com/ishanshrestha14/velocity/releases/latest), open it, and drag Velocity into Applications.

Velocity is ad-hoc signed, not notarized — this is a free, solo-maintained project without a paid Apple Developer account behind it. That means macOS will refuse to open it the first time with an "Apple could not verify this app" warning. To get past that (once, per install or per update):

1. Right-click (or Control-click) Velocity.app and choose **Open**, then confirm in the dialog that appears — **or**
2. If that doesn't offer an "Open" option, go to **System Settings → Privacy & Security**, scroll to the Security section, and click **Open Anyway**.

Requires macOS 15 or later.

## Building from source

- Xcode 16 or later
- `git clone https://github.com/ishanshrestha14/velocity.git`
- Open `Velocity.xcodeproj`, then Run (`⌘R`)

Swift Package dependencies (just [Sparkle](https://github.com/sparkle-project/Sparkle)) resolve automatically on first build.

```sh
# Run the test suite
xcodebuild test -project Velocity.xcodeproj -scheme Velocity -destination 'platform=macOS'
```

## How it works

1. Add one or more local Git repositories in **Settings → Repositories**, and set the Git author email whose commits should count.
2. Velocity scans on a timer (configurable) or on demand, imports matching commits, and scores each one — 1, 3, or 5 points based on a conventional-commit-style prefix in the message (`fix:` vs `feat:` vs a breaking change, roughly).
3. Anything Git doesn't capture — a design review, a support call, writing docs — gets logged by hand from the menu bar in a few seconds.
4. The dashboard shows a cumulative daily chart against a goal path you set, plus a feed of everything shipped.

Everything is local: data lives in `~/Library/Application Support/Velocity/velocity.json`, plain and human-readable. Nothing is sent anywhere.

## Auto-updates

Velocity checks for updates itself via [Sparkle](https://sparkle-project.org). Because releases are ad-hoc signed rather than notarized (see **Install** above), an update may need the same one-time "Open Anyway" step after it installs.

## Contributing

Issues and PRs are welcome. Two other docs in this repo are worth knowing about before diving in:

- **[PRD.md](PRD.md)** — the original product spec: architecture rules, design principles, the phase-by-phase plan the app was built against. Read this to understand *why* something works the way it does.
- **[PROGRESS.md](PROGRESS.md)** — the build log: what shipped in each phase, decisions made along the way, and a table of known, intentionally deferred work.

Changes ship as a branch + PR per issue, with tests. `xcodebuild test` should stay green.

## License

[MIT](LICENSE)
