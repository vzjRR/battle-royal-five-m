-- EVENT STUDIO — mode: zone_survival (shrinking battle zone, last player/team alive)

local U = ES.Util

local defaultPhases = {
    { wait = 60, shrinkTo = 0.7, duration = 45 },
    { wait = 45, shrinkTo = 0.45, duration = 40 },
    { wait = 40, shrinkTo = 0.25, duration = 35 },
    { wait = 30, shrinkTo = 0.1, duration = 30 },
}

ES.RegisterMode('zone_survival', {
    label = 'Zone Survival',
    category = 'survival',
    description = 'A safe zone shrinks in phases. Staying outside hurts and eventually eliminates. Last player or team alive wins.',
    teams = 'optional',
    rankBy = 'score',
    lastStanding = true,
    lastTeamStanding = true,
    arena = { requires = { 'spawns' } },
    objectiveKey = 'obj_zone_survival',
    rulesKey = 'rules_zone_survival',
    options = {
        phases = { type = 'list', item = 'table', maxItems = 12, default = defaultPhases, label = 'Phases (wait, shrinkTo ratio, duration)', order = 1 },
        moving = { type = 'boolean', default = true, label = 'Zone center moves each phase', order = 2 },
        eliminateOutsideSeconds = { type = 'integer', min = 3, max = 120, default = 20, label = 'Eliminated after N seconds outside', order = 3 },
        damagePerSecond = { type = 'integer', min = 0, max = 50, default = 4, label = 'Damage per second outside (client)', order = 4 },
        weapons = { type = 'list', item = { type = 'string', maxLen = 40 }, maxItems = 16, default = { 'WEAPON_PISTOL' }, label = 'Weapons (empty = fists)', order = 5 },
        ammo = { type = 'integer', min = 1, max = 9999, default = 60, label = 'Ammo (limited ammo survival)', order = 6 },
        requireVehicle = { type = 'boolean', default = false, label = 'Vehicle survival', order = 7 },
        vehicle = { type = 'object', optional = true, label = 'Vehicle', order = 8, fields = {
            model = { type = 'string', maxLen = 32, default = 'sandking' }, type = { type = 'string', maxLen = 16, default = 'automobile' } } },
    },

    setup = function(inst)
        local o = inst.def.options
        local arena = inst.arena
        inst:use('spawns', { strategy = 'sequential' }):placeAll()
        local z = arena.zones and arena.zones[1] or { x = arena.center.x, y = arena.center.y, z = arena.center.z, radius = arena.radius }
        inst:use('zones', { zones = { { id = 'safe', x = z.x, y = z.y, z = z.z, radius = z.radius or arena.radius, height = 500.0, label = 'Safe zone' } },
                            safe = true, color = '#7cff6b' })
        inst:use('combat', { weapons = o.weapons, ammo = o.ammo, lives = 1, respawnDelay = 3 })
        if o.requireVehicle then
            inst:use('vehicles', { vehicle = o.vehicle or { model = 'sandking', type = 'automobile' }, lock = true,
                eliminateOnWreck = true, outOfVehicleAction = 'eliminate', points = arena.vehicleSpawns or arena.spawns }):provisionAll()
        end
        inst.data.out = {}
        inst.data.phase = 0
        inst.data.initialRadius = z.radius or arena.radius
        inst:broadcast('mode', { zoneDamage = o.damagePerSecond })
    end,

    start = function(inst)
        local first = inst.def.options.phases[1]
        inst.data.nextPhaseAt = ES.now() + (first and first.wait or 60) * 1000
    end,

    tick = function(inst, dt)
        local o = inst.def.options
        local zones = inst:component('zones')
        local zone = zones.zones.safe
        if inst.data.nextPhaseAt and ES.now() >= inst.data.nextPhaseAt then
            inst.data.phase = inst.data.phase + 1
            local ph = o.phases[inst.data.phase]
            if ph then
                local target = math.max(10.0, inst.data.initialRadius * (tonumber(ph.shrinkTo) or 0.5))
                local center
                if o.moving then
                    local maxShift = math.max(0, zone.radius - target)
                    local ang, dist = math.random() * math.pi * 2, math.random() * maxShift
                    center = { x = zone.x + math.cos(ang) * dist, y = zone.y + math.sin(ang) * dist, z = zone.z }
                end
                zones:shrinkTo('safe', target, (tonumber(ph.duration) or 30) * 1000, center)
                inst:announce('announce_zone_shrinking', 'warn', inst.data.phase, #o.phases)
                local nxt = o.phases[inst.data.phase + 1]
                inst.data.nextPhaseAt = nxt and (ES.now() + ((tonumber(ph.duration) or 30) + (tonumber(nxt.wait) or 30)) * 1000) or nil
            else
                inst.data.nextPhaseAt = nil
            end
        end
        local limit = o.eliminateOutsideSeconds * 1000
        for _, p in ipairs(inst:activeParticipants()) do
            if zones:outside(p, 'safe') then
                inst.data.out[p] = (inst.data.out[p] or 0) + dt
                if inst.data.out[p] >= limit then
                    inst.data.out[p] = nil
                    inst:eliminate(p, 'zone')
                end
            elseif inst.data.out[p] then
                inst.data.out[p] = math.max(0, inst.data.out[p] - dt * 2)
            end
        end
    end,

    onDeath = function(inst, victim, killer)
        if killer and killer ~= victim then inst:addScore(killer, 1, 'kill') end
    end,

    hud = function(inst, p)
        return { alive = #inst:activeParticipants(), phase = inst.data.phase or 0, phases = #inst.def.options.phases,
                 kills = p.stats.kills }
    end,

    rowExtra = function(_, p) return ('%d K'):format(p.stats.kills) end,
})
