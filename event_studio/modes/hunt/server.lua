-- EVENT STUDIO — mode: hunt
-- Scavenger / checkpoint / hidden object / landmark / photo / treasure / clue hunts.
-- Discovery is fully server-side (proximity from server coordinates); hidden targets never reach clients.

local U = ES.Util

ES.RegisterMode('hunt', {
    label = 'Hunt / Scavenger',
    category = 'hunt',
    description = 'Find targets across the map. Visible or hidden (warmer/colder hints), ordered clue chains or free order.',
    teams = 'none',
    minPlayers = 1,
    rankBy = 'finish',
    finishLine = true,
    arena = { requires = { 'targets' } },
    objectiveKey = 'obj_hunt',
    rulesKey = 'rules_hunt',
    options = {
        ordered = { type = 'boolean', default = false, label = 'Ordered (clue chain)', order = 1 },
        hidden = { type = 'boolean', default = false, label = 'Hidden targets (hints only)', order = 2 },
        hints = { type = 'boolean', default = true, label = 'Warmer / colder hints', order = 3 },
        pointsPerFind = { type = 'integer', min = 0, max = 1000, default = 10, label = 'Points per find', order = 4 },
        radius = { type = 'number', min = 2, max = 100, default = 8, label = 'Discovery radius', order = 5 },
        vehicle = { type = 'object', optional = true, label = 'Give each player a vehicle', order = 6, fields = {
            model = { type = 'string', maxLen = 32, default = 'blista' }, type = { type = 'string', maxLen = 16, default = 'automobile' } } },
    },

    setup = function(inst)
        local o = inst.def.options
        inst:use('spawns', {}):placeAll()
        if o.vehicle then
            inst:use('vehicles', { vehicle = o.vehicle, lock = false, points = inst.arena.vehicleSpawns or inst.arena.spawns }):provisionAll()
        end
        inst:use('checkpoints', {
            points = inst.arena.targets, ordered = o.ordered, hidden = o.hidden, serverDetect = true, radius = o.radius,
            allowReset = false,
            onCheckpoint = function(p, index)
                local cp = inst:component('checkpoints')
                local pr = cp:personal(p)
                p.progress = pr.count
                inst:addScore(p, o.pointsPerFind, 'find')
                inst:addStat(p, 'objectives', 1)
                local t = cp.points[index]
                inst:push(p, 'announce', { text = L('hunt_found', t.label or ('#' .. index), pr.count, pr.total), kind = 'success' })
            end,
            onComplete = function(p)
                inst:markFinished(p)
                inst:announce('announce_hunt_complete', 'success', p.name, U.fmtDuration(p.finishMs))
            end,
        })
        inst.data.hintAt = 0
    end,

    tick = function(inst)
        local o = inst.def.options
        if not o.hints or ES.now() < inst.data.hintAt then return end
        inst.data.hintAt = ES.now() + 2000
        local cp = inst:component('checkpoints')
        for _, p in ipairs(inst:activeParticipants()) do
            local d = cp:nearestDistance(p)
            if d then
                local band = d < 50 and 'hot' or (d < 150 and 'warm' or (d < 400 and 'cool' or 'cold'))
                inst:push(p, 'mode', { hint = { band = band, distance = o.hidden and nil or math.floor(d / 10) * 10 } })
            end
        end
    end,

    hud = function(inst, p)
        local cp = inst:component('checkpoints')
        if not cp then return nil end
        local pr = cp:personal(p)
        local nextClue
        if cp.ordered and cp.points[pr.next] then nextClue = cp.points[pr.next].clue end
        return { found = pr.count, total = pr.total, clue = nextClue }
    end,

    rowExtra = function(inst, p)
        local cp = inst:component('checkpoints')
        if p.finishMs then return U.fmtDuration(p.finishMs) end
        if not cp then return nil end
        local pr = cp:personal(p)
        return ('%d/%d'):format(pr.count, pr.total)
    end,
})
