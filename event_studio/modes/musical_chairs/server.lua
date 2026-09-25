-- EVENT STUDIO — mode: musical_chairs
-- While the "music" plays everyone roams. When it stops, "chairs" (small zones) appear. There is one chair fewer
-- than players; each chair seats only one player (the one closest to its center). Anyone without a chair is out.
-- Chairs are generated around the arena center each round; occupancy is measured on the server.

local U = ES.Util

local function placeChairs(inst, count)
    local c = inst.arena.center
    local r = math.max(6, math.min((inst.arena.radius or 40) * 0.8, inst.def.options.spread))
    local chairs = {}
    for i = 1, count do
        local ang = (i / count) * math.pi * 2 + math.random() * 0.6
        local dist = r * (0.3 + math.random() * 0.7)
        chairs[i] = { id = 'c' .. i, x = c.x + math.cos(ang) * dist, y = c.y + math.sin(ang) * dist, z = c.z,
                      radius = inst.def.options.chairRadius, height = 20.0, label = '🪑' }
    end
    return chairs
end

local function musicPhase(inst)
    local o = inst.def.options
    inst.data.round = (inst.data.round or 0) + 1
    inst.data.phase = 'music'
    inst.data.phaseEnds = ES.now() + math.floor((o.musicMin + math.random() * (o.musicMax - o.musicMin)) * 1000)
    inst:component('zones'):setZones({})
    inst:broadcast('mode', { banner = { text = L('chairs_music'), color = '#c36bff', untilMs = 2500 } })
end

local function stopPhase(inst)
    local o = inst.def.options
    local alive = #inst:activeParticipants()
    inst.data.phase = 'stop'
    inst.data.phaseEnds = ES.now() + o.seatSeconds * 1000
    inst:component('zones'):setZones(placeChairs(inst, math.max(1, alive - 1)))
    inst:broadcast('mode', { banner = { text = L('chairs_stop'), color = '#ff3d5e', untilMs = o.seatSeconds * 1000 } })
end

local function resolveSeats(inst)
    local zones = inst:component('zones')
    local seated = {}
    for _, zone in ipairs(zones.order) do
        local best, bestD
        for _, p in ipairs(zones:occupantsOf(zone.id)) do
            if not seated[p] then
                local d = U.dist2d(U.vec(GetEntityCoords(GetPlayerPed(p.src))), zone)
                if not bestD or d < bestD then best, bestD = p, d end
            end
        end
        if best then seated[best] = true end
    end
    local out = {}
    for _, p in ipairs(inst:activeParticipants()) do
        if seated[p] then inst:addScore(p, 1, 'seated') else out[#out + 1] = p end
    end
    for _, p in ipairs(out) do
        inst:announce('announce_chairs_out', 'error', p.name)
        inst:eliminate(p, 'no_chair')
    end
end

ES.RegisterMode('musical_chairs', {
    label = 'Musical Chairs',
    category = 'social',
    description = 'When the music stops, grab a chair. There is always one chair too few.',
    teams = 'none',
    minPlayers = 2,
    rankBy = 'score',
    lastStanding = true,
    arena = { requires = { 'spawns' } },
    objectiveKey = 'obj_musical_chairs',
    rulesKey = 'rules_musical_chairs',
    options = {
        musicMin = { type = 'number', min = 3, max = 60, default = 6, label = 'Music min (s)', order = 1 },
        musicMax = { type = 'number', min = 3, max = 60, default = 14, label = 'Music max (s)', order = 2 },
        seatSeconds = { type = 'integer', min = 3, max = 30, default = 6, label = 'Seconds to find a chair', order = 3 },
        chairRadius = { type = 'number', min = 1, max = 10, default = 2.5, label = 'Chair radius (m)', order = 4 },
        spread = { type = 'number', min = 6, max = 100, default = 25, label = 'Max chair distance from center (m)', order = 5 },
    },

    validate = function(def)
        if def.options.musicMin > def.options.musicMax then return false, 'musicMin must be <= musicMax' end
        return true
    end,

    setup = function(inst)
        inst:use('spawns', { strategy = 'random' }):placeAll()
        inst:use('zones', { zones = {}, color = '#c36bff' })
    end,

    start = function(inst) musicPhase(inst) end,

    tick = function(inst)
        if ES.now() < inst.data.phaseEnds then return end
        if inst.data.phase == 'music' then
            stopPhase(inst)
        else
            resolveSeats(inst)
            if inst.state == ES.Lifecycle.States.ACTIVE and #inst:activeParticipants() > 1 then musicPhase(inst) end
        end
    end,

    hud = function(inst, p)
        return { round = inst.data.round, alive = #inst:activeParticipants(), score = p.score }
    end,
})
