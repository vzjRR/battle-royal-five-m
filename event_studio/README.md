# EVENT STUDIO

**An event & competition platform for FiveM servers.** Create, schedule, run, watch, score and reward recurring events (races, PvP, objectives, survival, hunts, obstacle courses, social games and tournaments) from one resource.

By **Krovix Store** · Version: **0.1.0-alpha** · Frameworks: **Standalone, ESX, QBCore, Qbox**

---

## Highlights

- **One event engine, 20 modes, 48 ready-made presets.** Modes: race, deathmatch, gun game, sumo/derby, king of the hill/domination, capture the flag, zone survival, hunt/scavenger, red light green light, trivia, reaction, custom (staff-hosted), juggernaut, protect the VIP, hunters vs runners, keep moving, musical chairs, bounty/assassin hunt, package (deliver/hold), vehicle tag — plus KOTH attack-vs-defense and memory trivia styles. Between them they cover 92 of the 119 event types in the [catalog](docs/EVENT_CATALOG.md).
- **English and Arabic** out of the box, with a right-to-left NUI; add languages by copying one file.
- **Several events at once.** Each event runs in its own routing bucket, with no traffic or peds and its own vehicles.
- **The server decides everything.** Checkpoints are checked against the server's own positions and travel times. Kills come from a server-side damage log. Zones, bounds and red-light movement are computed on the server. Every payout passes through a ledger that blocks duplicates. There is a single network entry point with rate limiting, input validation and permission checks.
- **Admin Center (in game):** dashboard, event builder whose forms come from each mode's options, arena editor ("add point at my position"), scheduler with rotations, live control (start, pause, force-finish, cancel, restart, spectate, add/remove/teleport/reset/disqualify players, announce, manual score), tournaments, leaderboards, logs.
- **Player experience:** event browser, lightweight HUD, live scoreboard, countdown, results screen, spectator camera, personal bests, season leaderboards.
- **Scheduler and Director:** daily, weekly, monthly, one-off and interval schedules; weekly category rotations; an optional director that starts events on its own based on how many players are online.
- **Tournaments:** single elimination with byes, round robin / league, best of 1/3/5. Every match runs as a normal event instance.
- **Persistence is optional:** oxmysql (migrations run automatically), resource KVP (no database needed), or memory only.
- **Rewards:** cash, bank, items (ox_inventory or the framework), XP hook, console command, webhook, or custom reward types.
- **Discord webhooks, announcements** (NUI, chat, framework notify), **localization**, and an exports API.
- **8 designs, fully recolorable in game.** Krovix Gilded, Sapphire, Obsidian, Emerald, Crimson and Arctic, plus Classic and Light. Staff switch the design, the player window layout (compact, docked or full) and every color live from the Admin Center.
- **Low overhead.** Nothing runs while no event exists. The server ticks at 500 ms while events run, the scoreboard only sends changes, and timers count down on the client.

## Requirements

- FXServer with **OneSync** enabled (a recent artifact is recommended)
- Optional: `oxmysql`, `es_extended` / `qb-core` / `qbx_core`, `ox_inventory`, `chat`

## Quick start

```cfg
# server.cfg
set onesync on
ensure oxmysql        # optional
ensure es_extended    # or qb-core / qbx_core — optional
ensure event_studio

add_ace group.admin eventstudio.admin allow
```

In game:

- **Players:** press **F7** to open the events window, where they see every event and register, join, leave or spectate. Players have no typed commands. Other keys: `F9` (races, back to the last checkpoint), hold `U` (full scoreboard).
- **Staff** (host and above): `/event` opens the Admin Center. `/events`, `/eventjoin [id]`, `/eventleave`, `/eventspectate [id]` and `/eventarenafix` exist only for staff.
- If F7 (or another key) clashes with a resource on your server, change it in **Admin Center → Appearance → Player controls**. The change reaches every player at once.

## Documentation

| For | Read |
|---|---|
| Server owners | [Installation](docs/guides/INSTALLATION.md) · [Configuration](docs/guides/CONFIGURATION.md) · [Frameworks](docs/guides/FRAMEWORKS.md) · [Admin guide](docs/guides/ADMIN_GUIDE.md) · [Creating events](docs/guides/EVENT_CREATION.md) · [Troubleshooting](docs/guides/TROUBLESHOOTING.md) · [FAQ](docs/guides/FAQ.md) |
| Developers | [API](docs/API.md) · [Architecture](docs/ARCHITECTURE.md) · [Event Engine](docs/EVENT_ENGINE.md) · [Security](docs/SECURITY.md) · [Database](docs/DATABASE.md) · [Development](docs/DEVELOPMENT.md) · [Testing](docs/TESTING.md) |
| Product | [Protection & licensing](docs/PROTECTION.md) · [Master plan](docs/MASTER_PLAN.md) · [Research](docs/RESEARCH.md) · [Event catalog](docs/EVENT_CATALOG.md) · [Changelog](CHANGELOG.md) |

## License

See [LICENSE.md](LICENSE.md). The commercial license text will be finalised by the creator.
