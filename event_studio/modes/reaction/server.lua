-- EVENT STUDIO — mode: reaction (server-timed reflex rounds, ping-compensated)

local U = ES.Util

local function nextRound(inst)
    local d, o = inst.data, inst.def.options
    d.round = d.round + 1
    if d.round > o.rounds then return inst:finishNow('rounds_done') end
    d.phase = 'ready'
    d.reactions, d.early = {}, {}
    d.goAt = ES.now() + math.floor((o.minDelay + math.random() * (o.maxDelay - o.minDelay)) * 1000)
    inst:broadcast('mode', { reaction = { phase = 'ready', round = d.round, rounds = o.rounds } })
end

local function closeRound(inst)
    local d, o = inst.data, inst.def.options
    d.phase = 'results'
    local list = {}
    for p, ms in pairs(d.reactions) do list[#list + 1] = { p = p, ms = ms } end
    table.sort(list, function(a, b) return a.ms < b.ms end)
    local summary = {}
    for i, r in ipairs(list) do
        local pts = o.points[i] or 0
        if pts > 0 and r.p.status == 'active' then inst:addScore(r.p, pts, 'reaction') end
        summary[#summary + 1] = { name = r.p.name, ms = r.ms, points = pts }
        if not r.p.bestReaction or r.ms < r.p.bestReaction then r.p.bestReaction = r.ms end
    end
    inst:broadcast('mode', { reaction = { phase = 'results', round = d.round, rows = summary } })
    d.nextAt = ES.now() + 3500
end

ES.RegisterMode('reaction', {
    label = 'Reaction Challenge',
    category = 'social',
    description = 'Press as soon as the signal appears. Early presses are penalised. Server-timed with ping compensation.',
    teams = 'none',
    rankBy = 'score',
    arena = { none = true },
    objectiveKey = 'obj_reaction',
    rulesKey = 'rules_reaction',
    options = {
        rounds = { type = 'integer', min = 1, max = 20, default = 5, label = 'Rounds', order = 1 },
        minDelay = { type = 'number', min = 1, max = 20, default = 2, label = 'Min delay (s)', order = 2 },
        maxDelay = { type = 'number', min = 1, max = 30, default = 6, label = 'Max delay (s)', order = 3 },
        earlyPenalty = { type = 'integer', min = 0, max = 50, default = 5, label = 'Early press penalty', order = 4 },
        points = { type = 'list', item = 'integer', default = { 10, 7, 5, 3, 1 }, label = 'Points by rank', order = 5 },
        windowMs = { type = 'integer', min = 1000, max = 10000, default = 3000, label = 'Response window (ms)', order = 6 },
    },

    validate = function(def)
        if def.options.minDelay > def.options.maxDelay then return false, 'minDelay must be <= maxDelay' end
        return true
    end,

    setup = function(inst) inst.data.round = 0 end,

    start = function(inst)
        inst.deadline = nil
        nextRound(inst)
    end,

    tick = function(inst)
        local d, o = inst.data, inst.def.options
        local now = ES.now()
        if d.phase == 'ready' and now >= d.goAt then
            d.phase = 'go'
            d.goAt = now
            inst:broadcast('mode', { reaction = { phase = 'go', round = d.round } })
        elseif d.phase == 'go' and now - d.goAt >= o.windowMs then
            closeRound(inst)
        elseif d.phase == 'results' and now >= d.nextAt then
            nextRound(inst)
        end
    end,

    onAction = function(inst, p, action)
        if action ~= 'react' then return nil end
        local d, o = inst.data, inst.def.options
        if p.status ~= 'active' then return false, 'not_active' end
        if d.phase == 'ready' then
            if not d.early[p] then
                d.early[p] = true
                inst:addScore(p, -o.earlyPenalty, 'early')
                inst:push(p, 'mode', { reaction = { phase = 'early' } })
            end
            return true
        end
        if d.phase ~= 'go' or d.reactions[p] or d.early[p] then return false, 'closed' end
        local ping = GetPlayerPing(tostring(p.src)) or 0
        d.reactions[p] = math.max(50, (ES.now() - d.goAt) - ping)
        inst:push(p, 'mode', { reaction = { phase = 'recorded', ms = d.reactions[p] } })
        return true
    end,

    hud = function(inst, p)
        return { round = inst.data.round or 0, rounds = inst.def.options.rounds, best = p.bestReaction }
    end,

    rowExtra = function(_, p) return p.bestReaction and (p.bestReaction .. ' ms') or nil end,
})
