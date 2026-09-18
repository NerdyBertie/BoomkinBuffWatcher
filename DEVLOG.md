# Development Log

## 1.1.0 build notes
- The "Hide outside of combat" setting went through three implementations
  before landing on one that actually worked:
  1. `Settings.RegisterAddOnSetting` + `Settings.CreateCheckbox` (the
     newer "auto-binding" Settings API) — the checkbox rendered fine, but
     the underlying value never reliably reflected in-game
  2. Reading through `hideSetting:GetValue()` instead of the raw saved
     table directly — still didn't work
  3. A plain manual `CheckButton` with a direct read/write to
     `BoomkinBuffWatcherDB` on click, matching the exact pattern already
     proven working in ItemWatch's own published options panel — this
     one worked immediately
- Also found and fixed a real bug during this troubleshooting: settings
  fields added after the first release stayed permanently `nil` for
  existing users, since `BoomkinBuffWatcherDB = BoomkinBuffWatcherDB or
  {defaults}` only applies when the whole saved table doesn't exist yet —
  it doesn't backfill individual missing keys into an already-existing
  table from an earlier version

This is the blow-by-blow build history from before the first public release
— every local test iteration, bug, and dead end. Kept for reference, not
meant for the public-facing CHANGELOG.

## Local dev iterations (pre-1.0.0 release)
- **1.0.0** — Initial build: Astral Power bar, event-driven Eclipse window
  detection, Balance-spec-only visibility, draggable frame with saved
  position
- **1.1.0** — Fixed the Eclipse window never triggering: the event args for
  `UNIT_SPELLCAST_SUCCEEDED` were being destructured incorrectly
- **1.2.0** — Split the frame into two rows (Eclipse label on top, Astral
  Power bar on bottom) to stop the two text strings overlapping. Added the
  initial (later reworked) Astral Power warning glow
- **1.3.0 – 1.4.0** — Attempted fixes for the warning glow (curve-based
  percent lookup, then rendered fill-width measurement) — both still hit
  secret-value restrictions; superseded by 1.6.0
- **1.5.0** — Removed the comparison-based warning glow after confirming
  (via three separate failed approaches) that Astral Power's value can't
  be compared or measured indirectly under current API restrictions
- **1.6.0** — Reworked the warning glow to avoid all arithmetic/comparison
  on the power value: a second StatusBar with a range of 90–max does the
  threshold check natively via its own fill rendering
- **1.7.0** — Added the Mark of the Wild reminder icon, shown only when
  the buff is missing, checked defensively via `pcall`
- **1.8.0** — Added the proc row and `/bbw learn` for populating it with
  real spell IDs

## Packaging setup (also folded into the real v1.0.0 release)
- Switched the TOC `Version` field to `@project-version@`, substituted by
  the packager from the git tag
- In-game "loaded" message reads the version from addon metadata instead
  of a hardcoded string
- Added `.pkgmeta` and the GitHub Actions release workflow
- Added `LICENSE` (MIT)
