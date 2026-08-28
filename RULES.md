# Tempo — Hard Rules

> Non-negotiable. Read together with `DESIGN.md`. If a rule here conflicts with anything else, this file wins.

## 1. NO TESTS. EVER.

- Do **not** write, edit, or read test files.
- Do **not** run `flutter test`, `dart test`, or any test runner.
- Do **not** build, install, launch, or screenshot the app.
- The `test/` folder is off limits.

## 2. Verification = `flutter analyze` ONLY

- The **only** allowed check is `flutter analyze`.
- Run it **once, at the very end of each phase** — never in the middle.
- Do not run it after every file. Do not run it "just to be safe".
- Target: **0 errors**. Warnings/infos get fixed only if they are mine.

## 3. Don't waste time inside a phase

- No re-reading files already read in this session.
- No re-explaining work already done.
- No extra passes: no formatting sweeps, no doc/changelog files, no refactors nobody asked for.
- No exploring code unrelated to the current phase.
- Write the code → finish the phase → analyze once → report.

## 4. Don't miss anything

- Each phase has a written scope. Deliver **every item** in that scope before stopping.
- Nothing silently dropped or downscaled. If something truly can't be done, finish everything else and say exactly what was skipped and why.
- No placeholders, no `TODO` stubs, no "will add later" unless the phase says so.
- Every screen/component listed in `DESIGN.md` must eventually exist and match the design system.

## 5. Phase discipline

- **6 phases**, one phase per turn. Stop after each.
- End-of-phase report format:
  - `CHANGED` — files touched
  - `VERIFIED` — `flutter analyze` result
  - `NOTES` — anything worth knowing
- Update `PROGRESS.md` with the exact stopping point so the next session resumes cleanly.
- Never start the next phase without the user saying so.

## 6. Output style

- Short replies. No long explanations, no code dumps in chat.
- Minimal diffs — touch only what the phase needs.

## 7. Use the best skills, and research when needed

- Apply the **highest level of craft** available: the design/animation skills, Flutter desktop best practices, real design-system thinking — not the quick generic answer.
- **When something is unknown, search first, then build.** Package APIs, desktop window behaviour, macOS/Windows specifics, shader/blur limits, chart techniques, motion curves — look it up instead of guessing.
- Prefer proven, well-maintained packages over hand-rolled code, but never add a dependency the phase doesn't need.
- Research happens **inside** the phase, before writing code — it must not become an extra stop or a separate turn.
- Guessing that leads to a broken build is worse than one search.
