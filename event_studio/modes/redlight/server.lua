-- EVENT STUDIO — mode: redlight (Red Light / Green Light, Freeze challenge)
-- Movement is measured from server-side coordinates; clients only display the light.

local U = ES.Util

local function schedule(inst)
    local o = inst.def.options
    local green = inst.data.light == 'green'
    local lo, hi = green and o.greenMin or o.redMin, green and o.greenMax or o.redMax
    local ms = math.floor((lo + math.random() * (hi - lo)) * 1000)
    inst.data.switchAt = ES.now() + ms
    inst:broadcast('mode', { banner = { text = L(green and 'redlight_green' or 'redlight_red'), lkey = green and 'redlight_green' or 'redlight_red',
                                        color = green and '#3dff8b' or '#ff3d5e', untilMs = ms } })
end

local function setLight(inst, light)
    inst.data.light = light
    inst.data.snapshot = nil
    inst.data.redAt = light == 'red' and ES.now() or nil
    schedule(inst)
end

ES.RegisterMode('redlight', {
    label = 'Red Light, Green Light',
    category = 'social',
    description = 'Move on green, freeze on red. Movement during red eliminates. Reach the finish line first.',
    teams = 'none',
    rankBy = 'custom',        -- red light: finishers first; freeze challenge: every survivor shares 1st place
    finishLine = true,
    arena = { requires = { 'spawns' } },
    objectiveKey = 'obj_redlight',
    rulesKey = 'rules_redlight',
    options = {
        freezeOnly = { type = 'boolean', default = false, label = 'Freeze challenge (always red, survive the timer)', order = 1 },
        greenMin = { type = 'number', min = 1, max = 30, default = 3, label = 'Green min (s)', order = 2 },
        greenMax = { type = 'number', min = 1, max = 30, default = 7, label = 'Green max (s)', order = 3 },
        redMin = { type = 'number', min = 1, max = 30, default = 2, label = 'Red min (s)', order = 4 },
        redMax = { type = 'number', min = 1, max = 30, default = 5, label = 'Red max (s)', order = 5 },
        tolerance = { type = 'number', min = 0.2, max = 5, default = 0.8, label = 'Allowed drift during red (m)', order = 6 },
        reactionMs = { type = 'integer', min = 200, max = 2000, default = 700, label = 'Reaction window (ms)', order = 7 },
        settleSeconds = { type = 'integer', min = 1, max = 15, default = 4, label = 'Freeze challenge: seconds to get still before it counts', order = 8 },
    },

    validate = function(def)
        local arena = ES.Arenas.get(def.arena)
        if not def.options.freezeOnly and not (arena and arena.finish) then return false, 'arena needs a finish line (finish)' end
        if def.options.greenMin > def.options.greenMax or def.options.redMin > def.options.redMax then return false, 'min must be <= max' end
        return true
    end,

    objectiveKeyOf = function(inst) return inst.def.options.freezeOnly and 'obj_freeze' or 'obj_redlight' end,

    setup = function(inst)
        inst:use('spawns', {}):placeAll()
        inst.data.light = 'red'
        -- the freeze challenge has no finish line (the arena's finish zone is ignored)
        if inst.arena.finish and not inst.def.options.freezeOnly then
            local f = inst.arena.finish
            inst:use('zones', { zones = { { id = 'finish', x = f.x, y = f.y, z = f.z, radius = f.radius, label = 'Finish' } }, color = '#ffffff' })
        end
    end,

    start = function(inst)
        if inst.def.options.freezeOnly then
            -- a few seconds to land and stand still after the release, then any movement counts
            local settle = (inst.def.options.settleSeconds or 4) * 1000
            inst.data.light = 'red'
            inst.data.redAt = ES.now() + settle
            inst.data.freezeAnnounced = false
            inst:broadcast('mode', { banner = { text = L('redlight_freeze_soon'), lkey = 'redlight_freeze_soon', color = '#3dd6ff', untilMs = settle } })
        else
            setLight(inst, 'green')
        end
        local f = not inst.def.options.freezeOnly and inst.arena.finish
        if f then
            inst.data.startDist = {}
            for _, p in ipairs(inst:activeParticipants()) do
                inst.data.startDist[p] = math.max(1, U.dist2d(U.vec(GetEntityCoords(GetPlayerPed(p.src))), f))
            end
        end
    end,

    tick = function(inst)
        local o = inst.def.options
        local now = ES.now()
        if not o.freezeOnly and inst.data.switchAt and now >= inst.data.switchAt then
            setLight(inst, inst.data.light == 'green' and 'red' or 'green')
        end
        local f = not o.freezeOnly and inst.arena.finish
        if o.freezeOnly and not inst.data.freezeAnnounced and inst.data.redAt and now >= inst.data.redAt then
            inst.data.freezeAnnounced = true
            inst:broadcast('mode', { banner = { text = L('redlight_freeze'), lkey = 'redlight_freeze', color = '#3dd6ff' } })
        end
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
            if f and U.dist2d(pos, f) <= f.radius then
                inst:markFinished(p)
            elseif measuring then
                local ref = inst.data.snapshot[p]
                if not ref then
                    inst.data.snapshot[p] = pos
                elseif U.dist2d(pos, ref) > o.tolerance then   -- horizontal only: landing or slopes do not count
                    inst:announce('announce_redlight_moved', 'error', p.name)
                    inst:eliminate(p, 'moved')
                end
            end
            if f and inst.data.startDist and inst.data.startDist[p] and p.status == 'active' then
                p.progress = 1 - U.dist2d(pos, f) / inst.data.startDist[p]
            end
        end
    end,

    onTimeUp = function(inst)
        if inst.def.options.freezeOnly then
            -- everyone still standing survived the challenge
            for _, p in ipairs(inst:activeParticipants()) do
                p.status = 'finished'
                p.finishMs = inst:elapsedMs()
            end
        end
        inst:finishNow('time')
    end,

    rank = function(inst, list)
        if not inst.def.options.freezeOnly then return ES.Scoring.rankParticipants(list, 'finish') end
        return ES.Scoring.rank(list, function(p)
            if p.status == 'active' or p.status == 'finished' then return { 1, 0 } end            -- survivors share 1st
            if p.status == 'eliminated' then return { 2, -(p.eliminatedAt or 0) } end        -- lasted longer = better
            return { 3, 0 }
        end)
    end,

    hud = function(inst)
        return { alive = #inst:activeParticipants() }
    end,
})
