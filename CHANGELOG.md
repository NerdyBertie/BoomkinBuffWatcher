# Changelog

## 1.0.1 (Unreleased)
- Fixed a bug where the frame could get stuck hidden if the addon loaded
  mid-combat (the combat-enter event never fires in that case). Visibility
  now also self-corrects on a one-second timer instead of relying only on
  the enter/leave-combat events
- Frame now only shows while actually in combat, in addition to the
  existing Balance-spec check

## 1.0.0
- Initial public release: Astral Power bar with a math-free "time to
  spend" glow, Eclipse window detection with a live countdown, Mark of
  the Wild reminder, and a configurable (currently empty) proc row
- See `DEVLOG.md` for the detailed build history and troubleshooting
  behind this release
