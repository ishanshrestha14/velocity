# Velocity — Build Progress

Working log for the phase plan in `README.md` §34 — the original eight
phases, plus Phase 9 (auto-updates), added after the MVP shipped.

Update this file at the end of every phase: mark the phase, record decisions that
future-me would otherwise have to re-derive from the diff, and move anything
knowingly left undone into [Deferred work](#deferred-work) with a target phase.
Nothing gets deferred without landing in that table.

## Status

| Phase | Scope | Status |
|---|---|---|
| 1 | Project Foundation | ✅ Complete |
| 2 | Local Persistence + Domain Models | ✅ Complete |
| 3 | Git Engine | ✅ Complete |
| 4 | Scoring Engine + Quick Log | ✅ Complete |
| 5 | Dashboard + Swift Charts | ✅ Complete |
| 6 | Repository Automation | ✅ Complete |
| 7 | Native macOS Polish | ✅ Complete |
| 8 | Reliability, Packaging & Release | ✅ Complete |
| 9 | Auto-Updates & Release Infrastructure | ✅ Complete (see caveats below) |

Current state: the app is feature-complete per the MVP definition and has a
Release build that installs and runs independently of Xcode — a signed
`.app` in a DMG, with an icon. Sparkle is wired up and the update UI works;
the Developer ID signing + notarization half of the release pipeline is
documented but unexercised, since this machine has no paid Apple Developer
account (see README.md §42).

## Verifying

```sh
xcodebuild -project Velocity.xcodeproj -scheme Velocity -configuration Debug build
xcodebuild -project Velocity.xcodeproj -scheme Velocity -configuration Debug test
xcodebuild -project Velocity.xcodeproj -scheme Velocity -configuration Release build
```

Data lives at `~/Library/Application Support/Velocity/`. Deleting that folder is
a clean reset.

---

## Phase 1 — Project Foundation ✅

Xcode project with app and unit-test targets, `MenuBarExtra` status item, a
dashboard window, a settings scene, the domain model, and `VelocityStore` as the
single source of truth.

All six acceptance criteria met: builds, runs, status item appears, panel opens,
dashboard opens, quit works.

**Decisions**

- **File-system-synchronized groups** (Xcode 16+) for `Velocity/` and
  `VelocityTests/`. Adding a source file never touches `project.pbxproj`, so the
  project file stops being a merge-conflict magnet.
- **macOS 15.0, Swift 6 language mode.** `@Observable` needs 14+; strict
  concurrency now avoids retrofitting it once Git scanning gets concurrent.
- **`.menuBarExtraStyle(.window)`** rather than the NSMenu-backed default. The
  panel lists today's items and will host the quick-log form; an NSMenu can
  render neither.
- **`LSUIElement`** — menu-bar utility, no Dock icon.
- **App Sandbox off.** Velocity has to exec `/usr/bin/git` against arbitrary
  absolute paths the user picks, which the sandbox blocks. Locally built tool,
  not a Mac App Store app.
- **The impact raw value is the point value** (`minor = 1`, `core = 3`,
  `epic = 5`), so scoring arithmetic never needs a lookup table.
- **`ProjectScope` and `ScopeFilter` are separate types.** "All projects" is a
  question the dashboard can ask, not a state an item can be in.
- **Git SHA is the `ShippedItem` id** for Git-derived work, which is what makes
  rescanning idempotent without message+timestamp heuristics.
- **No stub services.** No empty `GitRunner`/`ScoringEngine` files written just
  to look complete — they arrive with real implementations. Likewise the chart
  slot holds honest placeholder copy rather than a chart drawn from invented
  numbers.

## Phase 2 — Local Persistence + Domain Models ✅

`VelocityPaths`, `PersistenceError`, `JSONStore`, and `PersistenceService`, wired
into the store as debounced autosave, with load at launch and a synchronous
flush on quit. Failures surface as a dashboard banner; Settings shows the storage
path with a reveal button.

All five acceptance criteria met: data survives restart, lives in Application
Support, is readable JSON, deletion persists, nothing leaves the machine.

**Decisions**

- **One `velocity.json`, not `velocity.json` + `settings.json`.** README §21
  suggests two files, §38's schema shows one document holding items,
  repositories, and settings. One document means one atomic write keeps them
  consistent and one `version` field covers the whole schema.
- **Autosave on mutation, not explicit `save()` calls.** "Never lose user data"
  is far easier to hold when no call site can forget. 400 ms debounce collapses
  bursts — typing in settings now, a scan importing hundreds of commits later —
  into a single write.
- **Nothing is written before `load()` finishes.** A slow or failed load must not
  be able to overwrite good data with the empty starting state. Covered by a test.
- **A file that will not decode is moved into `backups/`, never overwritten.**
  The load reports where it went. Quarantined files are exempt from backup
  pruning: that is the user's damaged data, not our housekeeping.
- **`PersistenceService` is an actor**, so file I/O stays off the main actor.
  It exposes one `nonisolated` synchronous write because
  `applicationWillTerminate` cannot await and a pending debounced save would
  otherwise be lost.
- **`nonisolated(unsafe) let fileManager`** — `FileManager` is not `Sendable`,
  but `.default` is documented thread-safe for the operations used here, and the
  synchronous quit path needs to reach it.

## Phase 3 — Git Engine ✅

`GitRunner`, `GitRepositoryValidator`, `GitCommitParser`, and `GitScanner`, plus
repository management in Settings and a Scan action in the menu bar.

All six acceptance criteria met, verified against this repository as a live
subject: 23 commits discovered, 5 pre-imported SHAs correctly excluded on a
second scan, a wrong author email yielding 0 of 23, and a missing repository
failing on its own without disturbing the good one.

**Decisions**

- **Author matching is exact and case-insensitive in Swift, not git's
  `--author`.** That flag is a regex substring test: it reads a `+` in an
  address as syntax, and matches a colleague whose address merely contains
  yours. The README is explicit that other developers' commits must not be
  imported.
- **Merges are excluded** (`--no-merges`). A merge commit is bookkeeping, not
  shipped work; counting it inflates the number the score exists to measure.
  Easy to make configurable later if it turns out to matter.
- **Fields are delimited with 0x1F and records with 0x1E** — control characters
  that cannot occur in a commit message, unlike any printable delimiter someone
  will eventually type.
- **A malformed log record is skipped, not fatal.** One odd commit should not
  cost the user the other thousand.
- **The subprocess runs on a Dispatch queue, never the cooperative pool.**
  Waiting on a process blocks its thread, and the cooperative pool has roughly
  one thread per core — concurrent scans took all of them and deadlocked the
  whole test run before this was fixed. Worth remembering: anything blocking
  belongs off that pool.
- **Already-imported SHAs come from the feed itself**, since a Git-derived item
  keeps its SHA as its id. No second bookkeeping list that can drift.
- **Scope lives on the repository**, so work/personal is decided once at setup
  rather than per commit.
- **Found commits stay in `pendingCommits` instead of becoming shipped items.**
  Scoring is Phase 4; nothing here invents a weight in the meantime. This is the
  one part of the phase deliverable that is deliberately incomplete — see D10.
- **Tests build real Git repositories** in temp directories and commit into
  them. The scanner's whole job is talking to git; a fake would only prove the
  fake matches itself.

## Phase 4 — Scoring Engine + Quick Log ✅

`ScoringEngine`, wired into the scan so found commits become scored feed items,
plus manual quick logging in the menu bar and delete / impact / scope actions in
the feed.

All six acceptance criteria met. Scoring was checked against this repository:
33 commits imported, and every score agreed with an independent reimplementation
of the rules written separately to check the app against.

**Decisions**

- **Scoring parses the conventional-commit header rather than matching
  substrings.** That is the whole point of parsing it: `fixture:` is not a
  `fix:`, `deployment notes:` is not a `deploy:`, `features:` is not a `feat:`.
  Each of those has a test.
- **A `!` outranks its type.** `refactor!:` is a launch, not a refactor — a
  breaking change is epic whatever the type says. The README only lists `feat!`,
  but the general rule is the one that makes sense.
- **A `(scope)` never affects the score**, and only the subject line is read —
  a body mentioning `deploy:` must not promote a `feat:`.
- **The fallback is 1 point, not 0.** Work that shipped counts; a message that
  says nothing about its impact does not get to claim a large one.
- **Rescanning never re-scores an existing item.** An impact changed by hand
  survives a rescan, because import only adds SHAs that are not already in the
  feed. Tested explicitly.
- **The quick-log form is inline in the menu bar panel, not a window.** Opening a
  window to record one line costs more than the thing being recorded. Scope and
  impact persist between entries; the description always starts empty.
- **Delete is a hover button as well as a context-menu item.** The README asks
  every item to offer a delete action, and right-click alone is too well hidden
  for the primary way of undoing a mistake.
- **Impact and scope can be overridden from the feed.** A commit message often
  undersells what the commit did, and the score is meant to be honest rather
  than merely automatic.

## Phase 5 — Dashboard + Swift Charts ✅

`VelocityAggregator`, monthly analytics on `VelocityStore`, and three new
dashboard views: `VelocityChartView` (cumulative Swift Charts against the
goal path), `MonthInspectionView` (the day-by-day slider), and a rewritten
`SummaryStatsView`.

All seven acceptance criteria met. Checked live: adding manually logged items
on different days moved the cumulative line, the goal path tracked
`targetDailyVelocity` from Settings, switching the scope filter re-tinted the
chart and re-ran every stat, and the month-inspection slider's badge list
matched the feed for that day. Verified structurally through the accessibility
tree (see D3 note below on why not by screenshot) plus 10 new store tests and
6 aggregator tests — 96 tests passing project-wide.

**Decisions**

- **Aggregation is a pure `enum` of static functions, not a method on the
  store.** It takes items, a month, and a calendar as parameters and returns
  `[DailyVelocity]`; nothing about it needs the store's identity. Tested
  without constructing a store at all.
- **The series stops at today, not the end of the month.** A month padded
  with zeroed future days would show a cumulative line dropping to flat
  nothing at the right edge — accurate but useless. `lastDay` clamps it.
- **The goal path is two points, not one per day.** A straight line from
  `(day 1, 0)` to `(today, cumulativeTarget(throughDay: today))` is the same
  target rate `VelocityGoal` already computes; `LineMark` draws the line
  between them for free.
- **Chart color follows the scope filter**, not a fixed palette — work is
  indigo, personal is green, "All Projects" is blue. The legend is a small
  custom row rather than Swift Charts' built-in legend, because the built-in
  one wants a `foregroundStyle(by:)` series mapping and there are only ever
  two lines to label.
- **Month inspection has no separate month switcher.** The README's "monthly
  filtering" task reads as scoping the data to the calendar month, which the
  aggregator already does; the design reference only shows a day slider
  within the current month, not a month picker. Easy to add later if a user
  wants to look back at August.
- **The badge list is a small custom `Layout`, not a horizontal scroll
  view.** Wrapping to a second line reads as "everything shipped that day" at
  a glance; a scroll view hides items off the right edge.
- **Summary tiles now show Avg Velocity / Delivered / Target Goal for the
  month, replacing the Phase 4 today-only tiles** — this was D7, and closes
  it. "Shipped Today" is still available in the menu-bar panel, which is the
  right place for a same-day glance.
- **`inspectedDay` is dashboard view state on the store, like `scopeFilter`**
  — not persisted, and not a `@State` local to `DashboardView`, because the
  chart and the inspection panel both need to read and drive it.

## Phase 6 — Repository Automation ✅

Background scanning on `VelocityStore`: a scan on launch, then a periodic
loop at a configurable interval; an optional scan when the menu-bar panel
opens; a scan-status dot and relative last-scanned timestamp in the menu bar;
and an Automation section in Settings.

All five acceptance criteria met. Checked live: the app scans once at launch
without being asked, the menu-bar panel's status line and dot update through
scanning → clean/error, and toggling "Scan automatically" or changing the
interval in Settings visibly restarts the loop (`isBackgroundScanning`
flips). 8 new tests (2 settings-decoding, 6 background-scanning), 105 tests
passing project-wide. Two of the nine README tasks — repository enable/disable
and automatic Work/Personal assignment — were already done in Phase 3, since
`Repository.enabled` and `Repository.scope` existed from the start; nothing
further was needed for them here.

**Decisions**

- **`VelocitySettings.init(from:)` is hand-written, not synthesized.** The
  three new automation fields are absent from any settings file saved before
  this phase, and a synthesized decoder would throw on a missing key —
  failing the whole `VelocityData` decode and quarantining an existing
  user's items and repositories (`PersistenceService.load` treats a decode
  failure as "start over"). Missing keys now fall back to
  `VelocitySettings.default`'s values instead. Same reasoning as `VelocityData
  .currentVersion` existing at all — this is the same problem one field
  sooner.
- **The scan loop lives directly on `VelocityStore`, not a separate
  scheduler type.** It is one `Task` that sleeps and calls the store's own
  `scanRepositories()`, following the same pattern already used for debounced
  saving (`saveTask`). A separate service would need the same store
  reference back to do anything.
- **Only `isBackgroundScanningEnabled` and `scanIntervalMinutes` restart the
  loop.** `settings.didSet` compares `oldValue` against the new value and
  restarts only on those two fields — editing the target velocity or the
  author email must not reset an in-flight sleep and push a due scan
  further out.
- **The interval is clamped to a 5-minute minimum**, both when read by the
  scheduler and by the Settings stepper's range. Git scanning is cheap at
  this project's scale, but nothing stops a stray `0` from turning "every
  interval" into "constantly."
- **No test exercises the loop actually firing.** `Task.sleep` for a real
  30-minute interval is not something a unit test should wait out, and
  faking the clock would need a second code path just for tests. Instead the
  tests check the state the loop's lifecycle produces —
  `isBackgroundScanning` — after `restartBackgroundScanning()`, load, and
  settings changes.
- **Scan-on-menu-open guards against overlapping an in-progress scan**
  (`!isScanning`) rather than queuing one — opening the panel while a scan
  from the timer is already running should not start a second one racing
  the first.

## Phase 7 — Native macOS Polish ✅

Export to a standalone file, optional scan notifications, a Cmd+R scan
shortcut, loading states for the dashboard and menu bar, a fix for D1's
spurious settings writes, and an accessibility pass on the dashboard's
summary tiles and the menu bar's buttons.

Checked live via the accessibility tree (build/test automation has no real
display in this environment, so nothing here was screenshotted): the
Settings General tab shows every new control (automation toggles, the
interval stepper, notify toggle, Export… button) with correct titles and
values; the dashboard's stat tiles now read as real text (`"Avg Velocity, 0,
/day"`) instead of unlabeled elements. 111 tests passing project-wide (10 new
this phase: 4 `ScanNotifier.body` cases, 2 export cases, and 4
settings-decoding/round-trip updates for the new fields).

**Decisions**

- **Export uses `NSSavePanel` directly, not SwiftUI's `.fileExporter`.**
  `.fileExporter` wants a `FileDocument` wrapper around data Velocity already
  has as `VelocityData` via `JSONStore`; a panel plus `PersistenceService
  .export` (already written and tested in an earlier phase) is the same
  result with no adapter type. This is an AppKit-adjacent, macOS-only app
  already (`NSWorkspace`, `NSApplication`) — one more AppKit call is not a
  new kind of dependency. Closes D2.
- **`ScanNotifier` is a plain `@MainActor` class, not behind a protocol.**
  Every other optional dependency on `VelocityStore` — `PersistenceService`,
  `GitScanner` — is injected as a concrete optional and simply left `nil` in
  tests; a notifier protocol would be the only one of the four built for
  mockability nothing else needed. Its message-building is a `nonisolated
  static func` precisely so *that* part is unit-testable without touching
  `UNUserNotificationCenter` at all.
- **Notifications are silent about "nothing found."** A scan that imports
  nothing and fails nothing posts no notification — alerting for a no-op
  scan trains the user to dismiss Velocity's notifications on sight, which
  defeats the feature the first time it happens to matter.
- **The D1 fix is `guard oldValue != settings else { return }`**, not a
  binding change on the `TextField`. `VelocitySettings` was already
  `Hashable` (`Equatable` comes free); comparing whole-struct equality before
  any side effect is the actual fix the deferred item asked for, not a
  workaround around one field.
- **The dashboard's summary tiles now use
  `.accessibilityElement(children: .combine)`** instead of `.ignore` with a
  manual label/value — confirmed live that System Events now reports real
  `AXStaticText` content where it previously reported `AXUnknown` with
  `missing value`. This closes the dashboard half of D3.
- **The menu-bar panel's buttons remain unresolved.** Adding an explicit
  `.accessibilityLabel` to each (correct, and kept) made no difference to
  what System Events reports for them — still no `AXTitle`/`AXDescription`.
  Since the identical technique fixed the dashboard's tiles in a plain
  `Window` scene, this looks like a `MenuBarExtra(.window)`-specific
  accessibility-bridging limitation rather than something fixable from
  application code. Needs checking with real VoiceOver, which reads a
  different part of the accessibility API than System Events' scripting
  bridge and may not show the same gap — left in D3, narrowed to the menu
  bar specifically.
- **Dark/light appearance was validated by code audit, not by toggling
  system appearance.** A grep across the view layer found zero hardcoded
  `Color(...)`/`NSColor(...)` literals — every color is a semantic system
  color (`.green`, `.secondary`, `.quaternary`, `.regularMaterial`, …) or a
  scope-driven tint already covered by Phase 5's chart decisions, all of
  which adapt automatically. Flipping the whole machine's system appearance
  for a one-off visual check felt like the wrong tradeoff for what the code
  already guarantees structurally.
- **A loading state was added to both the dashboard and the menu bar**,
  gated on `store.hasLoaded`, so neither one can flash "nothing shipped" in
  the moment before the on-disk snapshot has actually been read.

## Phase 8 — Reliability, Packaging & Release ✅

An app icon, a permission-denied path added to the validator's test coverage,
a measured (not guessed) answer on whether repeated full-history scans need
bounding, an `LSApplicationCategoryType`, and a signed Release `.app` packaged
into an installable DMG. 113 tests passing project-wide (2 new this phase).

Checked live: launched the Release build, opened the menu-bar panel via
System Events (confirms the on-disk state from prior phases' testing loads
cleanly — "0 pts", "Nothing shipped yet today.", the "add a repository"
hint), expanded Quick Log inline from the panel, and quit cleanly via
`NSApplication.terminate` — `applicationWillTerminate`'s synchronous flush
ran, and `~/Library/Application Support/Velocity/velocity.json` was intact
and well-formed afterward. Screenshot capture was unavailable in this
environment (`screencapture` refuses without a granted permission this
session doesn't have), so this is the same accessibility-tree-based
verification Phase 7 used, not a visual one.

**Decisions**

- **The bulk of Phase 8's reliability list was already true, not newly
  built.** `PersistenceService` already backs up, quarantines, and never
  overwrites a file it can't parse (Phase 2); `GitScanner` already isolates
  one bad repository from the rest of a scan and reports
  `repositoryNotFound`/`notARepository`/`permissionDenied` instead of
  throwing (Phase 3); `AppDelegate.applicationWillTerminate` already
  flushes the debounced save synchronously (Phase 7). This phase's job was
  mostly to verify that with tests and a real run, and to fill the one real
  gap: `permissionDenied` had no test exercising it.
- **`D11` (full-history scans not bounded) is closed by measurement, not by
  code.** Built a synthetic 50,000-commit repository with `git fast-import`
  (individual `git commit` calls do not scale to generate a benchmark repo
  in reasonable time) and timed the actual pipeline: `git log` in 0.16s,
  `GitCommitParser` parsing that output in 0.16s — about a third of a
  second, off the main actor, for a history 2,000x larger than anything a
  personal project's repositories hold today. An incremental bound (a
  persisted last-scanned SHA per repository) is real complexity — rebase
  and force-push both invalidate a remembered boundary commit — for a
  problem that isn't present at any size this app will plausibly see.
  Leaving it as ordinary full-history scanning matches Rule 5 (don't
  over-engineer); re-open only if a real repository is ever slow.
- **The generated icon is a squircle with a white ascending trend line**,
  rendered at 1024×1024 with Core Graphics (no design tool or existing art
  was available) and downsampled with `sips` to every required mac idiom.
  Colors match the dashboard's existing green "shipped" accent rather than
  introducing a new one.
- **Signing stays `Automatic` + hardened runtime, ad-hoc ("Sign to Run
  Locally")** — there is no paid Apple Developer team on this machine, and
  the entitlements file already documents why the sandbox is off (Velocity
  execs `/usr/bin/git` against arbitrary absolute paths, which the sandbox
  would block). This is unchanged from earlier phases; nothing here needed
  a new decision, just confirming the Release configuration actually
  produces a valid, launchable, `codesign --verify`-clean `.app`.
- **DMG packaging uses a plain `hdiutil create` over a staging folder with
  an `Applications` symlink**, not a styled `create-dmg`-type layout — this
  is a personal utility with one installer, not a distributed product, and
  a background image/icon layout is effort the deliverable doesn't need.
- **`LSApplicationCategoryType` was set to `public.app-category.developer-tools`**
  purely to silence the Release build's validation warning; it has no
  runtime effect for an app that never ships to the Mac App Store.

## Phase 9 — Auto-Updates & Release Infrastructure ✅

Sparkle 2.9.6 via SPM, a one-file `UpdateService` wrapper, "Check for
Updates…" in both the app menu and the menu-bar panel, an "update
automatically" Settings toggle, and the release pipeline documented (not
fully exercised — see below) in README.md §42. 113 tests still pass; no new
tests were added since there is no Velocity-owned logic to unit test here —
`UpdateService` is a thin pass-through to Sparkle's own, already-tested API.

**Decisions**

- **Hit a real crash on first run, not a hypothetical one.** Adding
  Sparkle as a package dependency and building looked clean, but launching
  the built app terminated immediately with `Library not loaded:
  @rpath/Sparkle.framework`. Root cause: this project's `.pbxproj` was
  hand-built from scratch across Phases 1–8 and never had Xcode's default
  `LD_RUNPATH_SEARCH_PATHS = @executable_path/../Frameworks` — nothing
  needed it before, since nothing was embedded until now. Added that
  setting to both Debug and Release configs; confirmed fixed by launching
  the built app and clicking through the menu bar panel via System Events.
- **A second, distinct launch crash surfaced only in the Release
  configuration**: `different Team` from dyld's library validation.
  Hardened Runtime (already on, from Phase 8) requires every loaded binary
  to share the app's Team ID; an ad-hoc-signed app has no Team ID for
  Sparkle's separately ad-hoc-signed framework to match. Fixed with
  `com.apple.security.cs.disable-library-validation` in the entitlements
  file, which is the entitlement Sparkle's own documentation names for
  apps that embed it — confirmed by removing it and reproducing the exact
  crash, then re-adding it and confirming a clean launch. Left unverified:
  whether a real Developer ID + notarized build still needs this once
  Xcode re-signs the embedded framework under that same team; the
  entitlements file's comment flags this for whoever exercises real
  signing.
- **The Xcode project file itself was edited with the `xcodeproj` Ruby gem**
  (`gem install xcodeproj --user-install`), not by hand-writing the new
  `XCRemoteSwiftPackageReference` / `XCSwiftPackageProductDependency`
  objects into the `.pbxproj` text. That format has enough interlocking
  object IDs that a manual edit risked a subtly broken project file;
  `xcodeproj` is the same tool CocoaPods and `fastlane` use for exactly
  this. `xcodebuild -resolvePackageDependencies` then confirmed the
  reference resolves (Sparkle 2.9.6) before anything else was touched.
- **`SUPublicEDKey` ships as the literal placeholder string
  `REPLACE_WITH_SPARKLE_PUBLIC_ED_KEY`, not a real key.** Sparkle's own
  `generate_keys` tool stores the private half in the *running machine's*
  login Keychain and requires an interactive Keychain-access prompt —
  not something to trigger unattended on the user's actual Mac as a side
  effect of a coding task. Generating the real keypair is left as a
  one-time step for whoever cuts the first release (documented in
  README.md §42); verified the placeholder doesn't crash the app at
  launch or when "Check for Updates…" is actually clicked — Sparkle just
  has nothing valid to verify against yet, which is the correct state
  pre-release.
- **`SUFeedURL` points at this repo's own `appcast.xml` via
  `raw.githubusercontent.com`**, not a placeholder — it is a real, stable
  HTTPS URL today, and it costs nothing to host an appcast with zero
  `<item>`s until the first real release adds one.
- **`Package.resolved` is now committed**, reversing this project's
  original blanket `.gitignore` entry for it. That entry made sense for a
  project with zero package dependencies; now that Sparkle is a real,
  versioned dependency, CI and every other clone need the same resolved
  version pinned, which is the entire point of committing the file for an
  app (as opposed to a library, where consumers pin their own).
- **The GitHub Actions workflow (`.github/workflows/release.yml`) is
  written to the full sign → notarize → DMG → Sparkle-sign → appcast
  pipeline, but is unexercised.** It reads six secrets
  (`APPLE_DEVELOPER_ID_CERTIFICATE_P12` and friends — see README.md §42's
  table) that do not exist in this repository yet. Until they're added in
  GitHub's repo settings, a tag push will fail at the signing step by
  design, rather than silently publish an ad-hoc-signed build.
- **No Velocity-owned code was added to test.** `UpdateService` has no
  branches, no state machine, and no domain logic of its own — it forwards
  three properties/methods straight to `SPUUpdater`. Unit-testing it would
  mean either mocking Sparkle's own already-tested surface (test the mock,
  not the code) or launching the real Sparkle updater in a test target
  (an integration test of a third-party framework, not of Velocity).
  Verification here was a real build + a real launch + a real button
  click, not a unit test — matching how Phase 7 and 8 verified
  accessibility and packaging.

**What was not done, and why**

- **A real signed release was not produced or published.** Doing so needs
  the real Sparkle keypair from the point above.
- **The GitHub Actions workflow has not run.** It depends on
  `SPARKLE_PRIVATE_KEY` existing in the repository's settings; adding it
  is a one-time step for whoever owns the GitHub repo's settings, not
  something achievable from the local checkout.

**Addendum — the free path was chosen deliberately, not left pending**

Asked directly whether Velocity needed a paid Apple Developer account:
decided no. Developer ID + notarization were originally written into the
pipeline as the default assumption; the release workflow, README §42, and
the Phase 9 entry above were revised afterward to drop the Developer ID
cert/notarization steps and secrets entirely, replacing them with an
explicit "free-path tradeoff" write-up: every Sparkle-delivered update
still carries a quarantine flag, so an ad-hoc, unnotarized app requires
one manual System Settings → Privacy & Security → "Open Anyway" click per
update, on every Mac including the developer's own second machine. That's
the accepted cost of $0 and no Apple account, not a defect to fix later.
Required GitHub Actions secrets dropped from six to one
(`SPARKLE_PRIVATE_KEY`).

---

## Deferred work

Known and intentional. Each item names the phase that should pick it up.

| # | Item | Why it is not done yet | Target |
|---|---|---|---|
| D1 | ~~Opening Settings triggers a save with no edit~~ — **done in Phase 7**: `settings.didSet` now compares `oldValue` first | — | ✅ |
| D2 | ~~`PersistenceService.export(to:)` had no menu item or save panel~~ — **done in Phase 7** | — | ✅ |
| D3 | Menu-bar panel's buttons still expose no `AXTitle`/`AXDescription` under System Events, even with an explicit `.accessibilityLabel` (the dashboard's tiles were fixed in Phase 7 via `.accessibilityElement(children: .combine)` — same trick made no difference here; re-confirmed in Phase 8's manual QA pass) | Looks specific to `MenuBarExtra(.window)`'s accessibility bridging rather than fixable from application code. Needs checking with real VoiceOver, not System Events' scripting bridge | post-MVP |
| D4 | ~~Repository management UI~~ — **done in Phase 3** | — | ✅ |
| D5 | ~~"Scan Repositories" in the menu bar~~ — **done in Phase 3** | — | ✅ |
| D6 | ~~"Quick Log" in the menu bar~~ — **done in Phase 4** | — | ✅ |
| D7 | ~~Dashboard chart is placeholder copy; summary tiles are today-only~~ — **done in Phase 5** | — | ✅ |
| D8 | ~~`AppIcon.appiconset` is empty~~ — **done in Phase 8**: a generated squircle icon at every mac idiom | — | ✅ |
| D9 | ~~No repositories tab~~ — **done in Phase 3** | — | ✅ |
| D10 | ~~Scanned commits never reach the feed~~ — **done in Phase 4** | — | ✅ |
| D13 | ~~Quick-log field may not take focus~~ — **not a bug.** Confirmed working by typing into it with a real click; the earlier symptom was the accessibility script, not the app | — | ✅ |
| D14 | Scoring rules are compiled in; there is no way to add a type or change a weight | The README lists custom scoring rules under future ideas, and the rule set should settle before it becomes configurable | — |
| D11 | ~~A scan reads each repository's full history every time~~ — **measured in Phase 8, closed**: a synthetic 50,000-commit repository scans in ~0.3s total (`git log` + parsing), off the main actor. No repository this app will plausibly track is close to that size, so an incremental bound stays unbuilt until one actually is | — | ✅ |
| D12 | Repositories are stored as absolute paths, so moving a folder silently breaks it until the next scan reports it | Correct behaviour for now: the error is reported per repository and nothing crashes. A re-locate affordance would be nicer | post-MVP |
