# EVENT STUDIO — Testing

## 1. Automated tests (no game needed)

```
cd event_studio
lua5.4 tests/run.lua            # everything
lua5.4 tests/run.lua sim_race   # one file
ES_LOGS=1 lua5.4 tests/run.lua  # print the last server logs for failing tests
ES_VERBOSE=1 lua5.4 tests/run.lua
```

`tests/lib/fivem.lua` is a **FiveM server mock runtime**: natives (players, peds, vehicles, buckets, KVP, state bags, ACE), events (`RegisterNetEvent`, `TriggerClientEvent`, `CancelEvent`), coroutine threads with a **virtual clock** (`Wait`, `SetTimeout`, `Citizen.Await`), and a loader that runs the **real server scripts listed in `fxmanifest.lua`**. Fake clients call RPCs exactly as the NUI does and react to `teleport`/`respawn`/`left` pushes, so server-side coordinates follow them.

| File | Covers |
|---|---|
| `test_boot.lua` | boot, all modes, all presets/arenas validate, schedules, exports |
| `test_units.lua` | lifecycle, schema, ranking/ties, season points, team ranking, scheduler recurrences (daily/weekly/monthly/once/interval/UTC offset), tournament brackets/byes/series/round robin, rate limiter |
| `test_sim_race.lua` | full race at **1, 2, 4, 8, 16, 32, 64 players** (buckets, vehicles, results, rewards, cleanup, return positions), checkpoint validation (order/distance/speed), elimination race, leaving mid-race |
| `test_sim_combat.lua` | kill counting, spoofed killer hints, fake death hints, damage filter (whitelist, cross-instance, outsiders, friendly fire), LMS, TDM, disconnect + reconnect within grace, grace expiry, crash-recovery return point |
| `test_sim_modes.lua` | sumo, derby, KOTH, domination, CTF, zone survival, hidden hunt (no coordinate leak), red light, trivia (answers hidden), reaction, gun game, duel rounds, staff manual scoring |
| `test_sim_v2.lua` | juggernaut (role health, role passing, time scoring), Protect the VIP (extraction, VIP kill, timeout, rounds), hunters vs runners (head start, infection, survivor bonus), keep moving (speed check, grace), musical chairs (N-1 chairs, closest to the center keeps the chair) |
| `test_sim_v2b.lua` | bounty (leader marked, growth, claim), assassin (private ring, wrong-kill penalty, inheritance, leaver skip), package deliver/hold (pickup, delivery, drop on death, reset), vehicle tag (server proximity, no tag-back window), KOTH attack (sequential zones, early captures reset, defenders win on time), memory trivia (memorize phase, hidden correct ordering) |
| `test_fuzz.lua` | every RPC × 60 hostile payloads as a player (no errors, no privilege leak) and × 40 as an admin; 300 random actions in each of 24 mode presets (no errors, no fake kills or finishes). `ES_SEED=n` changes the seed |
| `test_sim_platform.lua` | RPC fuzzing, rate limiting, permissions & roles, confirmation, builder validation & persistence, join rules, payout ledger idempotency, parallel isolated instances, pause clock, resource stop cleanup, scheduler auto-creation, director, tournament end-to-end, browser visibility |

Offline tick benchmark (not a test): `lua5.4 tests/bench.lua`.

CI: `.github/workflows/test.yml` runs the syntax check, all tests and the release guard on every push.

Syntax check of every Lua file (client included):

```
find . -name '*.lua' -print0 | xargs -0 -n1 luac5.4 -p
```

NUI preview without a server: serve the resource folder (`python3 -m http.server`) and open `web/index.html#browser` (also `#admin`, `#live`, `#builder`, `#tournaments`, `#hud`, `#results`, `#trivia`, `#tdm`). `web/js/dev.js` supplies sample data and is only loaded outside FiveM.

## 2. In-game test plan (manual)

Run before each release on a test server with 2+ clients.

| # | Scenario | Expected |
|---|---|---|
| 1 | Start resource standalone / ESX / QBCore / Qbox | ready log, correct adapter |
| 2 | `/events` → join open race | registered, card shows ✓ |
| 3 | Registration ends | teleported into vehicle at grid, frozen, countdown, GO |
| 4 | Drive checkpoints | markers, blips/route, lap toasts, HUD position |
| 5 | Stuck → F9 | back at last checkpoint in a new vehicle |
| 6 | Finish | results screen, reward toast, returned to the original position and bucket 0 |
| 7 | TDM 2v2 | team spawns, friendly fire blocked, kills counted, respawn with protection |
| 8 | Die in LMS | auto-spectate, ←/→ switch targets, Backspace leaves |
| 9 | Quit mid-event and rejoin within 60 s | back in the event |
| 10 | Crash (kill the game) during an event, rejoin after it ends | teleported back to the pre-event position |
| 11 | `restart event_studio` mid-event | players unfrozen, weapons restored, bucket 0, vehicles gone |
| 12 | Admin: pause/resume, force finish, cancel, restart, teleport, reset, DQ, announce, spectate | each works, confirmations shown, audit logs written |
| 13 | Non-staff tries `/event` | "No permission", security log |
| 14 | Sumo / derby / KOTH / CTF / zone / hunt / red light / trivia / reaction | per catalog |
| 15 | 3 events at once | isolated players, no cross damage |
| 16 | Tournament with 4 players | bracket progresses on its own, winner announced |
| 17 | ox_inventory server | weapon wheel usable in the event, inventory restored afterwards |
| 18 | ambulance resource | no stuck death screen after respawn/exit |

## 3. Performance profiling (resmon)

Record `resmon` for event_studio at: idle; open registration; lobby (16 players); active race (16); active TDM (32); 3 simultaneous events; cleanup. Targets: idle client/server 0.00 ms; active client < 0.20 ms (markers are drawn only near checkpoints and zones); server < 0.50 ms per active instance at 32 players.
