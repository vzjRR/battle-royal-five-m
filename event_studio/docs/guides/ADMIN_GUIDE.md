# Admin guide

Open the Admin Center with `/event`. What you see depends on your role; the server re-checks every action regardless of what the UI shows.

| Role | Typical rights |
|---|---|
| host | open the center, create/start/pause events, add/reset players, announce, spectate |
| moderator | + force finish, cancel, restart, remove/teleport/disqualify players, manual score, view logs |
| manager | + edit definitions, arenas, schedules, director, tournaments |
| admin | + delete definitions, manual rewards |

## Sections

- **Dashboard:** live/open counts, upcoming schedule, recent events.
- **Events:** every definition. *Run now* opens registration straight away; *Edit* / *Duplicate* open the builder; toggle to enable or disable.
- **Event Builder:** basics, players, teams, timing, gameplay, mode options (generated from the selected mode) and rewards. **Route** picks the route or location the event runs on (with its check status); **Edit route** / **New route** open the route editor and come back to the builder. Rewards: any number of rewards per place (cash, bank, item, XP), as many places as you like, a participation reward and, for team modes, a reward for each member of the winning team. Built-in events can be edited too; your version is saved on top of the config.
- **Routes & arenas:** every route and location with its type (road, water, open ground, on foot, air) and check status.
  - **Check route** moves you invisibly to every point and uses the game map: road routes are snapped to drivable roads and every leg is checked for a road path; boat routes are kept on open water deep enough for boats and every leg is checked for land; on-foot points are moved to safe ground outside buildings. The report lists each point (OK, Fixed, Problem, Kept) and each leg; **Apply fixes** saves the corrections and marks the route as checked. Points marked Problem need a new position.
  - **Editor:** **Record by driving** (drive the route; a checkpoint is added every *spacing* metres and at sharp turns, G adds one now, F2 finishes), **From map waypoint** (road routes, beta: checkpoints along the GPS line to your waypoint), **Start grid behind me** (8 start places), and per point: go there, move to my position, insert my position after it, move up/down, radius, remove. **Show in world** draws the points and the route line in the game while you edit.
- **Scheduler:** turn schedules on or off, create weekly/daily/monthly/one-off/interval schedules, toggle the Event Director.
- **Active Events:** full control of each instance. The actions marked in red ask for confirmation.
  - Start (needs the minimum player count) / Force start (ignores it)
  - Pause / Resume (the timer freezes, players freeze)
  - Force finish (goes straight to results and rewards) / Cancel (no rewards) / Restart (same players, fresh instance)
  - Per player: Teleport to spawn, Reset (respawn plus vehicle and loadout), +10 points, Remove, Disqualify
  - Add player, Announce to the instance, Announce to everyone (optionally in chat too)
  - Spectate (enters the instance invisibly)
- **Tournaments:** create one (event definition, format, best-of, seeding, registration time), let players sign up in the events window (F7) → Tournaments, then *Begin*. Matches start on their own, and players who don't show up forfeit.
- **Leaderboard:** season points per category.
- **Logs:** audit, security and lifecycle entries.
- **Appearance:** choose the design from the gallery, the player window layout (compact, docked or full, and whether players can keep moving with the docked panel), the HUD side, every color, the title, logo and background artwork, and each category's icon and color. **Player controls** sets the key that opens the events window (default F7), the scoreboard key and the race reset key; pick another key when one clashes with a resource on your server. The saved keys reach every player at once. Changes preview on your screen immediately; **Save** applies them for every player right away, **Discard** throws them away, **Reset to config** returns to `config/ui.lua`.
- **Settings:** product, developer and rights.

Normal players have no typed commands: they use the events window key (F7 by default) to see events and register, join, leave or spectate. Only staff get `/event`, `/events`, `/eventjoin`, `/eventleave`, `/eventspectate` and `/eventarenafix`.

## Console commands

```
eventstudio status
eventstudio list
eventstudio defs
eventstudio create <definition> [registrationSeconds]
eventstudio start <id> [force]
eventstudio stop <id>
eventstudio cancel <id>
eventstudio director on|off
```

## Good practice

- Run **Check route** on every route before using it publicly, and record your own routes by driving them.
- For races, keep the start/finish checkpoint as the **last** point in the list.
- Keep `visibility = 'hidden'` for tournament match definitions.
- Point the Discord `security` webhook at a staff-only channel.
