# Tempo — Progress

Design-first build. Rules in `RULES.md`, design direction in `DESIGN.md`.
One phase per turn. Verification is `flutter analyze` only.

## Phase plan

| Phase | Scope | Status |
|---|---|---|
| 1 | Foundation: architecture, design tokens, both themes, glass component library, icon set, ambient background, desktop shell (custom title bar, sidebar, tracking pill), navigation + page transitions + keyboard shortcuts, responsive rail, all eight destinations reachable with designed empty states, working Appearance settings | **done** |
| 2 | Home dashboard + Today: analytics layer (repository + models), hero screen-time figure with counting numbers, activity ring, active vs idle split, seven-day chart, hour-by-hour timeline, animated application rows | **done** |
| 3 | Applications list + application detail: range switching, ranking cards, share of period, trend, per-application history chart and facts | **done** |
| 4 | Week + Month: period navigation, seven-day chart with measure switching and last-week ghosts, week-over-week comparison, month calendar heatmap with day drill-in | **done** |
| 5 | Year: 365/366-day activity grid with hover detail and day drill-in, year navigation across recorded years, monthly comparison, computed yearly insights | **done** |
| 18 | Day timeline, weekly digest, application limits, focus blocks | **done** |
| 17 | Distribution: Inno Setup installer, MSIX configuration, macOS sign/DMG/notarise script, releases link | **done** |
| 16 | Looking after the data: retention, backup, restore from an export, optimise, sessions in the JSON export | **done** |
| 15 | Categories: seven kinds of application, defaults plus corrections, category split on Today and Week, picker on the detail page | **done** |
| 13 | Field hardening: rolling log file, diagnostics panel with integrity checks | **done** |
| 12 | Release: README, product identity, dependency pass, build configuration | **done** |
| 11 | System integration: tray icon and menu, background running, launch at startup, notifications, app icon and product identity | **done** |
| 10 | Accuracy: sleep, wake and lock, clock and time-zone changes, first-run explanation, permission state, tracking that stays off when turned off | **done** |
| 8 + 9 | Tracking engine: Windows and macOS foreground detection, session building, idle handling, pause/resume | **done** |
| 7 | Storage: SQLite schema, real repository, preference persistence, history deletion | **done** |
| 6 | Insights with span switching, the share flow (card, text, WhatsApp, files), daily goal, export, full Settings, final polish | **done** |

Functionality (SQLite, foreground-app detection on Windows/macOS, idle and
sleep handling, tray, startup, notifications, export, sharing) comes after the
design phases. Nothing in the UI invents data it does not have.

## Phase 1 — delivered

**Design system** (`lib/core/`)
- `theme/tempo_colors.dart` — semantic colour slots, midnight + daylight, lerp,
  the three product gradients, three shadow recipes.
- `theme/tempo_metrics.dart` — 4pt spacing scale, radius scale, chrome sizes.
- `theme/tempo_typography.dart` — system display-face stack, tabular figures,
  full text theme.
- `theme/tempo_theme.dart` — `TempoTheme` theme extension (animates between
  appearances) + `context.tempo` / `context.colors` / `context.typo`.
- `motion/` — durations, curves, reduced-motion gate, `TempoEntrance`,
  `HoverBuilder`, `PressableScale`, `TempoPageSwitcher`.
- `layout/` — desktop breakpoints, desktop scroll behaviour.
- `utilities/tempo_dates.dart` — DST-safe date maths, leap-year-safe day counts,
  greeting, week range.

**Components** (`lib/shared/widgets/`)
- `glass/` — `GlassSurface` (the one primitive), `GlassCard`, `GlassPanel`,
  `GlassButton`, `GlassIconButton`, `TempoSegmented`.
- `tempo_icon.dart` — 20 hand-drawn glyphs on a 24pt grid, one stroke weight.
- `tempo_mark.dart` — the Tempo identity mark (orbit + travelling point).
- `ambient_background.dart` — gradient, four drifting light blobs, vignette.
- `page_scaffold.dart`, `empty_state.dart`, `awaiting_data.dart`.

**Shell** (`lib/app/`, `lib/features/shell/`)
- `main.dart` → window setup → `ProviderScope` → `TempoApp`.
- `window_setup.dart` — hidden system title bar, 1120×700 minimum,
  1440×900 default, native window buttons kept on macOS.
- `app_shell.dart` — ambient room, sidebar, overlaid title bar, page host with
  crossfade transitions, Cmd/Ctrl+1…8, Cmd/Ctrl+, and Cmd/Ctrl+B.
- Sidebar with gliding selection pill, rail collapse below 1180px (or by
  choice), live tracking pill reporting real engine state.

**Destinations** (`lib/features/`)
- Home, Today, Applications, Week, Month, Year, Insights — real headers with
  live dates and a tailored empty state that shows the true tracking state.
- Settings — working Theme, Accent intensity and Sidebar controls, plus Privacy
  and About. Nothing that does not yet exist is shown.

## Phase 2 — delivered

**Analytics layer**
- `domain/analytics/` — `AppUsage`, `DaySummary` (active, idle, sessions, longest
  stretch, per-hour minutes, ranked apps, `topApps` folding the tail into
  "Other"), `HomeOverview` (week + previous week), `AnalyticsRepository`.
- `data/analytics/` — `EmptyAnalyticsRepository` (production, until the usage
  engine lands: reports honestly that nothing is measured) and
  `PreviewAnalyticsRepository` (deterministic sample activity for design work).
- `analytics_providers.dart` — `previewDataProvider` (can only ever be true in a
  debug build), the repository selector, `todaySummaryProvider`,
  `homeOverviewProvider`. Screens read `AsyncValue` and render loading, error,
  empty and data states.
- While preview data is on, the title bar carries a **Preview data** badge and
  Settings gains a Developer section to switch it off. A release build cannot
  turn it on.

**Components**
- `stats/` — `AnimatedDuration` and `AnimatedCount` (counting figures, tabular),
  `DeltaChip` (non-judgmental comparison), `MetricCard` + `SplitBar`,
  `MetricGrid` (4 → 2 → 1 columns, equal heights).
- `charts/` — `ActivityRing` (gradient sweep, glow without a blur filter,
  travelling head), `TempoBarChart` (tracked bars, staggered growth, hover +
  tooltip), `DayTimeline` (24 hourly columns), `UsageRow` (application mark,
  time, animated share bar, trend).
- `AppGlyph` (per-application tone + initial, standing in until real icons),
  `LiveClock`, `PageLoading`, `ErrorStateView`, `EmptyState` tone support,
  `tempo_format.dart`, `tempo_palette.dart`, two new glyphs.

**Screens**
- **Home** — greeting, live clock, hero card (screen time inside the activity
  ring, week comparison chip, active/idle legend), seven-day chart with totals,
  four metric cards, today's top applications with a route to the full list.
- **Today** — screen time / active / idle / sessions, the day hour by hour with
  hover detail and the longest stretch, then every application ranked.

## Phase 3 — delivered

**Aggregation**
- `domain/analytics/usage_aggregate.dart` — pure roll-ups shared by every
  screen: active/screen totals, per-application totals, `mergeApps` (merges
  days into one ranked list and carries the previous span for trends),
  `seriesFor`, `peakOf`, and the `DayValue` point type.
- `domain/analytics/application_detail.dart` — today / this week / this month /
  this year, the thirty-day series, days used, share of the year, busiest day.

**Controller** (`features/applications/applications_controller.dart`)
- `AppsRange` (Today / 7 days / 30 days) with its own captions and comparison
  wording, `ApplicationsOverview`, the ranked-list provider (fetches the span
  and the span before it), `SelectedApp` + selection controller, the
  `applicationDetailProvider` family, and `openApplication`, which any screen
  can call to jump straight to an application.

**Screens**
- **Applications** — range segmented control in the header, four summary cards
  (active time, applications, most used, comparison), then ranked cards: place,
  mark, name, platform identity, time, share bar, percentage, trend chip and a
  chevron that leads in.
- **Application detail** — the mark and identity in the header with a week
  trend chip and a way back, totals for today/week/month/year, a history chart
  that switches between the last seven and last thirty days, and a facts panel
  (busiest day, days used this year, share of active time, average per day
  used).
- Rows on Home and Today now open the application they name; grouped "Other"
  entries open the list instead. Escape leaves a detail view, and the sidebar
  always returns Applications to its ranked list.

## Phase 4 — delivered

**Models and controllers**
- `WeekSummary` / `MonthSummary` — totals, recorded days, averages over days
  with activity, longest session, busiest and lightest days, month peak for the
  heat scale, ranked applications with the previous period for trends.
- `week_controller.dart` — `WeekMeasure` (screen time / active / sessions) with
  its own units and wording, week offset stepping, `weekSummaryProvider`.
- `month_controller.dart` — month offset stepping, `selectedDayProvider` (day
  opened from the calendar, cleared when the month changes),
  `monthSummaryProvider`.

**Components**
- `TempoHeat` — the four-step blue-to-violet intensity scale plus `HeatLegend`,
  shared by the month calendar and, next phase, the year grid.
- `PeriodStepper` — ‹ label › with a way back to the present and no stepping
  into the future.
- `CalendarHeatmap` — Monday-first month grid, today ringed, hover detail,
  click to open, cascading in a row at a time.
- `DayDetailPanel` — any day in place: totals, hour-by-hour timeline and its
  applications. Built to be reused by the year grid.
- `TempoBarChart` generalised to numeric amounts with an optional ghost bar for
  the same measure a period earlier.

**Screens**
- **Week** — steps between weeks, four cards (screen time with the week trend,
  daily average, most used, longest session with the busiest day), the seven-day
  chart with a measure switch and last week behind each bar, an "against last
  week" comparison, and the week's applications.
- **Month** — steps between months, four cards (screen time with the month
  trend, daily average, most used, busiest day), the calendar with its legend
  and busiest/lightest footnotes, and the opened day below it.

## Phase 5 — delivered

**Model**
- `YearSummary` — built in a single pass over the year: totals, active days,
  sessions, busiest and lightest days, longest session and the day it fell on,
  twelve monthly totals plus last year's, weekday totals and counts. Day counts
  come from the calendar, so 366-day years need no special case.
- `AnalyticsRepository.earliestDay()` — how far back navigation may go.
  `TempoDates.daysInYear` now derives from February rather than a Duration,
  which a daylight-saving change could round the wrong way.

**Controller** (`features/year/year_controller.dart`)
- `selectedYearProvider` (defaults to the calendar year, never hard-coded),
  `availableYearsProvider` (first recorded year through this one),
  `yearSummaryProvider` (the year and the year before it), `yearDayProvider`
  for the day opened from the grid.

**Components**
- `YearActivityGrid` — the signature view. Every day of the year is one rounded
  square in a Monday-first week grid, painted as a single layer so 365 cells
  cost one repaint. Month names sit above the column each month starts in, read
  off the day list. Columns reveal left to right; hovering resolves from the
  pointer and raises a glass card with the date, screen time, top application
  and session count; clicking opens the day.
- `InsightCard` — figure plus the sentence behind it, ready for Phase 6.

**Screen**
- **Year** — the year as the title with `‹ 2026 ›` navigation that stops at the
  first recorded year and offers a way back to this one, six cards (screen time
  with the year-over-year trend, average per day, most used, most active day,
  longest session, active days), the activity grid with its legend, the opened
  day below it, twelve monthly bars with last year ghosted behind each, and the
  insight cards.
- `year_insights.dart` — every line computed from stored days: hours in the
  year, most-used application, busiest month, change in daily average against
  last year, longest session and its date, heaviest and lightest days, heaviest
  weekday, and days used out of 365 or 366. An observation that cannot be made
  is left out rather than invented.

## Phase 6 — delivered

**Insights**
- `InsightReport` — one pass over a span: screen/active/idle, sessions, active
  days, busiest and lightest day, longest session and its date, ranked apps.
- `InsightSpan` (Week / Month / Year) compares the span so far against exactly
  as many days of the span before it, so a half-finished week is never measured
  against a whole one.
- **Insights screen** — headline card (figure, trend, active/idle split, four
  sub-stats) and up to ten computed observation cards. Anything not derivable
  is left out rather than invented.

**Sharing** (`features/sharing/`)
- `ShareCard` — the image, always drawn in the midnight identity at a fixed
  460×640 so exports are predictable, carrying the total, daily average, trend
  and top applications, stamped `PREVIEW DATA` when preview data is on.
- `buildShareText` — the message, honouring the application-names preference.
- `ShareService` — copy to clipboard, open WhatsApp with the text prefilled
  (`wa.me`, nothing sent by Tempo), save the text, and render the card at 3×
  into a PNG. Files land in Downloads.
- `ShareSheet` — the card as it will look, the text as it will read, the
  names toggle, and the four actions. Reachable from Insights and Settings.

**Settings, goal and export**
- Appearance, Screen time (daily goal), Sharing, Your data (CSV + JSON export
  of everything stored), Privacy, Developer, About with a themed licence page.
- `TempoPreferences` — daily goal and the application-names choice, honoured
  today. They live in memory until the storage layer lands, deliberately: one
  place will write preferences and history, not two.
- **Daily goal on Today** — the activity ring against the goal, `5h 12m / 6h`,
  and a plain sentence when it is passed.
- `ExportService` — daily roll-ups as CSV or JSON; an empty history is reported
  rather than written as an empty file. Session times join when the engine
  records them.

**Components and polish**
- `GlassDialog` and `TempoToast` complete the component library.
- `InsightLine` shared by the year and insights screens.
- Repaint boundaries around the bar chart and day timeline; the year grid was
  already isolated.

## Phase 7 — delivered

**Database** (`lib/data/database/`)
- `tempo_database.dart` — one SQLite file in the platform application-support
  folder, opened before the first frame, WAL journaling, versioned schema with
  an upgrade path. A file that cannot be opened returns null instead of
  crashing the app.
- Schema: `usage_sessions` (every measured stretch, indexed by day and by
  application), `daily_summaries` (active, idle, session count, longest
  session, per-hour minutes), `application_summaries` (per application per
  day), `settings` (preferences).
- `usage_dao.dart` — reads days and ranges (gaps come back as empty days so
  charts keep their rhythm), earliest recorded day, recorded-day count; writes
  sessions in a transaction and rebuilds every day they touch, spreading each
  session across the hours it actually covers; sets idle per day; deletes all
  history or everything before a date.
- `settings_dao.dart` — key/value preferences with the keys in one place.

**Wiring**
- `SqliteAnalyticsRepository` is now the production repository;
  `UnavailableAnalyticsRepository` throws `StorageFailure` when the database
  could not be opened, so the screens show their storage error rather than a
  quiet empty week. `EmptyAnalyticsRepository` is gone.
- `usageRevisionProvider` — every data provider watches it, so anything that
  changes stored usage refreshes all nine screens at once. The tracking engine
  will bump it after each flush.
- `UsageSession` — the entity the engine will produce. Sessions never cross
  midnight, so a day total never needs splitting.

**Preferences and privacy**
- Theme, accent intensity, daily goal and the application-names choice are read
  from the database at startup and written back on change.
- Settings gained a real **Delete history** action, with a confirmation that
  says how many days will go, and a row showing exactly where the file lives.
- macOS entitlements now include Downloads read/write, since the app is
  sandboxed and reports and exports are written there.

## Phases 8 and 9 — delivered

**Platform layer** (`lib/platform/usage_tracking/`)
- `UsageTrackingPlatform` — the shared contract: `activeApplication()`,
  `idleTime()`, `permission()`, `requestPermission()`, plus a sentence for
  Settings about what each system allows. `UsageTrackingPlatform.forThisDevice`
  picks the implementation; anywhere else gets `UnsupportedUsageTracker`, which
  says so instead of pretending.
- **Windows** — `GetForegroundWindow` → `GetWindowThreadProcessId` →
  `OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION)` →
  `QueryFullProcessImageName`, through `package:win32`. Usage is grouped by the
  executable name, so ten Chrome windows are one application. The display name
  is the executable's own file description ("Google Chrome"), read once per
  executable and cached, falling back to a tidied file name. Idle comes from
  `GetLastInputInfo` against `GetTickCount`, handling the 49-day tick wrap. No
  window titles or documents are read.
- **macOS** — a method channel registered in `MainFlutterWindow.swift`, so no
  Xcode project changes were needed. `NSWorkspace.frontmostApplication` gives
  the bundle identifier and localised name; idle is the shortest
  `CGEventSource.secondsSinceLastEventType` across the real input events.
  Neither needs Accessibility or Screen Recording permission, and Apple's own
  Screen Time data stays private — Tempo says so rather than implying access.

**Engine** (`lib/domain/tracking/usage_tracking_service.dart`)
- Samples every 5 seconds, writes about once a minute, and updates the session
  it is holding open in place, so a two-hour stretch is one row rather than a
  hundred.
- Idle: the session is closed at the moment input actually stopped, not when
  the timeout expired, and the idle stretch is counted against the day rather
  than any application. `Never` turns it off.
- Sleep and suspension: a gap much larger than the sample interval closes the
  open session at the last moment Tempo actually saw, so a sleeping machine
  records nothing.
- Midnight: sessions never cross a day, so day totals are always whole.
- Pause and resume: the sidebar pill and Settings both toggle it, and pausing
  writes down whatever was open first.

**Wiring**
- The shell watches the engine, so it runs exactly as long as the window is
  open and writes down what it was holding on the way out.
- The tracking pill is now live: it reports the real state and pauses on click.
- Settings gained a Tracking section — status, pause/resume, and the idle
  timeout (1m / 5m / 10m / 15m / Never), all stored in the database.

## Phase 10 — delivered

**One rule, applied everywhere: Tempo only records time it actually watched.**

**Sleep, suspension and the clock**
- A stopwatch runs beside the wall clock. It cannot be set by hand and does not
  run while the machine sleeps, so the two disagreeing is how the engine knows
  the machine stopped or the clock moved — a network correction, a manual
  change, a time-zone shift, a daylight-saving jump or a suspended process all
  land in the same guard. The open session closes at the last moment actually
  observed and the gap counts as nothing, in any application or in idle.
- A clock that goes backwards closes the session at its own last known end
  rather than at a timestamp in the future.

**Sleep, wake and lock as events**
- `SystemEvent` joins the platform contract. macOS publishes sleep, wake,
  session switching and screen locking through `NSWorkspace` and the
  distributed notification centre, forwarded over the existing channel, so
  measurement stops at the moment it happens rather than at the next sample.
- Windows has no equivalent Tempo can hear from Dart, so the drift guard covers
  sleep, and the lock and sign-in screens (`LockApp.exe`, `LogonUI.exe`) are
  simply not treated as applications. macOS ignores `loginwindow` the same way.

**Idle, honestly**
- Idle is accumulated only across intervals Tempo was awake for. After a wake
  the system reports hours of "idle"; none of it is counted, because none of it
  was watched.

**First run and permission**
- `WelcomeOverlay` explains, before anything is recorded: what is measured,
  what is never read, where it is kept, what this system requires, and the two
  answers — **Start measuring** or **Not now**. Both are honoured, and the
  choice is stored.
- `trackingPermissionProvider` reads the real state; Settings shows it rather
  than assuming. Neither Windows nor macOS asks for anything for what Tempo
  does, and the app says so instead of implying otherwise.
- Tracking on or off is now a stored preference, so a pause survives a restart.
  The sidebar pill, Settings and the first-run choice all write the same one.

## Phase 11 — delivered

**Identity**
- The supplied artwork is now the application icon everywhere: cropped to its
  own rounded square, masked so the corners are transparent, and written out at
  every size macOS asks for plus a multi-size Windows `.ico`.
- The Windows tray icon is the same artwork; the macOS menu bar gets a drawn
  template version of the Tempo mark, so the system inverts it correctly in
  light and dark bars.
- Product identity fixed up: the window, the executable's version strings and
  the macOS product name all say Tempo rather than the template's placeholder.

**Tray and background** (`lib/platform/desktop/desktop_integration.dart`)
- A tray icon whose tooltip and menu always say what the app says: today's
  screen time, open Tempo, Settings, pause or resume tracking, and quit.
- Closing the window leaves Tempo measuring from the tray, or quits properly,
  depending on the new **Keep running in the background** setting. Quitting
  always finishes and writes down the open session first.
- Left click opens the window on Windows; on macOS it raises the menu, as it
  should.

**Startup**
- `launch_at_startup` registers Tempo through the mechanism each system already
  has — the Run key on Windows, a login item on macOS — and the setting is read
  back from the system rather than remembered separately.
- Opened at login it starts with `--hidden`: straight into the tray, measuring,
  without taking over the screen.

**Notifications** (`lib/platform/notifications/notification_service.dart`)
- Two, at most once each per day: today passing the goal, and two unbroken
  hours in one application. Both state a measured fact and neither scolds.
- One switch in Settings turns them off entirely.

**Settings**
- A General section: keep running in the background, launch at startup, and
  notifications.

## Phase 12 — delivered

- **README.md** — what Tempo does, every screen, the privacy position,
  requirements and permissions per platform, exact run and build commands, the
  architecture and its principles, how tracking works, the database schema, how
  the year grid handles 365 and 366 days, sharing, exporting, preview data,
  known limitations, troubleshooting, and the project's own rules.
- **Product identity** — `Tempo.exe` rather than `tempo.exe`, real version
  strings, `com.tempo.desktop` as the macOS bundle identifier, and the version
  the About section shows aligned with `pubspec.yaml` at 1.0.0.
- **Dependency pass** — `cupertino_icons` removed (the product draws its own
  glyphs); every remaining dependency is used by shipped code.
- **Artwork** kept with the project at `assets/branding/app_icon_source.png`,
  out of the root and out of the bundle.

## Phases 13, 15, 16 and 17 — delivered

Phase 14 (real application icons) was deliberately skipped.

**13 · Field hardening**
- `TempoLog` — a rolling log beside the database, holding failures rather than
  usage. Every quiet failure in the engine, the platform layer, the database,
  the tray and the notifications is written there.
- Settings → Diagnostics — what is stored, whether it is self-consistent, and
  where the file and log are. The checks are the engine's own promises: no
  session crossing midnight, none overlapping, day totals matching their
  sessions, and SQLite's own integrity check. The report can be copied and the
  log folder opened.
- The two failures found by actually running the app — the shell Stack needing
  `StackFit.expand`, and the opening size needing to be clamped to the display
  — were already fixed in the working tree.

**15 · Categories**
- `AppCategory` — work, communication, browsing, media, games, system, other;
  each with its own tone, and work counting as focused time.
- Defaults for around ninety common applications on both platforms, with
  corrections stored in a new `application_categories` table (schema 2, with
  its migration). Only corrections are stored, so better defaults later still
  reach applications nobody has touched.
- `CategoryCard` on Today and Week: one proportional bar, a legend, and how
  much of the period was focused. `CategoryPicker` on an application's own page
  moves it, and every screen re-reads.

**16 · Looking after the data**
- Retention (Forever / 1 year / 6 months / 3 months), applied at startup.
- Backup through SQLite's `VACUUM INTO`, so the copy is consistent even mid-write.
- The JSON export now carries the sessions themselves, and `ImportService`
  reads them back — twice over the same file changes nothing.
- `VACUUM` on demand, and the whole lot in a Settings section of its own.

**17 · Distribution**
- `packaging/windows/tempo.iss` — a per-user Inno Setup installer that leaves
  the usage database alone on uninstall.
- `msix_config` in `pubspec.yaml` for the Store or sideloading.
- `packaging/macos/build_release.sh` — build, sign, DMG, notarise, staple, with
  every identity taken from the environment.
- Settings → About can open the releases page. Tempo still makes no network
  request of its own; the browser makes that one.

## Phase 18 — delivered

Four features, chosen over real application icons, which stays skipped.

**The day's real timeline**
- `AnalyticsRepository.sessions(day)` joins the contract; SQLite reads them,
  the preview generator makes plausible ones from the same shape as its totals,
  and the unavailable repository fails like everything else.
- `SessionTimeline` draws every recorded stretch in its place on the clock, in
  its application's own colour, with hour marks, hover detail and a click
  through to the application. It is the only view drawn from sessions rather
  than summaries — which also makes it the way to see that the engine measured
  what you remember doing.

**Daily limits**
- `application_limits` (schema 3) with a limit picker on an application's own
  page, a Today card showing where each stands, and a notification the first
  time one is reached in a day.

**Focus blocks**
- `focus_sessions` (schema 3), a controller that runs the block and, when it
  ends, flushes the engine and reads the sessions inside the window to work out
  how much stayed in focus categories. Nothing is estimated.
- A card on Today: pick 25, 50 or 90 minutes, watch the ring, see whether what
  is in front counts as focus while it runs, and keep the last few results.

**Weekly digest**
- One notification when the week turns: the total, the daily average, what led,
  and how it compares with the week before. The week it covered is stored, so a
  restart cannot make it repeat. Its own switch in Settings.

## Stopping point

All six design phases and the storage phase are complete and analysing clean. The interface is
finished: every screen, component and animation in `DESIGN.md` exists, and no
screen shows a number it did not compute.

All twelve phases are complete and analysing clean. Tempo is finished as
specified: a designed desktop product that measures real application usage on
Windows and macOS, stores it locally, and shows it across nine screens.

What is left is what this project's rules put out of bounds — running the app
and producing the release builds:

    flutter build windows --release
    flutter build macos --release

The native paths (Win32 FFI, the Swift channel, tray, startup, notifications)
have been written and analysed but never executed here, so they are the first
things to exercise on a real machine. `README.md` covers everything needed to
do that.
`test/` was removed: it held only the generated counter-app test, and the
project rules forbid tests.

---

## Identity and first run (post-release pass)

- **App icon** — the supplied Tempo artwork is now the product's icon everywhere
  Windows and macOS look for one. `assets/branding/app_icon_source.png` is the
  1254px master; everything else is generated from it with Pillow:
  `windows/runner/resources/app_icon.ico` (9 sizes, 16 → 256),
  `assets/tray/tray_icon.ico` (the mark alone, cut off its tile, 16 → 64, so it
  still reads in the notification area), the seven
  `macos/.../AppIcon.appiconset/app_icon_*.png`, `assets/branding/app_icon.png`
  for `msix_config.logo_path`, and `assets/branding/tempo_icon.png`, the only
  one bundled — the 512px tile the first run shows. Regenerate all of them
  together if the artwork ever changes.
- **First run** — one card became four pages: welcome, what is measured, the six
  views, and the two behaviour choices. `welcome_overlay.dart` owns the paging,
  the dots, the keyboard (←/→/Enter) and the two endings;
  `onboarding_pages.dart` holds the pages and the six miniature charts, which
  are the real charts' silhouettes drawn from one controller with a staggered
  interval each. Every duration goes through `TempoMotion`, so "reduce motion"
  makes the whole flow static rather than fast.

## Chrome and hover polish

- **Page header** trimmed twice: the window strip is 32pt, the header pads
  `titleBar + 4` above and 12 below, the title is `headlineSmall` and the
  subtitle `bodySmall`. The block went from ~147pt to ~93pt, so a full row of
  cards and the metric row sit on screen together.
- **The title is lit**: `_LitTitle` runs a band of accent and violet through
  the page title on a 5.2s loop and leaves it white again. `TempoMotion`
  stills it under "reduce motion".
- **Cards answer with light, not depth**: hovering drops the shadow entirely,
  the standing edge line under the cursor is gone, and one long arc of the
  three accents travels the outline over 11 seconds. The controller turns only
  while the pointer is on the card.
- **The brand** is the mark inside its own 18s orbit, the name in a
  white-to-violet gradient and `SCREEN TIME` in spaced small caps.
- **Settings** ends with an *About me* card: monogram, name, and the address,
  with a Write button that opens a mail composer.
- **Every screen** signs off bottom-right with `© Rahoz Osman`, from
  `_Colophon` in `PageScaffold`, so no page has to remember it.

## Room for the data

- **About is a section**, not a settings row: `TempoSection.about` sits between
  Insights and Settings with its own page — the developer's name plate, what
  Tempo measures, five things worth knowing on the first day, and the keyboard.
  The Settings card that briefly held it is gone, and `Ctrl+9` reaches it.
- **The heading gets out of the way.** `PageScaffold` no longer condenses into
  a glass strip: there is no strip. It sits on the page's own background, and
  a `UserScrollNotification` hides it — height and opacity together — the
  moment you scroll down, bringing it back on the first scroll up or at the
  top of the page. The title is `titleLarge`, the block ~84pt.
- **The rail is 140pt**, from 248. Every label still reads: the lockup, rows,
  tracking pill and privacy line were all refitted, and the two lines that no
  longer fit (the tracking detail and the privacy sentence) moved into
  tooltips.
- The per-screen copyright line was removed again at the user's request.
