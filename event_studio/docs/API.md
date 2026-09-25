# EVENT STUDIO — Developer API

All exports are **server-side** unless marked. Resource name is assumed to be `event_studio`.

```lua
local ES = exports.event_studio
```

Return convention: functions that can fail return `ok (boolean), resultOrError`.
Error codes are strings such as `'not_found'`, `'invalid_state'`, `'full'`, `'already_joined'`, `'invalid_definition'`.

## 1. Definitions & arenas

| Export | Description |
|---|---|
| `RegisterDefinition(def)` → ok, id | Register/replace a definition at runtime (not persisted). Validated against the mode schema. |
| `SaveDefinition(def)` → ok, id | Register and persist (storage). |
| `GetDefinition(id)` → def \| nil | |
| `GetDefinitions()` → { def… } | |
| `RegisterArena(arena)` → ok, id | Register arena at runtime. |
| `GetArena(id)` → arena \| nil | |
| `GetModes()` → { {id,label,category,options}… } | Mode list with option schemas. |

## 2. Instances

| Export | Description |
|---|---|
| `CreateEvent(definitionId, opts)` → ok, instanceId | Create an instance. `opts = { startIn = seconds?, registration = seconds?, invite = {src…}?, tournament = id?, overrides = {…}? }` |
| `StartEvent(instanceId, force)` → ok | Close registration and go to LOBBY now (`force` ignores min players). |
| `StopEvent(instanceId, reason)` → ok | Force finish (results + rewards). |
| `CancelEvent(instanceId, reason)` → ok | Cancel (no rewards). |
| `PauseEvent(instanceId)` / `ResumeEvent(instanceId)` → ok | |
| `GetEventState(instanceId)` → table \| nil | `{ id, definitionId, mode, state, remainingMs, participants, teams }` |
| `GetActiveEvents()` → { state… } | |
| `GetPlayerEvent(src)` → instanceId \| nil | |

## 3. Participants

| Export | Description |
|---|---|
| `JoinPlayer(instanceId, src, force)` → ok, err | `force` bypasses capacity/visibility (admin/API use), never state rules. |
| `RemovePlayer(instanceId, src, reason)` → ok | |
| `GetParticipants(instanceId)` → { {src,name,team,status,score,placement,stats}… } | |
| `SetTeam(instanceId, src, teamIndex)` → ok | Before ACTIVE only. |

## 4. Gameplay

| Export | Description |
|---|---|
| `GivePoints(instanceId, src, amount, reason)` → ok | Adds match score (audited). |
| `CompleteObjective(instanceId, src, objectiveId, points)` → ok | Increments objectives stat + optional points. |
| `EliminatePlayer(instanceId, src, reason)` → ok | |
| `FinishPlayer(instanceId, src)` → ok | Mark as finished (race-like modes). |
| `FinishEvent(instanceId, reason)` → ok | Same as StopEvent but from gameplay code. |

## 5. Leaderboards & stats

| Export | Description |
|---|---|
| `GetLeaderboard(category?, season?, limit?)` → rows | category default `'*'`, season default current. |
| `GetPlayerStats(src or identifier, season?)` → rows | |
| `GetPersonalBests(definitionId, limit?)` → rows | |

## 6. Rewards

| Export | Description |
|---|---|
| `GiveReward(src, reward, reason)` → ok | Direct payout through the reward adapters (no ledger; for your own validated logic). |
| `RegisterRewardType(type, handler)` → ok | Custom reward type: `handler(src, reward, context) -> ok`. Must be called from a server script **inside event_studio** (`integrations/custom/hooks.lua`) or via this export (function crosses as funcref). |

## 7. Tournaments

| Export | Description |
|---|---|
| `CreateTournament(cfg)` → ok, id | `{ name, definitionId, format='single_elimination'|'round_robin', bestOf=1|3|5, seeding='registration'|'random', entrants? }` |
| `GetTournament(id)` → table | |

## 8. Server events (non-networked; listen with `AddEventHandler`)

| Event | Args |
|---|---|
| `event_studio:instanceState` | `instanceId, newState, oldState, summary` |
| `event_studio:participantJoined` | `instanceId, src` |
| `event_studio:participantLeft` | `instanceId, src, reason` |
| `event_studio:eliminated` | `instanceId, src, reason, killerSrc?` |
| `event_studio:results` | `instanceId, results` (ordered rows) |
| `event_studio:rewarded` | `instanceId, src, reward` |

These are emitted with `TriggerEvent` (local only); clients cannot trigger them on the server.

## 9. Client exports

| Export | Description |
|---|---|
| `IsInEvent()` → bool | Local player is a participant or spectator. |
| `GetCurrentEvent()` → `{ id, mode, state, role }` \| nil | |
| `OpenBrowser()` | Open the event browser NUI. |

Also the local player state bag `es:inEvent` (instance id or false) is set by the server for other resources (e.g. to disable a phone or job actions while in an event).

## 10. Adding a mode (in-resource)

See `EVENT_ENGINE.md §2` and `docs/guides/EVENT_CREATION.md`.

## 11. Example

```lua
-- Start a street race in 60 seconds from another resource
local ok, id = exports.event_studio:CreateEvent('street_circuit', { registration = 60 })

AddEventHandler('event_studio:results', function(instanceId, results)
  if instanceId ~= id then return end
  print(('Winner: %s'):format(results[1] and results[1].name or 'none'))
end)
```
