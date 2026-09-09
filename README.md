# Velocity — Solo Dev Shipping Engine

> A native, ultra-lightweight macOS developer productivity tracker that turns Git activity and manual logs into a simple, visual measure of shipping velocity.

---

## 1. Project Overview

**Velocity** is a native macOS menu-bar application for solo developers who want to track momentum rather than traditional productivity metrics.

The core idea is simple:

> **What did I actually ship, how much did it matter, and am I moving toward my target?**

Velocity scans selected local Git repositories, identifies commits belonging to the configured Git author, assigns an impact score based on conventional commit-style prefixes, and turns those commits into daily/monthly velocity data.

It also supports manual logging for work that may not exist as a Git commit.

The application is:

- **Native macOS**
- **Swift + SwiftUI**
- **Offline-first**
- **Local-only**
- **Zero backend**
- **Zero account system**
- **Zero cloud dependency**
- **Menu-bar-first**
- Designed for **Apple Silicon**, especially modern M-series Macs

The first version should prioritize reliability, simplicity, and a polished native experience over feature quantity.

---

# 2. Product Goals

## Primary goals

1. Make it effortless to see how much I shipped today.
2. Automatically derive shipping activity from local Git repositories.
3. Distinguish **Work** and **Personal** projects.
4. Convert commit types into a simple 1 / 3 / 5 point impact system.
5. Show cumulative monthly progress against a target.
6. Allow manual logging when Git does not capture an accomplishment.
7. Keep all data local and portable.
8. Make the app feel like a native macOS utility rather than a web app running inside a wrapper.
9. Make the menu bar the fastest way to interact with the application.

## Non-goals for v1

Do NOT build these unless explicitly requested later:

- Cloud synchronization
- User accounts
- Team collaboration
- Web dashboard
- Mobile application
- SaaS backend
- Social features
- Public leaderboards
- AI-generated productivity analysis
- Calendar integration
- Jira/Linear/GitHub cloud integrations
- Complex project-management functionality

Velocity is intentionally a **solo developer utility**.

---

# 3. Design Reference

A dashboard prototype/reference image is included in this project as:

`design-reference.png`

The reference demonstrates the intended visual direction:

- Dark native-style interface
- Green personal/work progress line
- Yellow dotted goal path
- Large cumulative chart
- Summary statistics
- Work / Personal / All Projects segmentation
- Daily velocity control
- Month progress inspection
- Chronological shipped-item feed
- Compact visual tags

The image is a **visual reference, not a pixel-perfect implementation specification**.

The final SwiftUI application should adapt the design to native macOS conventions where appropriate.

---

# 4. Technology Stack

## Required

| Area | Technology |
|---|---|
| Language | Swift |
| UI | SwiftUI |
| Platform | macOS |
| Charts | Swift Charts |
| Application lifecycle | SwiftUI App |
| Menu bar | `MenuBarExtra` |
| Persistence | JSON + `FileManager` |
| Serialization | `Codable` |
| Git execution | `Process` |
| Icons | SF Symbols |
| Concurrency | Swift Concurrency (`async/await`, actors where appropriate) |
| Notifications | UserNotifications, if needed |
| Build system | Xcode / Swift Package Manager where useful |

## Avoid unnecessary dependencies

Prefer Apple's frameworks and native APIs.

Do not introduce third-party libraries unless there is a clear technical reason.

Velocity should remain lightweight and easy to maintain.

---

# 5. High-Level Architecture

```text
                         ┌─────────────────────┐
                         │     VelocityApp     │
                         └──────────┬──────────┘
                                    │
                   ┌────────────────┴────────────────┐
                   │                                 │
                   ▼                                 ▼
          ┌─────────────────┐              ┌──────────────────┐
          │   MenuBarExtra  │              │ Dashboard Window │
          │   MenuBarView   │              │  DashboardView   │
          └────────┬────────┘              └─────────┬────────┘
                   │                                 │
                   └────────────────┬────────────────┘
                                    ▼
                         ┌─────────────────────┐
                         │   VelocityStore     │
                         │  Observable State   │
                         └──────────┬──────────┘
                                    │
             ┌──────────────────────┼──────────────────────┐
             │                      │                      │
             ▼                      ▼                      ▼
     ┌───────────────┐      ┌────────────────┐     ┌──────────────────┐
     │  Git Scanner  │      │ Scoring Engine │     │ Persistence Layer│
     └───────┬───────┘      └────────────────┘     └────────┬─────────┘
             │                                                │
             ▼                                                ▼
      Local Git repos                                Application Support
```

---

# 6. Suggested Project Structure

Use a feature/domain-oriented structure rather than putting everything into a few giant Swift files.

```text
Velocity/
├── Velocity.xcodeproj
│
├── Velocity/
│   ├── App/
│   │   ├── VelocityApp.swift
│   │   └── AppEnvironment.swift
│   │
│   ├── Models/
│   │   ├── ShippedItem.swift
│   │   ├── Commit.swift
│   │   ├── Repository.swift
│   │   ├── ProjectScope.swift
│   │   ├── ImpactWeight.swift
│   │   ├── DailyVelocity.swift
│   │   ├── VelocityGoal.swift
│   │   └── VelocitySettings.swift
│   │
│   ├── Services/
│   │   ├── Git/
│   │   │   ├── GitRunner.swift
│   │   │   ├── GitScanner.swift
│   │   │   └── GitCommitParser.swift
│   │   │
│   │   ├── Scoring/
│   │   │   └── ScoringEngine.swift
│   │   │
│   │   ├── Persistence/
│   │   │   ├── PersistenceService.swift
│   │   │   └── JSONStore.swift
│   │   │
│   │   └── Export/
│   │       └── ExportService.swift
│   │
│   ├── Store/
│   │   └── VelocityStore.swift
│   │
│   ├── Views/
│   │   ├── MenuBar/
│   │   │   ├── MenuBarView.swift
│   │   │   └── QuickLogView.swift
│   │   │
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift
│   │   │   ├── VelocityChart.swift
│   │   │   ├── SummaryStatsView.swift
│   │   │   ├── ProjectScopePicker.swift
│   │   │   ├── VelocityControlsView.swift
│   │   │   └── ShippedFeedView.swift
│   │   │
│   │   └── Settings/
│   │       ├── SettingsView.swift
│   │       ├── RepositorySettingsView.swift
│   │       └── GeneralSettingsView.swift
│   │
│   └── Resources/
│       └── Assets.xcassets
│
└── README.md
```

The exact structure can evolve, but maintain clear separation between UI, state, business logic, Git execution, and persistence.

---

# 7. Core Domain Model

## 7.1 Project Scope

```swift
enum ProjectScope: String, Codable {
    case work
    case personal
}
```

---

## 7.2 Impact Weight

Velocity uses three impact levels.

```swift
enum ImpactWeight: Int, Codable {
    case minor = 1
    case core = 3
    case epic = 5
}
```

### Epic Launch — 5 points

Examples:

```text
feat!
breaking:
deploy:
```

### Core Feature — 3 points

Examples:

```text
feat:
refactor:
db:
```

### Minor Tweak — 1 point

Examples:

```text
fix:
docs:
style:
chore:
cleanup
```

The scoring system should be implemented as deterministic business logic and should be easy to extend later.

---

# 8. Git Data Ingestion

Velocity monitors user-selected **absolute local repository paths**.

Example:

```text
/Users/<user>/Code/velocity
/Users/<user>/Code/fetnepal
/Users/<user>/Code/bobcheck
```

The application should verify that each configured path:

1. Exists.
2. Is a directory.
3. Contains a `.git` repository.
4. Can be accessed by the application.

---

## 8.1 Git Author Filtering

Only commits matching the configured Git author should be imported.

The preferred configuration is the user's Git email.

Example:

```text
user.email = developer@example.com
```

Velocity should allow the user to configure the email explicitly rather than assuming the current machine's identity.

Where practical, provide a "Detect Git Email" action that reads:

```bash
git config user.email
```

The scanner should not blindly import commits authored by other developers.

---

# 9. Git Commit Identity / Idempotency

## Important implementation decision

Use the **Git commit SHA as the primary identity for imported commits**.

Do NOT rely primarily on:

```text
commit_message + timestamp
```

because Git already provides a much stronger unique identifier.

Example:

```swift
struct Commit: Codable, Identifiable {
    let id: String       // Git SHA
    let message: String
    let timestamp: Date
    let repositoryPath: String
    let authorEmail: String
}
```

A Git commit should only become one Velocity item.

Repeated scans must never create duplicates.

---

# 10. Shipped Item Model

Use a unified model for Git-generated and manually created entries.

Suggested model:

```swift
struct ShippedItem: Identifiable, Codable {
    let id: String
    var title: String
    var timestamp: Date
    var scope: ProjectScope
    var weight: ImpactWeight
    var source: Source
    var repositoryPath: String?
    var commitSHA: String?
}
```

Where:

```swift
enum Source: String, Codable {
    case git
    case manual
}
```

For Git entries:

```text
source = git
commitSHA = actual Git SHA
repositoryPath = repository path
```

For manual entries:

```text
source = manual
commitSHA = nil
repositoryPath = nil
id = UUID
```

---

# 11. Scoring Engine

The scoring engine must be:

- Deterministic
- Testable
- Independent from SwiftUI
- Independent from persistence
- Independent from Git execution

Example conceptual API:

```swift
struct ScoringEngine {
    func score(message: String) -> ImpactWeight
}
```

Classification should happen from strongest/highest-impact rules to weakest.

For example:

```text
Epic rules
    ↓
Core rules
    ↓
Minor rules
    ↓
Fallback
```

Avoid accidental substring matches where possible.

The implementation should be covered with unit tests.

---

# 12. Manual Quick Log

The user must be able to log shipped work manually.

The quick-log UI contains:

```text
Description
[________________________]

Scope
[ Work ] [ Personal ]

Impact
[ 1 ] [ 3 ] [ 5 ]

[ Log Shipment ]
```

The manual log should immediately appear in the shipped feed and update the dashboard statistics.

Manual logs must be deletable.

---

# 13. Menu Bar Application

Velocity should primarily operate as a menu-bar utility.

Use SwiftUI's:

```swift
MenuBarExtra
```

The menu bar label should show a compact representation of current activity.

Possible states:

```text
Velocity · 8
```

or:

```text
● 8 pts
```

The exact visual treatment can be refined during implementation.

---

## Menu Bar Menu

Suggested structure:

```text
Velocity                         8 pts

Today
────────────────────────────
3 pts   Authentication
3 pts   Dashboard redesign
1 pt    Documentation

────────────────────────────
+ Quick Log
Open Dashboard
Scan Repositories
Settings

────────────────────────────
Quit Velocity
```

The menu must remain lightweight and fast.

---

# 14. Dashboard

The main dashboard is the primary analytics surface.

It should contain:

1. Cumulative monthly chart
2. Goal path
3. Work / Personal comparison
4. Summary statistics
5. Scope filter
6. Target daily velocity
7. Month-progress inspection
8. Shipped feed

---

# 15. Cumulative Velocity Chart

Use:

```text
Swift Charts
```

Do not use Chart.js or a web canvas.

The chart represents cumulative progress through the selected month.

Example:

```text
Day       Cumulative Points
1                 2
2                 5
3                 8
4                10
5                15
...
15               24
```

The chart should support:

- Current month
- Historical days
- Cumulative actual progress
- Goal path
- Work / Personal filtering
- Tooltip/inspection on data points
- Current-day indicator where appropriate

---

# 16. Goal Path

The user sets a target daily velocity.

Example:

```text
Target daily velocity: 2.5/day
```

For a 30-day month:

```text
Goal = 2.5 × 30
     = 75 points
```

For a 31-day month:

```text
Goal = 2.5 × 31
     = 77.5 points
```

The UI can display the target as an integer where appropriate, but calculations should preserve numeric precision internally.

The chart should render the target as a dotted/dashed goal line.

---

# 17. Scope Filtering

Dashboard filter:

```text
[ All Projects ] [ Work ] [ Personal ]
```

All Projects:

```text
Work + Personal
```

Work:

```text
Work only
```

Personal:

```text
Personal only
```

The chart, summary statistics, and shipped feed should respond consistently to the selected scope.

---

# 18. Summary Statistics

At minimum:

### Avg Velocity

Average shipped points per day for the inspected period.

Example:

```text
Avg Velocity
1.6 / day
```

### Delivered

Total points/items delivered within the inspected period.

Example:

```text
Delivered
24 features
```

The exact label can be "items" or "points" depending on the final UX decision. Do not confuse the two metrics.

### Target Goal

Total target for the selected month.

Example:

```text
Target Goal
38 items
```

The underlying model should distinguish between **points** and **item count**.

---

# 19. Month Progress Inspection

The dashboard should allow the user to inspect progress at a particular day.

Example:

```text
Inspect Month Progress

───────────────●────────
              Day 15
```

When inspecting Day 15, the chart and relevant statistics should represent progress up to that day.

Do not alter the underlying stored data.

This is an analytics view state only.

---

# 20. Shipped Feed

Display shipped items chronologically.

Newest first is recommended.

Example:

```text
Delivered on Sep 15

[ 5 ] Major deployment
[ 3 ] Authentication
[ 3 ] Dashboard
[ 1 ] Documentation
```

Items should show:

- Impact
- Title/message
- Scope
- Date/time where useful
- Source indicator if useful

Each item should provide a delete action.

Deletion should remove the item from the local dataset and update all derived statistics.

---

# 21. Persistence

Velocity must be entirely local.

Recommended location:

```text
~/Library/Application Support/Velocity/
```

Suggested structure:

```text
Velocity/
├── velocity.json
├── settings.json
└── backups/
```

Use `FileManager` to create and access the directory.

Do not write persistent application data into the project directory.

---

# 22. JSON Storage

Use Swift's:

```swift
Codable
JSONEncoder
JSONDecoder
```

Example:

```swift
struct VelocityData: Codable {
    var items: [ShippedItem]
}
```

Storage should be atomic where practical.

Avoid corrupting the main file if the application is terminated during a write.

A safe write strategy should be considered, such as writing to a temporary file and replacing the original.

---

# 23. Import / Export

The application should provide a way to export its state to a standalone JSON file.

Example:

```text
Velocity → Export Data
```

The exported file should contain enough information to reconstruct the application's state.

Example filename:

```text
velocity-backup-2026-09-01.json
```

An import feature can be added after the initial export implementation if necessary.

---

# 24. Repository Configuration

Settings should allow the user to manage repositories.

Example:

```text
Repositories

✓ velocity
  /Users/<user>/Code/velocity

✓ fetnepal
  /Users/<user>/Code/fetnepal

✓ bobcheck
  /Users/<user>/Code/bobcheck

[ + Add Repository ]
```

Each repository should have:

- Path
- Display name
- Scope
- Enabled/disabled state

Example:

```text
velocity
Personal
Enabled
```

```text
fetnepal
Work
Enabled
```

This allows automatic scope classification.

---

# 25. Scan Strategy

The first implementation should support manual scanning:

```text
Scan Repositories
```

After the core scanner is stable, add automatic background scanning.

Possible strategies:

```text
On app launch
On menu open
Every 15 minutes
Every 30 minutes
Every hour
```

The exact default interval can be decided during implementation.

Do not build an unnecessarily complicated daemon.

---

# 26. Git Execution Safety

Git commands should be executed through Swift's `Process`.

Do not construct shell commands by interpolating arbitrary user input into a shell string.

Prefer:

```swift
Process()
```

with:

```swift
executableURL
arguments
```

rather than:

```bash
sh -c "..."
```

This avoids unnecessary shell parsing and quoting problems.

The Git layer should provide useful errors such as:

```text
Repository not found
Not a Git repository
Git executable unavailable
Permission denied
Git command failed
```

Errors should not crash the application.

---

# 27. Swift Concurrency

Git scanning may involve multiple repositories.

Use Swift concurrency appropriately.

Potential approach:

```text
ScanManager
    ↓
Task
    ↓
Concurrent repository scanning
    ↓
Parse commits
    ↓
Deduplicate
    ↓
Update store
```

UI updates must happen safely on the main actor.

Avoid blocking the main UI thread while scanning repositories.

---

# 28. State Management

Keep application state centralized.

A possible approach:

```swift
@Observable
final class VelocityStore {
    var shippedItems: [ShippedItem] = []
    var repositories: [Repository] = []
    var settings: VelocitySettings
}
```

The exact observation mechanism should follow the current Swift/macOS deployment target chosen for the project.

Avoid scattering mutable global state throughout views.

Views should primarily render state and trigger actions.

---

# 29. Design Principles

Velocity should feel:

### Fast

Opening the menu should feel instantaneous.

### Quiet

It should not constantly interrupt the user.

### Native

Use macOS conventions wherever appropriate.

### Minimal

Do not turn the application into a project-management suite.

### Visual

The chart should communicate progress immediately.

### Honest

The score should represent shipped work, not arbitrary activity.

---

# 30. Visual Direction

Use the attached design reference as inspiration.

General visual direction:

- Dark appearance as the primary presentation
- Subtle borders/dividers
- Rounded cards
- Strong typography hierarchy
- Green for actual progress
- Yellow for target/goal path
- Blue for interactive controls where appropriate
- Minimal iconography
- SF Symbols instead of custom icon libraries
- Avoid excessive gradients
- Avoid web-style UI components
- Respect native macOS spacing and controls

The final application does **not** need to exactly reproduce the screenshot.

Prioritize:

1. Native macOS feel
2. Readability
3. Information hierarchy
4. Smooth interaction
5. Visual consistency

---

# 31. Accessibility

The application should use native SwiftUI controls wherever possible.

Provide:

- VoiceOver-friendly labels
- Meaningful accessibility labels for chart controls
- Keyboard navigation where practical
- Sufficient contrast
- Dynamic text support where practical
- Tooltips for unfamiliar icons

Do not sacrifice accessibility just to reproduce the prototype visually.

---

# 32. Error Handling

The application must fail gracefully.

Examples:

### Invalid repository

Show:

```text
This folder is not a Git repository.
```

### Git failure

Show a useful error rather than crashing.

### Corrupted JSON

Do not silently overwrite the user's data.

Prefer:

```text
Unable to load Velocity data.

A backup may be available in:
Application Support/Velocity/backups/
```

### Permission issue

Explain that macOS may require the user to grant access to the selected folder.

---

# 33. Testing Requirements

Business logic should be testable independently of SwiftUI.

At minimum, create unit tests for:

## Scoring

```text
feat!          → 5
breaking:      → 5
deploy:        → 5

feat:          → 3
refactor:      → 3
db:            → 3

fix:           → 1
docs:          → 1
style:         → 1
chore:         → 1
```

## Deduplication

Given the same Git SHA twice:

```text
Input:
A
A

Output:
A
```

## Scope filtering

```text
All      → Work + Personal
Work     → Work
Personal → Personal
```

## Monthly aggregation

Verify:

- Daily totals
- Cumulative totals
- Average velocity
- Goal calculation
- Partial-month inspection

## Persistence

Verify:

```text
Save → Load → same data
```

---

# 34. Development Phases

Build Velocity in **8 phases**.

Do not attempt the entire application in one pass.

Each phase should leave the project in a working state.

---

## Phase 1 — Project Foundation

### Goal

Create a working native macOS menu-bar application.

### Tasks

- Create Xcode macOS project
- Configure SwiftUI
- Configure deployment target
- Create `VelocityApp`
- Add `MenuBarExtra`
- Create basic dashboard window
- Establish project folder structure
- Create initial models
- Establish basic app state architecture

### Deliverable

The application launches successfully and displays a functioning menu-bar item.

### Acceptance criteria

```text
✓ Builds
✓ Runs
✓ Menu bar icon appears
✓ Menu opens
✓ Dashboard window can open
✓ Quit works
```

---

# Phase 2 — Local Persistence + Domain Models

### Goal

Make the application's data durable.

### Tasks

- Implement `ShippedItem`
- Implement `Repository`
- Implement `VelocitySettings`
- Implement `ProjectScope`
- Implement `ImpactWeight`
- Implement JSON persistence
- Create Application Support directory
- Implement safe save/load
- Handle missing data files
- Handle corrupted data gracefully

### Deliverable

The app can create, save, load, and delete Velocity items locally.

### Acceptance criteria

```text
✓ Data survives app restart
✓ Data is stored in Application Support
✓ JSON is readable
✓ Delete persists
✓ No cloud dependency
```

---

# Phase 3 — Git Engine

### Goal

Automatically import real Git activity.

### Tasks

- Implement `GitRunner`
- Implement repository validation
- Implement Git log execution
- Parse SHA
- Parse timestamp
- Parse commit message
- Parse author email
- Implement author filtering
- Implement repository configuration
- Implement commit deduplication
- Handle Git errors

### Deliverable

Velocity can scan a configured local repository and import matching commits.

### Acceptance criteria

```text
✓ Repository can be added
✓ Git commits are discovered
✓ Author filtering works
✓ SHA is preserved
✓ Duplicate scans do not duplicate commits
✓ Invalid repositories do not crash the app
```

---

# Phase 4 — Scoring Engine + Quick Log

### Goal

Turn raw commits into meaningful Velocity points.

### Tasks

- Implement scoring rules
- Add unit tests
- Convert commits into `ShippedItem`
- Implement manual quick logging
- Add Work/Personal selector
- Add 1/3/5 impact selector
- Add delete functionality
- Connect menu-bar quick log

### Deliverable

The application can automatically score Git commits and manually log shipments.

### Acceptance criteria

```text
✓ Git commits receive correct scores
✓ Manual entries work
✓ Scope works
✓ 1/3/5 override works
✓ Delete works
✓ Feed updates immediately
```

---

# Phase 5 — Dashboard + Swift Charts

### Goal

Build the main visual analytics experience.

### Tasks

- Build dashboard layout
- Implement cumulative daily aggregation
- Implement monthly filtering
- Implement Swift Charts
- Implement goal path
- Implement current-day indicator
- Implement scope filter
- Implement summary statistics
- Implement shipped feed
- Implement month inspection

### Deliverable

A polished dashboard similar in information architecture to `design-reference.png`.

### Acceptance criteria

```text
✓ Chart displays real data
✓ Cumulative values are correct
✓ Goal path is correct
✓ Work/Personal filtering works
✓ Summary statistics update
✓ Shipped feed updates
✓ Month inspection works
```

---

# Phase 6 — Repository Automation

### Goal

Make the app useful without manual scanning.

### Tasks

- Background scanning
- Configurable scan interval
- Scan on launch
- Optional scan on menu open
- Repository enable/disable
- Automatic Work/Personal assignment
- Scan status indicator
- Last scan timestamp
- Error reporting

### Deliverable

Velocity quietly keeps itself up to date in the background.

### Acceptance criteria

```text
✓ Repositories scan automatically
✓ UI remains responsive
✓ Duplicate commits never appear
✓ Scope is assigned correctly
✓ Failed repositories don't break other scans
```

---

# Phase 7 — Native macOS Polish

### Goal

Make Velocity feel like a real macOS application.

### Tasks

- Refine menu-bar UI
- Add SF Symbols
- Add keyboard shortcuts
- Add tooltips
- Add animations where appropriate
- Add native window behavior
- Add settings UI
- Add export
- Add optional notifications
- Improve empty states
- Improve loading states
- Improve error states
- Accessibility pass
- Dark/light appearance validation

### Deliverable

A polished personal utility suitable for daily use.

### Acceptance criteria

```text
✓ Feels native
✓ Fast
✓ No obvious UI rough edges
✓ Accessible
✓ Export works
✓ Settings work
```

---

# Phase 8 — Reliability, Packaging & Release

### Goal

Create a stable installable local application.

### Tasks

- Full unit test pass
- Manual QA
- Test with multiple repositories
- Test with large Git histories
- Test corrupted persistence
- Test missing repositories
- Test permissions
- Test app restart
- Test sleep/wake behavior
- Test automatic scanning
- Optimize unnecessary work
- Configure application icon
- Configure signing as appropriate
- Build Release configuration
- Create `.app`
- Optional DMG packaging

### Deliverable

A stable Release build that can be installed and used independently of Xcode.

---

# Phase 9 — Auto-Updates & Release Infrastructure

### Goal

Let Velocity update itself once it is out of Xcode's hands, without depending on the Mac App Store.

### Tasks

- Add Sparkle 2 via Swift Package Manager
- Wrap `SPUStandardUpdaterController` behind a single `UpdateService`
- Add "Check for Updates…" to the app menu and the menu-bar panel
- Add a "check automatically" setting
- Configure `SUFeedURL` / `SUPublicEDKey` / `SUEnableAutomaticChecks`
- Keep the Sparkle EdDSA private key out of the repository entirely
- Define the ad-hoc-sign → DMG → Sparkle-sign → appcast release pipeline
  (no Developer ID/notarization — see §42's free-path tradeoff)
- Document versioning, signing, and the appcast for whoever cuts a release

### Deliverable

Velocity can check a hosted appcast and offer an in-app update, and the
release process that produces that appcast is documented and fully
runnable on the free path — no paid Apple Developer account. The
tradeoff (a manual Gatekeeper "Open Anyway" click per update) is a
deliberate choice, documented in §42, not a gap waiting to be closed.

---

# 35. Phase Execution Rule

**Do not skip ahead just because a later feature is visible in the design.**

For each phase:

1. Implement the phase.
2. Build the application.
3. Run it.
4. Test the relevant functionality.
5. Fix compile/runtime issues.
6. Confirm acceptance criteria.
7. Only then move to the next phase.

Do not create placeholder implementations for major functionality just to claim a phase is complete.

---

# 36. MVP Definition

The first meaningful MVP consists of:

```text
✓ Native menu-bar application
✓ Local JSON persistence
✓ Repository configuration
✓ Git scanning
✓ Git author filtering
✓ SHA-based deduplication
✓ 1/3/5 scoring
✓ Work/Personal scopes
✓ Manual quick log
✓ Delete shipped items
✓ Monthly cumulative chart
✓ Goal path
✓ Summary statistics
✓ Shipped feed
✓ JSON export
```

Background automation and advanced polish can follow after this MVP is reliable.

---

# 37. Important Engineering Rules for Claude

When implementing this project:

### Rule 1 — Prefer native Apple APIs

Before adding a dependency, ask whether Swift/macOS already provides the required capability.

### Rule 2 — Keep business logic out of Views

Views should not contain Git parsing, scoring rules, persistence logic, or complex aggregation algorithms.

### Rule 3 — Keep Git isolated

Git execution and parsing should live in the Git service layer.

### Rule 4 — Make calculations testable

Chart calculations should be derived from testable model/service logic rather than hidden inside `View` bodies.

### Rule 5 — Don't over-engineer

This is a local solo-dev utility.

Do not introduce:

- Core Data unless genuinely necessary
- A database server
- Networking
- Dependency injection frameworks
- Redux-like architectures
- Large third-party UI frameworks

unless there is a strong reason.

### Rule 6 — Preserve user data

Never silently overwrite or destroy existing local data.

### Rule 7 — No shell injection

Use `Process` arguments directly.

Do not build arbitrary shell command strings.

### Rule 8 — Keep the app responsive

Git scanning must not block the main UI thread.

### Rule 9 — Use the Git SHA

The SHA is the canonical identity for Git-derived shipments.

### Rule 10 — Don't blindly reproduce web UI

Use the design reference for visual direction, but adapt controls and interaction patterns to macOS.

---

# 38. Suggested Initial Data Schema

A possible initial JSON structure:

```json
{
  "version": 1,
  "items": [
    {
      "id": "abc123",
      "title": "feat: add authentication",
      "timestamp": "2026-09-01T10:30:00Z",
      "scope": "personal",
      "weight": 3,
      "source": "git",
      "repositoryPath": "/Users/example/Code/project",
      "commitSHA": "abc123..."
    }
  ],
  "repositories": [
    {
      "id": "repo-1",
      "name": "project",
      "path": "/Users/example/Code/project",
      "scope": "personal",
      "enabled": true
    }
  ],
  "settings": {
    "targetDailyVelocity": 2.5,
    "gitAuthorEmail": "developer@example.com"
  }
}
```

The schema may evolve, but include a top-level version so future migrations are possible.

---

# 39. Future Ideas

These are intentionally **not part of the initial implementation**.

Potential future versions could add:

- Git branch filtering
- Commit message customization
- Custom scoring rules
- Weekly analytics
- Yearly analytics
- Streaks
- Goal notifications
- Menu-bar mini chart
- Launch-at-login
- GitHub/GitLab integration
- AI summaries
- Natural-language activity summaries
- Project-specific goals
- Export to CSV
- iCloud sync
- Multiple profiles
- Productivity trends

Do not implement these until the core application is stable.

---

# 40. Definition of Done

Velocity v1 is considered complete when:

```text
✓ App runs natively on macOS
✓ Menu bar utility works
✓ Dashboard window works
✓ Local persistence works
✓ Git repositories can be configured
✓ Git commits are scanned
✓ Correct author filtering occurs
✓ Git SHA prevents duplicate imports
✓ Scoring rules work
✓ Manual logs work
✓ Work/Personal filtering works
✓ Monthly cumulative chart works
✓ Goal path works
✓ Statistics are correct
✓ Shipped feed works
✓ Deletion works
✓ JSON export works
✓ Background scanning works
✓ Errors are handled gracefully
✓ Unit tests pass
✓ App remains responsive during scanning
✓ User data is never silently lost
✓ Release build runs independently of Xcode
```

---

# 41. Starting Instruction

When beginning implementation, **start with Phase 1 only**.

Do not implement the entire roadmap immediately.

First create the native macOS project and establish:

```text
VelocityApp
    ↓
MenuBarExtra
    ↓
MenuBarView

and

Dashboard Window
    ↓
DashboardView
```

Then establish the basic model/service/store structure.

Once Phase 1 is complete, verify that the application builds and launches before proceeding to Phase 2.

The goal is to build Velocity incrementally as a reliable native macOS application, not as a large one-shot code generation exercise.

---

## Final Product Vision

Velocity should ultimately feel like a tiny native instrument sitting quietly in the macOS menu bar:

```text
              ┌─────────────────────────┐
              │       Velocity           │
              │                          │
              │       ● 8 pts today      │
              │                          │
              │   + Quick Log            │
              │   Open Dashboard         │
              │   Scan Repositories      │
              │   Settings               │
              └─────────────────────────┘
```

And when the user wants the bigger picture:

```text
              Velocity Dashboard

       Actual Progress ─────────╮
                                 ╰──────

       Goal Path    ┄┄┄┄┄┄┄┄┄┄┄┄┄╮
                                    ╰──

       24 shipped                    38 target
       1.6/day                       2.5/day
```

**The product is not about tracking everything a developer does.**

It is about making **shipping momentum visible**.

---

# 42. Auto-Updates & Release Infrastructure

Sparkle handles **application updates only** — checking a hosted appcast,
verifying a release's signature, downloading and installing a newer build.
It has nothing to do with Velocity's data: `VelocityData` stays local JSON
under `~/Library/Application Support/Velocity/` on each Mac, exactly as
before. There is no iCloud, CloudKit, backend, or cross-device sync, and
none should be added as part of this.

## Architecture

Sparkle is isolated to one file, `Velocity/Services/Update/UpdateService.swift`.
Nothing else in the app imports Sparkle — `AppEnvironment`, `VelocityApp`,
`MenuBarView`, and `GeneralSettingsView` only see `UpdateService`'s plain
`checkForUpdates()` method and `canCheckForUpdates` / `automaticallyChecksForUpdates`
properties. If Sparkle is ever swapped for something else, this is the only
file that changes.

## Local development

- Sparkle is a Swift Package dependency (`https://github.com/sparkle-project/Sparkle`,
  `.upToNextMajor(2.6.4)`), resolved automatically on first build —
  no manual setup needed to build and run.
- `Info.plist` ships with a placeholder `SUPublicEDKey`
  (`REPLACE_WITH_SPARKLE_PUBLIC_ED_KEY`) and a real `SUFeedURL` pointing at
  `appcast.xml` in this repo. With the placeholder key, Sparkle's update
  *checks* still run (the UI is fully invokable — button, menu item, and
  Settings toggle all work), but signature verification will not validate
  against a real release until the real public key from your own keypair
  replaces the placeholder.
- Debug and Release builds are both ad-hoc signed ("Sign to Run Locally").
  This is a deliberate choice, not a placeholder waiting for a paid Apple
  Developer account — see **The free-path tradeoff** below for what that
  means for updates specifically.

## Generating the Sparkle signing key (once, by whoever releases)

Sparkle's own EdDSA keypair is separate from Apple code signing. Generate it
once, on the machine that will cut releases:

```sh
# Path comes from the resolved package under DerivedData, or build
# Sparkle's own tool from the checked-out package.
/path/to/Sparkle/bin/generate_keys
```

This stores the **private** key in that Mac's login Keychain (item "Private
key for signing Sparkle updates") and prints the **public** key to paste into
`SUPublicEDKey` in the Xcode project's build settings. The private key:

- **never** leaves the Keychain as a file you'd accidentally commit,
- is exported (`generate_keys -x key.pem`) only to hand to a CI secret store,
  never to a path inside this repository,
- should be re-imported into GitHub Actions as a secret
  (`SPARKLE_PRIVATE_KEY`), consumed at build time, and not written to disk
  in the runner's workspace.

If this key is ever lost, existing installs simply stop trusting new
releases signed with a different key — there is no silent downgrade in
trust, so losing it means shipping one update that asks users to
reinstall, not a security hole.

## Versioning

Two Xcode build settings drive both the app's version and Sparkle's update
comparison:

| Setting | Meaning | Example |
|---|---|---|
| `MARKETING_VERSION` | Human-facing version (`CFBundleShortVersionString`) | `0.2.0` |
| `CURRENT_PROJECT_VERSION` | Build number (`CFBundleVersion`) — what Sparkle actually compares to decide "is this newer?" | `4` |

**To cut a release:** bump `CURRENT_PROJECT_VERSION` by 1 every single
release, no exceptions — this is the number Sparkle orders by. Bump
`MARKETING_VERSION` whenever the human-facing version should change (most
releases); a hotfix that doesn't warrant a new marketing version can bump
only the build number. Both live in `Velocity.xcodeproj/project.pbxproj`
under the `Velocity` target's Debug/Release configurations.

## The free-path tradeoff

Velocity deliberately ships **without** a paid Apple Developer Program
membership ($99/year), which means no Developer ID signing and no
notarization. This is a considered choice, not a temporary gap:

- **What this costs you:** every file macOS downloads over the network —
  including every Sparkle update, not just the first install — gets a
  quarantine flag. Without notarization, Gatekeeper refuses to open a
  quarantined, ad-hoc-signed app outright ("Apple could not verify this app
  is free of malware"). The fix is one manual step per update: **System
  Settings → Privacy & Security → scroll to the security section → "Open
  Anyway"** — then relaunch. This applies to you on any second Mac just as
  much as to anyone else who installs it.
- **What this gets you:** zero cost, no Apple account enrollment, no
  certificate/notarization credentials to manage or leak. Sparkle still
  checks the appcast, downloads, verifies its own EdDSA signature, and
  offers the update — the *only* difference from a paid setup is that one
  extra manual click after each update, instead of a silent install.
- **If this ever changes:** getting a Developer ID later only means adding
  the signing/notarization steps to the release workflow below and
  populating the secrets table — nothing about `UpdateService`, the
  appcast format, or the versioning scheme would need to change.

## Release pipeline

```text
Source code
    ↓
GitHub Actions (on a version tag, e.g. v0.2.0)
    ↓
Build macOS app (Release configuration, universal binary, ad-hoc signed)
    ↓
Create DMG (hdiutil, as done locally for Phase 8)
    ↓
Sign the DMG and (re)generate appcast.xml in one step
    (Sparkle's own `generate_appcast` tool: reads the DMG plus the
    existing appcast.xml, signs the new entry, folds it in)
    ↓
Commit the updated appcast.xml to main
    ↓
Publish: GitHub Release (DMG as an asset)
```

No Developer ID signing or notarization step exists in this pipeline —
see **The free-path tradeoff** above for why that's intentional here.
`.github/workflows/release.yml` implements exactly this shape, using
Sparkle's bundled `generate_appcast` binary (found under the resolved
package's `artifacts/sparkle/Sparkle/bin/`) rather than hand-writing the
`<item>` XML — it infers the version, signs it with
`SPARKLE_PRIVATE_KEY`, and merges it into the existing feed.

### GitHub Releases + appcast hosting

- Release artifacts (the DMG) are attached to a GitHub Release, one per
  version tag.
- `appcast.xml` lives at the repository root and is served at a stable,
  permanent URL: `https://raw.githubusercontent.com/ishanshrestha14/velocity/main/appcast.xml`
  (this is exactly what `SUFeedURL` points at). Every release regenerates
  this file and the workflow commits it straight to `main` — Sparkle
  re-reads it on every check.
- GitHub Actions (`.github/workflows/release.yml`) automates all of this
  from a single tag push (`git tag v0.2.0 && git push --tags`); see that
  file's comments for what it does and the one secret it needs.

### Required GitHub Actions secrets

| Secret | Used for |
|---|---|
| `SPARKLE_PRIVATE_KEY` | Exported EdDSA private key, for `generate_appcast`'s `--ed-key-file` |

This is the only secret the free path needs. It is not hardcoded anywhere
in this repository — the workflow reads it from `secrets.SPARKLE_PRIVATE_KEY`.
(If Developer ID signing is ever added later, that reintroduces the
certificate/notarization secrets described in the free-path section above.)

## What cannot be tested locally

- **A real end-to-end update.** `SUPublicEDKey` is now the real public key
  and `SPARKLE_PRIVATE_KEY` is set in GitHub, but `appcast.xml` still lists
  no releases — Sparkle's "Check for Updates…" path runs (build, link,
  invoke, no crash — see `PROGRESS.md`'s Phase 9 entry) but has nothing to
  find yet. The first real tag push is also the first real test of the
  full pipeline.
- **The GitHub Actions workflow itself** — it is written to the pipeline
  shape above but has not run in CI yet; it will run on the first
  `git tag v* && git push --tags`.
- **The Gatekeeper "Open Anyway" step** — not exercisable from this
  environment (it's a GUI prompt on the machine receiving the update), but
  it is the expected, documented behavior of the free path above, not a bug.
