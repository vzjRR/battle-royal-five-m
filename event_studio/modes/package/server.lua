-- EVENT STUDIO — mode: package (Deliver the Package / Hold the Objective / Resource Collection)
-- deliver: packages appear at the arena's targets; carry one to the drop zone (arena.finish) to score.
-- hold:    one package at the arena center; the carrier scores every second until they die.
-- Pickups, drops and deliveries are computed from server-side coordinates only.

local U = ES.Util

local function publicPackages(inst)
    local out = {}
    for i, pk in ipairs(inst.data.packages) do
        out[i] = { x = pk.pos.x, y = pk.pos.y, z = pk.pos.z, carrier = pk.carrier and pk.carrier.src or nil }
    end
    return out
end

local function broadcast(inst) inst:broadcast('mode', { packages = publicPackages(inst) }) end

local function sources(inst)
    return (inst.arena.targets and #inst.arena.targets > 0) and inst.arena.targets or { inst.arena.center }
end

local function spawnPackage(inst, pk)
    local src = inst.def.options.style == 'hold' and inst.arena.center or U.pick(sources(inst))
    pk.pos = { x = src.x, y = src.y, z = src.z }
    pk.carrier, pk.droppedAt = nil, nil
end

local function carrying(inst, p)
    for _, pk in ipairs(inst.data.packages) do if pk.carrier == p then return pk end end
end

local function drop(inst, pk, pos)
    pk.carrier = nil
    pk.pos = pos or pk.pos
    pk.droppedAt = ES.now()
end

ES.RegisterMode('package', {
    label = 'Package (Deliver / Hold)',
    category = 'objective',
    description = 'Deliver packages to the drop zone, or hold the single package as long as you can.',
    teams = 'optional',
    rankBy = 'score',
    arena = { requires = { 'spawns' } },
    objectiveKey = 'obj_package',
    rulesKey = 'rules_package',
    options = {
        style = { type = 'enum', values = { 'deliver', 'hold' }, default = 'deliver', label = 'Style', order = 1 },
        packages = { type = 'integer', min = 1, max = 10, default = 3, label = 'Packages at once (deliver)', order = 2 },
        pickupRadius = { type = 'number', min = 1, max = 10, default = 2.5, label = 'Pickup radius', order = 3 },
        pointsPerDelivery = { type = 'integer', min = 1, max = 100, default = 10, label = 'Points per delivery', order = 4 },
        pointsPerSecond = { type = 'integer', min = 1, max = 20, default = 1, label = 'Points per second held (hold)', order = 5 },
        resetSeconds = { type = 'integer', min = 5, max = 120, default = 20, label = 'Dropped package resets after (s)', order = 6 },
        scoreTarget = { type = 'integer', min = 0, max = 10000, default = 100, label = 'Score target (0 = none)', order = 7 },
        weapons = { type = 'list', item = { type = 'string', maxLen = 40 }, maxItems = 8, default = { 'WEAPON_PISTOL', 'WEAPON_BAT' }, label = 'Weapons', order = 8 },
        respawnDelay = { type = 'integer', min = 1, max = 30, default = 4, label = 'Respawn delay (s)', order = 9 },
    },

    validate = function(def)
        local arena = ES.Arenas.get(def.arena)
        if def.options.style == 'deliver' and not (arena and arena.finish) then return false, 'deliver style needs a drop zone (arena finish)' end
        return true
    end,

    setup = function(inst)
        local o = inst.def.options
        inst:use('spawns', { strategy = 'random' }):placeAll()
        inst:use('combat', { weapons = o.weapons, lives = 0, respawnDelay = o.respawnDelay })
        if inst.arena.finish then
            local f = inst.arena.finish
            inst:use('zones', { zones = { { id = 'drop', x = f.x, y = f.y, z = f.z, radius = f.radius, label = 'Drop zone' } }, color = '#3ddc84' })
        end
        inst.data.packages = {}
        local n = o.style == 'hold' and 1 or o.packages
        for i = 1, n do
            inst.data.packages[i] = {}
            spawnPackage(inst, inst.data.packages[i])
        end
        inst.data.acc = 0
        broadcast(inst)
    end,

    start = function(inst) broadcast(inst) end,

    tick = function(inst, dt)
        local o = inst.def.options
        local changed, carried = false, false
        inst.data.acc = inst.data.acc + dt
        local second = inst.data.acc >= 1000
        if second then inst.data.acc = inst.data.acc - 1000 end
        for _, pk in ipairs(inst.data.packages) do
            local c = pk.carrier
            if c then
                carried = true
                if c.status ~= 'active' or not c.src then
                    drop(inst, pk)
                    changed = true
                else
                    pk.pos = U.vec(GetEntityCoords(GetPlayerPed(c.src)))
                    if o.style == 'hold' then
                        if second then
                            inst:addScore(c, o.pointsPerSecond, 'hold')
                            inst:addStat(c, 'objectives', 1)
                        end
                    else
                        local f = inst.arena.finish
                        if U.dist(pk.pos, f) <= f.radius then
                            inst:addScore(c, o.pointsPerDelivery, 'delivery')
                            inst:addStat(c, 'objectives', 1)
                            inst:announce('announce_package_delivered', 'success', c.name)
                            spawnPackage(inst, pk)
                            changed = true
                        end
                    end
                end
            else
                if pk.droppedAt and ES.now() - pk.droppedAt >= o.resetSeconds * 1000 then
                    spawnPackage(inst, pk)
                    changed = true
                else
                    for _, p in ipairs(inst:activeParticipants()) do
                        if not carrying(inst, p) and U.dist(U.vec(GetEntityCoords(GetPlayerPed(p.src))), pk.pos) <= o.pickupRadius then
                            pk.carrier, pk.droppedAt = p, nil
                            inst:push(p, 'announce', { text = L('package_picked'), kind = 'info' })
                            changed = true
                            break
                        end
                    end
                end
            end
        end
        if changed or carried then broadcast(inst) end
        if o.scoreTarget > 0 then
            for _, t in ipairs(inst.teams) do if t.score >= o.scoreTarget then return inst:finishNow('score_target') end end
            for _, p in ipairs(inst:activeParticipants()) do
                if #inst.teams == 0 and p.score >= o.scoreTarget then return inst:finishNow('score_target') end
            end
        end
    end,

    onDeath = function(inst, victim, killer)
        local pk = carrying(inst, victim)
        if pk then
            drop(inst, pk, victim.src and U.vec(GetEntityCoords(GetPlayerPed(victim.src))) or nil)
            if killer and killer ~= victim then inst:addScore(killer, 2, 'carrier_kill', true) end
            broadcast(inst)
        end
    end,

    onLeave = function(inst, p)
        local pk = carrying(inst, p)
        if pk then drop(inst, pk) broadcast(inst) end
    end,

    onRejoin = function(inst) broadcast(inst) end,
    onLateJoin = function(inst) broadcast(inst) end,

    hud = function(inst, p)
        return { score = p.score, target = inst.def.options.scoreTarget > 0 and inst.def.options.scoreTarget or nil,
                 holding = carrying(inst, p) and L('package_label') or nil }
    end,
})
