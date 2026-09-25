-- EVENT STUDIO — mode: ctf (capture the flag)
-- Flags live at team bases (arena.objectives with team = 1/2). Pickup/return/capture are computed from
-- server-side coordinates — no client intents are involved.

local U = ES.Util

local function flagPublic(f)
    return { team = f.team, x = f.pos.x, y = f.pos.y, z = f.pos.z, home = f.home, carrier = f.carrier and f.carrier.src or nil }
end

local function broadcastFlags(inst)
    local list = {}
    for i, f in ipairs(inst.data.flags) do list[i] = flagPublic(f) end
    inst:broadcast('mode', { flags = list })
end

local function returnHome(inst, f)
    f.carrier, f.home, f.droppedAt = nil, true, nil
    f.pos = U.deepCopy(f.base)
end

local function drop(inst, f, pos)
    f.carrier = nil
    f.home = false
    f.droppedAt = ES.now()
    f.pos = pos
    inst:announce('announce_flag_dropped', 'warn', inst.teams[f.team].name)
end

ES.RegisterMode('ctf', {
    label = 'Capture the Flag',
    category = 'objective',
    description = 'Steal the enemy flag and bring it to your base while your own flag is home.',
    teams = 'required',
    minPlayers = 2,
    rankBy = 'score',
    arena = { requires = { 'objectives', 'teamSpawns' } },
    objectiveKey = 'obj_ctf',
    rulesKey = 'rules_ctf',
    options = {
        capturesToWin = { type = 'integer', min = 1, max = 20, default = 3, label = 'Captures to win', order = 1 },
        pickupRadius = { type = 'number', min = 1, max = 10, default = 2.5, label = 'Pickup radius', order = 2 },
        captureRadius = { type = 'number', min = 2, max = 20, default = 5, label = 'Capture radius', order = 3 },
        dropReturnSeconds = { type = 'integer', min = 5, max = 120, default = 30, label = 'Dropped flag auto-return (s)', order = 4 },
        weapons = { type = 'list', item = { type = 'string', maxLen = 40 }, maxItems = 16, default = { 'WEAPON_PISTOL', 'WEAPON_SMG' }, label = 'Weapons', order = 5 },
        respawnDelay = { type = 'integer', min = 1, max = 30, default = 5, label = 'Respawn delay (s)', order = 6 },
    },

    validate = function(def)
        if def.players.teams and def.players.teams.count ~= 2 then return false, 'ctf requires exactly 2 teams' end
        local arena = ES.Arenas.get(def.arena)
        local bases = {}
        for _, o in ipairs(arena and arena.objectives or {}) do if o.team then bases[o.team] = true end end
        if not bases[1] or not bases[2] then return false, 'arena objectives need a flag base with team = 1 and team = 2' end
        return true
    end,

    setup = function(inst)
        local o = inst.def.options
        inst:use('spawns', {}):placeAll()
        inst:use('combat', { weapons = o.weapons, lives = 0, respawnDelay = o.respawnDelay })
        inst.data.flags = {}
        for _, obj in ipairs(inst.arena.objectives) do
            if obj.team == 1 or obj.team == 2 then
                local base = { x = obj.x, y = obj.y, z = obj.z }
                inst.data.flags[obj.team] = { team = obj.team, base = base, pos = U.deepCopy(base), home = true }
            end
        end
        broadcastFlags(inst)
    end,

    start = function(inst) broadcastFlags(inst) end,

    tick = function(inst)
        local o = inst.def.options
        local changed = false
        for _, f in ipairs(inst.data.flags) do
            if f.carrier then
                local c = f.carrier
                if c.status ~= 'active' or not c.src then
                    drop(inst, f, f.pos)
                    changed = true
                else
                    f.pos = U.vec(GetEntityCoords(GetPlayerPed(c.src)))
                    local ownFlag = inst.data.flags[c.team]
                    if ownFlag.home and U.dist(f.pos, ownFlag.base) <= o.captureRadius then
                        inst:addTeamScore(c.team, 1)
                        inst:addScore(c, 10, 'capture', true)
                        inst:addStat(c, 'objectives', 1)
                        inst:announce('announce_flag_captured', 'success', c.name, inst.teams[c.team].name)
                        returnHome(inst, f)
                        changed = true
                        if inst.teams[c.team].score >= o.capturesToWin then
                            broadcastFlags(inst)
                            return inst:finishNow('captures')
                        end
                    end
                end
            else
                if not f.home and f.droppedAt and ES.now() - f.droppedAt >= o.dropReturnSeconds * 1000 then
                    returnHome(inst, f)
                    inst:announce('announce_flag_returned', 'info', inst.teams[f.team].name)
                    changed = true
                else
                    for _, p in ipairs(inst:activeParticipants()) do
                        local pos = U.vec(GetEntityCoords(GetPlayerPed(p.src)))
                        if U.dist(pos, f.pos) <= o.pickupRadius then
                            if p.team ~= f.team then
                                f.carrier, f.home, f.droppedAt = p, false, nil
                                inst:announce('announce_flag_taken', 'warn', p.name, inst.teams[f.team].name)
                                changed = true
                                break
                            elseif not f.home then
                                returnHome(inst, f)
                                inst:addScore(p, 2, 'return', true)
                                inst:announce('announce_flag_returned', 'info', inst.teams[f.team].name)
                                changed = true
                                break
                            end
                        end
                    end
                end
            end
        end
        local carried = false
        for _, f in ipairs(inst.data.flags) do if f.carrier then carried = true end end
        if changed or carried then broadcastFlags(inst) end
    end,

    onDeath = function(inst, victim, killer)
        for _, f in ipairs(inst.data.flags or {}) do
            if f.carrier == victim then
                drop(inst, f, victim.src and U.vec(GetEntityCoords(GetPlayerPed(victim.src))) or f.pos)
                if killer and killer ~= victim then inst:addScore(killer, 3, 'carrier_kill', true) end
                broadcastFlags(inst)
            end
        end
        if killer and killer ~= victim then inst:addScore(killer, 1, 'kill', true) end
    end,

    onLeave = function(inst, p)
        for _, f in ipairs(inst.data.flags or {}) do
            if f.carrier == p then drop(inst, f, f.pos) broadcastFlags(inst) end
        end
    end,

    onRejoin = function(inst) broadcastFlags(inst) end,
    onLateJoin = function(inst) broadcastFlags(inst) end,

    hud = function(inst, p)
        local carrying = false
        for _, f in ipairs(inst.data.flags or {}) do if f.carrier == p then carrying = true end end
        return { carrying = carrying, target = inst.def.options.capturesToWin }
    end,

    rowExtra = function(_, p) return ('%d caps · %d K'):format(p.stats.objectives or 0, p.stats.kills) end,
})
