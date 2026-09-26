-- EVENT STUDIO — mode: vehicle_tag
-- One vehicle is "it". Touch another vehicle (server-side distance) to pass it on. Everyone who is not "it"
-- scores every second. No tag-backs for a few seconds after a tag.

local U = ES.Util

local function setIt(inst, p)
    local roles = inst:component('roles')
    if inst.data.it then roles:set(inst.data.it, 'runner', true) end
    inst.data.it = p
    inst.data.lastTag = ES.now()
    roles:set(p, 'it')
    inst:broadcast('mode', { markPlayer = p.src, markLabel = L('tag_it_label') })
end

ES.RegisterMode('vehicle_tag', {
    label = 'Vehicle Tag',
    category = 'vehicle',
    description = 'One car is "it". Bump another car to pass it on. Score every second you are not it.',
    teams = 'none',
    minPlayers = 3,
    rankBy = 'score',
    arena = { requires = { 'vehicleSpawns' } },
    objectiveKey = 'obj_vehicle_tag',
    rulesKey = 'rules_vehicle_tag',
    options = {
        vehicle = { type = 'object', label = 'Vehicle', order = 1, fields = {
            model = { type = 'string', maxLen = 32, default = 'issi2' }, type = { type = 'string', maxLen = 16, default = 'automobile' } } },
        tagDistance = { type = 'number', min = 2, max = 10, default = 4.5, label = 'Tag distance (m)', order = 2 },
        noTagBackSeconds = { type = 'integer', min = 0, max = 20, default = 4, label = 'No tag-back window (s)', order = 3 },
    },

    setup = function(inst)
        local o = inst.def.options
        inst:use('spawns', { points = inst.arena.vehicleSpawns })
        inst:use('vehicles', { vehicle = o.vehicle, points = inst.arena.vehicleSpawns, lock = true, outOfVehicleAction = 'reseat', outOfVehicleSeconds = 4 }):provisionAll()
        if inst.arena.bounds then inst:use('bounds', { graceMs = 5000, action = 'respawn' }) end
        inst:use('roles', { default = 'runner', roles = {
            it = { label = 'IT', color = '#ff3d71' }, runner = { label = 'Runner', color = '#3ddc84' } } })
        inst.data.acc = 0
    end,

    start = function(inst)
        local list = inst:activeParticipants()
        if #list > 0 then setIt(inst, U.pick(list)) end
    end,

    tick = function(inst, dt)
        local o = inst.def.options
        local it = inst.data.it
        if not it or it.status ~= 'active' or not it.src then
            local list = inst:activeParticipants()
            if #list > 0 then setIt(inst, U.pick(list)) end
            return
        end
        inst.data.acc = inst.data.acc + dt
        while inst.data.acc >= 1000 do
            inst.data.acc = inst.data.acc - 1000
            for _, p in ipairs(inst:activeParticipants()) do if p ~= it then inst:addScore(p, 1, 'free') end end
        end
        if ES.now() - (inst.data.lastTag or 0) < o.noTagBackSeconds * 1000 then return end
        local veh = inst:component('vehicles')
        local itVeh = veh:entityOf(it)
        if not itVeh then return end
        local itPos = U.vec(GetEntityCoords(itVeh))
        for _, p in ipairs(inst:activeParticipants()) do
            if p ~= it and not (p == inst.data.previousIt and ES.now() < (inst.data.previousItUntil or 0)) then
                local e = veh:entityOf(p)
                if e and U.dist(U.vec(GetEntityCoords(e)), itPos) <= o.tagDistance then
                    inst.data.previousIt = it
                    inst.data.previousItUntil = ES.now() + (o.noTagBackSeconds + 1) * 1000
                    inst:addStat(it, 'objectives', 1)
                    inst:announce('announce_tag', 'info', it.name, p.name)
                    setIt(inst, p)
                    return
                end
            end
        end
    end,

    hud = function(inst, p)
        return { score = p.score, target = inst.data.it and inst.data.it.name or nil, alive = #inst:activeParticipants() }
    end,
})
