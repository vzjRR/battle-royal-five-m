-- EVENT STUDIO — mode: race
-- Circuit, sprint, time trial, drag, elimination race, boat/air/bike races, parkour & obstacle courses (onFoot).

local U = ES.Util

local vehicleSpec = { type = 'object', optional = true, fields = {
    model = { type = 'string', maxLen = 32, default = 'sultan' },
    type = { type = 'enum', values = { 'automobile', 'bike', 'boat', 'heli', 'plane', 'submarine' }, default = 'automobile' },
} }

ES.RegisterMode('race', {
    label = 'Race',
    category = 'racing',
    description = 'Ordered checkpoints with laps, vehicles or on foot. Covers circuits, sprints, time trials, elimination races and parkour.',
    teams = 'none',
    minPlayers = 1,
    rankBy = 'finish',
    graceOnFinish = true,
    finishLine = true,        -- finish grace after the podium (Config.General.flow)
    personalBests = true,
    arena = { requires = { 'checkpoints' } },
    objectiveKey = 'obj_race',
    rulesKey = 'rules_race',
    options = {
        laps = { type = 'integer', min = 1, max = 50, default = 1, label = 'Laps', order = 1 },
        onFoot = { type = 'boolean', default = false, label = 'On foot (parkour / obstacle)', order = 2 },
        vehicle = U.merge(vehicleSpec, { label = 'Vehicle', order = 3 }),
        pool = { type = 'list', item = 'table', maxItems = 32, optional = true, label = 'Vehicle pool (overrides vehicle)', order = 4 },
        random = { type = 'boolean', default = false, label = 'Random vehicle from pool', order = 5 },
        ghost = { type = 'boolean', default = false, label = 'Ghost mode (no collisions)', order = 6 },
        reverse = { type = 'boolean', default = false, label = 'Reverse route', order = 7 },
        use3d = { type = 'boolean', default = false, label = '3D checkpoints (air)', order = 8 },
        checkpointRadius = { type = 'number', min = 2, max = 60, default = 12, label = 'Checkpoint radius', order = 9 },
        eliminateEvery = { type = 'integer', min = 0, max = 600, default = 0, label = 'Eliminate last place every N seconds (0 = off)', order = 10 },
        allowReset = { type = 'boolean', default = true, label = 'Allow reset to last checkpoint', order = 11 },
    },

    setup = function(inst)
        local o = inst.def.options
        local arena = inst.arena
        local spawns = inst:use('spawns', { points = arena.vehicleSpawns or arena.spawns })
        if o.onFoot then
            spawns:placeAll()
        else
            local vehicles = inst:use('vehicles', {
                vehicle = o.vehicle or { model = 'sultan', type = 'automobile' }, pool = o.pool, random = o.random,
                points = arena.vehicleSpawns or arena.spawns, lock = true, ghost = o.ghost,
                outOfVehicleAction = 'reseat', outOfVehicleSeconds = 6,
            })
            vehicles:provisionAll()
        end
        inst:use('checkpoints', {
            laps = o.laps, radius = o.checkpointRadius, reverse = o.reverse, use3d = o.use3d, allowReset = o.allowReset,
            onComplete = function(p)
                local first = not inst.data.winner
                inst:markFinished(p)
                if first then
                    inst.data.winner = p
                    inst:announce('announce_race_winner', 'success', p.name, U.fmtDuration(p.finishMs))
                end
            end,
            onLap = function(p, lap)
                inst:push(p, 'announce', { text = L('lap_n', lap, o.laps), kind = 'info' })
            end,
        })
    end,

    start = function(inst)
        local every = inst.def.options.eliminateEvery
        if every and every > 0 then inst.data.nextElim = ES.now() + every * 1000 end
    end,

    tick = function(inst)
        local every = inst.def.options.eliminateEvery
        if not every or every <= 0 or not inst.data.nextElim or ES.now() < inst.data.nextElim then return end
        inst.data.nextElim = ES.now() + every * 1000
        local active = inst:activeParticipants()
        if #active <= 1 then return end
        table.sort(active, function(a, b) return (a.progress or 0) < (b.progress or 0) end)
        local last = active[1]
        inst:announce('announce_race_eliminated', 'warn', last.name)
        inst:eliminate(last, 'last_place')
    end,

    hud = function(inst, p)
        local cp = inst:component('checkpoints')
        if not cp then return nil end
        local pr = cp:personal(p)
        local position
        for i, row in ipairs(inst:scoreRows()) do if row.src == p.src then position = i end end
        return { lap = pr.lap, laps = pr.laps, checkpoint = pr.passed, checkpoints = pr.total,
                 position = position, racers = #inst:allParticipants() }
    end,

    rowExtra = function(inst, p)
        if p.finishMs then return U.fmtDuration(p.finishMs) end
        local cp = inst:component('checkpoints')
        if not cp then return nil end
        local pr = cp:personal(p)
        return ('L%d · %d/%d'):format(pr.lap, pr.passed, pr.total)
    end,
})
