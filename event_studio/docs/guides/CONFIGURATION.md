# Configuration

All settings live in `config/`. Files marked **shared** are also sent to players, so never put secrets in them.

| File | Scope | What it controls |
|---|---|---|
| `general.lua` | shared | locale, engine tick, bucket range, default definition values, exit behaviour, join cooldown, anti-cheat tolerances |
| `commands.lua` | shared | staff command names (set one to `false` to disable it) and the default player keys (F7 events window, U scoreboard, F9 race reset; Admin Center → Appearance → Player controls overrides them) |
| `ui.lua` | shared | design (theme), player window layout, colors, branding, artwork, HUD position, scoreboard, category icons/colors |
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

Everything below can also be changed **live in game** from the Admin Center → **Appearance** (role with `ui.edit`, admin by default). What staff save there overrides `config/ui.lua` for every player; **Reset to config** goes back to the file.

```lua
Config.UI.theme = 'krovix-gilded'      -- see the list below
Config.UI.browserLayout = 'compact'    -- player window (F7): 'compact' | 'docked' | 'full'
Config.UI.browserKeepMoving = false    -- docked only: players can keep driving/walking while it is open
Config.UI.brand = { title = 'My City Events', subtitle = 'Weekly competitions', logo = 'auto' }  -- 'auto' | false | 'img/logo.png' | https://…
Config.UI.colors = { accent = '#00c2ff' }   -- accent, accent2, background, panel, text, good, warn, bad (nil = design default)
Config.UI.artwork = 'auto'             -- panel background artwork: 'auto' | false | 'img/art/my.svg' | https://…
```

| Design (`theme`) | Look |
|---|---|
| `krovix-gilded` (default) | navy glass, gold hairlines, metallic gold titles |
| `krovix-sapphire` | deep blue, teal highlights, gold rings, app-icon badges |
| `krovix-obsidian` | near-black, cut corners, gold used sparingly |
| `krovix-emerald` | deep green glass with gold |
| `krovix-crimson` | dark red and amber, cut corners |
| `krovix-arctic` | light frosted glass, navy text, gold accent |
| `classic` | the original violet look |
| `light` | plain light theme |

When you change one color, the lighter and darker shades that go with it (button gradient, borders, soft backgrounds) are worked out for you.

**Your own design:** copy `web/themes/krovix-gilded.css` to `web/themes/mytheme.css`, change the values, then add it to `Config.UI.extraThemes` (`{ id = 'mytheme', name = 'My Theme', file = 'mytheme', shape = 'round', title = 'plain', logo = false, art = false, preview = { '#000000', '#111111', '#ff0000', '#ffffff' } }`). It then shows up in the Appearance gallery. `web/themes/base.css` lists every token with a comment. No build step is needed.

Category icons use the built-in icon names (`flag`, `car`, `crosshair`, `target`, `shield`, `compass`, `mountain`, `dice`, `trophy`, `anchor`, `bolt`, `star`, `question`, `users` and more in `web/js/icons.js`); an emoji also works. The fonts are bundled in `web/fonts/` (SIL Open Font License), so nothing is loaded from the internet.

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
