# Velocity — Build Progress

Working log for the eight-phase plan in `README.md` §34.

Update this file at the end of every phase: mark the phase, record decisions that
future-me would otherwise have to re-derive from the diff, and move anything
knowingly left undone into [Deferred work](#deferred-work) with a target phase.
Nothing gets deferred without landing in that table.

## Status

| Phase | Scope | Status |
|---|---|---|
| 1 | Project Foundation | ✅ Complete |
| 2 | Local Persistence + Domain Models | ✅ Complete |
| 3 | Git Engine | ⬜ Not started |
| 4 | Scoring Engine + Quick Log | ⬜ Not started |
| 5 | Dashboard + Swift Charts | ⬜ Not started |
| 6 | Repository Automation | ⬜ Not started |
| 7 | Native macOS Polish | ⬜ Not started |
| 8 | Reliability, Packaging & Release | ⬜ Not started |

Current state: the app runs from the menu bar, opens a dashboard and a settings
window, and keeps its state in local JSON across restarts. It has no Git
integration and no way to add work yet, so in practice the feed is always empty.

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

---

## Deferred work

Known and intentional. Each item names the phase that should pick it up.

| # | Item | Why it is not done yet | Target |
|---|---|---|---|
| D1 | Opening Settings triggers a save with no edit — the `TextField` number binding writes back a normalised value on appearance, tripping `settings.didSet` | Harmless today: the write is atomic and idempotent. Wants a real fix (commit-on-change binding, or compare before assigning), not a workaround | 7 |
| D2 | `PersistenceService.export(to:)` exists and is tested, but has no menu item or save panel | The service method was two lines next to `save`; the UI is an export feature | 7 |
| D3 | Menu-bar panel exposes `missing value` for `AXTitle`/`AXValue` under System Events | May be a SwiftUI panel quirk rather than a real defect. Needs checking with VoiceOver, not with a script | 7 |
| D4 | Repository management UI — add, remove, name, scope, enable/disable | Nothing to point it at until the scanner exists | 3 |
| D5 | "Scan Repositories" entry in the menu-bar panel | Same | 3 |
| D6 | "Quick Log" entry in the menu-bar panel | Manual logging is its own phase | 4 |
| D7 | Dashboard chart is placeholder copy; summary tiles are today-only | Month aggregation, cumulative totals, and the goal path arrive with the chart that consumes them | 5 |
| D8 | `AppIcon.appiconset` is empty, so the app ships with the generic icon | Packaging concern | 8 |
| D9 | Settings changes are written but there is no repositories tab, so `VelocitySettings.gitAuthorEmail` cannot yet be verified against a real repo | Needs the Git layer to validate against | 3 |
