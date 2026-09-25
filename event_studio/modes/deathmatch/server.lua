-- EVENT STUDIO — mode: deathmatch
-- FFA, TDM, Last Man/Team Standing, duels, weapon-restricted & rotating/random weapon variants, rounds.

local U = ES.Util

local function sideKey(p) return p.team or p.src end

local function roundsEnabled(inst) return (inst.def.options.rounds or 1) > 1 end

local function startRound(inst)
    local combat = inst:component('combat')
    local spawns = inst:component('spawns')
    inst.data.round = (inst.data.round or 0) + 1
    inst.data.betweenRounds = false
    for _, p in ipairs(inst:allParticipants()) do
        if p.src and (p.status == 'active' or p.status == 'eliminated') then
            p.status = 'active'
            p.eliminatedAt = nil
            p.lives = inst.def.options.lives > 0 and inst.def.options.lives or nil
            combat.alive[p] = true
            spawns:respawn(p)
            combat:giveLoadout(p)
        end
    end
    inst:announce('announce_round', 'info', inst.data.round, inst.def.options.rounds)
    inst:syncState()
    inst:dirty()
end

local function roundWinner(inst)
    local active = inst:activeParticipants()
    local key = active[1] and sideKey(active[1]) or nil
    local rounds = inst.def.options.rounds
    inst.data.wins = inst.data.wins or {}
    if key then
        inst.data.wins[key] = (inst.data.wins[key] or 0) + 1
        if #inst.teams > 0 then
            inst:addTeamScore(key, 1)
            inst:announce('announce_round_won', 'success', inst.teams[key].name)
        else
            inst:addScore(active[1], 1, 'round')
            inst:announce('announce_round_won', 'success', active[1].name)
        end
    end
    local need = rounds // 2 + 1
    if (key and inst.data.wins[key] >= need) or inst.data.round >= rounds then
        inst:finishNow('rounds')
        return
    end
    SetTimeout(4000, function()
        if inst.state == ES.Lifecycle.States.ACTIVE then startRound(inst) end
    end)
    inst.data.betweenRounds = true
end

ES.RegisterMode('deathmatch', {
    label = 'Deathmatch',
    category = 'combat',
    description = 'Free-for-all or team combat with configurable weapons, lives, kill target and rounds.',
    teams = 'optional',
    rankBy = 'score',
    arena = { requires = { 'spawns' } },
    objectiveKey = 'obj_deathmatch',
    rulesKey = 'rules_deathmatch',
    options = {
        weapons = { type = 'list', item = { type = 'string', maxLen = 40 }, maxItems = 16,
                    default = { 'WEAPON_PISTOL', 'WEAPON_SMG', 'WEAPON_CARBINERIFLE' }, label = 'Weapons', order = 1 },
        ammo = { type = 'integer', min = 1, max = 9999, default = 250, label = 'Ammo per weapon', order = 2 },
        randomWeapons = { type = 'boolean', default = false, label = 'One random weapon per life', order = 3 },
        rotateEvery = { type = 'integer', min = 0, max = 600, default = 0, label = 'Rotate weapon every N seconds (0 = off)', order = 4 },
        killTarget = { type = 'integer', min = 0, max = 500, default = 30, label = 'Kill target (0 = none)', order = 5 },
        lives = { type = 'integer', min = 0, max = 20, default = 0, label = 'Lives (0 = unlimited)', order = 6 },
        respawnDelay = { type = 'integer', min = 1, max = 30, default = 3, label = 'Respawn delay (s)', order = 7 },
        rounds = { type = 'integer', min = 1, max = 15, default = 1, label = 'Rounds (lives > 0)', order = 8 },
    },

    validate = function(def)
        if def.options.rounds > 1 and def.options.lives == 0 then return false, 'rounds require lives > 0' end
        return true
    end,

    setup = function(inst)
        local o = inst.def.options
        local spawns = inst:use('spawns', { strategy = #inst.teams > 0 and 'sequential' or 'farthest' })
        spawns:placeAll()
        inst:use('combat', {
            weapons = o.weapons, ammo = o.ammo, random = o.randomWeapons, lives = o.lives, respawnDelay = o.respawnDelay,
        })
        inst.data.round = 1
        inst.data.rotation = 1
    end,

    start = function(inst)
        local o = inst.def.options
        if o.rotateEvery > 0 and #o.weapons > 0 then
            inst.data.nextRotate = ES.now() + o.rotateEvery * 1000
            local combat = inst:component('combat')
            combat.cfg.weapons = { o.weapons[1] }
            combat:giveAll({ o.weapons[1] })
        end
        if roundsEnabled(inst) then inst:announce('announce_round', 'info', 1, o.rounds) end
    end,

    tick = function(inst)
        local o = inst.def.options
        if inst.data.nextRotate and ES.now() >= inst.data.nextRotate then
            inst.data.nextRotate = ES.now() + o.rotateEvery * 1000
            inst.data.rotation = inst.data.rotation % #o.weapons + 1
            local w = o.weapons[inst.data.rotation]
            local combat = inst:component('combat')
            combat.cfg.weapons = { w } -- late joiners / respawns get the current weapon (whitelist unchanged)
            combat:giveAll({ w })
            inst:announce('announce_weapon_rotate', 'info', w:gsub('WEAPON_', ''))
        end
    end,

    onDeath = function(inst, victim, killer)
        if killer and killer ~= victim and not roundsEnabled(inst) then
            inst:addScore(killer, 1, 'kill')
            local target = inst.def.options.killTarget
            if target > 0 then
                local reached = (#inst.teams > 0 and killer.team and inst.teams[killer.team].score >= target) or killer.score >= target
                if reached then inst:finishNow('kill_target') end
            end
        elseif killer and killer ~= victim then
            killer.scoreAt = inst:elapsedMs()
        end
    end,

    viability = function(inst)
        local o = inst.def.options
        local active = inst:activeParticipants()
        if #active == 0 then return false end
        local sides = {}
        for _, p in ipairs(active) do sides[sideKey(p)] = true end
        local n = U.count(sides)
        if o.lives == 0 then
            return n > 1 or (inst.startCount or 0) <= 1
        end
        if n <= 1 and (inst.startCount or 0) > 1 then
            if roundsEnabled(inst) then
                if not inst.data.betweenRounds then roundWinner(inst) end
                return true
            end
            return false
        end
        inst.data.betweenRounds = false
        return true
    end,

    onRespawn = function(inst, p) end,

    hud = function(inst, p)
        local o = inst.def.options
        return { kills = p.stats.kills, deaths = p.stats.deaths, target = o.killTarget > 0 and o.killTarget or nil,
                 round = roundsEnabled(inst) and inst.data.round or nil, rounds = roundsEnabled(inst) and o.rounds or nil,
                 lives = p.lives }
    end,

    rowExtra = function(_, p) return ('%d / %d'):format(p.stats.kills, p.stats.deaths) end,
})
