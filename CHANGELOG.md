# Changelog

## Unreleased
- Switched the TOC `Version` field to `@project-version@`, substituted
  automatically by the packager from the git tag — no more manual version
  bumps
- The in-game "loaded" message now reads the version from the addon's own
  metadata instead of a hardcoded string
- Added `.pkgmeta` and the GitHub Actions release workflow
  (`.github/workflows/release.yml`) for automated packaging and upload to
  CurseForge, WoWInterface, and Wago on tag push
- Added `LICENSE` (MIT)

## 1.8.0
- Added the proc row: a configurable set of icons that appear only while a
  watched buff is active
- Added `/bbw learn` to print real buff names/spell IDs for populating the
  proc row from your own character

## 1.7.0
- Added the Mark of the Wild reminder icon, shown only when the buff is
  missing. Checks defensively via `pcall` so a failed read never shows a
  false "missing" state
- Added Mark of the Wild status to `/bbw debug`

## 1.6.0
- Reworked the Astral Power warning glow to avoid all arithmetic/comparison
  on the power value: a second StatusBar with a range of 90–max now does the
  threshold check natively via its own fill rendering

## 1.5.0
- Removed the original comparison-based warning glow after confirming (via
  three separate failed approaches) that Astral Power's value can't be
  compared or measured indirectly under current API restrictions

## 1.4.0 – 1.3.0
- Attempted fixes for the warning glow (curve-based percent lookup, then
  rendered fill-width measurement) — both still hit secret-value
  restrictions; kept for history, superseded by 1.6.0

## 1.2.0
- Split the frame into two rows (Eclipse label on top, Astral Power bar on
  bottom) to stop the two text strings overlapping
- Added the initial (later reworked) Astral Power warning glow

## 1.1.0
- Fixed the Eclipse window never triggering: the event args for
  `UNIT_SPELLCAST_SUCCEEDED` were being destructured incorrectly

## 1.0.0
- Initial release: Astral Power bar, event-driven Eclipse window detection,
  Balance-spec-only visibility, draggable frame with saved position
