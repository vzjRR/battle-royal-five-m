-- EVENT STUDIO — mode: koth
-- King of the Hill, capture point, domination, territory control, multi-point, vehicle KOTH, hardpoint rotation.

local U = ES.Util

ES.RegisterMode('koth', {
    label = 'King of the Hill / Domination',
    category = 'objective',
    description = 'Hold zones to earn points. Hill style scores the uncontested occupant; domination scores zone owners.',
    teams = 'optional',
    rankBy = 'score',
    arena = { requires = { 'zones' } },
    objectiveKey = 'obj_koth',
    rulesKey = 'rules_koth',
    options = {
        style = { type = 'enum', values = { 'hill', 'domination' }, default = 'hill', label = 'Style', order = 1 },
        pointsPerSecond = { type = 'integer', min = 1, max = 100, default = 1, label = 'Points per second', order = 2 },
        captureSeconds = { type = 'integer', min = 1, max = 60, default = 6, label = 'Capture time (domination)', order = 3 },
        scoreTarget = { type = 'integer', min = 0, max = 100000, default = 250, label = 'Score target (0 = none)', order = 4 },
        rotateEvery = { type = 'integer', min = 0, max = 900, default = 0, label = 'Rotate active zone every N s (hardpoint)', order = 5 },
        requireVehicle = { type = 'boolean', default = false, label = 'Must be in a vehicle', order = 6 },
        vehicle = { type = 'object', optional = true, label = 'Vehicle (when required)', order = 7, fields = {
            model = { type = 'string', maxLen = 32, default = 'sandking' }, type = { type = 'string', maxLen = 16, default = 'automobile' } } },
        weapons = { type = 'list', item = { type = 'string', maxLen = 40 }, maxItems = 16, default = { 'WEAPON_PISTOL', 'WEAPON_SMG' }, label = 'Weapons', order = 8 },
        respawnDelay = { type = 'integer', min = 1, max = 30, default = 5, label = 'Respawn delay (s)', order = 9 },
    },

    setup = function(inst)
        local o = inst.def.options
        local teams = #inst.teams > 0
        inst:use('spawns', { strategy = teams and 'sequential' or 'farthest' }):placeAll()
        inst:use('zones', {
            teamBased = teams, requireVehicle = o.requireVehicle,
            captureSeconds = o.style == 'domination' and o.captureSeconds or nil,
            onCapture = function(zone, key)
                local label = teams and inst.teams[key] and inst.teams[key].name
                if not label then
                    local p = inst.participants[key]
                    label = p and p.name or '?'
                end
                inst:announce('announce_zone_captured', 'info', zone.label, label)
            end,
        })
        inst:use('combat', { weapons = o.weapons, lives = 0, respawnDelay = o.respawnDelay })
        if o.requireVehicle then
            inst:use('vehicles', { vehicle = o.vehicle or { model = 'sandking', type = 'automobile' }, lock = false,
                                   points = inst.arena.vehicleSpawns or inst.arena.spawns }):provisionAll()
        end
        inst.data.acc = 0
        inst.data.active = (o.rotateEvery > 0) and 1 or nil
    end,

    start = function(inst)
        local o = inst.def.options
        if o.rotateEvery > 0 then
            inst.data.nextRotate = ES.now() + o.rotateEvery * 1000
            inst:broadcast('mode', { activeZone = inst:component('zones').order[1].id })
        end
    end,

    tick = function(inst, dt)
        local o = inst.def.options
        local zones = inst:component('zones')
        local teams = #inst.teams > 0
        if inst.data.nextRotate and ES.now() >= inst.data.nextRotate then
            inst.data.nextRotate = ES.now() + o.rotateEvery * 1000
            inst.data.active = inst.data.active % #zones.order + 1
            local z = zones.order[inst.data.active]
            inst:broadcast('mode', { activeZone = z.id })
            inst:announce('announce_zone_moved', 'info', z.label)
        end
        inst.data.acc = inst.data.acc + dt
        while inst.data.acc >= 1000 do
            inst.data.acc = inst.data.acc - 1000
            for i, zone in ipairs(zones.order) do
                if not inst.data.active or inst.data.active == i then
                    if o.style == 'domination' then
                        local owner = zones:ownerOf(zone.id)
                        if owner then
                            if teams then
                                inst:addTeamScore(owner, o.pointsPerSecond)
                            elseif inst.participants[owner] then
                                inst:addScore(inst.participants[owner], o.pointsPerSecond, 'zone')
                            end
                        end
                    elseif not zones:isContested(zone.id) then
                        local occ = zones:occupantsOf(zone.id)
                        if #occ > 0 then
                            if teams then inst:addTeamScore(occ[1].team, o.pointsPerSecond) end
                            for _, p in ipairs(occ) do
                                inst:addScore(p, o.pointsPerSecond, 'hold', teams)
                                inst:addStat(p, 'objectives', 1)
                            end
                        end
                    end
                end
            end
        end
        if o.scoreTarget > 0 then
            for _, t in ipairs(inst.teams) do
                if t.score >= o.scoreTarget then return inst:finishNow('score_target') end
            end
            if not teams then
                for _, p in ipairs(inst:activeParticipants()) do
                    if p.score >= o.scoreTarget then return inst:finishNow('score_target') end
                end
            end
        end
    end,

    onDeath = function(inst, victim, killer)
        if killer and killer ~= victim then inst:addScore(killer, 0, 'kill') end
    end,

    hud = function(inst, p)
        local o = inst.def.options
        local zones = inst:component('zones')
        local holding = false
        if zones then
            for _, zone in ipairs(zones.order) do
                for _, occ in ipairs(zones:occupantsOf(zone.id)) do if occ == p then holding = zone.label end end
            end
        end
        return { holding = holding, target = o.scoreTarget > 0 and o.scoreTarget or nil, score = p.score }
    end,

    rowExtra = function(_, p) return ('%d s'):format(p.stats.objectives or 0) end,
})
