# Boomkin Buff Watcher

A small, focused HUD for Balance Druids. Tracks Astral Power, your current
Eclipse window, whether Mark of the Wild is up, and (once configured) any
reactive procs you want a heads-up on.

Built for Balance Druids specifically — the frame only appears while
you're both in Balance spec and in combat.

---

## Features

- **Astral Power bar** — live current/max display
- **Warning glow** — the bar fills in gold as you approach capping Astral
  Power, so you know to spend it. This never inspects the actual power value
  directly; it works by handing the same number to a second bar whose range
  only covers the top 10%, so the widget's own rendering does the work
- **Eclipse window** — shows "Solar", "Lunar", or "Celestial" with a live
  countdown whenever one is active. Detected from your own casts (Wrath,
  Starfire, Celestial Alignment, Incarnation: Chosen of Elune) rather than
  read off the buff itself
- **Mark of the Wild reminder** — a small icon appears in the corner only
  when the buff is missing
- **Proc row** — a configurable row of icons below the Astral Power bar
  that lights up only while a watched buff is active. Ships empty by
  default
- **Draggable** — click and drag anywhere on the frame to move it; position
  is saved between sessions

## Installation

1. Extract this folder into `World of Warcraft/_retail_/Interface/AddOns/`
2. The folder must be named `BoomkinBuffWatcher`
3. Log in on a Balance Druid — the frame appears automatically

## Slash Commands

| Command | Description |
|---|---|
| `/bbw reset` | Resets the frame's position to default |

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
