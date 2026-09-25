-- EVENT STUDIO — mode: hunters (Hunters vs Runners)
-- A few armed hunters chase unarmed (or lightly armed) runners. Runners score for every second alive.
-- Infection variant: a caught runner becomes a hunter. Runners who survive the timer win.

ES.RegisterMode('hunters', {
    label = 'Hunters vs Runners',
    category = 'combat',
    description = 'Hunters chase the runners. Survive the timer as a runner, or catch everyone as a hunter. Optional infection.',
    teams = 'none',
    minPlayers = 3,
    rankBy = 'score',
    arena = { requires = { 'spawns' } },
    objectiveKey = 'obj_hunters',
    rulesKey = 'rules_hunters',
    options = {
        hunterRatio = { type = 'number', min = 0.1, max = 0.5, default = 0.25, label = 'Share of players who start as hunters', order = 1 },
        infect = { type = 'boolean', default = true, label = 'Caught runners become hunters', order = 2 },
        hunterWeapons = { type = 'list', item = { type = 'string', maxLen = 40 }, maxItems = 6, default = { 'WEAPON_KNIFE', 'WEAPON_PISTOL' }, label = 'Hunter weapons', order = 3 },
        runnerWeapons = { type = 'list', item = { type = 'string', maxLen = 40 }, maxItems = 6, default = {}, label = 'Runner weapons (empty = unarmed)', order = 4 },
        runnerPointsPerSecond = { type = 'integer', min = 0, max = 20, default = 1, label = 'Runner points per second alive', order = 5 },
        catchPoints = { type = 'integer', min = 0, max = 100, default = 10, label = 'Hunter points per catch', order = 6 },
        surviveBonus = { type = 'integer', min = 0, max = 500, default = 50, label = 'Bonus for surviving runners', order = 7 },
        hunterReleaseSeconds = { type = 'integer', min = 0, max = 60, default = 10, label = 'Runner head start (hunters frozen, s)', order = 8 },
    },

    setup = function(inst)
        local o = inst.def.options
        inst:use('spawns', { strategy = 'random' }):placeAll()
        local all = {}
        for _, w in ipairs(o.hunterWeapons) do all[#all + 1] = w end
        for _, w in ipairs(o.runnerWeapons) do all[#all + 1] = w end
        inst:use('combat', { weapons = all, lives = 0, respawnDelay = 4 })
        inst:use('roles', {
            default = 'runner',
            roles = {
                hunter = { label = 'Hunter', weapons = o.hunterWeapons, armor = 50, color = '#ff3d71' },
                runner = { label = 'Runner', weapons = o.runnerWeapons, color = '#3ddc84' },
            },
        })
        local roles = inst:component('roles')
        for _, p in ipairs(inst:activeParticipants()) do roles:set(p, 'runner', true) end
        local n = math.max(1, math.floor(#inst:activeParticipants() * o.hunterRatio + 0.5))
        inst.data.initialHunters = roles:pick('hunter', n)
        inst.data.acc = 0
    end,

    start = function(inst)
        local o = inst.def.options
        if o.hunterReleaseSeconds > 0 then
            for _, h in ipairs(inst.data.initialHunters or {}) do inst:push(h, 'freeze', { frozen = true }) end
            inst.data.releaseAt = ES.now() + o.hunterReleaseSeconds * 1000
            inst:announce('announce_hunters_headstart', 'warn', o.hunterReleaseSeconds)
        end
    end,

    tick = function(inst, dt)
        local o = inst.def.options
        local roles = inst:component('roles')
        if inst.data.releaseAt and ES.now() >= inst.data.releaseAt then
            inst.data.releaseAt = nil
            for _, h in ipairs(roles:members('hunter', true)) do inst:push(h, 'freeze', { frozen = false }) end
            inst:announce('announce_hunters_released', 'error')
        end
        inst.data.acc = inst.data.acc + dt
        while inst.data.acc >= 1000 do
            inst.data.acc = inst.data.acc - 1000
            for _, r in ipairs(roles:members('runner', true)) do inst:addScore(r, o.runnerPointsPerSecond, 'alive') end
        end
        if #roles:members('runner', true) == 0 then return inst:finishNow('all_caught') end
    end,

    onDeath = function(inst, victim, killer)
        local o = inst.def.options
        local roles = inst:component('roles')
        if roles:roleOf(victim) ~= 'runner' then return end
        if killer and killer ~= victim and roles:roleOf(killer) == 'hunter' then
            inst:addScore(killer, o.catchPoints, 'catch')
            inst:addStat(killer, 'objectives', 1)
        end
        if o.infect then
            roles:set(victim, 'hunter')
            inst:announce('announce_hunters_infected', 'warn', victim.name)
        else
            inst:eliminate(victim, 'caught')
        end
    end,

    onTimeUp = function(inst)
        local roles = inst:component('roles')
        for _, r in ipairs(roles:members('runner', true)) do
            inst:addScore(r, inst.def.options.surviveBonus, 'survived')
        end
        inst:finishNow('time')
    end,

    viability = function(inst)
        local roles = inst:component('roles')
        if not roles then return nil end
        if #roles:members('hunter', true) == 0 and #inst:activeParticipants() > 1 then
            roles:pick('hunter', 1)
        end
        return #inst:activeParticipants() > 0
    end,

    hud = function(inst, p)
        local roles = inst:component('roles')
        return { role = roles and roles:roleOf(p) or nil, alive = roles and #roles:members('runner', true) or 0, score = p.score }
    end,

    rowExtra = function(inst, p)
        local roles = inst:component('roles')
        return (roles and roles:roleOf(p) == 'hunter' and 'H · ' or 'R · ') .. p.score
    end,
})
