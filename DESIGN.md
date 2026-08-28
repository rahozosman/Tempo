# Tempo — Design & Working Guide

> This file is the single source of truth. Read it before any work in this project.

---

## 1. Working Agreement (rules from the user)

- **Platforms:** macOS + Windows desktop only. No mobile/web focus.
- **NEVER test, NEVER run the app.** No test files, no `flutter test`, no builds, no installs, no screenshots.
- **Verification:** `flutter analyze` only.
- **Token discipline:** minimal diffs, no redoing finished work, short replies, no unrequested extras.
- **Phased build:** work is split into **6 phases**. Do **one phase per turn**, then stop.
- **After every phase:** report `CHANGED / VERIFIED / NOTES` and update `PROGRESS.md` with the stopping point.
- **Functionality comes later.** Phases 1–N are design/UI/motion only unless stated otherwise.

---

## 2. Design Direction

Design this app as a **premium macOS-quality desktop application**.
Focus ONLY on visual design, theme, UI, animations, and overall experience. Do not implement tracking functionality yet.

### 2.1 Style

- Premium, elegant, minimal, modern
- Inspired by the visual quality of macOS apps
- **Original design — do NOT copy Apple's UI**
- Spacious layouts, excellent typography
- Beautiful glassmorphism, soft translucent panels
- Large rounded corners
- Subtle borders and shadows
- Smooth depth and layering
- Clean professional icons
- **No generic Flutter/Material look**

### 2.2 Colors

Luxurious **midnight blue + electric blue + purple + violet** palette.

| Role | Direction |
|---|---|
| Background | Deep midnight |
| Surfaces | Dark navy |
| Accent | Electric blue |
| Secondary | Royal purple |
| Highlight | Soft violet |
| Text | White / light lavender |

Elegant blue → purple gradients, **used sparingly**.

### 2.3 Feeling

**Premium + Calm + Futuristic + Intelligent + macOS-like** — the quality level of a polished Mac productivity app.

### 2.4 Motion & Animation

- Smooth page transitions
- Floating / glass effects
- Sidebar selection animation
- Card entrance animations
- Animated charts
- Number counting
- Hover effects
- Soft glowing elements
- Heatmap transitions
- Micro-interactions
- Subtle background movement

Animations must be **slow, smooth, elegant, purposeful** — never flashy or childish.

---

## 3. Screens

One consistent visual system across:

1. Home Dashboard
2. Today
3. Applications
4. Week
5. Month
6. Year
7. Insights
8. Settings
9. Application Details
10. Yearly Activity Heatmap

**Year page:** a beautiful GitHub-contribution-inspired yearly activity grid, with an original blue/purple visual style.

---

## 4. Design System (must be reusable)

- Colors
- Typography
- Spacing
- Border radius
- Shadows
- Glass components
- Buttons
- Cards
- Icons
- Charts
- Animations

The whole app must feel like **one premium product**, not a collection of unrelated screens.

---

## 5. Phase Plan

To be filled in at `start`. Progress tracked in `PROGRESS.md`.

| Phase | Scope | Status |
|---|---|---|
| 1 | Foundation: architecture, tokens, themes, glass library, icons, shell, navigation, responsive rail, empty states, Appearance settings | done |
| 2 | Home dashboard + Today | not started |
| 3 | Applications + application detail | not started |
| 4 | Week + Month | not started |
| 5 | Year activity grid + year navigation | not started |
| 6 | Insights, sharing, full Settings, final polish | not started |
