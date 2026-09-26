-- EVENT STUDIO — mode: bounty (Bounty Hunt / Assassin Hunt)
-- bounty:   the leader carries a growing bounty and is marked for everyone; claiming it pays big.
-- assassin: everyone gets one secret target (a ring). Kill your target for points and inherit theirs;
--           killing anyone else costs points. Each player only ever learns their own target.

local function sendTarget(inst, p)
    local t = inst.data.targetOf[p]
    if p.src then inst:push(p, 'mode', { markPlayer = t and t.src or false, markLabel = t and t.name or nil }) end
end

local function buildRing(inst)
    local list = inst:activeParticipants()
    ES.Util.shuffle(list)
    inst.data.targetOf = {}
    for i, p in ipairs(list) do inst.data.targetOf[p] = list[i % #list + 1] end
    for _, p in ipairs(list) do sendTarget(inst, p) end
end

local function nextLiving(inst, p)
    -- walk the ring past anyone who left
    local seen, t = {}, inst.data.targetOf[p]
    while t and (t.status ~= 'active' or not t.src) and not seen[t] do
        seen[t] = true
        t = inst.data.targetOf[t]
    end
    if t == p then return nil end
    return t
end

local function updateBounty(inst)
    local leader
    for _, p in ipairs(inst:activeParticipants()) do
        if not leader or p.score > leader.score then leader = p end
    end
    if leader and leader ~= inst.data.bountyOn and leader.score > 0 then
        inst.data.bountyOn = leader
        inst.data.bountyValue = inst.def.options.bountyBase
        inst:broadcast('mode', { markPlayer = leader.src, markLabel = L('bounty_label', inst.data.bountyValue) })
        inst:announce('announce_bounty_new', 'warn', leader.name)
    end
end

ES.RegisterMode('bounty', {
    label = 'Bounty / Assassin Hunt',
    category = 'combat',
    description = 'Bounty: the leader is marked and worth big points. Assassin: everyone hunts one secret target.',
    teams = 'none',
    minPlayers = 3,
    rankBy = 'score',
    arena = { requires = { 'spawns' } },
    objectiveKey = 'obj_bounty',
    rulesKey = 'rules_bounty',
    options = {
        style = { type = 'enum', values = { 'bounty', 'assassin' }, default = 'bounty', label = 'Style', order = 1 },
        weapons = { type = 'list', item = { type = 'string', maxLen = 40 }, maxItems = 8, default = { 'WEAPON_PISTOL', 'WEAPON_SMG' }, label = 'Weapons', order = 2 },
        bountyBase = { type = 'integer', min = 1, max = 100, default = 5, label = 'Bounty value (bounty style)', order = 3 },
        bountyGrowth = { type = 'integer', min = 0, max = 50, default = 2, label = 'Bounty grows per kill by the target', order = 4 },
        targetPoints = { type = 'integer', min = 1, max = 100, default = 5, label = 'Points for your target (assassin)', order = 5 },
        wrongKillPenalty = { type = 'integer', min = 0, max = 100, default = 3, label = 'Penalty for killing a non-target (assassin)', order = 6 },
        scoreTarget = { type = 'integer', min = 0, max = 1000, default = 30, label = 'Score target (0 = none)', order = 7 },
        respawnDelay = { type = 'integer', min = 1, max = 30, default = 4, label = 'Respawn delay (s)', order = 8 },
    },

    setup = function(inst)
        local o = inst.def.options
        inst:use('spawns', { strategy = 'farthest' }):placeAll()
        inst:use('combat', { weapons = o.weapons, lives = 0, respawnDelay = o.respawnDelay })
        inst.data.targetOf = {}
    end,

    start = function(inst)
        if inst.def.options.style == 'assassin' then buildRing(inst) end
    end,

    onDeath = function(inst, victim, killer)
        local o = inst.def.options
        if not killer or killer == victim then return end
        if o.style == 'assassin' then
            if nextLiving(inst, killer) == victim then
                inst:addScore(killer, o.targetPoints, 'target')
                inst:addStat(killer, 'objectives', 1)
                inst.data.targetOf[killer] = nextLiving(inst, victim)
                if inst.data.targetOf[killer] == killer then inst.data.targetOf[killer] = nil end
                sendTarget(inst, killer)
                inst:push(killer, 'announce', { text = L('assassin_new_target', inst.data.targetOf[killer] and inst.data.targetOf[killer].name or '—'), kind = 'success' })
            else
                inst:addScore(killer, -o.wrongKillPenalty, 'wrong_target')
                inst:push(killer, 'announce', { text = L('assassin_wrong_target'), kind = 'error' })
            end
        else
            if victim == inst.data.bountyOn then
                inst:addScore(killer, inst.data.bountyValue, 'bounty')
                inst:addStat(killer, 'objectives', 1)
                inst:announce('announce_bounty_claimed', 'success', killer.name, inst.data.bountyValue, victim.name)
                inst.data.bountyOn = nil
            else
                inst:addScore(killer, 1, 'kill')
                if killer == inst.data.bountyOn then
                    inst.data.bountyValue = inst.data.bountyValue + o.bountyGrowth
                    inst:broadcast('mode', { markPlayer = killer.src, markLabel = L('bounty_label', inst.data.bountyValue) })
                end
            end
            updateBounty(inst)
        end
        if o.scoreTarget > 0 and killer.score >= o.scoreTarget then inst:finishNow('score_target') end
    end,

    onLeave = function(inst, p)
        if inst.def.options.style == 'assassin' then
            for hunter, target in pairs(inst.data.targetOf) do
                if target == p and hunter.status == 'active' then
                    inst.data.targetOf[hunter] = nextLiving(inst, p)
                    sendTarget(inst, hunter)
                end
            end
        elseif inst.data.bountyOn == p then
            inst.data.bountyOn = nil
            updateBounty(inst)
        end
    end,

    onRejoin = function(inst, p) if inst.def.options.style == 'assassin' then sendTarget(inst, p) end end,

    hud = function(inst, p)
        local o = inst.def.options
        if o.style == 'assassin' then
            local t = inst.data.targetOf and inst.data.targetOf[p]
            return { score = p.score, kills = p.stats.kills, target = t and t.name or nil }
        end
        return { score = p.score, kills = p.stats.kills, target = inst.data.bountyOn and inst.data.bountyOn.name or nil }
    end,
})
