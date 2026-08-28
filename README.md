# Tempo

**Screen time, measured beautifully.** A private desktop screen-time tracker
for Windows and macOS, built with Flutter.

Tempo watches which application is in front of you and for how long, turns that
into sessions, and shows you your day, week, month and year. Everything it
measures stays in one file on your computer.

---

## Contents

1. [What it does](#what-it-does)
2. [Screens](#screens)
3. [Privacy](#privacy)
4. [Requirements](#requirements)
5. [Permissions](#permissions)
6. [Getting started](#getting-started)
7. [Running](#running)
8. [Building a release](#building-a-release)
9. [Architecture](#architecture)
10. [How tracking works](#how-tracking-works)
11. [The database](#the-database)
12. [The year grid](#the-year-grid)
13. [Sharing a report](#sharing-a-report)
14. [Exporting your data](#exporting-your-data)
15. [Looking after your data](#looking-after-your-data)
16. [Preview data](#preview-data)
17. [Known limitations](#known-limitations)
18. [Troubleshooting](#troubleshooting)
19. [Project rules](#project-rules)

---

## What it does

- Measures the **foreground application** and how long you spend in it, grouped
  by application rather than by window: ten Chrome windows are one Chrome.
- Separates **active time** from **idle time** — time the machine was awake but
  untouched belongs to no application.
- Keeps a full history: today, the week, the month, the year, and every
  application's own record.
- Runs from the **tray** so it keeps measuring with the window closed, and can
  open when you sign in.
- Shares a report you write yourself — as text, as an image, or handed to
  WhatsApp — and exports everything as CSV or JSON.
- Sorts applications into categories, so a day reads as work, communication,
  browsing, media or games rather than a list of names.
- Shows the day **as it happened** — every recorded stretch in its place on the
  clock, not just totals.
- Has a screen-time goal and **per-application daily limits**, and says when you
  pass either without making a fuss.
- Runs **focus blocks**: start one, and afterwards see how much of it actually
  stayed in work applications — measured, not estimated.
- Sends **one weekly digest** when the week turns, and nothing else unasked.
- Keeps its own record honest: a diagnostics panel checks the stored history
  against the rules the engine is meant to follow.

---

## Screens

| Screen | What it shows |
|---|---|
| **Home** | The day in one figure inside an activity ring, the week beside it, four statistics, and today's applications. |
| **Today** | Screen time, active, idle and sessions; the daily goal; the day as it happened and as a shape; a focus block; daily limits; where the day went by category; every application ranked. |
| **Applications** | Every application over today, seven days or thirty, with its share and trend. Opening one shows its whole history. |
| **Week** | Seven days measured as screen time, active time or sessions, with last week ghosted behind each bar and a direct comparison. |
| **Month** | A calendar where every day is shaded by screen time. Click a day to open it in place. |
| **Year** | Every day of the year as one square, month by month, with the twelve monthly totals and computed insights. |
| **Insights** | What the data actually says over a week, month or year — and the report you can share. |
| **Settings** | Appearance, general behaviour, tracking, screen time, sharing, your data, privacy and about. |

Weeks, months and years can all be stepped back through history; the year
picker only offers years that have data.

---

## Privacy

Tempo is a personal tool and is built like one.

- **No account, no cloud, no analytics, no advertising.** The app makes no
  network requests of its own — not even to check for updates. Settings → About
  can open the releases page, and it is your browser that makes that request.
- **Only the application identity is read** — the executable on Windows, the
  bundle identifier on macOS. No window titles, no documents, no addresses, no
  screenshots.
- **One local file.** Everything is stored in a single SQLite database in your
  own application-support folder. Settings shows the exact path, and can delete
  the whole history.
- **Nothing leaves the machine unless you send it.** Sharing shows you the exact
  text and image first; WhatsApp is opened with the message prefilled and you
  press send yourself.
- On first run Tempo explains all of this and asks before recording anything.

---

## Requirements

**Both platforms**

- Flutter (stable) with desktop support enabled. Developed against Flutter
  3.44, Dart SDK `^3.12.2`.

**Windows**

- Windows 10 or 11.
- Visual Studio 2022 with the *Desktop development with C++* workload.
- Nothing to install for tracking itself: it uses the Win32 APIs already there.

**macOS**

- macOS 10.15 or later.
- Xcode with command-line tools.
- CocoaPods (`sudo gem install cocoapods`) for the plugin pods.

---

## Permissions

**Neither platform asks for anything for what Tempo measures**, and Tempo says
so rather than implying it has more access than it does.

- **Windows** — the foreground window, its process and the executable's own
  description are all readable without elevation or a prompt.
- **macOS** — `NSWorkspace` publishes the frontmost application and
  `CGEventSource` the idle timer. Neither needs Accessibility or Screen
  Recording, because neither reads window contents.
- **Apple's own Screen Time data is private to the system.** Tempo has no
  access to it. What you see is Tempo's own measurement.

Settings shows the real permission state as the platform reports it, rather
than assuming.

---

## Getting started

```bash
git clone <your-repository> tempo
cd tempo
flutter pub get
```

Confirm desktop support is on:

```bash
flutter config --enable-windows-desktop   # on Windows
flutter config --enable-macos-desktop     # on macOS
flutter devices
```

---

## Running

```bash
flutter run -d windows
flutter run -d macos
```

The first launch shows the welcome screen explaining what is measured; nothing
is recorded until you answer it.

Debug builds start with **preview data** on so the interface can be judged
before any real history exists — see [Preview data](#preview-data).

Static analysis:

```bash
flutter analyze
```

---

## Building a release

**Windows**

```bash
flutter build windows --release
```

Output: `build\windows\x64\runner\Release\Tempo.exe` with its `data\` folder
beside it. Ship the whole `Release` folder.

**macOS**

```bash
flutter build macos --release
```

Output: `build/macos/Build/Products/Release/Tempo.app`.

**Installers**

```bash
# Windows: a plain installer (Inno Setup 6)
flutter build windows --release
iscc packaging\windows\tempo.iss

# Windows: an MSIX for the Microsoft Store or sideloading
dart run msix:create

# macOS: build, sign, DMG, notarise and staple in one go
./packaging/macos/build_release.sh
```

`packaging/macos/build_release.sh` takes its identity from the environment
(`TEMPO_SIGN_IDENTITY`, `TEMPO_NOTARY_PROFILE`), so nothing secret lives in the
repository; without them it still produces an unsigned DMG. The MSIX identity
lives in `msix_config` in `pubspec.yaml` — set `publisher` to your certificate
subject before signing.

Before distributing:

- Set your own bundle identifier in `macos/Runner/Configs/AppInfo.xcconfig`
  (`PRODUCT_BUNDLE_IDENTIFIER`, currently `com.tempo.desktop`) and sign the app
  with your team.
- The app is sandboxed. `macos/Runner/*.entitlements` already grant
  `files.downloads.read-write`, which is what saving reports and exports needs.
- Bump `version:` in `pubspec.yaml`; `AppInfo.version` in
  `lib/core/constants/app_info.dart` is what the About section shows.

---

## Architecture

```
lib/
  app/                     window setup, MaterialApp, theming entry
  core/
    constants/             product facts
    layout/                desktop breakpoints, scroll behaviour
    motion/                durations, curves, entrances, reduced-motion gate
    platform/              which desktop this is
    theme/                 colours, typography, metrics, heat scale, palette
    utilities/             date maths, formatting
  data/
    analytics/             repositories and providers
    database/              SQLite: schema, usage DAO, settings DAO
  domain/
    analytics/             models and pure aggregation
    tracking/              sessions, tracking status, the engine
  features/
    applications/ dashboard/ insights/ month/ navigation/ onboarding/
    settings/ sharing/ shell/ today/ week/ year/
  platform/
    desktop/               tray, window behaviour
    notifications/         desktop notifications
    startup/               launch at login
    usage_tracking/        the platform contract and its two implementations
  shared/widgets/          glass components, charts, stats, states
```

Principles the code sticks to:

- **One design system.** Every colour, radius, duration and shadow comes from
  `core/theme` and `core/motion`; no screen invents its own.
- **Screens never touch storage.** They read `AnalyticsRepository`, so the same
  interface serves the database, the preview generator, and the failure case.
- **Aggregation is pure.** `UsageAggregate` and the summary models are plain
  Dart with no I/O, so they behave the same wherever the days came from.
- **Platform code is isolated.** `UsageTrackingPlatform` is the only thing that
  knows Win32 or AppKit exists.
- **State is Riverpod.** Controllers hold state, providers compose it, and
  `usageRevisionProvider` is the single signal that stored usage changed.

---

## How tracking works

```
Timer (5s)
   ↓
UsageTrackingPlatform.activeApplication()   ← Win32 / NSWorkspace
   ↓
UsageTrackingService                        ← sessions, idle, sleep, midnight
   ↓
UsageDao.saveSession()                      ← SQLite, day rebuilt from sessions
   ↓
usageRevisionProvider                       ← every screen re-reads
```

The rule underneath all of it: **Tempo only records time it actually watched.**

- **Sampling.** Every five seconds; the open session is *updated in place*
  about once a minute, so a two-hour stretch is one row rather than a hundred,
  and a crash costs at most a minute.
- **Grouping.** By executable name on Windows, bundle identifier on macOS. The
  display name is the executable's own file description, so you see "Google
  Chrome", not "chrome.exe".
- **Idle.** When input stops for longer than the timeout (1, 5, 10, 15 minutes,
  or never), the session is closed *at the moment input stopped*, not when the
  timeout expired. Idle is recorded against the day and belongs to no
  application.
- **Sleep and clock changes.** A stopwatch runs beside the wall clock. It
  cannot be set by hand and does not run while the machine sleeps, so when the
  two disagree Tempo knows it was not watching: the session closes at the last
  observed moment and the gap counts as nothing. This covers sleep, suspension,
  network clock corrections, manual changes, daylight saving and time-zone
  moves.
- **Lock and wake.** macOS announces sleeping, waking and screen locking, and
  measurement stops and starts at that moment. Windows publishes nothing Tempo
  can hear from Dart, so its lock and sign-in screens are simply not treated as
  applications.
- **Midnight.** Sessions never cross a day boundary, so a day's totals are
  always whole.
- **Pausing** is a stored preference: it survives a restart, and the sidebar
  pill, the tray menu and Settings all write the same one.

---

## The database

One SQLite file, opened before the first frame, in the platform's
application-support folder (Settings shows the path). WAL journaling, so the
engine's small writes never block the screens reading.

| Table | Holds |
|---|---|
| `usage_sessions` | Every measured stretch: application id and name, start, end, duration, local day, platform. Indexed by day and by application. |
| `daily_summaries` | One row per day: active seconds, idle seconds, session count, longest session, and the day's per-hour minutes. |
| `application_summaries` | One row per application per day. |
| `settings` | Preferences, stored beside the history rather than in a second place. |

Summaries are always **rebuilt from the sessions** of the day they belong to,
so they can never drift from the record they came from. Days with nothing
stored are returned as empty days rather than missing ones, which is why charts
keep their rhythm across quiet stretches.

---

## The year grid

The signature screen. Every day of the selected year is one rounded square,
laid out in Monday-first week columns, shaded on a four-step blue-to-violet
scale against the busiest day of that year.

- The whole grid is **painted as a single layer**, so 365 or 366 cells cost one
  repaint rather than several hundred widgets.
- Leap years need no special case: the grid draws whatever days the calendar
  returns, and the first column's offset comes from 1 January's weekday. 2024
  and 2028 get 366 squares and the correct starting row automatically.
- Hovering resolves from the pointer and raises a card with the date, screen
  time, top application and session count. Clicking opens that day in full
  underneath.
- Year navigation offers the first recorded year through this one; a year with
  nothing in it says so rather than showing an empty grid.
- The insights below it are computed from the stored days: hours in the year,
  most-used application, busiest month, change in daily average against last
  year, longest session and its date, heaviest and lightest days, heaviest
  weekday, and days used out of 365 or 366. Anything that cannot be worked out
  is left out rather than invented.

---

## Sharing a report

Insights → **Share report** (also in Settings) opens a flow that shows exactly
what would leave the machine before anything does:

1. The **card** as an image — the totals, the trend and your top applications,
   always drawn in the midnight identity at a fixed size.
2. The **text** as it will read, which you can select and edit after copying.
3. **Application names** can be left out, giving totals only.
4. Four actions: copy the text, save the text, save the image (PNG, rendered at
   three times its logical size), or **Share to WhatsApp** — which opens
   WhatsApp with the message prefilled through `wa.me`. Tempo never sends
   anything; you choose the chat and press send.

Saved files land in your Downloads folder.

---

## Exporting your data

Settings → Your data → **CSV** or **JSON**. Both cover everything stored.

CSV columns:

```
date,active_seconds,idle_seconds,sessions,longest_session_seconds,
application,application_id,application_seconds
```

JSON carries the same, plus each day's per-hour minutes.

Files are written to Downloads as `tempo-usage-YYYY-MM-DD.csv` (or `.json`).
Exports made while preview data is on are named `tempo-preview-…` so they can
never be mistaken for measurements.

---

## Looking after your data

Settings → **Looking after it**:

- **Keep history for** — Forever (the default), 1 year, 6 months or 3 months.
  Older days are removed the next time Tempo starts.
- **Back up** — writes a complete copy of the database to Downloads using
  SQLite's own `VACUUM INTO`, so the copy is consistent even though the engine
  may be mid-write.
- **Restore from an export** — reads a Tempo JSON export back in, session by
  session. Importing the same file twice changes nothing: a session is the same
  session if it is the same application starting at the same moment.
- **Tidy the database** — rewrites the file compactly, reclaiming space left by
  anything deleted.

Settings → **Diagnostics** asks the app whether its own record makes sense: no
session crossing midnight, none overlapping another, every day's totals
matching the sessions behind them, and the file itself sound. The report can be
copied, and errors are written to a rolling log beside the database
(`tempo.log`), which the same panel can open.

## Preview data

Debug builds start with sample activity so the interface can be designed and
reviewed before any history exists.

- It is **deterministic** — the same day always looks the same.
- While it is on, the title bar shows a **Preview data** badge and shared cards
  are stamped `PREVIEW DATA`.
- A release build cannot turn it on: the controller refuses outside debug mode.
- Turn it off in Settings → Developer to see your own measurements.

---

## Known limitations

- **Windows sleep is inferred, not announced.** Windows publishes no power
  event Tempo can receive from Dart, so sleep is detected by the stopwatch
  disagreeing with the wall clock. The result is correct; it is simply noticed
  at the next sample rather than at the instant.
- **macOS screen-lock notifications may be restricted** under the sandbox on
  some versions. If they do not arrive, idle detection and the drift guard
  still cover it.
- **Application icons are stand-ins.** Each application is shown as its initial
  on a tinted tile; extracting real icons from executables and bundles is not
  done yet.
- **CSV exports carry daily roll-ups only.** The JSON export carries the
  sessions themselves, which is what makes it restorable; CSV stays a
  spreadsheet-friendly summary.
- **Retention is applied at startup**, not continuously, so a window left open
  for weeks keeps what it has until the next launch.
- **No automated tests.** See [Project rules](#project-rules).
- **Linux** builds will run, but nothing is measured: the platform layer
  reports itself unsupported and the interface says so.

---

## Troubleshooting

**"Tempo could not open its usage database."**
The file could not be opened — a full disk, a read-only folder, or a corrupted
database. The app still runs. Quit, check the path shown in Settings → Your
data, and restart. Deleting that file loses your history but always fixes it.

**The tracking pill says "Not available here."**
Either the platform is unsupported (Linux) or the database could not be opened.
Both are reported honestly rather than shown as an empty week.

**Nothing is being recorded.**
Check Settings → Tracking: the status must not be paused, and preview data must
be off if you expect your own numbers. Tracking is a stored preference, so a
pause made earlier is still in effect after a restart.

**Notifications never appear (Windows).**
Toast notifications require a Start-menu shortcut, which the app creates on
first run. If notifications are blocked for Tempo in Windows settings, no
notification will be shown.

**Closing the window does not quit the app.**
That is the default: Tempo keeps measuring from the tray. Use the tray menu's
**Quit Tempo**, or turn off Settings → General → Keep running in the
background.

**Nothing shows up for a past year.**
The year picker only offers years with recorded data, and a year with nothing
in it says so.

---

## Project rules

This repository is built under two rules from its owner, and they explain what
you will not find here:

- **No tests, ever.** No test files, no test runner. `test/` was removed.
  Verification is `flutter analyze` only, which passes with no issues.
- **The app is never run or built as part of development.** Every change is
  written and analysed statically. The native paths — Win32 FFI, the Swift
  channel, the tray, startup and notifications — have been analysed, not
  exercised.

`DESIGN.md` holds the design direction, `RULES.md` the working agreement, and
`PROGRESS.md` a phase-by-phase record of what was built and where each phase
stopped.
