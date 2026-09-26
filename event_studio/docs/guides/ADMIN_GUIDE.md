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
- **Event Builder:** basics, players, teams, timing, gameplay, mode options (generated from the selected mode) and rewards per placement.
- **Arenas:** edit or create locations. Stand where you want a point and press **Add point at my position**. ⌖ sets a waypoint to an existing point.
- **Scheduler:** turn schedules on or off, create weekly/daily/monthly/one-off/interval schedules, toggle the Event Director.
- **Live Events:** full control of each instance. The actions marked in red ask for confirmation.
  - Start (needs the minimum player count) / Force start (ignores it)
  - Pause / Resume (the timer freezes, players freeze)
  - Force finish (goes straight to results and rewards) / Cancel (no rewards) / Restart (same players, fresh instance)
  - Per player: Teleport to spawn, Reset (respawn plus vehicle and loadout), +10 points, Remove, Disqualify
  - Add player, Announce to the instance, Announce to everyone (optionally in chat too)
  - Spectate (enters the instance invisibly)
- **Tournaments:** create one (event definition, format, best-of, seeding, registration time), let players sign up in `/events → Tournaments`, then *Begin*. Matches start on their own, and players who don't show up forfeit.
- **Leaderboard:** season points per category.
- **Logs:** audit, security and lifecycle entries.
- **Appearance:** choose the design from the gallery, the player window layout (compact, docked or full, and whether players can keep moving with the docked panel), the HUD side, every color, the title, logo and background artwork, and each category's icon and color. Changes preview on your screen immediately; **Save** applies them for every player right away, **Discard** throws them away, **Reset to config** returns to `config/ui.lua`.
- **Settings:** version, framework, storage and your permissions.

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

- Walk each arena once and fix its points before running it publicly.
- For races, keep the start/finish checkpoint as the **last** point in the list.
- Keep `visibility = 'hidden'` for tournament match definitions.
- Point the Discord `security` webhook at a staff-only channel.
