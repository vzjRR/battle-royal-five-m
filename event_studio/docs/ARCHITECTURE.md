# EVENT STUDIO — Architecture

> Author: Krovix Store · Applies to: 0.1.0-alpha and later

## 1. Guiding principles

1. **One engine, many modes.** A *mode* is a small Lua module that composes reusable *components*. An *event definition* (preset) configures a mode with options, an arena, scoring and rewards. ~120 catalog entries map to ~11 V1 modes.
2. **Server authoritative.** Clients render and send *intents*. The server decides scores, eliminations, completion, placement and rewards.
3. **Adapters at every edge.** Framework, inventory, storage, notifications, permissions, Discord: each is an adapter behind an interface. The core never names ESX/QBCore/Qbox.
4. **Event-driven, low idle cost.** Zero client loops when not in an event. One server engine tick (default 500 ms) only while instances exist.
5. **Buyer-editable surface.** Everything a buyer customises lives in `config/`, `locales/`, `web/themes/`, `integrations/custom/`. Core can be escrowed later without harming customisation.

## 2. Layered view

```
┌───────────────────────────────────────────────────────────────┐
│ NUI (web/)  Browser · HUD · Results · Admin Center · Spectator│
├───────────────────────────────────────────────────────────────┤
│ Client (client/)  RPC client · NUI bridge · client components │
│   checkpoints · zones · vehicles · loadout/death · spectator  │
├──────────────── es:rpc / es:push (single net channel) ────────┤
│ Server API (server/core/api.lua) exports for 3rd parties      │
├───────────────────────────────────────────────────────────────┤
│ Services: Scheduler · Director · Tournaments · Stats ·        │
│           Rewards(ledger) · Announce · Discord · Logs · Admin │
├───────────────────────────────────────────────────────────────┤
│ EVENT ENGINE: Manager · Instance (state machine) · Registry   │
│   Participants · Teams · Scoring · Buckets · Arenas · Defs    │
├───────────────────────────────────────────────────────────────┤
│ Server components: checkpoints · zones · combat · vehicles ·  │
│   spawns · bounds                                             │
├───────────────────────────────────────────────────────────────┤
│ Modes (modes/<id>/server.lua [+client.lua])                   │
├───────────────────────────────────────────────────────────────┤
│ Adapters: framework bridge · storage (oxmysql/kvp/none) ·     │
│   permissions (ace/framework) · notify                        │
└───────────────────────────────────────────────────────────────┘
```

## 3. Folder structure

```
event_studio/
├── fxmanifest.lua
├── README.md · LICENSE.md · CHANGELOG.md
├── docs/                      RESEARCH, MASTER_PLAN, ARCHITECTURE, EVENT_ENGINE, EVENT_CATALOG,
│                              SECURITY, DATABASE, API, DEVELOPMENT, TESTING, guides/
├── config/                    (escrow_ignore) split config files
│   ├── general.lua  commands.lua  ui.lua  scoring.lua          (shared)
│   ├── permissions.lua framework.lua database.lua rewards.lua   (server)
│   ├── notifications.lua discord.lua scheduler.lua director.lua (server)
│   ├── events/*.lua           event presets (definitions)       (server)
│   └── arenas/*.lua           arena/location definitions        (server)
├── locales/en.lua             (escrow_ignore)
├── shared/                    namespace, utils, lifecycle, schema validation, locale
├── server/
│   ├── core/                  engine + services (see §5)
│   └── components/            reusable gameplay components (server half)
├── client/
│   ├── core/                  rpc, nui bridge, state, commands
│   └── components/            client halves: checkpoints, zones, vehicles, combat, spectator
├── modes/<mode>/server.lua    mode logic ; optional client.lua for mode-specific rendering
├── integrations/
│   ├── framework/             standalone, esx, qbcore, qbox  (server + client)
│   └── custom/                buyer hooks (escrow_ignore)
├── web/                       vanilla ES-module NUI, no build step; themes/*.css
├── migrations/                ordered .sql files, applied automatically when oxmysql is used
└── tests/                     pure-Lua unit tests + FiveM mock runtime simulation tests
```

Why not `events/racing/...` per catalog entry? Because catalog entries are **presets** of modes. A buyer adds a new "Pistol Duel at Docks" by writing a 20-line preset file, not code.

## 4. Core domain model

| Concept | Where | Description |
|---|---|---|
| **Mode** | `modes/*` | Code. Rules and hooks. Declares an option schema used for validation and builder UI generation. |
| **Arena** | `config/arenas`, DB | Data. Spawns, team spawns, checkpoints, zones, objectives, vehicle spawns, spectator points, bounds. |
| **Definition** | `config/events`, DB | Data. mode + arena + options + players + timing + scoring + rewards + presentation. |
| **Schedule** | `config/scheduler`, DB | Data. Recurrence rule → definition or rotation slot. |
| **Instance** | memory | Runtime. One running occurrence of a definition, in its own routing bucket. |
| **Participant** | memory | Player inside an instance: status, team, lives, stats, score, return point. |
| **Tournament** | memory + DB | Bracket that spawns instances for each match. |

## 5. Server modules (`server/core`)

| File | Responsibility |
|---|---|
| `log.lua` | Levelled logging, debug convar, audit log sink (storage + Discord). |
| `storage.lua` | Storage adapter selection: `oxmysql` → SQL repository, `kvp` → resource KVP JSON, `none` → memory. Runs migrations. |
| `permissions.lua` | Role levels (host < moderator < manager < admin), ACE + framework group resolution, action→role map. |
| `rpc.lua` | The only networked entry point: `es:rpc`. Per-player token-bucket rate limiting, payload validation, permission gates, confirmation requirement, response routing. |
| `registry.lua` | Mode registry (`ES.RegisterMode`). |
| `arenas.lua` | Arena registry (config + storage), validation. |
| `definitions.lua` | Definition registry (config presets + builder-created), schema validation against mode options. |
| `buckets.lua` | Routing bucket pool allocation/release, lockdown + population setup. |
| `instance.lua` | The Instance class: state machine, participants, teams, timers, scoring hooks, component host, client sync. |
| `manager.lua` | Instance lifecycle orchestration, engine tick, player→instance index, disconnect/reconnect, resource stop cleanup, crash-recovery return points. |
| `scoring.lua` | Score profiles, ranking, placement assignment, season points. Pure functions. |
| `rewards.lua` | Reward resolution from definition + payout ledger + adapter dispatch. |
| `stats.lua` | Result persistence, player stats, personal bests, leaderboards. |
| `scheduler.lua` | Recurrence evaluation (pure `nextOccurrence`), rotations, instance creation at lead time. |
| `director.lua` | Optional automatic event selection by player count, category, cooldown, weights. |
| `tournament.lua` | Single elimination, round robin, best-of-N series; creates match instances. |
| `announce.lua` | Announcement adapters: nui, chat, notify, discord. |
| `discord.lua` | Queued webhook sender with rate limiting. |
| `admin.lua` | Admin RPC handlers (definitions, arenas, schedules, live control, logs). |
| `player.lua` | Player RPC handlers (browse, join, leave, spectate, actions). |
| `api.lua` | Exports for third-party resources. |
| `commands.lua` | Configurable commands + key mappings. |
| `main.lua` | Boot order, framework detection, readiness. |

## 6. Components

A component has a **server half** (state + validation, in `server/components`) and usually a **client half** (rendering + intent, in `client/components`). The server half is attached to an instance by the mode:

```lua
local cp = inst:use('checkpoints', { points = arena.checkpoints, laps = opts.laps, radius = 12 })
```

| Component | Server responsibility | Client responsibility |
|---|---|---|
| `checkpoints` | ordered/unordered progress, server-side position + timing validation, laps, positions | marker + blip of next checkpoint(s), local enter detection → intent |
| `zones` | occupancy computed from server coords each tick, capture progress, shrinking radius | sphere/cylinder markers, blips, "outside zone" warning, local damage when outside |
| `bounds` | elimination when outside arena bounds / below Z for > grace | warning overlay |
| `combat` | loadouts, weapon whitelist enforcement (`weaponDamageEvent`), friendly-fire filter, kill attribution from damage log, lives/respawn | apply loadout, death detection → hint, respawn, spawn protection, weapon snapshot/restore |
| `vehicles` | server-side spawn (`CreateVehicleServerSetter`), bucket, seat, lock-in, wreck detection, cleanup | warp-in fallback, exit prevention, ghosting |
| `spawns` | spawn point allocation (solo/team, round robin, farthest-from-enemies) | teleport + fade |

Spectating is engine-level (not a component) because it applies to every mode.

## 7. Event lifecycle

```
              ┌───────────── cancel (any state before RESULTS) ──────────────┐
              │                                                              ▼
SCHEDULED → REGISTRATION → LOBBY → COUNTDOWN → ACTIVE ⇄ PAUSED → FINISHING → RESULTS → REWARDS → ARCHIVED
                                     │  ▲                                                          ▲
                                     └──┘ (abort countdown back to LOBBY)                CANCELLED ┘
```

- `DRAFT` is a **definition** status (not runnable, hidden). Instances start at `SCHEDULED` or `REGISTRATION`.
- Allowed transitions live in `shared/lifecycle.lua` and are enforced; illegal transitions are logged and rejected.
- Entering `LOBBY`: bucket allocated, players' return points stored, players moved into bucket and to spawns, vehicles/loadouts provisioned, mode `setup`.
- `ACTIVE`: mode `start`, clock runs (pause-aware).
- `FINISHING`: grace window (e.g. racers still finishing after the winner). Mode or timer triggers.
- `RESULTS`: ranking frozen → placements + season points computed, stats persisted, results screen.
- `REWARDS`: ledger-guarded payout.
- `ARCHIVED`: players returned, entities deleted, bucket released, instance dropped from memory after summary persisted.

## 8. Networking architecture

- **One inbound net event**: `es:rpc (name, requestId, payload)`. All client→server traffic goes through `rpc.lua` which applies rate limit → schema → permission → handler. There are no other `RegisterNetEvent` handlers on the server except engine-internal lifecycle events from the Cfx runtime.
- **One outbound net event**: `es:push (topic, data)` sent only to affected players (instance members + spectators). `es:rpc:res` returns RPC results.
- **Scoreboard** pushes are throttled per instance (`Config.UI.scoreboardHz`, default 1) and only sent when the content changed (change-only; unchanged boards are never re-sent).
- **Timers** are sent as `remainingMs`; the NUI counts down locally. No per-second messages.
- **Browser** data is pulled on open.
- **Routing buckets** from a configurable pool (`Config.General.buckets = { from = 7100, to = 7299 }`), `lockdown = 'relaxed'`, population disabled. Buckets are isolation, **not** a security boundary.
- Server reads positions via `GetEntityCoords(GetPlayerPed(src))` (OneSync), so zones/bounds/red-light never need client reports.

## 9. UI architecture

- `web/index.html` + ES modules in `web/js/`: `app.js` (router + message bus), `hud.js`, `browser.js`, `results.js`, `admin/*.js`, `ui.js` (tiny DOM helpers), `i18n.js`.
- Themes are CSS custom properties in `web/themes/<name>.css`; selected by `Config.UI.theme`; branding (title, accent, logo URL) from config.
- The Builder form is **generated from the mode option schema** sent by the server, so new modes get builder support for free.
- NUI focus only when a panel is open; HUD never takes focus.

## 10. Framework adapter architecture

```
integrations/framework/
  standalone/server.lua  client.lua
  esx/server.lua         client.lua
  qbcore/server.lua      client.lua
  qbox/server.lua        client.lua
integrations/custom/     hooks.lua (server) · client_hooks.lua
```

Each server adapter implements:

```lua
Bridge = {
  name, detect() -> bool,
  getIdentifier(src), getName(src), getGroups(src) -> { [group]=true },
  addMoney(src, account, amount, reason) -> bool,
  addItem(src, item, count, metadata) -> bool,
  notify(src, message, kind),
}
```

Client adapters implement `revive(coords, heading)`, `onEnterEvent()`, `onLeaveEvent()` (e.g. suppress ambulance death screens, block inventory hotbar). Detection order: configured → `qbx_core` → `qb-core` → `es_extended` → standalone. Items prefer `ox_inventory` when started.

## 11. Security architecture

See `SECURITY.md`. Summary: single RPC gateway, per-action permissions, schema validation, rate limiting, server-side positional validation, damage-log kill attribution, weapon whitelist enforcement, payout ledger, audit logs, dangerous actions require `confirm`.

## 12. Persistence

See `DATABASE.md`. Storage is optional; three adapters (oxmysql / kvp / none). KVP gives standalone servers persistence of definitions, schedules, arenas, stats and crash-recovery return points without MySQL.

## 13. Extensibility

- **Mode packs** are drop-in folders: `modes/<id>/server.lua` (+ optional `client.lua`) are picked up by the manifest glob. Modes run inside EVENT STUDIO's Lua state so they receive the real `Instance` object (functions and metatables cannot cross the export boundary, which is why modes are not registered from other resources).
- **Data packs** (definitions, arenas) can live in any resource: `exports.event_studio:RegisterArena(arena)`, `RegisterDefinition(def)`.
- **Gameplay hooks from other resources** use instance IDs: `AddPoints`, `CompleteObjective`, `EliminatePlayer`, `FinishInstance` … (see `API.md`).
- Server events (non-networked, `AddEventHandler`) are emitted for every lifecycle transition: `event_studio:instanceState`, `event_studio:participantJoined`, `event_studio:participantLeft`, `event_studio:results`, `event_studio:rewarded`.
