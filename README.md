# Boomkin Buff Watcher

A small, focused HUD for Balance Druids. Tracks Astral Power, your current
Eclipse window, whether Mark of the Wild is up, and (once configured) any
reactive procs you want a heads-up on.

Built for Balance Druids specifically. The Astral Power/Eclipse HUD only
appears in Balance spec, and by default only while in combat (toggleable —
see Settings below). The Mark of the Wild reminder is separate: it works
for any Druid spec (Mark of the Wild isn't Balance-specific), and is
always visible regardless of combat state, since it's meant to be checked
before a pull, not during one.

---

## Features

- **Astral Power bar** — live current/max display
- **Warning glow** — the bar fills in gold as you approach capping Astral
  Power, so you know to spend it. This never inspects the actual power value
  directly; it works by handing the same number to a second bar whose range
  only covers the top 10%, so the widget's own rendering does the work
- **Eclipse window** — shows "Solar", "Lunar", or "Celestial" with a live
  countdown and a radial cooldown-swipe timer whenever one is active.
  Detected from your own casts (Wrath, Starfire, Celestial Alignment,
  Incarnation: Chosen of Elune) rather than read off the buff itself
- **Mark of the Wild reminder** — a small, independently draggable icon
  that appears only when the buff is missing. Works for any Druid spec and
  isn't tied to combat state
- **Proc row** — a configurable row of icons below the Astral Power bar
  that lights up only while a watched buff is active. Ships empty by
  default
- **Draggable** — click and drag the main frame or the Mark of the Wild
  icon to move them independently; positions are saved between sessions

## Installation

1. Extract this folder into `World of Warcraft/_retail_/Interface/AddOns/`
2. The folder must be named `BoomkinBuffWatcher`
3. Log in on a Balance Druid — the frame appears automatically

## Settings

Open with `/bbw config`, or via Options > AddOns > Boomkin Buff Watcher.

- **Hide outside of combat** — on by default. Turn this off if you want
  the Astral Power/Eclipse HUD visible all the time, e.g. to reposition it
  without needing to be mid-fight (useful if you're playing with a
  controller and can't easily reposition things during combat).

## Slash Commands

| Command | Description |
|---|---|
| `/bbw reset` | Resets both frames' positions to default |
| `/bbw config` | Opens the settings panel |

## Notes on API restrictions

A few design choices here exist specifically to work within current aura
and combat-data restrictions rather than around them:

- Astral Power's raw value can't be compared or used in arithmetic directly,
  so the warning glow is done via a second StatusBar with a narrow value
  range instead of a Lua-side threshold check
- Eclipse state isn't read from the buff itself — it's inferred from the
  cast that triggers it, with a local countdown
- Buff checks (Mark of the Wild, the proc row) are wrapped defensively:
  a failed check is treated as "can't tell right now," never as "missing,"
  since most aura data is unreliable while in combat

## Release process

- `## Version` in the TOC is `@project-version@` — never edit it by hand.
  BigWigsMods/packager substitutes the real version from the git tag at
  release time
- To ship a release: commit to main, draft a new GitHub Release, create a
  version tag, publish — the Actions workflow in
  `.github/workflows/release.yml` handles packaging and uploads
  automatically
- Distribution: CurseForge, WoWInterface, Wago, WowUp, GitHub Releases

## Support

If you'd like to support development, check the NerdyBertie Ko-fi page.

## License

MIT. See `LICENSE`. Author: NerdyBertie.
