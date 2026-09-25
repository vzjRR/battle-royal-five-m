# EVENT STUDIO — Security

**Threat model:** any connected client may run an executor, trigger any net event with any arguments, spoof timing, teleport, spawn entities, and read anything sent to it. The server is the only trusted party. Routing buckets are isolation, not a security boundary.

## 1. Single RPC gateway

- The server registers exactly one client-facing net event: `es:rpc`.
- Every RPC is declared with `RPC.register(name, spec, handler)`:

```lua
RPC.register('admin:instance:stop', {
  perm = 'instance.stop',       -- permission action (server-side check)
  confirm = true,               -- payload.confirm must be true (dangerous)
  rate = { burst = 5, per = 10 },
  schema = { id = 'integer' },  -- type/range validation, unknown keys dropped
}, function(src, data) ... end)
```

- Order: player exists → rate limit → schema → permission → confirmation → handler (in `pcall`). Failures are logged; repeated violations raise a `security` log + optional Discord alert, and can auto-kick (`Config.General.security.kickOnViolations`, default off).
- Unknown RPC names are violations.

## 2. What the client may send (intents only)

| Intent | Server validation |
|---|---|
| `event:join` | instance state = REGISTRATION, capacity, visibility, not in another instance, not banned (hook), cooldown, player not dead, bridge `canJoin` hook |
| `event:leave` | membership |
| `event:spectate` | spectators allowed, not a participant, instance live |
| `action` `checkpoint {index}` | participant active, index == expected (ordered) or unvisited (unordered), server-side ped coords within `radius + tolerance` (default +8 m), time since previous checkpoint ≥ plausible minimum (`distance / maxSpeed`), not paused |
| `action` `died {killer}` | victim ped health ≤ 100 (dead) on the server, re-checked once after 750 ms for sync lag; killer only accepted if present in the victim's recent damage log (10 s) — otherwise last damager or none |
| `action` `answer {choice}` | round open, first answer only, choice in range; correct answer never sent before round closes |
| `action` `react` | round state; early press = penalty; response time measured on the server |
| `action` `pickup` / `capture` | never trusted — objectives are computed from server coords each tick |

## 3. Never trusted from the client

Score, kills, placement, completion, rewards, money, objective state, event state, permissions, team, vehicle model, weapon list, spawn point, timestamps.

## 4. Combat protections

- `weaponDamageEvent` (server): cancel if attacker and victim are not in the same instance; cancel if friendly fire disabled and same team; cancel + flag if weapon not in the instance whitelist; cancel damage from/to spectators.
- Kill attribution via server-side damage log from `weaponDamageEvent` (attacker = event source).
- Duplicate death hints within 2 s are ignored; a death is only processed once per life.

## 5. Rewards

- No RPC can trigger a payout. Payout runs only inside the engine's `REWARDS` transition.
- Reward amounts come from the server-side definition, clamped by `Config.Rewards.limits` (max cash per reward, max items).
- **Ledger:** key = `instanceId:identifier:rewardKey`. The storage adapter claims the key atomically (SQL `INSERT IGNORE` affected rows; KVP existence check under a lock in a single Lua thread). A claimed key is never paid twice, even if the step re-runs after a crash.
- Every payout is audit-logged.

## 6. Permissions

- Role levels: `host (10) < moderator (20) < manager (30) < admin (40)`. Each RPC action maps to a minimum role in `config/permissions.lua`.
- Resolution sources: ACE (`IsPlayerAceAllowed(src, 'eventstudio.<role>')`) and/or framework groups mapped in config. Evaluated server-side on every call; cached for 30 s, cache cleared on drop.
- Console (`src == 0`) is admin for commands.

## 7. Data exposure

- Discord webhook URLs, database settings and reward hooks are in **server-only** config files (never in `shared_scripts`).
- Arena/definition data is only sent to admins (builder) or to participants for the parts they need (e.g. the current checkpoint list, never trivia answers, never hidden-object locations until discovered when `hidden = true`).
- Player identifiers are never sent to other players' NUIs; only display names.

## 8. Entity safety

- Instance buckets use lockdown `relaxed` by default (clients cannot create script entities); configurable to `strict`.
- Vehicles are server-created and deleted on cleanup; players cannot request arbitrary models.

## 9. Logging

- Security violations: `security` level, include src, identifier, RPC, reason. Throttled.
- Admin actions: `audit` level with actor and target.

## 10. Checklist for contributors

- [ ] No new `RegisterNetEvent` on the server — add an RPC.
- [ ] Every RPC has `perm` (or explicit `public = true`), `schema`, `rate`.
- [ ] Dangerous admin RPCs have `confirm = true`.
- [ ] Never use client-provided numbers for score/rewards.
- [ ] Positional claims verified with server coords.
- [ ] Nothing secret in shared config.
