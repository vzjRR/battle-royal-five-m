-- EVENT STUDIO — mode: juggernaut
-- One heavily armoured player vs everyone. Classic variant: whoever kills the Juggernaut becomes the Juggernaut.
-- The Juggernaut earns points every second they survive plus per kill; attackers earn points for the takedown.

ES.RegisterMode('juggernaut', {
    label = 'Juggernaut',
    category = 'combat',
    description = 'One armoured Juggernaut vs everyone. Kill the Juggernaut to take the role; score by surviving as the Juggernaut.',
    teams = 'none',
    minPlayers = 3,
    rankBy = 'score',
    arena = { requires = { 'spawns' } },
    objectiveKey = 'obj_juggernaut',
    rulesKey = 'rules_juggernaut',
    options = {
        juggernautHealth = { type = 'integer', min = 200, max = 1000, default = 800, label = 'Juggernaut health', order = 1 },
        juggernautArmor = { type = 'integer', min = 0, max = 100, default = 100, label = 'Juggernaut armor', order = 2 },
        juggernautWeapons = { type = 'list', item = { type = 'string', maxLen = 40 }, maxItems = 8, default = { 'WEAPON_MG', 'WEAPON_PISTOL50' }, label = 'Juggernaut weapons', order = 3 },
        attackerWeapons = { type = 'list', item = { type = 'string', maxLen = 40 }, maxItems = 8, default = { 'WEAPON_PISTOL', 'WEAPON_SMG', 'WEAPON_PUMPSHOTGUN' }, label = 'Attacker weapons', order = 4 },
        passOnKill = { type = 'boolean', default = true, label = 'Killer becomes the Juggernaut', order = 5 },
        pointsPerSecond = { type = 'integer', min = 0, max = 50, default = 1, label = 'Juggernaut points per second', order = 6 },
        juggernautKillPoints = { type = 'integer', min = 0, max = 100, default = 3, label = 'Points per kill as Juggernaut', order = 7 },
        takedownPoints = { type = 'integer', min = 0, max = 200, default = 10, label = 'Points for killing the Juggernaut', order = 8 },
        scoreTarget = { type = 'integer', min = 0, max = 10000, default = 150, label = 'Score target (0 = none)', order = 9 },
        respawnDelay = { type = 'integer', min = 1, max = 30, default = 4, label = 'Respawn delay (s)', order = 10 },
    },

    setup = function(inst)
        local o = inst.def.options
        inst:use('spawns', { strategy = 'farthest' }):placeAll()
        local all = {}
        for _, w in ipairs(o.juggernautWeapons) do all[#all + 1] = w end
        for _, w in ipairs(o.attackerWeapons) do all[#all + 1] = w end
        inst:use('combat', { weapons = all, lives = 0, respawnDelay = o.respawnDelay })
        inst:use('roles', {
            default = 'attacker',
            roles = {
                juggernaut = { label = 'Juggernaut', health = o.juggernautHealth, armor = o.juggernautArmor, weapons = o.juggernautWeapons, color = '#ff3d71' },
                attacker = { label = 'Attacker', weapons = o.attackerWeapons, color = '#3d8bff' },
            },
        })
        local roles = inst:component('roles')
        for _, p in ipairs(inst:activeParticipants()) do roles:set(p, 'attacker', true) end
        inst.data.acc = 0
    end,

    start = function(inst)
        local jug = inst:component('roles'):pick('juggernaut', 1)[1]
        if jug then inst:announce('announce_juggernaut_new', 'warn', jug.name) end
    end,

    tick = function(inst, dt)
        local o = inst.def.options
        local roles = inst:component('roles')
        local jugs = roles:members('juggernaut', true)
        if #jugs == 0 and #inst:activeParticipants() > 0 then
            local jug = roles:pick('juggernaut', 1)[1]
            if jug then inst:announce('announce_juggernaut_new', 'warn', jug.name) end
            return
        end
        inst.data.acc = inst.data.acc + dt
        while inst.data.acc >= 1000 do
            inst.data.acc = inst.data.acc - 1000
            for _, j in ipairs(jugs) do
                if inst:component('combat').alive[j] then inst:addScore(j, o.pointsPerSecond, 'juggernaut_time') end
            end
        end
        if o.scoreTarget > 0 then
            for _, p in ipairs(inst:activeParticipants()) do
                if p.score >= o.scoreTarget then return inst:finishNow('score_target') end
            end
        end
    end,

    onDeath = function(inst, victim, killer)
        local o = inst.def.options
        local roles = inst:component('roles')
        if roles:roleOf(victim) == 'juggernaut' then
            if killer and killer ~= victim then
                inst:addScore(killer, o.takedownPoints, 'takedown')
                inst:addStat(killer, 'objectives', 1)
            end
            roles:set(victim, 'attacker')
            local next = (o.passOnKill and killer and killer ~= victim and killer.status == 'active') and killer or nil
            if next then
                roles:set(next, 'juggernaut')
                inst:announce('announce_juggernaut_new', 'warn', next.name)
            end
        elseif killer and killer ~= victim and roles:roleOf(killer) == 'juggernaut' then
            inst:addScore(killer, o.juggernautKillPoints, 'juggernaut_kill')
        end
    end,

    onLeave = function(inst, p)
        local roles = inst:component('roles')
        if roles and roles:roleOf(p) == 'juggernaut' then roles.of[p] = 'attacker' end
    end,

    hud = function(inst, p)
        local roles = inst:component('roles')
        return { score = p.score, target = inst.def.options.scoreTarget > 0 and inst.def.options.scoreTarget or nil,
                 kills = p.stats.kills, role = roles and roles:roleOf(p) or nil }
    end,

    rowExtra = function(inst, p)
        local roles = inst:component('roles')
        return (roles and roles:roleOf(p) == 'juggernaut') and ('★ ' .. p.score) or tostring(p.score)
    end,
})
