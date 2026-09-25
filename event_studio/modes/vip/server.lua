-- EVENT STUDIO — mode: vip (Protect the VIP)
-- Team 1 escorts a VIP to the extraction point; team 2 must kill the VIP. Sides swap each round.
-- Extraction is detected from server-side coordinates.

local U = ES.Util

local function defenders(inst) return inst.data.defenders end
local function attackers(inst) return inst.data.defenders == 1 and 2 or 1 end

local function startRound(inst)
    local o = inst.def.options
    local roles = inst:component('roles')
    local combat = inst:component('combat')
    local spawns = inst:component('spawns')
    inst.data.round = (inst.data.round or 0) + 1
    inst.data.roundOver = false
    for _, p in ipairs(inst:allParticipants()) do
        if p.src and (p.status == 'active' or p.status == 'eliminated') then
            p.status = 'active'
            p.eliminatedAt = nil
            combat.alive[p] = true
            roles:set(p, p.team == defenders(inst) and 'bodyguard' or 'attacker', true)
        end
    end
    local vip = roles:pick('vip', 1, function(p) return p.team == defenders(inst) end)[1]
    inst.data.vip = vip
    for _, p in ipairs(inst:activeParticipants()) do spawns:respawn(p) end
    inst:announce('announce_vip_round', 'info', inst.data.round, o.rounds, vip and vip.name or '?', inst.teams[defenders(inst)].name)
    inst:syncState()
end

local function endRound(inst, winnerTeam, reason)
    if inst.data.roundOver then return end
    inst.data.roundOver = true
    local o = inst.def.options
    inst:addTeamScore(winnerTeam, 1)
    inst:announce(reason == 'extracted' and 'announce_vip_extracted' or 'announce_vip_killed', 'success', inst.teams[winnerTeam].name)
    local need = o.rounds // 2 + 1
    if inst.teams[winnerTeam].score >= need or inst.data.round >= o.rounds then
        return inst:finishNow('rounds')
    end
    SetTimeout(4000, function()
        if inst.state ~= ES.Lifecycle.States.ACTIVE then return end
        if o.swapSides then inst.data.defenders = attackers(inst) end
        startRound(inst)
    end)
end

ES.RegisterMode('vip', {
    label = 'Protect the VIP',
    category = 'combat',
    description = 'Bodyguards escort a VIP to extraction while attackers try to take the VIP out. Sides swap every round.',
    teams = 'required',
    minPlayers = 2,
    rankBy = 'score',
    endWhenOneTeamLeft = true,
    arena = { requires = { 'teamSpawns', 'finish' } },
    objectiveKey = 'obj_vip',
    rulesKey = 'rules_vip',
    options = {
        rounds = { type = 'integer', min = 1, max = 9, default = 3, label = 'Rounds (best of)', order = 1 },
        swapSides = { type = 'boolean', default = true, label = 'Swap sides each round', order = 2 },
        roundSeconds = { type = 'integer', min = 30, max = 900, default = 180, label = 'Round time limit (s) — attackers win on timeout', order = 3 },
        vipHealth = { type = 'integer', min = 100, max = 1000, default = 300, label = 'VIP health', order = 4 },
        vipWeapons = { type = 'list', item = { type = 'string', maxLen = 40 }, maxItems = 4, default = { 'WEAPON_PISTOL' }, label = 'VIP weapons', order = 5 },
        weapons = { type = 'list', item = { type = 'string', maxLen = 40 }, maxItems = 8, default = { 'WEAPON_SMG', 'WEAPON_CARBINERIFLE', 'WEAPON_PISTOL' }, label = 'Team weapons', order = 6 },
        respawnDelay = { type = 'integer', min = 1, max = 30, default = 5, label = 'Respawn delay (s) — VIP never respawns', order = 7 },
    },

    validate = function(def)
        if def.players.teams and def.players.teams.count ~= 2 then return false, 'vip requires exactly 2 teams' end
        return true
    end,

    setup = function(inst)
        local o = inst.def.options
        inst:use('spawns', {}):placeAll()
        local all = {}
        for _, w in ipairs(o.weapons) do all[#all + 1] = w end
        for _, w in ipairs(o.vipWeapons) do all[#all + 1] = w end
        inst:use('combat', { weapons = all, lives = 0, respawnDelay = o.respawnDelay })
        inst:use('roles', {
            default = 'attacker',
            roles = {
                vip = { label = 'VIP', health = o.vipHealth, armor = 50, weapons = o.vipWeapons, color = '#ffd23d' },
                bodyguard = { label = 'Bodyguard', weapons = o.weapons, color = '#3d8bff' },
                attacker = { label = 'Attacker', weapons = o.weapons, color = '#ff4d5e' },
            },
        })
        local f = inst.arena.finish
        inst:use('zones', { zones = { { id = 'extract', x = f.x, y = f.y, z = f.z, radius = f.radius, label = 'Extraction' } }, color = '#ffd23d' })
        inst.data.defenders = 1
    end,

    start = function(inst)
        startRound(inst)
        inst.data.roundStart = ES.now()
    end,

    tick = function(inst)
        local o = inst.def.options
        if inst.data.roundOver then inst.data.roundStart = ES.now() return end
        local vip = inst.data.vip
        if not vip or vip.status ~= 'active' or not vip.src then
            return endRound(inst, attackers(inst), 'killed')
        end
        local pos = U.vec(GetEntityCoords(GetPlayerPed(vip.src)))
        local f = inst.arena.finish
        if U.dist(pos, f) <= f.radius then
            inst:addScore(vip, 10, 'extracted', true)
            inst:addStat(vip, 'objectives', 1)
            return endRound(inst, defenders(inst), 'extracted')
        end
        if ES.now() - inst.data.roundStart >= o.roundSeconds * 1000 then
            return endRound(inst, attackers(inst), 'timeout')
        end
    end,

    onDeath = function(inst, victim, killer)
        if killer and killer ~= victim then inst:addScore(killer, 1, 'kill', true) end
        if victim == inst.data.vip then
            if killer and killer ~= victim then inst:addScore(killer, 5, 'vip_kill', true) end
            -- eliminated → the combat component does not respawn the VIP this round
            inst:eliminate(victim, 'vip_down')
            endRound(inst, attackers(inst), 'killed')
        end
    end,

    viability = function(inst)
        local teamsAlive = {}
        for _, p in ipairs(inst:activeParticipants()) do teamsAlive[p.team] = true end
        if ES.Util.count(teamsAlive) <= 1 and not inst.data.roundOver then return false end
        return true
    end,

    hud = function(inst, p)
        local roles = inst:component('roles')
        return { round = inst.data.round, rounds = inst.def.options.rounds, role = roles and roles:roleOf(p) or nil,
                 target = inst.data.vip and inst.data.vip.name or nil }
    end,
})
