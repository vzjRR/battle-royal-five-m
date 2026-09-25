# EVENT STUDIO — Research

> Phase 0 output. Author: vzjRR. Status: complete for V1 planning.
>
> Every finding below is tagged:
> - **[INSPIRATION]** — a mechanic or idea seen elsewhere (GTA Online, other games, other resources). Concept only; no code, UI or text is copied.
> - **[PATTERN]** — an observed industry / community practice that most successful resources follow.
> - **[TECH]** — a technical fact from official Cfx.re / framework documentation.
> - **[ORIGINAL]** — an EVENT STUDIO design decision that goes beyond what was observed.

---

## Sources

Authoritative (technical facts):

- Cfx.re — OneSync reference (routing buckets, lockdown modes, population, server setters): https://docs.fivem.net/docs/scripting-reference/onesync/
- Cfx.re — Routing Buckets: Split Game State (cookbook): https://docs.fivem.net/docs/cookbook/2020/11/27/routing-buckets-split-game-state/
- Cfx.re — Secure your events: https://docs.fivem.net/docs/developers/server-security/
- Cfx.re — Server events list (playerDropped, playerJoining, weaponDamageEvent, entityCreating, entityRemoved, onResourceStop): https://docs.fivem.net/docs/scripting-reference/events/server-events/
- Cfx.re — gameEventTriggered: https://docs.fivem.net/docs/scripting-reference/events/list/gameEventTriggered/
- Cfx.re — NUI callbacks: https://docs.fivem.net/docs/scripting-manual/nui-development/nui-callbacks/
- Cfx.re — Resource manifest: https://docs.fivem.net/docs/scripting-reference/resource-manifest/
- Cfx.re — Asset Escrow: https://docs.fivem.net/docs/server-manual/asset-escrow/
- citizenfx/fivem native declarations (SetPlayerRoutingBucket, SetEntityRoutingBucket, AddStateBagChangeHandler): https://github.com/citizenfx/fivem/tree/master/ext/native-decls
- IsPlayerAceAllowed native: https://docs.fivem.net/natives/?_0xDEDAE23D=
- txAdmin spectate implementation (reference for spectate focus handling, MIT): https://github.com/citizenfx/txAdmin/blob/master/resource/menu/client/cl_spectate.lua
- Qbox qbx_core server exports: https://docs.qbox.re/resources/qbx_core/exports/server
- QBCore player data: https://docs.qbcore.org/qbcore-documentation/qb-core/player-data
- ESX xPlayer functions: https://docs.esx-framework.org/en/esx_core/es_extended/server/xplayer
- ox_inventory server functions: https://overextended.dev/docs/ox_inventory/Functions/Server
- oxmysql (query / insert / prepare): https://overextended.dev/docs/oxmysql

Game-design inspiration (concept only):

- GTA Online Adversary Modes overview: https://www.gtabase.com/gta-online/jobs/adversary-modes/
- GTA Wiki — Sumo (Adversary Mode): https://gta.fandom.com/wiki/Sumo_(Adversary_Mode)
- GTA Wiki — Races in GTA Online: https://gta.fandom.com/wiki/Races_in_GTA_Online
- GTA Wiki — Capture / Hold / Raid: https://gta.fandom.com/wiki/Capture , https://gta.fandom.com/wiki/Hold , https://gta.fandom.com/wiki/Raid
- Rockstar Newswire — Slipstream tips: https://www.rockstargames.com/newswire/article/398a4552513k8k/Game-Tips-Slipstream
- Sportskeeda — Kill Quota explanation: https://sportskeeda.com/gta/how-play-gta-online-kill-quota-adversary-mode-3x-bonuses

Community / ecosystem (opinions, feature demand — **not** technical authority):

- Open-source race resources: ImPatxi/fivem-races, mufty/mrp_races, Dalrae1/FiveM-Race-Event (GitHub)
- Open-source deathmatch resources: MajorKorgi/SquadBattle, xVemu/deathmatch-fivem (GitHub topic "deathmatch")
- Minigame collections: Gl1tchStudios/glitch-minigames (GitHub)
- Routing bucket helpers: nnsdev/nns_routing, JaredScar/Multiverse-World-Manager (GitHub)
- Cfx forum thread — "weaponDamageEvent best methods?" (kill attribution pain points)
- Various 2025–2026 community blogs on FiveM event security (zerotrust-ac.net, fivemdocs.com, space-node.net) — used for common practice, cross-checked against Cfx docs.

---

## A. Existing FiveM event systems

**[PATTERN]** The ecosystem is fragmented into single-purpose resources:

| Type | Typical shape | Common weaknesses |
|---|---|---|
| Race scripts | Lobby + checkpoints + NUI leaderboard; often framework-locked (QBCore/Qbox) | Client decides finish time; checkpoint coordinates hard-coded; no instancing; single race at a time |
| Deathmatch / TDM scripts | Teleport to arena, give weapons, count kills | Kills counted from client events (spoofable); arena coords in code; no cleanup on disconnect |
| "Staff event" menus | Admin teleports players, gives vehicles/weapons, announces | No scoring, no lifecycle, no rewards validation — just tools |
| Racing servers | Entire gamemode dedicated to racing | Not embeddable in an RP/freeroam server |
| Battle royale gamemodes | Entire server gamemode | Same — not a resource you add to an existing server |

**Observation:** No widely used resource combines *many* event types behind one lifecycle, one scoring model, one admin UI, and one reward pipeline. That gap is EVENT STUDIO's market position. **[ORIGINAL]**

## B. Existing FiveM minigame systems

**[PATTERN]** "Minigame" resources in FiveM are overwhelmingly *single-player skill checks* (lockpick, hacking, rhythm) exposed via exports — they are UI widgets, not multiplayer competitions. They are useful as a pattern for **exports-first extensibility** (one export call returns success/failure) but not as an architecture for events.

**Takeaway [ORIGINAL]:** EVENT STUDIO's *social/fun* category (trivia, reaction, quick draw) should be implemented as **server-authoritative multiplayer rounds** where the NUI is only an input device, not a mini-game widget that decides its own outcome.

## C. GTA Online inspiration

All concept-level. **[INSPIRATION]**

- **Races**: land / bike / water / air / stunt / transform / target-assault. Options such as catch-up, slipstream, non-contact, laps, vehicle class restriction. → EVENT STUDIO race mode exposes *laps, vehicle pool, class restriction, collisions (ghosting), catch-up* as **options**, not separate scripts.
- **Sumo**: stay inside an arena while pushing others out; handbrake disabled; sudden-death shrinking dome. → A generic **arena-bounds elimination** component + optional **shrinking zone** component.
- **Kill Quota / Gun Game**: weapon progression after N kills. → **Weapon progression** component.
- **Juggernaut**: one heavily-armed target vs a team. → **Role assignment** (role-based loadouts/health) — Tier 2.
- **Hunting Pack**: runners in a vehicle that must keep speed vs hunters. → **Keep-moving** rule + roles — Tier 2.
- **Capture (Contend / GTA / Hold / Raid)**: package pickup, carry, deliver to base, steal from enemy base. → A generic **carriable objective** component (flag/package) + **base zones**.
- **Survival**: 10 escalating NPC waves. → **Wave spawner** — Tier 2 (NPC networking cost + ownership complexity).
- **Last Team Standing**: rounds, single life, team elimination. → `lives = 1` + `rounds` option on the deathmatch mode.

## D. Common event categories

**[PATTERN]** Community server event calendars observed on public server listings/forums repeatedly include: street races, car meets with competitions, TDM/gang wars, hide & seek, scavenger/treasure hunts, derby, sumo, trivia nights, KOTH. These map to nine EVENT STUDIO categories: **racing, vehicle, combat, objective, survival, hunt, obstacle, social, tournament**.

## E. Common competitive mechanics

Reusable mechanics distilled from the library (these become the **component** layer):

1. Ordered checkpoints (race, parkour, obstacle, time trial)
2. Unordered checkpoints (scavenger, checkpoint hunt)
3. Zones: capture/hold (KOTH, domination), bounds (sumo, arena), shrinking (battle zone)
4. Eliminations: death-based, bounds-based, vehicle-destroyed-based, last-place-based (elimination race)
5. Lives / respawn with spawn protection
6. Weapon loadouts and progressions
7. Vehicle provisioning (fixed model, pool, class, random) and lock-in
8. Roles (VIP, juggernaut, hunter/runner)
9. Carriable objectives (flag, package)
10. Timers (countdown, round, overtime/sudden death)
11. Rounds (best-of-N)
12. Positions / ranking (race position by checkpoint progress + distance to next)
13. Server-driven question/answer rounds (trivia, reaction)

## F. Player retention mechanics

**[PATTERN]** Seasonal leaderboards, streaks, recurring weekly slots ("Friday race night"), participation rewards, visible upcoming-event calendar, personal bests.
**[ORIGINAL]** EVENT STUDIO adds: per-category leaderboards, *personal best* per event definition, participation streak tracking (weeks in a row), and a "next up" widget in the browser.

## G. Tournament mechanics

**[PATTERN]** Single elimination and round robin dominate small communities; double elimination is valued for fairness but is complex to explain; Swiss appears in larger esports-style communities.
**Decision [ORIGINAL]:** V1 ships **single elimination** and **round robin / league points**, with **best-of-N** series. Double elimination and Swiss are architecture-ready (Tier 2). Each match is a normal event instance created by the tournament engine — no separate game code.

## H. Scoring systems

**[PATTERN]** Placement tables (e.g. 1st=100, 2nd=75 …), kill/objective points, participation points, penalties for DQ/abandon.
**[ORIGINAL]** A single declarative **score profile** per event definition:

```lua
scoring = {
  placement = { 100, 75, 50, 35, 25, 20, 15, 10 },
  participation = 10, kill = 5, assist = 2, death = 0,
  objective = 10, checkpoint = 1, lap = 5, survivalPerMinute = 2,
  streak = { every = 3, bonus = 5 }, abandonPenalty = -10,
  timeBonus = { targetSeconds = 300, perSecondUnder = 1, max = 50 },
}
```

Match score (in-event, used to rank) is kept separate from **season points** (awarded after results) so that a mode can rank by e.g. race time while still awarding placement points.

## I. Reward systems

**[PATTERN]** Cash/bank via framework, items via inventory, XP via custom systems; many scripts pay out directly from a client event ("I won, pay me") — the #1 exploit vector.
**[ORIGINAL]** Rewards are **resolved server-side from the definition**, paid only after a validated `RESULTS` state, recorded in a **payout ledger** keyed by `(instance_id, participant, reward_key)` with a uniqueness guarantee, so re-running the payout step can never double pay.

## J. Admin management requirements

Admins need: create/edit definitions without restarts, schedule, live monitor, intervene (pause, remove, DQ, teleport, spectate), announce, audit log. Dangerous actions need confirmation and permission gates. **[PATTERN]** txAdmin has set expectations for a clean web-like admin UX inside the game.

## K. Security risks

**[TECH]** From Cfx "Secure your events":
- Any `RegisterNetEvent` handler is callable by any client with arbitrary arguments.
- Use `AddEventHandler` (non-networked) for same-context events.
- Validate all values server-side; derive rewards/prices from server config.
- `GetInvokingResource()` is `nil` for network events and is **not** authentication.

Risks specific to event systems:

| Risk | Mitigation |
|---|---|
| Fake checkpoint / finish | Server checks ped coords (OneSync server-side `GetEntityCoords`) within radius + tolerance, in order, with a minimum plausible travel time |
| Fake kills | Kills derived from server-observed death + recent `weaponDamageEvent` attribution window; client death report is only a hint and is cross-checked |
| Reward spoofing | No client event can trigger a payout; ledger with unique keys |
| Admin action spoofing | Every admin RPC checks permission server-side per action |
| Join exploits | Join validated for state, capacity, cooldown, bans, already-in-another-event, bucket |
| Event flooding | Per-player token-bucket rate limiter on the RPC layer |
| Zone/objective faking | Zone occupancy computed entirely server-side from coordinates, never client-reported |
| Trivia answer sniffing | Correct answers never sent to clients before the round closes |

## L. Networking considerations

**[TECH]**
- Routing buckets require OneSync. Players/entities only see entities in the same bucket. Bucket 0 is the default world.
- `SetRoutingBucketEntityLockdownMode(bucket, 'strict'|'relaxed'|'inactive')` controls client entity creation per bucket.
- `SetRoutingBucketPopulationEnabled(bucket, false)` disables ambient peds/traffic.
- The cookbook notes some game events (explosions, projectiles) have historically been able to cross buckets — do not rely on buckets as a security boundary.
- Server-created vehicles: `CreateVehicleServerSetter` + `SetEntityRoutingBucket`; server can read entity coords/health under OneSync.
- State bags: `Player(src).state:set(k, v, true)` replicates; `GlobalState` is global. A 2025 RFC discussion reports player-bag server→client replication issues in some builds → EVENT STUDIO uses **targeted net events** for per-instance data and uses state bags only for small, non-critical flags (`es:inEvent`).
- `NetworkSetInSpectatorMode` is known to mute voice for the spectator; txAdmin's approach of moving focus and attaching a camera is more robust.

**[ORIGINAL]** Network budget rules:
1. Clients only receive state for instances they are in or spectating.
2. Live scoreboard sent as **diffs**, throttled (default 1 Hz, configurable).
3. Event browser data is pulled on open (request/response), never pushed to all players continuously.
4. Server tick for instances runs at a configurable interval (default 500 ms), not per frame.

## M. Framework compatibility

**[TECH]**
- ESX: `exports['es_extended']:getSharedObject()`, `ESX.GetPlayerFromId(src)`, `xPlayer.addAccountMoney('bank', n, reason)`, `xPlayer.addInventoryItem`.
- QBCore: `exports['qb-core']:GetCoreObject()`, `QBCore.Functions.GetPlayer(src)`, `Player.Functions.AddMoney('bank', n, reason)`, `Player.Functions.AddItem`.
- Qbox: `exports.qbx_core:GetPlayer(src)`, `exports.qbx_core:AddMoney(src, 'bank', n, reason)`; items through ox_inventory.
- ox_inventory: `exports.ox_inventory:AddItem(inv, item, count, metadata)`.
- ACE: `IsPlayerAceAllowed(src, 'object')`, configured via `add_ace` / `add_principal` in server.cfg.

**[PATTERN]** Successful commercial resources use a *bridge* folder with one file per framework and auto-detection by `GetResourceState`.

## N. Commercial product considerations

- **[TECH]** Cfx Asset Escrow encrypts Lua; `escrow_ignore` in `fxmanifest.lua` keeps config/locales/editable files readable. Requires `lua54 'yes'`. Distributed via Tebex.
- **[PATTERN]** Buyers expect: zero-edit install, clear config split, framework auto-detect, English docs, SQL auto-migration, themes, locale files, update changelog, support-friendly logs (a `debug` convar).
- **[ORIGINAL]** Design so that *everything a buyer might customise* lives in escrow-ignored paths: `config/`, `locales/`, `web/themes/`, `integrations/custom/`, event presets and arena files, and an `open/` hooks file. Core logic can later be escrowed without harming customisation.
- No build step for the NUI (plain ES modules) → buyers can theme without Node.js.

## O. Features worth implementing (V1)

Core engine + lifecycle; instancing via buckets; definitions/arenas/presets from config **and** in-game builder (DB); scheduler with rotation; director (optional); score profiles; leaderboards; payout ledger; framework bridges (standalone/ESX/QBCore/Qbox); ACE + framework-group permissions; Discord webhooks; admin center; player browser + HUD; spectator; single-elim + round-robin tournaments; locales; 9 V1 modes covering ~30 catalog entries.

## P. Features to postpone (V2+)

NPC wave survival, juggernaut/VIP roles, hunter-vs-runners, double elimination & Swiss, in-game 3D arena/prop editor with gizmos, photo challenges, transform races, powerups, phone integrations, cross-server leaderboards, web dashboard outside the game.

## Q. Features that should NOT be implemented

- Client-authoritative scoring or payouts (security).
- Bundled vehicle/weapon/map assets (licensing, size, escrow issues).
- Hard dependency on any framework, ox_lib, or target system.
- Gambling/betting on events with real currency (legal/platform-ToS risk).
- Copying any existing paid resource's UI, code or naming.
- Per-frame NUI updates or 0 ms loops outside actively rendered components.
- 119 separate scripts — replaced by modes + options + presets.
