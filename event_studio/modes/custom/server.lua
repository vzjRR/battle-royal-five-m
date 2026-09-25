-- EVENT STUDIO — mode: custom (staff-hosted events with manual / API scoring)
-- Staff award points from the Live view (audited) or other resources call exports.GivePoints.

ES.RegisterMode('custom', {
    label = 'Custom / Staff Hosted',
    category = 'social',
    description = 'A host runs the activity; points are awarded manually by staff or by other resources through the API.',
    teams = 'optional',
    minPlayers = 1,
    rankBy = 'score',
    arena = { none = true, optional = true },
    objectiveKey = 'obj_custom',
    rulesKey = 'rules_custom',
    options = {
        teleport = { type = 'boolean', default = true, label = 'Teleport players to the arena spawns', order = 1 },
        weapons = { type = 'list', item = { type = 'string', maxLen = 40 }, maxItems = 16, default = {}, label = 'Weapons (optional)', order = 2 },
        vehicle = { type = 'object', optional = true, label = 'Vehicle for everyone (optional)', order = 3, fields = {
            model = { type = 'string', maxLen = 32, default = 'blista' }, type = { type = 'string', maxLen = 16, default = 'automobile' } } },
        instructions = { type = 'string', maxLen = 300, optional = true, label = 'Instructions shown to players', order = 4 },
    },

    setup = function(inst)
        local o = inst.def.options
        if inst.arena then
            local spawns = inst:use('spawns', {})
            if o.teleport then spawns:placeAll() end
            if o.vehicle then
                inst:use('vehicles', { vehicle = o.vehicle, lock = false, points = inst.arena.vehicleSpawns or inst.arena.spawns }):provisionAll()
            end
        end
        if #o.weapons > 0 then inst:use('combat', { weapons = o.weapons, lives = 0, respawnDelay = 5 }) end
    end,

    viability = function(inst)
        return #inst:activeParticipants() > 0
    end,

    hud = function(inst, p)
        return { score = p.score, instructions = inst.def.options.instructions }
    end,
})
