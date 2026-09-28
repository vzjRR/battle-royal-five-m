# Installation

## 1. Requirements

| | |
|---|---|
| FXServer | recent artifact (7290+ recommended) |
| OneSync | **required**: `set onesync on` (or `infinity`) |
| Database | optional: `oxmysql` (otherwise KVP storage is used automatically) |
| Framework | optional: ESX Legacy, QBCore or Qbox (standalone works without one) |

## 2. Install

1. Copy the `event_studio` folder into your `resources` directory. Keep the folder name `event_studio`: exports and NUI callbacks use it.
2. Add it to `server.cfg` **after** your database and framework:

```cfg
set onesync on
ensure oxmysql
ensure qb-core            # or es_extended / qbx_core, or nothing (standalone)
ensure ox_inventory       # optional
ensure event_studio
```

3. Give your staff a role (ACE):

```cfg
add_ace group.admin eventstudio.admin allow
add_ace group.moderator eventstudio.moderator allow
# a dedicated host group
add_ace group.eventhost eventstudio.host allow
add_principal identifier.license:xxxxxxxx group.eventhost
```

ESX/QBCore groups can also grant roles; see `config/permissions.lua`.

Typed commands (`/event`, `/events`, `/eventjoin`, …) are registered only for players with a role, so normal players never get them. The console command `eventstudio` (status, selftest, perms…) always works in the server console; to use it in game as well, add `add_ace group.admin command.eventstudio allow`.

4. Start the server. The console should show:

```
[event_studio:info] Storage adapter: oxmysql
[event_studio:info] Framework adapter: qbcore (items: ox_inventory)
[event_studio:info] Event Studio 0.1.0-alpha ready — 20 modes, 48 definitions, 13 arenas (Krovix Team)
```

With oxmysql, the tables are created automatically (`migrations/001_initial.sql`). To create them by hand, set `Config.Database.runMigrations = false` and import the SQL file yourself.

## 3. First steps

1. In game, type `/event` to open the Admin Center.
2. **Routes:** the sample routes use approximate coordinates. Open **Routes & arenas**, press **Check route** on each one and **Apply fixes**; re-place any point marked Problem, or record the route again by driving it.
3. **Events:** press *Run now* on "Downtown Street Circuit". Players press **F7** to open the events window and press *Join*. In **Active Events**, press **Close registration** to bring them into the arena, then **Start** when everyone is ready (10-second countdown) (players have no typed commands; if F7 clashes with another resource, change it in **Settings → Player controls**).
4. **Scheduler:** turn the example weekly schedules on or off, or create your own.

## 4. Updating

Replace every file **except** `config/`, `locales/`, `web/themes/` and `integrations/custom/`, then read `CHANGELOG.md` for new config keys. Database migrations run automatically.
