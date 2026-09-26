# EVENT STUDIO — Event Engine

The engine is the product. Modes are small because the engine does the heavy lifting.

## 1. Objects

```
Instance
 ├── id, definition (frozen copy), mode, arena
 ├── state, stateSince, clock (pause-aware)
 ├── bucket
 ├── participants  [src] → Participant
 ├── byIdentifier  [identifier] → Participant   (reconnect lookup)
 ├── teams         [index] → { index, name, color, score, members }
 ├── spectators    [src] → true
 ├── components    [name] → component state
 ├── data          mode-private state
 ├── ranking       frozen at RESULTS
 └── entities      server-created entities to clean up
```

```
Participant
 ├── src, identifier, name
 ├── status   registered | active | eliminated | finished | disconnected | left | disqualified
 ├── team, role
 ├── score (match score), points (season points, computed at RESULTS)
 ├── stats { kills, deaths, assists, objectives, checkpoints, laps, streak, bestStreak }
 ├── lives, finishMs, placement, eliminatedAt
 └── returnPoint { coords, heading, bucket }
```

## 2. Mode contract

```lua
ES.RegisterMode('race', {
  label = 'Race', category = 'racing',
  teams = 'none' | 'optional' | 'required',
  minPlayers = 1,                 -- absolute floor for this mode
  arena = { requires = { 'checkpoints' } },   -- arena validation
  options = {                     -- schema: validation + builder UI
    laps = { type = 'number', default = 1, min = 1, max = 50, label = 'Laps' },
    vehicle = { type = 'vehicle', default = { model = 'sultan' } },
  },
  rankBy = 'score' | 'finish' | 'custom',   -- default ranking strategy
  -- hooks (all optional)
  setup    = function(inst) end,           -- entering LOBBY, players placed
  start    = function(inst) end,           -- entering ACTIVE
  tick     = function(inst, dt) end,       -- engine tick while ACTIVE
  onAction = function(inst, p, action, data) end,  -- validated player intent
  onDeath  = function(inst, victim, killer, weapon) end,
  onRespawn= function(inst, p) end,
  onLeave  = function(inst, p, reason) end,
  onTimeUp = function(inst) end,           -- default: inst:finish('time')
  rank     = function(inst) return orderedEntries end, -- when rankBy='custom'
  hud      = function(inst, p) return { ... } end,     -- extra HUD fields
  cleanup  = function(inst) end,
})
```

### Optional mode flags

| Flag | Effect |
|---|---|
| `graceOnFinish` | `inst:finish()` enters FINISHING (grace window) instead of RESULTS |
| `lastStanding` / `lastTeamStanding` | finish automatically when one player / team remains |
| `endWhenOneTeamLeft = false` | keep running when only one team has members |
| `allowRejoin = false` | no reconnect grace for this mode |
| `personalBests` | store best finish times per definition |
| `objectiveKey` / `rulesKey` | locale keys shown in HUD / browser |
| `validate(def)` | extra definition validation (return false, err) |
| `viability(inst)` | override automatic finishing (return true = keep, false = finish, nil = default) |
| `onLateJoin`, `onRejoin`, `onResume`, `rowExtra(inst, p)` | extra hooks |

## 3. Instance API used by modes

| Method | Purpose |
|---|---|
| `inst:use(name, cfg)` | attach a component |
| `inst:component(name)` | get attached component |
| `inst:activeParticipants()` | list of `active` participants |
| `inst:addScore(p, amount, reason)` | match score (+team score) |
| `inst:addStat(p, key, n)` | stats counters |
| `inst:addTeamScore(team, amount)` | team score only |
| `inst:eliminate(p, reason)` | mark eliminated, spectate-on-elim if enabled |
| `inst:markFinished(p)` | set finish time (race-like) |
| `inst:finish(reason)` | go to FINISHING (grace) → RESULTS |
| `inst:finishNow(reason)` | skip grace |
| `inst:push(p, topic, data)` / `inst:broadcast(topic, data)` | client sync |
| `inst:announce(key, args)` | localized announcement to instance |
| `inst:elapsedMs()` / `inst:remainingMs()` | pause-aware clock |
| `inst:teleport(p, spawn)` / `inst:respawn(p)` | via spawns component |
| `inst:dirty()` | mark scoreboard dirty (throttled push) |

## 4. Ranking and results

1. Mode ranking (`finish` → finished by time then progress; `score` → match score desc; `custom` → mode `rank`).
2. Status ordering: finished/active > eliminated (later elimination ranks higher) > left/disconnected > disqualified (unranked).
3. Ties share placement (`1,1,3`) when compare values are equal.
4. `scoring.lua` converts placements + stats into **season points** from the definition's score profile.
5. Team modes rank teams; members inherit the team placement; individual stats still count.

## 5. Tick

`manager.lua` runs one loop (`Config.General.tickMs`, default 500 ms) *only while at least one instance exists*. Each tick, for each instance: state timers, mode `tick`, component ticks (zones, bounds, vehicles), throttled scoreboard push. Idle cost with no instances: zero.

## 6. Timers by state

| State | Duration source | On expiry |
|---|---|---|
| SCHEDULED | `startAt - registration` | → REGISTRATION |
| REGISTRATION | `timing.registration` | ≥ min players → LOBBY, else extend once (`timing.extendOnce`) or CANCELLED |
| LOBBY | `timing.lobby` | → COUNTDOWN |
| COUNTDOWN | `timing.countdown` | → ACTIVE |
| ACTIVE | `timing.duration` (0 = unlimited) | mode `onTimeUp` (default finish) |
| FINISHING | `timing.grace` | → RESULTS |
| RESULTS | `timing.results` | → REWARDS |
| REWARDS | immediate | → ARCHIVED |

## 7. Viability

After any leave/elimination the engine calls `inst:checkViability()`:
- 0 active participants → finish (or cancel if nobody ever became active).
- Solo last-standing modes: 1 active → finish.
- Team modes: ≤ 1 team with active members → finish.
- Modes can override via `viability = function(inst) return true|false end`.

## 8. Disconnect / reconnect

- `playerDropped` → participant `disconnected`, `disconnectedAt` set, mode `onLeave(…,'disconnect')`.
- If `definition.players.reconnectGrace > 0` and the mode allows (`allowRejoin`), a player with the same identifier who reconnects before grace expiry is restored (new `src`), moved back into the bucket and respawned.
- Grace expiry → `left`, viability check.
- Return points are persisted (KVP) so a server crash still returns players to where they were on next join.

## 9. Adding a mode — checklist

1. `modes/<id>/server.lua` with `ES.RegisterMode`, added to `server_scripts` in `fxmanifest.lua` (and `modes/<id>/client.lua` to `client_scripts` if there is one).
2. Reuse components; write client code only for new rendering needs (`modes/<id>/client.lua`).
3. Add locale keys to `locales/en.lua`.
4. Add at least one preset in `config/events/`.
5. Add a simulation test in `tests/`.
