-- EVENT STUDIO — mode: sumo (vehicle arena elimination)
-- Sumo, vehicle knockout, demolition derby, last vehicle standing.

local U = ES.Util

ES.RegisterMode('sumo', {
    label = 'Sumo / Derby',
    category = 'vehicle',
    description = 'Stay inside the arena while pushing others out. Optional wreck elimination (derby) and sudden-death shrink.',
    teams = 'optional',
    rankBy = 'score',
    lastStanding = true,
    lastTeamStanding = true,
    arena = { requires = { 'bounds' } },
    objectiveKey = 'obj_sumo',
    rulesKey = 'rules_sumo',
    options = {
        vehicle = { type = 'object', label = 'Vehicle', order = 1, fields = {
            model = { type = 'string', maxLen = 32, default = 'sandking' },
            type = { type = 'enum', values = { 'automobile', 'bike' }, default = 'automobile' },
        } },
        pool = { type = 'list', item = 'table', maxItems = 32, optional = true, label = 'Vehicle pool', order = 2 },
        random = { type = 'boolean', default = false, label = 'Random vehicle from pool', order = 3 },
        eliminateOnWreck = { type = 'boolean', default = false, label = 'Eliminate when vehicle is wrecked (derby)', order = 4 },
        scoreKnockouts = { type = 'boolean', default = true, label = 'Credit knockouts to nearest opponent', order = 5 },
        graceMs = { type = 'integer', min = 0, max = 10000, default = 1500, label = 'Out-of-bounds grace (ms)', order = 6 },
        suddenDeathAfter = { type = 'integer', min = 0, max = 3600, default = 150, label = 'Sudden death after N seconds (0 = off)', order = 7 },
        suddenDeathRatio = { type = 'number', min = 0.1, max = 0.95, default = 0.45, label = 'Sudden death radius ratio', order = 8 },
    },

    setup = function(inst)
        local o = inst.def.options
        local arena = inst.arena
        inst:use('spawns', { points = arena.vehicleSpawns or arena.spawns })
        local vehicles = inst:use('vehicles', {
            vehicle = o.vehicle, pool = o.pool, random = o.random, points = arena.vehicleSpawns or arena.spawns,
            lock = true, eliminateOnWreck = o.eliminateOnWreck, outOfVehicleAction = 'eliminate', outOfVehicleSeconds = 5,
        })
        vehicles:provisionAll()
        inst:use('bounds', {
            graceMs = o.graceMs,
            action = function(p)
                if o.scoreKnockouts and p.src then
                    local pos = U.vec(GetEntityCoords(GetPlayerPed(p.src)))
                    local best, bestD
                    for _, other in ipairs(inst:activeParticipants()) do
                        if other ~= p and (not p.team or other.team ~= p.team) then
                            local d = U.dist(pos, U.vec(GetEntityCoords(GetPlayerPed(other.src))))
                            if d < 25.0 and (not bestD or d < bestD) then best, bestD = other, d end
                        end
                    end
                    if best then
                        inst:addScore(best, 1, 'knockout')
                        inst:addStat(best, 'kills', 1)
                        inst:announce('announce_knockout', 'info', best.name, p.name)
                    end
                end
                inst:eliminate(p, 'out_of_bounds')
            end,
        })
    end,

    tick = function(inst)
        local o = inst.def.options
        if o.suddenDeathAfter > 0 and not inst.data.suddenDeath and inst:elapsedMs() >= o.suddenDeathAfter * 1000 then
            inst.data.suddenDeath = true
            local bounds = inst:component('bounds')
            bounds:shrinkTo(bounds.radius * o.suddenDeathRatio, 30000)
            inst:announce('announce_sudden_death', 'warn')
        end
    end,

    hud = function(inst, p)
        return { knockouts = p.score, alive = #inst:activeParticipants(), suddenDeath = inst.data.suddenDeath or false }
    end,

    rowExtra = function(_, p) return ('KO %d'):format(p.score) end,
})
