# EVENT STUDIO — Event Catalog

> Generated from structured data (source: `tools/gen_catalog.py`). Every entry is a **preset or option of a reusable mode**, not a separate script.

> Status: **V1** = playable in V1 via the named mode · **V2** = architecture-ready, needs a new component/option · **Future** = later expansion.

**Totals:** 119 events · V1 92 · V2 20 · Future 7

## V1 modes (the reusable engine modes)

| Mode | Category | Components | Catalog entries served |
|---|---|---|---|
| `race` | racing / obstacle | vehicles, checkpoints, spawns, combat(off), bounds(optional) | 19 |
| `sumo` | vehicle | vehicles, bounds, zones(shrink), spawns | 4 |
| `deathmatch` | combat | combat, spawns, teams, rounds | 14 |
| `gungame` | combat | combat, spawns | 1 |
| `koth` | objective / vehicle | zones, teams, combat, spawns | 7 |
| `ctf` | objective | teams, zones, combat, spawns (carriable flags) | 2 |
| `zone_survival` | survival | zones(shrink), combat, bounds, spawns | 6 |
| `hunt` | hunt | checkpoints(unordered/hidden), spawns | 9 |
| `redlight` | social | zones(finish), server displacement check | 2 |
| `trivia` | social | server rounds, NUI input | 3 |
| `reaction` | social | server rounds, NUI input | 1 |
| `custom` | social / any | manual scoring by staff, API scoring | 1 |
| `juggernaut` | combat | roles, combat, spawns | 1 |
| `vip` | combat | teams, roles, combat, zones | 1 |
| `hunters` | combat | roles, combat, spawns | 1 |
| `keep_moving` | vehicle | vehicles, server velocity, bounds | 1 |
| `musical_chairs` | social | dynamic zones, rounds | 1 |
| `bounty` | combat | combat, spawns, secret targets, marked players | 2 |
| `package` | objective | carriable packages, zones, combat | 3 |
| `vehicle_tag` | vehicle | vehicles, roles, server proximity | 1 |

## Racing

### 1. Standard Circuit Race  ·  **V1**

| Field | Value |
|---|---|
| Category | Racing |
| Players | 2-32 |
| Teams | Solo |
| Core mechanic | Lap-based ordered checkpoints on a closed loop |
| Win condition | First to complete all laps |
| Lose condition | DNF when time expires; last place |
| Scoring | Placement table; lap bonus; DNF 0 |
| Required systems | vehicles, checkpoints, timer, positions, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Easy |
| Development complexity | Low (mode race) |
| Potential exploits | teleport to checkpoint, speed hacks, vehicle spawning, corner cutting |
| Status | V1 · mode `race` preset `street_circuit` |

### 2. Point-to-Point Race  ·  **V1**

| Field | Value |
|---|---|
| Category | Racing |
| Players | 2-32 |
| Teams | Solo |
| Core mechanic | Single-lap ordered checkpoints A→B |
| Win condition | First to reach finish |
| Lose condition | DNF when time expires; last place |
| Scoring | Placement table |
| Required systems | vehicles, checkpoints, timer, positions, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | teleport to checkpoint, speed hacks, vehicle spawning, corner cutting |
| Status | V1 · mode `race` (laps=1) |

### 3. Checkpoint Race  ·  **V1**

| Field | Value |
|---|---|
| Category | Racing |
| Players | 2-32 |
| Teams | Solo |
| Core mechanic | Many dense ordered checkpoints, any vehicle |
| Win condition | First to finish |
| Lose condition | DNF when time expires; last place |
| Scoring | Placement + checkpoint points |
| Required systems | vehicles, checkpoints, timer, positions, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | teleport to checkpoint, speed hacks, vehicle spawning, corner cutting |
| Status | V1 · mode `race` |

### 4. Time Trial  ·  **V1**

| Field | Value |
|---|---|
| Category | Racing |
| Players | 1-32 |
| Teams | Solo |
| Core mechanic | Race against the clock; ghosted; personal bests |
| Win condition | Best time in window |
| Lose condition | DNF when time expires; last place |
| Scoring | Placement by time; PB tracked |
| Required systems | vehicles, checkpoints, timer, positions, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | teleport to checkpoint, speed hacks, vehicle spawning, corner cutting |
| Status | V1 · mode `race` (`ghost=true`, rankBy time) |

### 5. Drag Race  ·  **V1**

| Field | Value |
|---|---|
| Category | Racing |
| Players | 2-8 |
| Teams | Solo |
| Core mechanic | Short straight, 2-3 checkpoints, standing start |
| Win condition | First to finish line |
| Lose condition | DNF when time expires; last place |
| Scoring | Placement |
| Required systems | vehicles, checkpoints, timer, positions, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | teleport to checkpoint, speed hacks, vehicle spawning, corner cutting |
| Status | V1 · mode `race` preset `drag_strip` |

### 6. Street Race  ·  **V1**

| Field | Value |
|---|---|
| Category | Racing |
| Players | 2-16 |
| Teams | Solo |
| Core mechanic | Public-road circuit/sprint with traffic disabled in bucket |
| Win condition | First to finish |
| Lose condition | DNF when time expires; last place |
| Scoring | Placement |
| Required systems | vehicles, checkpoints, timer, positions, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | teleport to checkpoint, speed hacks, vehicle spawning, corner cutting |
| Status | V1 · mode `race` |

### 7. Off-road Race  ·  **V1**

| Field | Value |
|---|---|
| Category | Racing |
| Players | 2-16 |
| Teams | Solo |
| Core mechanic | Off-road vehicle class on dirt route |
| Win condition | First to finish |
| Lose condition | DNF when time expires; last place |
| Scoring | Placement |
| Required systems | vehicles, checkpoints, timer, positions, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | teleport to checkpoint, speed hacks, vehicle spawning, corner cutting |
| Status | V1 · mode `race` (class filter) |

### 8. Bike Race  ·  **V1**

| Field | Value |
|---|---|
| Category | Racing |
| Players | 2-16 |
| Teams | Solo |
| Core mechanic | Motorbikes/bicycles only |
| Win condition | First to finish |
| Lose condition | DNF when time expires; last place |
| Scoring | Placement |
| Required systems | vehicles, checkpoints, timer, positions, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | teleport to checkpoint, speed hacks, vehicle spawning, corner cutting |
| Status | V1 · mode `race` (vehicle type bike) |

### 9. Boat Race  ·  **V1**

| Field | Value |
|---|---|
| Category | Racing |
| Players | 2-16 |
| Teams | Solo |
| Core mechanic | Water checkpoints, boats spawned server-side as `boat` |
| Win condition | First to finish |
| Lose condition | DNF when time expires; last place |
| Scoring | Placement |
| Required systems | vehicles, checkpoints, timer, positions, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | teleport to checkpoint, speed hacks, vehicle spawning, corner cutting |
| Status | V1 · mode `race` (vehicle type boat) |

### 10. Aircraft Race  ·  **V1**

| Field | Value |
|---|---|
| Category | Racing |
| Players | 2-16 |
| Teams | Solo |
| Core mechanic | Air checkpoints (3D radius), planes/helis |
| Win condition | First to finish |
| Lose condition | DNF when time expires; last place |
| Scoring | Placement |
| Required systems | vehicles, 3D checkpoints, timer |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Hard |
| Development complexity | Medium |
| Potential exploits | Collision-free flying through terrain; checkpoint radius abuse |
| Status | V1 · mode `race` (vehicle type plane/heli, `checkpoint3d=true`) |

### 11. Random Vehicle Race  ·  **V1**

| Field | Value |
|---|---|
| Category | Racing |
| Players | 2-32 |
| Teams | Solo |
| Core mechanic | Each racer gets a random model from a pool |
| Win condition | First to finish |
| Lose condition | DNF when time expires; last place |
| Scoring | Placement |
| Required systems | vehicles, checkpoints, timer, positions, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | teleport to checkpoint, speed hacks, vehicle spawning, corner cutting |
| Status | V1 · mode `race` (`vehicle.random=true`) |

### 12. Vehicle Class Race  ·  **V1**

| Field | Value |
|---|---|
| Category | Racing |
| Players | 2-32 |
| Teams | Solo |
| Core mechanic | Player picks from a class-limited list in lobby |
| Win condition | First to finish |
| Lose condition | DNF when time expires; last place |
| Scoring | Placement |
| Required systems | vehicles, checkpoints, timer, positions, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | teleport to checkpoint, speed hacks, vehicle spawning, corner cutting |
| Status | V1 · mode `race` (vehicle pool = class list) |

### 13. Elimination Race  ·  **V1**

| Field | Value |
|---|---|
| Category | Racing |
| Players | 3-32 |
| Teams | Solo |
| Core mechanic | Last place eliminated every N seconds |
| Win condition | Last racer remaining / first to finish |
| Lose condition | Being last at elimination tick |
| Scoring | Placement by elimination order |
| Required systems | vehicles, checkpoints, timer, positions, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | teleport to checkpoint, speed hacks, vehicle spawning, corner cutting |
| Status | V1 · mode `race` (`eliminateEvery`) |

### 14. Reverse / Alternate Route Race  ·  **V1**

| Field | Value |
|---|---|
| Category | Racing |
| Players | 2-32 |
| Teams | Solo |
| Core mechanic | Arena checkpoints reversed or alternate set |
| Win condition | First to finish |
| Lose condition | DNF when time expires; last place |
| Scoring | Placement |
| Required systems | vehicles, checkpoints, timer, positions, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | teleport to checkpoint, speed hacks, vehicle spawning, corner cutting |
| Status | V1 · mode `race` (`reverse=true` / `route`) |

### 15. Stunt Race  ·  **V1**

| Field | Value |
|---|---|
| Category | Racing |
| Players | 2-16 |
| Teams | Solo |
| Core mechanic | Stunt props route; respawn at last checkpoint |
| Win condition | First to finish |
| Lose condition | DNF when time expires; last place |
| Scoring | Placement |
| Required systems | vehicles, checkpoints, props (map resource), respawn at checkpoint |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Hard |
| Development complexity | Medium (props via external map) |
| Potential exploits | teleport to checkpoint, speed hacks, vehicle spawning, corner cutting |
| Status | V1 · mode `race` with external map resource; built-in prop placement V2 |

### 16. Team Relay Race  ·  **V2**

| Field | Value |
|---|---|
| Category | Racing |
| Players | 4-16 |
| Teams | 2-4 teams |
| Core mechanic | Teammates run legs sequentially; baton passes at handover checkpoint |
| Win condition | Team finishes all legs first |
| Lose condition | DNF when time expires; last place |
| Scoring | Team placement |
| Required systems | vehicles, checkpoints, timer, positions, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | teleport to checkpoint, speed hacks, vehicle spawning, corner cutting |
| Status | V2 · needs relay leg handover in race mode |

## Vehicle Competitions

### 17. Sumo  ·  **V1**

| Field | Value |
|---|---|
| Category | Vehicle Competitions |
| Players | 2-16 |
| Teams | Solo or teams |
| Core mechanic | Push others off a platform/arena; handbrake optional disabled; sudden-death shrink |
| Win condition | Last in arena |
| Lose condition | eliminated (out of bounds / wrecked) |
| Scoring | Placement by elimination order; knockouts +points |
| Required systems | vehicles, bounds/zones, eliminations, timer, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | god-mode vehicle, handling mods, leaving vehicle, teleport |
| Status | V1 · mode `sumo` |

### 18. Vehicle Knockout  ·  **V1**

| Field | Value |
|---|---|
| Category | Vehicle Competitions |
| Players | 2-16 |
| Teams | Solo |
| Core mechanic | Sumo variant with knock-out credit to last contact |
| Win condition | Most knockouts / last standing |
| Lose condition | eliminated (out of bounds / wrecked) |
| Scoring | Knockouts ×points + placement |
| Required systems | vehicles, bounds/zones, eliminations, timer, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | god-mode vehicle, handling mods, leaving vehicle, teleport |
| Status | V1 · mode `sumo` (`scoreKnockouts=true`) |

### 19. Demolition Derby  ·  **V1**

| Field | Value |
|---|---|
| Category | Vehicle Competitions |
| Players | 2-24 |
| Teams | Solo or teams |
| Core mechanic | Wreck others; eliminated when vehicle destroyed |
| Win condition | Last vehicle running |
| Lose condition | eliminated (out of bounds / wrecked) |
| Scoring | Placement + wreck credits |
| Required systems | vehicles, bounds/zones, eliminations, timer, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | god-mode vehicle, handling mods, leaving vehicle, teleport |
| Status | V1 · mode `sumo` (`eliminateOnWreck=true`, larger bounds) |

### 20. King of the Hill (Vehicles)  ·  **V1**

| Field | Value |
|---|---|
| Category | Vehicle Competitions |
| Players | 2-16 |
| Teams | Solo or teams |
| Core mechanic | Hold a zone while in a vehicle |
| Win condition | Most hold time |
| Lose condition | eliminated (out of bounds / wrecked) |
| Scoring | Points per second held |
| Required systems | vehicles, bounds/zones, eliminations, timer, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | god-mode vehicle, handling mods, leaving vehicle, teleport |
| Status | V1 · mode `koth` (`requireVehicle=true`) |

### 21. Last Vehicle Standing  ·  **V1**

| Field | Value |
|---|---|
| Category | Vehicle Competitions |
| Players | 2-24 |
| Teams | Solo |
| Core mechanic | Arena bounds + wreck elimination |
| Win condition | Last remaining |
| Lose condition | eliminated (out of bounds / wrecked) |
| Scoring | Placement |
| Required systems | vehicles, bounds/zones, eliminations, timer, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | god-mode vehicle, handling mods, leaving vehicle, teleport |
| Status | V1 · mode `sumo` preset |

### 22. Vehicle Push  ·  **V2**

| Field | Value |
|---|---|
| Category | Vehicle Competitions |
| Players | 2-8 |
| Teams | 2 teams |
| Core mechanic | Push a heavy object/vehicle into goal zone |
| Win condition | Object reaches enemy goal |
| Lose condition | Opponent scores |
| Scoring | Goals |
| Required systems | vehicles, bounds/zones, eliminations, timer, spawns |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Hard |
| Development complexity | High |
| Potential exploits | Physics desync of pushed entity |
| Status | V2 · needs networked physics object ownership handling |

### 23. Vehicle Survival  ·  **V1**

| Field | Value |
|---|---|
| Category | Vehicle Competitions |
| Players | 1-16 |
| Teams | Solo |
| Core mechanic | Survive in vehicle vs hazards / shrinking zone |
| Win condition | Last alive |
| Lose condition | eliminated (out of bounds / wrecked) |
| Scoring | Survival time points |
| Required systems | vehicles, zones, eliminations |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | god-mode vehicle, handling mods, leaving vehicle, teleport |
| Status | V1 · mode `zone_survival` (`requireVehicle=true`) |

### 24. Checkpoint Destruction  ·  **V2**

| Field | Value |
|---|---|
| Category | Vehicle Competitions |
| Players | 2-16 |
| Teams | 2 teams |
| Core mechanic | Destroy enemy props/targets with vehicles |
| Win condition | Destroy all first |
| Lose condition | eliminated (out of bounds / wrecked) |
| Scoring | Objective points |
| Required systems | vehicles, destructible objectives |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Hard |
| Development complexity | High |
| Potential exploits | Fake destruction events |
| Status | V2 |

### 25. Hot Vehicle / Keep Moving  ·  **V1**

| Field | Value |
|---|---|
| Category | Vehicle Competitions |
| Players | 2-16 |
| Teams | Solo |
| Core mechanic | Must stay above a rising speed threshold (server-side velocity check) or be eliminated |
| Win condition | Last moving |
| Lose condition | eliminated (out of bounds / wrecked) |
| Scoring | Seconds above the limit |
| Required systems | vehicles, server velocity check, eliminations |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | god-mode vehicle, handling mods, leaving vehicle, teleport |
| Status | V1 · mode `keep_moving` |

### 26. Delivery Under Pressure  ·  **V2**

| Field | Value |
|---|---|
| Category | Vehicle Competitions |
| Players | 1-8 |
| Teams | Solo/teams |
| Core mechanic | Deliver a vehicle to destination without exceeding damage |
| Win condition | Delivered first with health above threshold |
| Lose condition | eliminated (out of bounds / wrecked) |
| Scoring | Time + health bonus |
| Required systems | vehicles, checkpoints, health check |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | god-mode vehicle, handling mods, leaving vehicle, teleport |
| Status | V2 |

### 27. Escort Vehicle  ·  **Future**

| Field | Value |
|---|---|
| Category | Vehicle Competitions |
| Players | 4-16 |
| Teams | 2 teams |
| Core mechanic | Defenders escort a slow vehicle to destination; attackers stop it |
| Win condition | Vehicle reaches destination / destroyed |
| Lose condition | eliminated (out of bounds / wrecked) |
| Scoring | Objective |
| Required systems | vehicles, roles, checkpoints, combat |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Hard |
| Development complexity | High |
| Potential exploits | god-mode vehicle, handling mods, leaving vehicle, teleport |
| Status | Future |

### 28. Vehicle Protection  ·  **V2**

| Field | Value |
|---|---|
| Category | Vehicle Competitions |
| Players | 4-16 |
| Teams | 2 teams |
| Core mechanic | Protect a parked vehicle for time |
| Win condition | Vehicle survives / destroyed |
| Lose condition | eliminated (out of bounds / wrecked) |
| Scoring | Objective |
| Required systems | vehicles, roles, combat |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | god-mode vehicle, handling mods, leaving vehicle, teleport |
| Status | V2 |

### 29. Vehicle Interception  ·  **Future**

| Field | Value |
|---|---|
| Category | Vehicle Competitions |
| Players | 4-16 |
| Teams | 2 teams |
| Core mechanic | Runners reach destination; hunters intercept |
| Win condition | Runner arrives / all runners stopped |
| Lose condition | eliminated (out of bounds / wrecked) |
| Scoring | Objective |
| Required systems | vehicles, roles, checkpoints |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Hard |
| Development complexity | High |
| Potential exploits | god-mode vehicle, handling mods, leaving vehicle, teleport |
| Status | Future (Hunting-pack inspired) |

### 30. Vehicle Tag  ·  **V1**

| Field | Value |
|---|---|
| Category | Vehicle Competitions |
| Players | 3-16 |
| Teams | Solo |
| Core mechanic | "It" vehicle tags others by contact (server proximity) |
| Win condition | Least time as "it" |
| Lose condition | eliminated (out of bounds / wrecked) |
| Scoring | Time not-it |
| Required systems | vehicles, roles, proximity |
| Dependencies | OneSync; vehicles |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | Fake contact reports (use server distance) |
| Status | V1 · mode `vehicle_tag` (score per second not-it) |

## Combat / PvP

### 31. Free For All  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 2-32 |
| Teams | Solo |
| Core mechanic | Everyone vs everyone, respawns |
| Win condition | Kill target or most kills at time |
| Lose condition | out of lives / lower score at time |
| Scoring | Kills ×points; placement |
| Required systems | combat (loadout, damage filter, kill attribution), lives/respawn, spawns, timer, teams |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat) |
| Status | V1 · mode `deathmatch` |

### 32. Team Deathmatch  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 4-32 |
| Teams | 2-4 teams |
| Core mechanic | Team kills, respawns, friendly fire off |
| Win condition | Team kill target / most at time |
| Lose condition | out of lives / lower score at time |
| Scoring | Team kills; individual kills |
| Required systems | combat (loadout, damage filter, kill attribution), lives/respawn, spawns, timer, teams |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat) |
| Status | V1 · mode `deathmatch` (teams) |

### 33. Last Man Standing  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 2-32 |
| Teams | Solo |
| Core mechanic | One life, no respawn |
| Win condition | Last alive |
| Lose condition | out of lives / lower score at time |
| Scoring | Placement by elimination order + kills |
| Required systems | combat (loadout, damage filter, kill attribution), lives/respawn, spawns, timer, teams |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat) |
| Status | V1 · mode `deathmatch` (`lives=1`) |

### 34. Last Team Standing  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 4-32 |
| Teams | 2-4 teams |
| Core mechanic | One life per round, rounds |
| Win condition | Team wins most rounds |
| Lose condition | out of lives / lower score at time |
| Scoring | Round wins |
| Required systems | combat (loadout, damage filter, kill attribution), lives/respawn, spawns, timer, teams |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat) |
| Status | V1 · mode `deathmatch` (teams, lives=1, rounds) |

### 35. Gun Game / Kill Quota  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 2-32 |
| Teams | Solo (teams V2) |
| Core mechanic | Advance weapon ladder per kill(s) |
| Win condition | First to complete ladder |
| Lose condition | out of lives / lower score at time |
| Scoring | Level reached; placement |
| Required systems | combat (loadout, damage filter, kill attribution), lives/respawn, spawns, timer, teams |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat) |
| Status | V1 · mode `gungame` |

### 36. Weapon Rotation  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 2-32 |
| Teams | Solo/teams |
| Core mechanic | All players switch weapon every N seconds |
| Win condition | Most kills |
| Lose condition | out of lives / lower score at time |
| Scoring | Kills |
| Required systems | combat (loadout, damage filter, kill attribution), lives/respawn, spawns, timer, teams |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat) |
| Status | V1 · mode `deathmatch` (`rotateEvery`) |

### 37. One Weapon Only  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 2-32 |
| Teams | Solo/teams |
| Core mechanic | Single configured weapon |
| Win condition | Most kills |
| Lose condition | out of lives / lower score at time |
| Scoring | Kills |
| Required systems | combat (loadout, damage filter, kill attribution), lives/respawn, spawns, timer, teams |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat) |
| Status | V1 · `deathmatch` preset |

### 38. Snipers Only  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 2-32 |
| Teams | Solo/teams |
| Core mechanic | Sniper rifles only |
| Win condition | Most kills |
| Lose condition | out of lives / lower score at time |
| Scoring | Kills |
| Required systems | combat (loadout, damage filter, kill attribution), lives/respawn, spawns, timer, teams |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat) |
| Status | V1 · `deathmatch` preset `snipers_only` |

### 39. Pistols Only  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 2-32 |
| Teams | Solo/teams |
| Core mechanic | Pistols only |
| Win condition | Most kills |
| Lose condition | out of lives / lower score at time |
| Scoring | Kills |
| Required systems | combat (loadout, damage filter, kill attribution), lives/respawn, spawns, timer, teams |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat) |
| Status | V1 · `deathmatch` preset `pistols_only` |

### 40. Melee Only  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 2-32 |
| Teams | Solo/teams |
| Core mechanic | Melee weapons only |
| Win condition | Most kills |
| Lose condition | out of lives / lower score at time |
| Scoring | Kills |
| Required systems | combat (loadout, damage filter, kill attribution), lives/respawn, spawns, timer, teams |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat) |
| Status | V1 · `deathmatch` preset `melee_brawl` |

### 41. Shotgun Arena  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 2-32 |
| Teams | Solo/teams |
| Core mechanic | Shotguns in close quarters arena |
| Win condition | Most kills |
| Lose condition | out of lives / lower score at time |
| Scoring | Kills |
| Required systems | combat (loadout, damage filter, kill attribution), lives/respawn, spawns, timer, teams |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat) |
| Status | V1 · `deathmatch` preset |

### 42. Random Weapons  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 2-32 |
| Teams | Solo/teams |
| Core mechanic | Random weapon per life from pool |
| Win condition | Most kills |
| Lose condition | out of lives / lower score at time |
| Scoring | Kills |
| Required systems | combat (loadout, damage filter, kill attribution), lives/respawn, spawns, timer, teams |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat) |
| Status | V1 · `deathmatch` (`randomWeapons=true`) |

### 43. Elimination Tournament  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 4-64 |
| Teams | Solo |
| Core mechanic | Bracket of duels/LMS matches |
| Win condition | Tournament winner |
| Lose condition | out of lives / lower score at time |
| Scoring | Tournament placement |
| Required systems | combat (loadout, damage filter, kill attribution), lives/respawn, spawns, timer, teams |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat) |
| Status | V1 · tournament (single elimination) of `duel` |

### 44. Duel  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 2 |
| Teams | Solo |
| Core mechanic | 1v1, rounds, one life |
| Win condition | Best of N rounds |
| Lose condition | out of lives / lower score at time |
| Scoring | Round wins |
| Required systems | combat (loadout, damage filter, kill attribution), lives/respawn, spawns, timer, teams |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat) |
| Status | V1 · `deathmatch` preset `pistol_duel` (min=max=2, rounds) |

### 45. Team Elimination  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 4-32 |
| Teams | 2 teams |
| Core mechanic | Elimination rounds, no respawn |
| Win condition | Round wins |
| Lose condition | out of lives / lower score at time |
| Scoring | Round wins |
| Required systems | combat (loadout, damage filter, kill attribution), lives/respawn, spawns, timer, teams |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat) |
| Status | V1 · `deathmatch` (teams, lives=1) |

### 46. Juggernaut  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 3-24 |
| Teams | Juggernaut vs everyone |
| Core mechanic | One heavily armoured player vs attackers; killer takes the role |
| Win condition | Most points (time as Juggernaut + takedowns) |
| Lose condition | out of lives / lower score at time |
| Scoring | Role-based points |
| Required systems | combat, roles |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat) |
| Status | V1 · mode `juggernaut` |

### 47. Hunter vs Runners  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 3-24 |
| Teams | 2 roles |
| Core mechanic | Runners survive with a head start, hunters catch; optional infection |
| Win condition | Runners survive / all caught |
| Lose condition | out of lives / lower score at time |
| Scoring | Survival seconds, catches, survive bonus |
| Required systems | roles, combat |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat) |
| Status | V1 · mode `hunters` |

### 48. Assassin Hunt  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 4-32 |
| Teams | Solo |
| Core mechanic | Each player assigned a secret target |
| Win condition | Most valid assassinations |
| Lose condition | out of lives / lower score at time |
| Scoring | Valid target kills +, wrong kills − |
| Required systems | combat, roles, secret assignment |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | Target leaks (server only sends own target) |
| Status | V1 · `bounty` (`style=assassin`) |

### 49. Bounty Hunt  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 4-32 |
| Teams | Solo |
| Core mechanic | Leader carries bounty, visible on map |
| Win condition | Most bounty points |
| Lose condition | out of lives / lower score at time |
| Scoring | Bounty kills |
| Required systems | combat, roles, blips |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat) |
| Status | V1 · mode `bounty` |

### 50. Protect the VIP  ·  **V1**

| Field | Value |
|---|---|
| Category | Combat / PvP |
| Players | 2-24 |
| Teams | 2 teams |
| Core mechanic | Bodyguards escort the VIP to extraction; attackers hunt the VIP; rounds with side swap |
| Win condition | VIP extracted / killed / timeout |
| Lose condition | out of lives / lower score at time |
| Scoring | Round wins |
| Required systems | roles, combat, zones |
| Dependencies | OneSync; weapons |
| Difficulty (player) | Hard |
| Development complexity | Medium |
| Potential exploits | fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat) |
| Status | V1 · mode `vip` |

## Objective / Team Modes

### 51. Capture the Flag  ·  **V1**

| Field | Value |
|---|---|
| Category | Objective / Team Modes |
| Players | 4-32 |
| Teams | 2 teams |
| Core mechanic | Grab enemy flag at base, return to own base while own flag home |
| Win condition | Capture target / most caps |
| Lose condition | opponent reaches target / higher score at time |
| Scoring | Captures ×points; returns, carrier kills |
| Required systems | teams, zones, objectives, combat, spawns, timer |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | fake captures, teleport into zone, carrier teleport |
| Status | V1 · mode `ctf` |

### 52. Capture Point  ·  **V1**

| Field | Value |
|---|---|
| Category | Objective / Team Modes |
| Players | 2-32 |
| Teams | Solo/teams |
| Core mechanic | Single zone; capture progress by occupancy |
| Win condition | Hold target reached |
| Lose condition | opponent reaches target / higher score at time |
| Scoring | Points per second held |
| Required systems | teams, zones, objectives, combat, spawns, timer |
| Dependencies | OneSync |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | fake captures, teleport into zone, carrier teleport |
| Status | V1 · mode `koth` |

### 53. King of the Hill  ·  **V1**

| Field | Value |
|---|---|
| Category | Objective / Team Modes |
| Players | 2-32 |
| Teams | Solo/teams |
| Core mechanic | Hold uncontested zone to earn points |
| Win condition | Most points / target |
| Lose condition | opponent reaches target / higher score at time |
| Scoring | Points per second |
| Required systems | teams, zones, objectives, combat, spawns, timer |
| Dependencies | OneSync |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | fake captures, teleport into zone, carrier teleport |
| Status | V1 · mode `koth` |

### 54. Territory Control  ·  **V1**

| Field | Value |
|---|---|
| Category | Objective / Team Modes |
| Players | 4-32 |
| Teams | 2-4 teams |
| Core mechanic | Several zones owned by teams; income per owned zone |
| Win condition | Most points |
| Lose condition | opponent reaches target / higher score at time |
| Scoring | Points per zone per tick |
| Required systems | teams, zones, objectives, combat, spawns, timer |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | fake captures, teleport into zone, carrier teleport |
| Status | V1 · mode `koth` (multiple zones, ownership) |

### 55. Domination  ·  **V1**

| Field | Value |
|---|---|
| Category | Objective / Team Modes |
| Players | 4-32 |
| Teams | 2 teams |
| Core mechanic | 3+ capture points with ownership flip |
| Win condition | Score target |
| Lose condition | opponent reaches target / higher score at time |
| Scoring | Points per owned point |
| Required systems | teams, zones, objectives, combat, spawns, timer |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | fake captures, teleport into zone, carrier teleport |
| Status | V1 · mode `koth` preset `domination` |

### 56. Search and Collect  ·  **V1**

| Field | Value |
|---|---|
| Category | Objective / Team Modes |
| Players | 2-32 |
| Teams | Solo/teams |
| Core mechanic | Collect scattered pickups (server proximity) |
| Win condition | Most collected |
| Lose condition | opponent reaches target / higher score at time |
| Scoring | Objective points |
| Required systems | checkpoints (unordered), timer |
| Dependencies | OneSync |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | fake captures, teleport into zone, carrier teleport |
| Status | V1 · mode `hunt` (visible, collect) |

### 57. Deliver the Package  ·  **V1**

| Field | Value |
|---|---|
| Category | Objective / Team Modes |
| Players | 2-16 |
| Teams | Solo/teams |
| Core mechanic | Pick up package, deliver to drop zone |
| Win condition | Most deliveries |
| Lose condition | opponent reaches target / higher score at time |
| Scoring | Delivery points |
| Required systems | carriable objective, zones |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | fake captures, teleport into zone, carrier teleport |
| Status | V1 · mode `package` (`style=deliver`) |

### 58. Escort  ·  **Future**

| Field | Value |
|---|---|
| Category | Objective / Team Modes |
| Players | 4-16 |
| Teams | 2 teams |
| Core mechanic | Move escort target along path by proximity |
| Win condition | Target reaches end |
| Lose condition | opponent reaches target / higher score at time |
| Scoring | Objective |
| Required systems | zones, path progress |
| Dependencies | OneSync |
| Difficulty (player) | Hard |
| Development complexity | High |
| Potential exploits | fake captures, teleport into zone, carrier teleport |
| Status | Future |

### 59. Attack vs Defense  ·  **V1**

| Field | Value |
|---|---|
| Category | Objective / Team Modes |
| Players | 4-32 |
| Teams | 2 teams |
| Core mechanic | Attackers capture sequence of points, defenders hold |
| Win condition | Attackers capture all / time out |
| Lose condition | opponent reaches target / higher score at time |
| Scoring | Objective |
| Required systems | zones (sequential), teams, combat |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | fake captures, teleport into zone, carrier teleport |
| Status | V1 · `koth` (`style=attack`) |

### 60. Bomb/Package Delivery  ·  **Future**

| Field | Value |
|---|---|
| Category | Objective / Team Modes |
| Players | 4-32 |
| Teams | 2 teams |
| Core mechanic | Carry bomb to site, plant, defend |
| Win condition | Detonate / defuse |
| Lose condition | opponent reaches target / higher score at time |
| Scoring | Round wins |
| Required systems | carriable, zones, timer, rounds |
| Dependencies | OneSync |
| Difficulty (player) | Hard |
| Development complexity | High |
| Potential exploits | fake captures, teleport into zone, carrier teleport |
| Status | Future |

### 61. Hold the Objective  ·  **V1**

| Field | Value |
|---|---|
| Category | Objective / Team Modes |
| Players | 2-32 |
| Teams | Solo/teams |
| Core mechanic | Carry an item as long as possible (server tracks carrier) |
| Win condition | Most carry time |
| Lose condition | opponent reaches target / higher score at time |
| Scoring | Points per second carried |
| Required systems | carriable |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | fake captures, teleport into zone, carrier teleport |
| Status | V1 · `package` (`style=hold`) |

### 62. Multi-Point Control  ·  **V1**

| Field | Value |
|---|---|
| Category | Objective / Team Modes |
| Players | 4-32 |
| Teams | 2-4 teams |
| Core mechanic | Multiple simultaneous points |
| Win condition | Most points |
| Lose condition | opponent reaches target / higher score at time |
| Scoring | Points per owned point |
| Required systems | teams, zones, objectives, combat, spawns, timer |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | fake captures, teleport into zone, carrier teleport |
| Status | V1 · `koth` multi-zone |

### 63. Steal and Return  ·  **V1**

| Field | Value |
|---|---|
| Category | Objective / Team Modes |
| Players | 4-16 |
| Teams | 2 teams |
| Core mechanic | Steal enemy packages to own base (Raid-like) |
| Win condition | Most packages |
| Lose condition | opponent reaches target / higher score at time |
| Scoring | Deliveries |
| Required systems | teams, zones, objectives, combat, spawns, timer |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | fake captures, teleport into zone, carrier teleport |
| Status | V1 · `ctf` (`flagsPerTeam>1`) partial; full V2 |

### 64. Resource Collection  ·  **V1**

| Field | Value |
|---|---|
| Category | Objective / Team Modes |
| Players | 2-32 |
| Teams | Solo/teams |
| Core mechanic | Collect resources, bank at base |
| Win condition | Most banked |
| Lose condition | opponent reaches target / higher score at time |
| Scoring | Banked amount |
| Required systems | carriable, zones |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | fake captures, teleport into zone, carrier teleport |
| Status | V1 · `package` (`style=deliver`, several packages) |

### 65. Zone Conquest  ·  **V2**

| Field | Value |
|---|---|
| Category | Objective / Team Modes |
| Players | 4-32 |
| Teams | 2-4 teams |
| Core mechanic | Sequential map-wide zone capture |
| Win condition | All zones captured |
| Lose condition | opponent reaches target / higher score at time |
| Scoring | Zones owned |
| Required systems | zones, teams |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | fake captures, teleport into zone, carrier teleport |
| Status | V2 |

## Survival

### 66. Zombie-style Survival  ·  **Future**

| Field | Value |
|---|---|
| Category | Survival |
| Players | 1-16 |
| Teams | Co-op |
| Core mechanic | Waves of hostile melee NPCs |
| Win condition | Survive all waves |
| Lose condition | All dead |
| Scoring | Waves survived, kills |
| Required systems | NPC wave spawner, combat |
| Dependencies | OneSync |
| Difficulty (player) | Hard |
| Development complexity | High |
| Potential exploits | NPC ownership desync, god mode |
| Status | Future (NPC ownership + performance) |

### 67. NPC Wave Survival  ·  **V2**

| Field | Value |
|---|---|
| Category | Survival |
| Players | 1-16 |
| Teams | Co-op |
| Core mechanic | Escalating armed NPC waves |
| Win condition | Survive waves |
| Lose condition | All dead |
| Scoring | Waves, kills |
| Required systems | NPC spawner, combat |
| Dependencies | OneSync |
| Difficulty (player) | Hard |
| Development complexity | High |
| Potential exploits | god mode, ignoring zone damage, teleport |
| Status | V2 |

### 68. Increasing Difficulty Survival  ·  **V2**

| Field | Value |
|---|---|
| Category | Survival |
| Players | 1-16 |
| Teams | Co-op |
| Core mechanic | Wave modifiers ramp |
| Win condition | Survive longest |
| Lose condition | death / outside zone too long |
| Scoring | Survival time |
| Required systems | NPC spawner |
| Dependencies | OneSync |
| Difficulty (player) | Hard |
| Development complexity | High |
| Potential exploits | god mode, ignoring zone damage, teleport |
| Status | V2 |

### 69. Vehicle Survival (zone)  ·  **V1**

| Field | Value |
|---|---|
| Category | Survival |
| Players | 1-16 |
| Teams | Solo |
| Core mechanic | Stay in vehicle inside shrinking zone |
| Win condition | Last alive |
| Lose condition | death / outside zone too long |
| Scoring | Survival points |
| Required systems | zones (shrinking), combat, lives, eliminations, timer |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | god mode, ignoring zone damage, teleport |
| Status | V1 · `zone_survival` (`requireVehicle`) |

### 70. Limited Ammo Survival  ·  **V1**

| Field | Value |
|---|---|
| Category | Survival |
| Players | 2-32 |
| Teams | Solo |
| Core mechanic | Last man standing with limited ammo |
| Win condition | Last alive |
| Lose condition | death / outside zone too long |
| Scoring | Placement + kills |
| Required systems | zones (shrinking), combat, lives, eliminations, timer |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | god mode, ignoring zone damage, teleport |
| Status | V1 · `zone_survival` / `deathmatch` (ammo option) |

### 71. Last Player Alive  ·  **V1**

| Field | Value |
|---|---|
| Category | Survival |
| Players | 2-64 |
| Teams | Solo |
| Core mechanic | Single life, combat allowed |
| Win condition | Last alive |
| Lose condition | death / outside zone too long |
| Scoring | Placement |
| Required systems | zones (shrinking), combat, lives, eliminations, timer |
| Dependencies | OneSync |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | god mode, ignoring zone damage, teleport |
| Status | V1 · `zone_survival` |

### 72. Safe Zone Survival  ·  **V1**

| Field | Value |
|---|---|
| Category | Survival |
| Players | 2-64 |
| Teams | Solo |
| Core mechanic | Must stay in safe zone that moves |
| Win condition | Last alive |
| Lose condition | death / outside zone too long |
| Scoring | Survival points |
| Required systems | zones (shrinking), combat, lives, eliminations, timer |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | god mode, ignoring zone damage, teleport |
| Status | V1 · `zone_survival` (`moving=true`) |

### 73. Shrinking Zone  ·  **V1**

| Field | Value |
|---|---|
| Category | Survival |
| Players | 2-64 |
| Teams | Solo/teams |
| Core mechanic | Battle zone shrinks in phases; outside = damage then elimination |
| Win condition | Last alive |
| Lose condition | death / outside zone too long |
| Scoring | Placement + kills |
| Required systems | zones (shrinking), combat, lives, eliminations, timer |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | god mode, ignoring zone damage, teleport |
| Status | V1 · mode `zone_survival` |

### 74. Environmental Survival  ·  **Future**

| Field | Value |
|---|---|
| Category | Survival |
| Players | 2-32 |
| Teams | Solo |
| Core mechanic | Weather/fire/explosion hazards |
| Win condition | Last alive |
| Lose condition | death / outside zone too long |
| Scoring | Survival time |
| Required systems | hazard spawner |
| Dependencies | OneSync |
| Difficulty (player) | Hard |
| Development complexity | High |
| Potential exploits | Cross-bucket explosions (Cfx caveat) |
| Status | Future |

## Hunt / Scavenger

### 75. Scavenger Hunt  ·  **V1**

| Field | Value |
|---|---|
| Category | Hunt / Scavenger |
| Players | 1-32 |
| Teams | Solo/teams |
| Core mechanic | Find list of locations in any order |
| Win condition | Find all first / most at time |
| Lose condition | not all found before time |
| Scoring | Objective points + time bonus |
| Required systems | checkpoints (unordered/hidden), timer, hints |
| Dependencies | OneSync |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | teleporting to targets, sniffing target coordinates |
| Status | V1 · mode `hunt` |

### 76. Checkpoint Hunt  ·  **V1**

| Field | Value |
|---|---|
| Category | Hunt / Scavenger |
| Players | 1-32 |
| Teams | Solo |
| Core mechanic | Visible unordered checkpoints across map |
| Win condition | All first |
| Lose condition | not all found before time |
| Scoring | Checkpoint points |
| Required systems | checkpoints (unordered/hidden), timer, hints |
| Dependencies | OneSync |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | teleporting to targets, sniffing target coordinates |
| Status | V1 · `hunt` (visible) |

### 77. Hidden Object Hunt  ·  **V1**

| Field | Value |
|---|---|
| Category | Hunt / Scavenger |
| Players | 1-32 |
| Teams | Solo |
| Core mechanic | Hidden locations, proximity "warmer/colder" |
| Win condition | Most found |
| Lose condition | not all found before time |
| Scoring | Objective points |
| Required systems | checkpoints (unordered/hidden), timer, hints |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | teleporting to targets, sniffing target coordinates |
| Status | V1 · `hunt` (`hidden=true`, hints) |

### 78. Vehicle Hunt  ·  **V2**

| Field | Value |
|---|---|
| Category | Hunt / Scavenger |
| Players | 1-16 |
| Teams | Solo |
| Core mechanic | Find parked target vehicles |
| Win condition | Most found |
| Lose condition | not all found before time |
| Scoring | Objective points |
| Required systems | hunt + vehicle spawn |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | teleporting to targets, sniffing target coordinates |
| Status | V2 |

### 79. Landmark Hunt  ·  **V1**

| Field | Value |
|---|---|
| Category | Hunt / Scavenger |
| Players | 1-32 |
| Teams | Solo |
| Core mechanic | Clues describe landmarks; reach them |
| Win condition | All first |
| Lose condition | not all found before time |
| Scoring | Objective points |
| Required systems | checkpoints (unordered/hidden), timer, hints |
| Dependencies | OneSync |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | teleporting to targets, sniffing target coordinates |
| Status | V1 · `hunt` (clue text per target) |

### 80. Photograph/Location Challenge  ·  **V1**

| Field | Value |
|---|---|
| Category | Hunt / Scavenger |
| Players | 1-32 |
| Teams | Solo |
| Core mechanic | Reach a place shown in a picture |
| Win condition | Most found |
| Lose condition | not all found before time |
| Scoring | Objective points |
| Required systems | hunt + image URLs in NUI |
| Dependencies | OneSync |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | teleporting to targets, sniffing target coordinates |
| Status | V1 · `hunt` (target `image` field) |

### 81. Treasure Hunt  ·  **V1**

| Field | Value |
|---|---|
| Category | Hunt / Scavenger |
| Players | 1-32 |
| Teams | Solo/teams |
| Core mechanic | Chain of clues leads to treasure |
| Win condition | First to treasure |
| Lose condition | not all found before time |
| Scoring | Placement |
| Required systems | checkpoints (unordered/hidden), timer, hints |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | teleporting to targets, sniffing target coordinates |
| Status | V1 · `hunt` (`ordered=true`, hidden, clues) |

### 82. Clue Hunt  ·  **V1**

| Field | Value |
|---|---|
| Category | Hunt / Scavenger |
| Players | 1-32 |
| Teams | Solo/teams |
| Core mechanic | Clue revealed after each find |
| Win condition | Finish chain first |
| Lose condition | not all found before time |
| Scoring | Placement |
| Required systems | checkpoints (unordered/hidden), timer, hints |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | teleporting to targets, sniffing target coordinates |
| Status | V1 · `hunt` ordered |

### 83. Timed Search  ·  **V1**

| Field | Value |
|---|---|
| Category | Hunt / Scavenger |
| Players | 1-32 |
| Teams | Solo |
| Core mechanic | Find as many as possible in time |
| Win condition | Most found |
| Lose condition | not all found before time |
| Scoring | Objective points |
| Required systems | checkpoints (unordered/hidden), timer, hints |
| Dependencies | OneSync |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | teleporting to targets, sniffing target coordinates |
| Status | V1 · `hunt` |

### 84. Multi-stage Hunt  ·  **V2**

| Field | Value |
|---|---|
| Category | Hunt / Scavenger |
| Players | 1-32 |
| Teams | Solo/teams |
| Core mechanic | Stages with different target sets |
| Win condition | Finish all stages |
| Lose condition | not all found before time |
| Scoring | Stage points |
| Required systems | hunt stages |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | teleporting to targets, sniffing target coordinates |
| Status | V2 |

## Obstacle / Skill

### 85. Parkour  ·  **V1**

| Field | Value |
|---|---|
| Category | Obstacle / Skill |
| Players | 1-32 |
| Teams | Solo |
| Core mechanic | On-foot ordered checkpoints; falling resets to last checkpoint |
| Win condition | Fastest finish |
| Lose condition | DNF at time |
| Scoring | Placement by time |
| Required systems | checkpoints, timer, bounds (fall = reset), spawns |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | teleport/noclip, flying |
| Status | V1 · mode `race` (`onFoot=true`) |

### 86. Obstacle Course  ·  **V1**

| Field | Value |
|---|---|
| Category | Obstacle / Skill |
| Players | 1-32 |
| Teams | Solo |
| Core mechanic | On-foot course, bounds reset |
| Win condition | Fastest finish |
| Lose condition | DNF at time |
| Scoring | Placement |
| Required systems | checkpoints, timer, bounds (fall = reset), spawns |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | teleport/noclip, flying |
| Status | V1 · `race` (`onFoot`) |

### 87. Rooftop Challenge  ·  **V1**

| Field | Value |
|---|---|
| Category | Obstacle / Skill |
| Players | 1-32 |
| Teams | Solo |
| Core mechanic | Rooftop parkour route |
| Win condition | Fastest finish |
| Lose condition | DNF at time |
| Scoring | Placement |
| Required systems | checkpoints, timer, bounds (fall = reset), spawns |
| Dependencies | OneSync |
| Difficulty (player) | Hard |
| Development complexity | Low |
| Potential exploits | teleport/noclip, flying |
| Status | V1 · `race` (`onFoot`) preset |

### 88. Precision Driving  ·  **V2**

| Field | Value |
|---|---|
| Category | Obstacle / Skill |
| Players | 1-16 |
| Teams | Solo |
| Core mechanic | Tight checkpoints; penalty per touch of wall (vehicle damage delta) |
| Win condition | Best time − penalties |
| Lose condition | DNF at time |
| Scoring | Time + damage penalty |
| Required systems | vehicles, checkpoints, server vehicle health |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | teleport/noclip, flying |
| Status | V2 |

### 89. Precision Parking  ·  **V2**

| Field | Value |
|---|---|
| Category | Obstacle / Skill |
| Players | 1-16 |
| Teams | Solo |
| Core mechanic | Stop inside a small zone with low speed & heading tolerance |
| Win condition | Best accuracy/time |
| Lose condition | DNF at time |
| Scoring | Accuracy points |
| Required systems | vehicles, zones, server heading/velocity |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | teleport/noclip, flying |
| Status | V2 |

### 90. Stunt Challenge  ·  **Future**

| Field | Value |
|---|---|
| Category | Obstacle / Skill |
| Players | 1-16 |
| Teams | Solo |
| Core mechanic | Stunt jumps & airtime measured |
| Win condition | Best score |
| Lose condition | DNF at time |
| Scoring | Stunt points |
| Required systems | vehicle telemetry (client) + sanity checks |
| Dependencies | OneSync |
| Difficulty (player) | Hard |
| Development complexity | High |
| Potential exploits | Client telemetry spoof |
| Status | Future |

### 91. Jump Challenge  ·  **V2**

| Field | Value |
|---|---|
| Category | Obstacle / Skill |
| Players | 1-16 |
| Teams | Solo |
| Core mechanic | Longest jump distance (server start/land positions) |
| Win condition | Longest distance |
| Lose condition | DNF at time |
| Scoring | Distance |
| Required systems | vehicles, server position sampling |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | teleport/noclip, flying |
| Status | V2 |

### 92. Landing Challenge  ·  **V2**

| Field | Value |
|---|---|
| Category | Obstacle / Skill |
| Players | 1-16 |
| Teams | Solo |
| Core mechanic | Parachute/aircraft land closest to target |
| Win condition | Closest landing |
| Lose condition | DNF at time |
| Scoring | Distance to target |
| Required systems | zones, server position |
| Dependencies | OneSync |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | teleport/noclip, flying |
| Status | V2 |

### 93. Balance Challenge  ·  **V2**

| Field | Value |
|---|---|
| Category | Obstacle / Skill |
| Players | 1-16 |
| Teams | Solo |
| Core mechanic | Stay on narrow structure longest |
| Win condition | Last on structure |
| Lose condition | DNF at time |
| Scoring | Survival time |
| Required systems | bounds (z/height) |
| Dependencies | OneSync |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | teleport/noclip, flying |
| Status | V2 · on-foot bounds (height) preset |

### 94. Skill Course  ·  **V1**

| Field | Value |
|---|---|
| Category | Obstacle / Skill |
| Players | 1-16 |
| Teams | Solo |
| Core mechanic | Mixed checkpoint course |
| Win condition | Fastest finish |
| Lose condition | DNF at time |
| Scoring | Placement |
| Required systems | checkpoints, timer, bounds (fall = reset), spawns |
| Dependencies | OneSync |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | teleport/noclip, flying |
| Status | V1 · `race` |

## Social / Fun

### 95. Musical Chairs  ·  **V1**

| Field | Value |
|---|---|
| Category | Social / Fun |
| Players | 2-32 |
| Teams | Solo |
| Core mechanic | Music stops → reach one of N-1 chairs (server occupancy, closest to center keeps it) |
| Win condition | Last remaining |
| Lose condition | No chair when the round ends |
| Scoring | Placement by elimination order |
| Required systems | zones, rounds |
| Dependencies | none beyond base |
| Difficulty (player) | Easy |
| Development complexity | Medium |
| Potential exploits | answer sniffing, auto-clickers, timing spoofing |
| Status | V1 · mode `musical_chairs` |

### 96. Random Challenge  ·  **V1**

| Field | Value |
|---|---|
| Category | Social / Fun |
| Players | 2-64 |
| Teams | Solo |
| Core mechanic | Director picks a random quick challenge |
| Win condition | Challenge winner |
| Lose condition | wrong answer / eliminated in round |
| Scoring | Per challenge |
| Required systems | director, social modes |
| Dependencies | none beyond base |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | answer sniffing, auto-clickers, timing spoofing |
| Status | V1 · director with social pool |

### 97. Simon Says  ·  **V2**

| Field | Value |
|---|---|
| Category | Social / Fun |
| Players | 3-32 |
| Teams | Solo |
| Core mechanic | Host issues commands; failures eliminated |
| Win condition | Last remaining |
| Lose condition | wrong answer / eliminated in round |
| Scoring | Placement |
| Required systems | host tools, rounds |
| Dependencies | none beyond base |
| Difficulty (player) | Easy |
| Development complexity | Medium |
| Potential exploits | Host bias (social) |
| Status | V2 |

### 98. Freeze / Movement Challenge  ·  **V1**

| Field | Value |
|---|---|
| Category | Social / Fun |
| Players | 2-64 |
| Teams | Solo |
| Core mechanic | Don't move for N seconds (server coords) |
| Win condition | Last remaining |
| Lose condition | wrong answer / eliminated in round |
| Scoring | Placement |
| Required systems | server rounds, NUI input, timer |
| Dependencies | none beyond base |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | answer sniffing, auto-clickers, timing spoofing |
| Status | V1 · mode `redlight` (always red) |

### 99. Red Light / Green Light  ·  **V1**

| Field | Value |
|---|---|
| Category | Social / Fun |
| Players | 2-64 |
| Teams | Solo |
| Core mechanic | Move on green, freeze on red; server measures displacement; reach finish line |
| Win condition | First to finish / survivors |
| Lose condition | wrong answer / eliminated in round |
| Scoring | Placement |
| Required systems | server rounds, NUI input, timer |
| Dependencies | none beyond base |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | answer sniffing, auto-clickers, timing spoofing |
| Status | V1 · mode `redlight` |

### 100. Trivia  ·  **V1**

| Field | Value |
|---|---|
| Category | Social / Fun |
| Players | 2-64 |
| Teams | Solo |
| Core mechanic | Server-timed multiple choice questions |
| Win condition | Most points |
| Lose condition | wrong answer / eliminated in round |
| Scoring | Correct × points + speed bonus |
| Required systems | server rounds, NUI input, timer |
| Dependencies | none beyond base |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | answer sniffing, auto-clickers, timing spoofing |
| Status | V1 · mode `trivia` |

### 101. Reaction Challenge  ·  **V1**

| Field | Value |
|---|---|
| Category | Social / Fun |
| Players | 2-64 |
| Teams | Solo |
| Core mechanic | Press when signal appears (server-timed); early = penalty |
| Win condition | Fastest average |
| Lose condition | wrong answer / eliminated in round |
| Scoring | Reaction points |
| Required systems | server rounds, NUI input, timer |
| Dependencies | none beyond base |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | answer sniffing, auto-clickers, timing spoofing |
| Status | V1 · mode `reaction` |

### 102. Quick Draw  ·  **V2**

| Field | Value |
|---|---|
| Category | Social / Fun |
| Players | 2-16 |
| Teams | Solo |
| Core mechanic | Duel: draw & fire on signal |
| Win condition | Fastest valid shot |
| Lose condition | wrong answer / eliminated in round |
| Scoring | Round wins |
| Required systems | reaction + combat |
| Dependencies | none beyond base |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | answer sniffing, auto-clickers, timing spoofing |
| Status | V2 |

### 103. Memory Challenge  ·  **V1**

| Field | Value |
|---|---|
| Category | Social / Fun |
| Players | 2-64 |
| Teams | Solo |
| Core mechanic | Remember sequence shown by server |
| Win condition | Most correct |
| Lose condition | wrong answer / eliminated in round |
| Scoring | Correct answers |
| Required systems | trivia engine (sequence questions) |
| Dependencies | none beyond base |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | answer sniffing, auto-clickers, timing spoofing |
| Status | V1 · `trivia` memory questions (`questionSet=memory`) |

### 104. Guessing Challenge  ·  **V1**

| Field | Value |
|---|---|
| Category | Social / Fun |
| Players | 2-64 |
| Teams | Solo |
| Core mechanic | Guess a number/value, closest wins |
| Win condition | Closest answers |
| Lose condition | wrong answer / eliminated in round |
| Scoring | Closeness points |
| Required systems | trivia engine (numeric) |
| Dependencies | none beyond base |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | answer sniffing, auto-clickers, timing spoofing |
| Status | V1 · `trivia` (`numeric` question type) |

### 105. Random Mini Challenge  ·  **V1**

| Field | Value |
|---|---|
| Category | Social / Fun |
| Players | 2-64 |
| Teams | Solo |
| Core mechanic | Rotation of short social modes |
| Win condition | Challenge winner |
| Lose condition | wrong answer / eliminated in round |
| Scoring | Per challenge |
| Required systems | director |
| Dependencies | none beyond base |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | answer sniffing, auto-clickers, timing spoofing |
| Status | V1 · director |

### 106. Staff Challenge  ·  **V1**

| Field | Value |
|---|---|
| Category | Social / Fun |
| Players | 2-64 |
| Teams | Solo |
| Core mechanic | Staff-hosted with manual scoring via admin panel |
| Win condition | Staff decision |
| Lose condition | wrong answer / eliminated in round |
| Scoring | Manual points (audited) |
| Required systems | admin manual scoring |
| Dependencies | none beyond base |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | Staff abuse (audit logged) |
| Status | V1 · mode `custom` (manual) |

### 107. Community Challenge  ·  **V2**

| Field | Value |
|---|---|
| Category | Social / Fun |
| Players | any |
| Teams | Everyone |
| Core mechanic | Server-wide goal (e.g. collective count) |
| Win condition | Goal reached |
| Lose condition | wrong answer / eliminated in round |
| Scoring | Participation |
| Required systems | global counters, API |
| Dependencies | none beyond base |
| Difficulty (player) | Easy |
| Development complexity | Medium |
| Potential exploits | answer sniffing, auto-clickers, timing spoofing |
| Status | V2 · API-driven |

## Tournaments

### 108. 1v1 Tournament  ·  **V1**

| Field | Value |
|---|---|
| Category | Tournaments |
| Players | 4-64 |
| Teams | Solo |
| Core mechanic | Bracket of duel matches |
| Win condition | Win final |
| Lose condition | losing a series / fewer league points |
| Scoring | Tournament points |
| Required systems | tournament engine, match instances, seeding, series |
| Dependencies | Event Engine + tournament engine |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | match fixing (social), disconnect abuse |
| Status | V1 · single elimination |

### 109. 2v2 Tournament  ·  **V1**

| Field | Value |
|---|---|
| Category | Tournaments |
| Players | 8-64 |
| Teams | Teams of 2 |
| Core mechanic | Team bracket |
| Win condition | Win final |
| Lose condition | losing a series / fewer league points |
| Scoring | Tournament points |
| Required systems | tournament engine + pre-made teams |
| Dependencies | Event Engine + tournament engine |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | match fixing (social), disconnect abuse |
| Status | V1 · single elimination with fixed teams |

### 110. 3v3 Tournament  ·  **V1**

| Field | Value |
|---|---|
| Category | Tournaments |
| Players | 12-48 |
| Teams | Teams of 3 |
| Core mechanic | Team bracket |
| Win condition | Win final |
| Lose condition | losing a series / fewer league points |
| Scoring | Tournament points |
| Required systems | tournament engine, match instances, seeding, series |
| Dependencies | Event Engine + tournament engine |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | match fixing (social), disconnect abuse |
| Status | V1 · single elimination with fixed teams |

### 111. Team Tournament  ·  **V1**

| Field | Value |
|---|---|
| Category | Tournaments |
| Players | 8-64 |
| Teams | Teams |
| Core mechanic | Generic team bracket |
| Win condition | Win final |
| Lose condition | losing a series / fewer league points |
| Scoring | Tournament points |
| Required systems | tournament engine, match instances, seeding, series |
| Dependencies | Event Engine + tournament engine |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | match fixing (social), disconnect abuse |
| Status | V1 |

### 112. Knockout Bracket  ·  **V1**

| Field | Value |
|---|---|
| Category | Tournaments |
| Players | 4-64 |
| Teams | Any |
| Core mechanic | Single elimination with byes and seeding |
| Win condition | Win final |
| Lose condition | losing a series / fewer league points |
| Scoring | Placement by round reached |
| Required systems | tournament engine, match instances, seeding, series |
| Dependencies | Event Engine + tournament engine |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | match fixing (social), disconnect abuse |
| Status | V1 |

### 113. Swiss-style Tournament  ·  **V2**

| Field | Value |
|---|---|
| Category | Tournaments |
| Players | 8-64 |
| Teams | Any |
| Core mechanic | Pair by record each round |
| Win condition | Best record |
| Lose condition | losing a series / fewer league points |
| Scoring | Match points + tiebreaks |
| Required systems | swiss pairing |
| Dependencies | Event Engine + tournament engine |
| Difficulty (player) | Hard |
| Development complexity | High |
| Potential exploits | match fixing (social), disconnect abuse |
| Status | V2 |

### 114. League  ·  **V1**

| Field | Value |
|---|---|
| Category | Tournaments |
| Players | 4-16 |
| Teams | Any |
| Core mechanic | Round robin, points per win/draw |
| Win condition | Most league points |
| Lose condition | losing a series / fewer league points |
| Scoring | League points |
| Required systems | tournament engine, match instances, seeding, series |
| Dependencies | Event Engine + tournament engine |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | match fixing (social), disconnect abuse |
| Status | V1 · round robin |

### 115. Seasonal Championship  ·  **V1**

| Field | Value |
|---|---|
| Category | Tournaments |
| Players | any |
| Teams | Solo |
| Core mechanic | Season points across all events |
| Win condition | Most season points |
| Lose condition | losing a series / fewer league points |
| Scoring | Season points from every event |
| Required systems | season leaderboards |
| Dependencies | Event Engine + tournament engine |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | match fixing (social), disconnect abuse |
| Status | V1 · season leaderboard |

### 116. Grand Final  ·  **V1**

| Field | Value |
|---|---|
| Category | Tournaments |
| Players | 2-16 |
| Teams | Any |
| Core mechanic | Final match/series between qualifiers |
| Win condition | Win final |
| Lose condition | losing a series / fewer league points |
| Scoring | Tournament points |
| Required systems | manual seeding from leaderboard |
| Dependencies | Event Engine + tournament engine |
| Difficulty (player) | Medium |
| Development complexity | Low |
| Potential exploits | match fixing (social), disconnect abuse |
| Status | V1 · tournament seeded from leaderboard (manual) |

### 117. Best-of-3  ·  **V1**

| Field | Value |
|---|---|
| Category | Tournaments |
| Players | 2+ |
| Teams | Any |
| Core mechanic | Series: first to 2 match wins |
| Win condition | Win series |
| Lose condition | losing a series / fewer league points |
| Scoring | Series wins |
| Required systems | tournament engine, match instances, seeding, series |
| Dependencies | Event Engine + tournament engine |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | match fixing (social), disconnect abuse |
| Status | V1 · series option |

### 118. Best-of-5  ·  **V1**

| Field | Value |
|---|---|
| Category | Tournaments |
| Players | 2+ |
| Teams | Any |
| Core mechanic | Series: first to 3 match wins |
| Win condition | Win series |
| Lose condition | losing a series / fewer league points |
| Scoring | Series wins |
| Required systems | tournament engine, match instances, seeding, series |
| Dependencies | Event Engine + tournament engine |
| Difficulty (player) | Easy |
| Development complexity | Low |
| Potential exploits | match fixing (social), disconnect abuse |
| Status | V1 · series option |

### 119. Points Championship  ·  **V2**

| Field | Value |
|---|---|
| Category | Tournaments |
| Players | any |
| Teams | Any |
| Core mechanic | Fixed list of events, points accumulate |
| Win condition | Most points |
| Lose condition | losing a series / fewer league points |
| Scoring | Championship points |
| Required systems | championship grouping |
| Dependencies | Event Engine + tournament engine |
| Difficulty (player) | Medium |
| Development complexity | Medium |
| Potential exploits | match fixing (social), disconnect abuse |
| Status | V2 · championship object (season tags) |

