-- EVENT STUDIO — mode: gungame (weapon ladder / kill quota)

ES.RegisterMode('gungame', {
    label = 'Gun Game',
    category = 'combat',
    description = 'Advance through a weapon ladder with every kill. First to finish the ladder wins.',
    teams = 'none',
    rankBy = 'score',
    arena = { requires = { 'spawns' } },
    objectiveKey = 'obj_gungame',
    rulesKey = 'rules_gungame',
    options = {
        ladder = { type = 'list', item = { type = 'string', maxLen = 40 }, minItems = 2, maxItems = 30, label = 'Weapon ladder', order = 1,
            default = { 'WEAPON_PISTOL', 'WEAPON_COMBATPISTOL', 'WEAPON_MICROSMG', 'WEAPON_SMG', 'WEAPON_PUMPSHOTGUN',
                        'WEAPON_ASSAULTRIFLE', 'WEAPON_CARBINERIFLE', 'WEAPON_MG', 'WEAPON_SNIPERRIFLE', 'WEAPON_KNIFE' } },
        killsPerLevel = { type = 'integer', min = 1, max = 10, default = 1, label = 'Kills per level', order = 2 },
        respawnDelay = { type = 'integer', min = 1, max = 15, default = 2, label = 'Respawn delay (s)', order = 3 },
        meleeDemotes = { type = 'boolean', default = true, label = 'Melee kill demotes victim', order = 4 },
    },

    setup = function(inst)
        local o = inst.def.options
        inst:use('spawns', { strategy = 'farthest' }):placeAll()
        local combat = inst:use('combat', { weapons = o.ladder, lives = 0, respawnDelay = o.respawnDelay, ammo = 9999 })
        combat:allowWeapon('WEAPON_KNIFE')
        inst.data.level, inst.data.progress = {}, {}
        for _, p in ipairs(inst:activeParticipants()) do
            inst.data.level[p], inst.data.progress[p] = 1, 0
            combat.weaponsOf[p] = { o.ladder[1] }
        end
    end,

    onLateJoin = function(inst, p)
        inst.data.level[p], inst.data.progress[p] = 1, 0
        inst:component('combat'):giveLoadout(p, { inst.def.options.ladder[1] })
    end,

    onDeath = function(inst, victim, killer, weapon)
        local o = inst.def.options
        local combat = inst:component('combat')
        if o.meleeDemotes and killer and weapon == combat.norm(GetHashKey('WEAPON_KNIFE')) then
            local lv = inst.data.level[victim] or 1
            if lv > 1 then
                inst.data.level[victim] = lv - 1
                inst:addScore(victim, -1, 'demoted')
                combat.weaponsOf[victim] = { o.ladder[lv - 1] }
                inst:push(victim, 'announce', { text = L('gungame_demoted'), kind = 'error' })
            end
        end
        if not killer or killer == victim then return end
        inst.data.progress[killer] = (inst.data.progress[killer] or 0) + 1
        if inst.data.progress[killer] < o.killsPerLevel then return end
        inst.data.progress[killer] = 0
        local lv = (inst.data.level[killer] or 1) + 1
        inst.data.level[killer] = lv
        inst:addScore(killer, 1, 'level')
        if lv > #o.ladder then
            inst:announce('announce_gungame_winner', 'success', killer.name)
            inst:finishNow('ladder_complete')
            return
        end
        combat:giveLoadout(killer, { o.ladder[lv] })
        if lv == #o.ladder then inst:announce('announce_gungame_final', 'warn', killer.name) end
    end,

    hud = function(inst, p)
        local lv = inst.data.level and inst.data.level[p] or 1
        local ladder = inst.def.options.ladder
        return { level = math.min(lv, #ladder), levels = #ladder, weapon = (ladder[lv] or ''):gsub('WEAPON_', ''), kills = p.stats.kills }
    end,

    rowExtra = function(inst, p)
        local lv = inst.data.level and inst.data.level[p] or 1
        return ('Lv %d/%d'):format(math.min(lv, #inst.def.options.ladder), #inst.def.options.ladder)
    end,
})
