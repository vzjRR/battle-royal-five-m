# Configuration

All settings live in `config/`. Files marked **shared** are also sent to players, so never put secrets in them.

| File | Scope | What it controls |
|---|---|---|
| `general.lua` | shared | locale, engine tick, bucket range, default definition values, exit behaviour, join cooldown, anti-cheat tolerances |
| `commands.lua` | shared | command names and default keys (set a command to `false` to disable it) |
| `ui.lua` | shared | theme, branding (title, logo, accent), HUD position, scoreboard, category icons/colors |
| `scoring.lua` | shared | season period and scoring profiles |
| `framework.lua` | shared | framework adapter, inventory, identifier strategy |
| `permissions.lua` | server | roles (host/moderator/manager/admin), ACE prefix, framework group mapping, action → role |
| `database.lua` | server | storage adapter, migrations, log retention |
| `rewards.lua` | server | reward limits, account names, XP hook |
| `notifications.lua` | server | which announcements go where (nui/chat/notify/discord) |
| `discord.lua` | server | webhooks and routing (disabled by default) |
| `scheduler.lua` | server | schedules and rotations |
| `director.lua` | server | automatic event selection |
| `trivia.lua` | server | trivia question sets |
| `arenas/*.lua` | server | arena/location definitions |
| `events/*.lua` | server | event presets (definitions) |

Definitions, arenas and schedules created in the Admin Center are stored in the database (or KVP) and override config entries with the same id. Deleting a stored override brings back the config preset.

## Branding & themes

```lua
Config.UI.brand = { title = 'My City Events', subtitle = 'Weekly competitions', logo = 'https://…/logo.png', accent = '#00c2ff' }
Config.UI.theme = 'default'   -- or 'light', or your own web/themes/<name>.css
```

A theme is just CSS variables; copy `web/themes/default.css` to start one. No build step is needed.

## Routing buckets

`Config.General.buckets = { from = 7100, to = 7299 }`. Pick a range that no other resource uses (housing, instances, character selection…). Each running event uses one bucket.

## Scoring profiles

Each event uses a profile, either by name (`scoring = 'competitive'`) or as an inline table. **Match score** decides the ranking inside an event; **season points** come from the profile and feed the leaderboards.

## Security tolerances

- `checkpointTolerance` (default 8 m) adds slack on top of the checkpoint radius to cover latency.
- `maxPlausibleSpeed` (default 140 m/s) sets the fastest believable travel between checkpoints. Raise it if you race very fast custom aircraft.
- `maxViolationsBeforeKick` (default 0 = never kick) sets how many violations inside the window lead to an automatic kick.

## Localization

Copy `locales/en.lua` to `locales/xx.lua`, change `ES.RegisterLocale('en', …)` to `'xx'`, translate it, then set `Config.General.locale = 'xx'`. Keys starting with `ui.` are the NUI strings. Missing keys fall back to English. Keep every `%s` / `%d` in the same order as the English text (the test suite checks this).

Shipped languages: English (`en`) and Arabic (`ar`). Arabic, Hebrew, Persian and Urdu (`ar`, `he`, `fa`, `ur`) switch the NUI to right-to-left automatically; any other locale can force it with `_dir = 'rtl'` at the top of its table. Mode option labels in the Admin Center builder and the texts you write in your own event definitions (names, descriptions) are not translated.
