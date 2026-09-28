-- EVENT STUDIO — mode: redlight (Red Light, Green Light)
-- Walk on green, stand still on red, reach the finish. Movement is measured from server-side coordinates;
-- clients only draw the lights and play the shot. With shootOnMove, anyone who moves on red is shot from the tower
-- at the finish line, dies and is out.

local U = ES.Util

local function banner(inst, key, color, ms)
    inst:broadcast('mode', { banner = { text = L(key), lkey = key, color = color, untilMs = ms } })
end

local function schedule(inst)
    local o = inst.def.options
    local green = inst.data.light == 'green'
    local lo, hi = green and o.greenMin or o.redMin, green and o.greenMax or o.redMax
    local ms = math.floor((lo + math.random() * (hi - lo)) * 1000)
    inst.data.switchAt = ES.now() + ms
    banner(inst, green and 'redlight_green' or 'redlight_red', green and '#3dff8b' or '#ff3d5e', ms)
end

local function setLight(inst, light)
    inst.data.light = light
    inst.data.snapshot = nil
    inst.data.redAt = light == 'red' and ES.now() or nil
    inst:broadcast('mode', { redlight = { light = light } })   -- world lights on every client
    schedule(inst)
end

---Tower above the finish line: where the lights hang and the shots come from.
local function tower(inst)
    local f = inst.arena.finish
    return f and { x = f.x, y = f.y, z = f.z + 9.0 } or nil
end

---Mode data for the clients: track (start → finish) for the light poles, the tower, walk-only rule.
local function clientSetup(inst)
    local f = inst.arena.finish
    local s = inst.arena.spawns and inst.arena.spawns[1]
    return { light = inst.data.light, tower = tower(inst), walkOnly = inst.def.options.walkOnly == true,
             start = s and { x = s.x, y = s.y, z = s.z } or nil, finish = f and { x = f.x, y = f.y, z = f.z, radius = f.radius } or nil }
end

---Moved on red: shot from the tower (shootOnMove) or simply out.
local function caught(inst, p)
    if p.caught then return end
    p.caught = true
    inst:announce('announce_redlight_moved', 'error', p.name)
    if not inst.def.options.shootOnMove then return inst:eliminate(p, 'moved') end
    inst:broadcast('mode', { redlightShot = { src = p.src, from = tower(inst) } })
    SetTimeout(1500, function()   -- the shot lands first, then the player is out
        if p.status == 'active' then inst:eliminate(p, 'shot') end
    end)
end

ES.RegisterMode('redlight', {
    label = 'Red Light, Green Light',
    category = 'social',
    description = 'Walk on green, stand still on red. Movement during red eliminates (optionally: shot from the tower). Reach the finish line first.',
    teams = 'none',
    rankBy = 'finish',
    finishLine = true,
    arena = { requires = { 'spawns' } },
    objectiveKey = 'obj_redlight',
    rulesKey = 'rules_redlight',
    options = {
        greenMin = { type = 'number', min = 1, max = 30, default = 3, label = 'Green min (s)', order = 1 },
        greenMax = { type = 'number', min = 1, max = 30, default = 7, label = 'Green max (s)', order = 2 },
        redMin = { type = 'number', min = 1, max = 30, default = 2, label = 'Red min (s)', order = 3 },
        redMax = { type = 'number', min = 1, max = 30, default = 5, label = 'Red max (s)', order = 4 },
        tolerance = { type = 'number', min = 0.2, max = 5, default = 0.8, label = 'Allowed drift during red (m)', order = 5 },
        reactionMs = { type = 'integer', min = 200, max = 2000, default = 700, label = 'Reaction window (ms)', order = 6 },
        shootOnMove = { type = 'boolean', default = false, label = 'Moving on red: shot from the tower (dies)', order = 7 },
        walkOnly = { type = 'boolean', default = false, label = 'Walking only (no sprint, no jump)', order = 8 },
    },

    validate = function(def)
        local arena = ES.Arenas.get(def.arena)
        if not (arena and arena.finish) then return false, 'arena needs a finish line (finish)' end
        if def.options.greenMin > def.options.greenMax or def.options.redMin > def.options.redMax then return false, 'min must be <= max' end
        return true
    end,

    setup = function(inst)
        inst:use('spawns', {}):placeAll()
        inst.data.light = 'red'
        local f = inst.arena.finish
        inst:use('zones', { zones = { { id = 'finish', x = f.x, y = f.y, z = f.z, radius = f.radius, label = 'Finish' } }, color = '#ffffff' })
        inst:broadcast('mode', { redlight = clientSetup(inst) })
    end,

    start = function(inst)
        setLight(inst, 'green')
        local f = inst.arena.finish
        inst.data.startDist = {}
        for _, p in ipairs(inst:activeParticipants()) do
            inst.data.startDist[p] = math.max(1, U.dist2d(U.vec(GetEntityCoords(GetPlayerPed(p.src))), f))
        end
    end,

    -- a player who reconnects gets the lights again
    onRejoin = function(inst, p) inst:push(p, 'mode', { redlight = clientSetup(inst) }) end,

    tick = function(inst)
        local o = inst.def.options
        local now = ES.now()
        if inst.data.switchAt and now >= inst.data.switchAt then
            setLight(inst, inst.data.light == 'green' and 'red' or 'green')
        end
        local f = inst.arena.finish
        local measuring = inst.data.light == 'red' and inst.data.redAt and now - inst.data.redAt >= o.reactionMs
        if measuring and not inst.data.snapshot then
            inst.data.snapshot = {}
            for _, p in ipairs(inst:activeParticipants()) do
                inst.data.snapshot[p] = U.vec(GetEntityCoords(GetPlayerPed(p.src)))
            end
            return
        end
        for _, p in ipairs(inst:activeParticipants()) do
            local pos = U.vec(GetEntityCoords(GetPlayerPed(p.src)))
            if U.dist2d(pos, f) <= f.radius then
                inst:markFinished(p)
            elseif measuring and not p.caught then
                local ref = inst.data.snapshot[p]
                if not ref then
                    inst.data.snapshot[p] = pos
                elseif U.dist2d(pos, ref) > o.tolerance then   -- horizontal only: slopes and landing do not count
                    caught(inst, p)
                end
            end
            if inst.data.startDist and inst.data.startDist[p] and p.status == 'active' then
                p.progress = 1 - U.dist2d(pos, f) / inst.data.startDist[p]
            end
        end
    end,

    onTimeUp = function(inst) inst:finishNow('time') end,

    hud = function(inst)
        return { alive = #inst:activeParticipants() }
    end,
})
