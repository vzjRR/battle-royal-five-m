-- EVENT STUDIO — mode: keep_moving (Hot Vehicle / Keep Moving)
-- Every driver must stay above a minimum speed. Slow down for too long and you're out.
-- Speed is measured on the server from the vehicle's velocity; the minimum speed rises over time.

local U = ES.Util

local function speedOf(veh)
    local v = GetEntityVelocity(veh)
    if not v then return 0 end
    local x, y, z = v.x or v[1] or 0, v.y or v[2] or 0, v.z or v[3] or 0
    return math.sqrt(x * x + y * y + z * z)
end

ES.RegisterMode('keep_moving', {
    label = 'Keep Moving',
    category = 'vehicle',
    description = 'Stay above the minimum speed or get eliminated. The limit rises over time. Last driver moving wins.',
    teams = 'none',
    rankBy = 'score',
    lastStanding = true,
    arena = { requires = { 'vehicleSpawns' } },
    objectiveKey = 'obj_keep_moving',
    rulesKey = 'rules_keep_moving',
    options = {
        vehicle = { type = 'object', label = 'Vehicle', order = 1, fields = {
            model = { type = 'string', maxLen = 32, default = 'elegy2' }, type = { type = 'string', maxLen = 16, default = 'automobile' } } },
        minKmh = { type = 'integer', min = 5, max = 250, default = 40, label = 'Starting minimum speed (km/h)', order = 2 },
        increaseKmh = { type = 'integer', min = 0, max = 100, default = 10, label = 'Increase per step (km/h)', order = 3 },
        increaseEvery = { type = 'integer', min = 10, max = 600, default = 45, label = 'Increase every N seconds', order = 4 },
        graceSeconds = { type = 'number', min = 0.5, max = 15, default = 3, label = 'Seconds allowed below the limit', order = 5 },
        startGrace = { type = 'integer', min = 0, max = 60, default = 8, label = 'Seconds to get up to speed at start', order = 6 },
        eliminateOnWreck = { type = 'boolean', default = true, label = 'Eliminate wrecked vehicles', order = 7 },
    },

    setup = function(inst)
        local o = inst.def.options
        inst:use('spawns', { points = inst.arena.vehicleSpawns })
        inst:use('vehicles', { vehicle = o.vehicle, points = inst.arena.vehicleSpawns, lock = true,
            eliminateOnWreck = o.eliminateOnWreck, outOfVehicleAction = 'eliminate', outOfVehicleSeconds = 4 }):provisionAll()
        if inst.arena.bounds then inst:use('bounds', { graceMs = 4000 }) end
        inst.data.slow = {}
        inst.data.acc = 0
    end,

    start = function(inst)
        local o = inst.def.options
        inst.data.limit = o.minKmh
        inst.data.checkFrom = ES.now() + o.startGrace * 1000
        inst.data.nextIncrease = ES.now() + o.increaseEvery * 1000
        inst:broadcast('mode', { banner = { text = L('keep_moving_limit', inst.data.limit), color = '#ffb020', untilMs = 3000 } })
    end,

    tick = function(inst, dt)
        local o = inst.def.options
        local now = ES.now()
        if now >= inst.data.nextIncrease and o.increaseKmh > 0 then
            inst.data.nextIncrease = now + o.increaseEvery * 1000
            inst.data.limit = inst.data.limit + o.increaseKmh
            inst:broadcast('mode', { banner = { text = L('keep_moving_limit', inst.data.limit), color = '#ffb020', untilMs = 3000 } })
        end
        inst.data.acc = inst.data.acc + dt
        local secondTick = inst.data.acc >= 1000
        if secondTick then inst.data.acc = inst.data.acc - 1000 end
        if now < inst.data.checkFrom then return end
        local veh = inst:component('vehicles')
        local limitMs = inst.data.limit / 3.6
        for _, p in ipairs(inst:activeParticipants()) do
            local e = veh:entityOf(p)
            local speed = e and speedOf(e) or 0
            if speed < limitMs then
                if not inst.data.slow[p] then
                    inst.data.slow[p] = now
                    inst:push(p, 'mode', { banner = { text = L('keep_moving_warning'), color = '#ff3d5e', untilMs = math.floor(o.graceSeconds * 1000) } })
                elseif now - inst.data.slow[p] >= o.graceSeconds * 1000 then
                    inst.data.slow[p] = nil
                    inst:announce('announce_keep_moving_out', 'error', p.name)
                    inst:eliminate(p, 'too_slow')
                end
            else
                inst.data.slow[p] = nil
                if secondTick then inst:addScore(p, 1, 'moving') end
            end
        end
    end,

    hud = function(inst, p)
        return { target = inst.data.limit and (inst.data.limit .. ' km/h') or nil, alive = #inst:activeParticipants(), score = p.score }
    end,
})
