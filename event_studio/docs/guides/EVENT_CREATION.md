# Creating events

There are three levels, from easiest to most powerful:

1. **Builder (in game):** no files needed; the event is stored in the database.
2. **Preset file:** a definition in `config/events/*.lua`.
3. **New mode (Lua):** new gameplay rules in `modes/<id>/server.lua`.

## 1. Preset (definition)

```lua
ES.Definition({
    id = 'pier_pistol_duel',            -- unique, [a-z0-9_-]
    name = 'Pier Pistol Duel',
    mode = 'deathmatch',                -- race | deathmatch | gungame | sumo | koth | ctf | zone_survival | hunt | redlight | trivia | reaction | custom | juggernaut | vip | hunters | keep_moving | musical_chairs | bounty | package | vehicle_tag
    arena = 'docks_yard',               -- arena id (not needed for trivia/reaction/custom)
    description = '1v1, first to three rounds.',
    category = 'combat',                -- optional (defaults to the mode's category)
    visibility = 'public',              -- public | hidden | staff
    difficulty = 'hard',
    players = { min = 2, max = 2, spectators = true, reconnectGrace = 60,
                teams = nil },          -- { count = 2, auto = true } for team events
    timing = { registration = 120, lobby = 5, countdown = 5, duration = 600, grace = 30, results = 15 },
    gameplay = { health = 200, armor = 0, friendlyFire = false, restoreWeapons = true },
    options = { lives = 1, rounds = 5, killTarget = 0, weapons = { 'WEAPON_PISTOL' } },   -- mode options
    scoring = 'competitive',            -- profile name or inline table
    rewards = {
        placement = { [1] = { { type = 'cash', amount = 5000 } }, [2] = { { type = 'item', name = 'medal', count = 1 } } },
        participation = { { type = 'xp', amount = 50 } },
        winnerTeam = nil,               -- team events: each member of the winning team
    },
})
```

Anything you leave out comes from `Config.General.definitionDefaults`. Definitions are checked when they load, and errors show in the console (for example `options.laps: must be <= 50`).

### Mode options at a glance

| Mode | Key options |
|---|---|
| race | laps, onFoot, vehicle {model,type}, pool, random, ghost, reverse, use3d, checkpointRadius, eliminateEvery, allowReset |
| deathmatch | weapons, ammo, randomWeapons, rotateEvery, killTarget, lives, respawnDelay, rounds |
| gungame | ladder, killsPerLevel, respawnDelay, meleeDemotes |
| sumo | vehicle, pool, random, eliminateOnWreck, scoreKnockouts, graceMs, suddenDeathAfter, suddenDeathRatio |
| koth | style (hill/domination/attack — attack needs 2 teams, team 1 captures the zones in order), pointsPerSecond, captureSeconds, scoreTarget, rotateEvery, requireVehicle, vehicle, weapons |
| ctf | capturesToWin, pickupRadius, captureRadius, dropReturnSeconds, weapons |
| zone_survival | phases, moving, eliminateOutsideSeconds, damagePerSecond, weapons, ammo, requireVehicle |
| hunt | ordered, hidden, hints, pointsPerFind, radius, vehicle |
| redlight | freezeOnly, greenMin/Max, redMin/Max, tolerance, reactionMs |
| trivia | questionSet (`memory` = sequence questions), questions, count, secondsPerQuestion, pointsCorrect, speedBonus, shuffle |
| reaction | rounds, minDelay, maxDelay, earlyPenalty, points, windowMs |
| custom | teleport, weapons, vehicle, instructions |
| juggernaut | juggernautHealth, juggernautArmor, juggernautWeapons, attackerWeapons, passOnKill, pointsPerSecond, juggernautKillPoints, takedownPoints, scoreTarget, respawnDelay |
| vip | rounds, swapSides, roundSeconds, vipHealth, vipWeapons, weapons, respawnDelay (arena needs `teamSpawns` + `finish`) |
| hunters | hunterRatio, infect, hunterWeapons, runnerWeapons, runnerPointsPerSecond, catchPoints, surviveBonus, hunterReleaseSeconds |
| keep_moving | vehicle, minKmh, increaseKmh, increaseEvery, graceSeconds, startGrace, eliminateOnWreck (arena needs `vehicleSpawns`) |
| musical_chairs | musicMin, musicMax, seatSeconds, chairRadius, spread |
| bounty | style (bounty/assassin), weapons, bountyBase, bountyGrowth, targetPoints, wrongKillPenalty, scoreTarget, respawnDelay |
| package | style (deliver/hold), packages, pickupRadius, pointsPerDelivery, pointsPerSecond, resetSeconds, scoreTarget, weapons, respawnDelay (deliver needs arena `finish`; packages spawn at `targets`) |
| vehicle_tag | vehicle, tagDistance, noTagBackSeconds (arena needs `vehicleSpawns`) |

## 2. Arena

```lua
ES.Arena({
    id = 'my_arena', name = 'My Arena', center = { x, y, z }, radius = 120,
    spawns = { { x, y, z, heading }, ... },
    teamSpawns = { { ...team 1 points }, { ...team 2 points } },
    vehicleSpawns = { ... },
    checkpoints = { { x, y, z, radius = 12 }, ... },         -- races: last point = finish
    zones = { { x, y, z, radius = 15, id = 'A', label = 'Alpha' } },
    objectives = { { x, y, z, team = 1 }, { x, y, z, team = 2 } },   -- ctf flag bases
    targets = { { x, y, z, radius = 10, label = 'Pier', clue = '…' } }, -- hunts
    bounds = { radius = 60, minZ = 10.0 },                  -- sumo/derby/elimination
    finish = { x, y, z, radius = 10 },                      -- red light
})
```

What each mode needs: race → `checkpoints`; deathmatch/gungame/zone_survival/redlight → `spawns`; sumo → `bounds`; koth → `zones`; ctf → `objectives` and `teamSpawns`; hunt → `targets`; package → `spawns` + `finish` (+ `targets`); vehicle_tag/keep_moving → `vehicleSpawns`; vip → `teamSpawns` + `finish`.

## 3. A new mode

```lua
-- modes/tag/server.lua
ES.RegisterMode('tag', {
    label = 'Tag', category = 'social', teams = 'none', rankBy = 'score',
    arena = { requires = { 'spawns' } },
    options = { tagRadius = { type = 'number', default = 3, min = 1, max = 10, label = 'Tag radius' } },
    setup = function(inst)
        inst:use('spawns', {}):placeAll()
        local list = inst:activeParticipants()
        inst.data.it = list[math.random(#list)]
    end,
    tick = function(inst, dt)
        local it = inst.data.it
        for _, p in ipairs(inst:activeParticipants()) do
            if p ~= it then inst:addScore(p, dt / 1000, 'not_it') end
        end
        -- …check the distance between `it` and the others using GetEntityCoords(GetPlayerPed(src))
    end,
})
```

Use the components before writing new client code: `spawns`, `vehicles`, `combat`, `bounds`, `zones`, `checkpoints`. The full hook list is in `docs/EVENT_ENGINE.md`. Add locale keys, a preset and a test (`tests/test_sim_modes.lua` shows how).
