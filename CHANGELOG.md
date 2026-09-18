# Changelog

## 1.1.0
- Added a settings panel (`/bbw config` or Options > AddOns) with a "Hide
  outside of combat" checkbox — off by default behavior preserved, but now
  toggleable for anyone who wants the frame visible all the time (e.g. to
  reposition it without needing to be in a fight)
- Mark of the Wild reminder is now its own independent, separately
  draggable frame — no longer tied to combat state, and now works for any
  Druid spec (not just Balance), since it's meant to be checked before a
  fight starts, whatever role you're playing
- Added a radial cooldown-swipe timer next to the Eclipse window text,
  matching the visual style of action bar cooldowns
- Fixed a bug where `/bbw learn` also silently reset the frame's position
  every time it was run, and `/bbw reset` did nothing
- See `DEVLOG.md` for the build history behind this release, including a
  couple of settings-API dead ends before landing on what actually works

## 1.0.1
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
