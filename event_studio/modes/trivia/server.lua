-- EVENT STUDIO — mode: trivia (server-timed questions; answers revealed only after each round)

local U = ES.Util

local function questionsFor(inst)
    local o = inst.def.options
    local pool = {}
    if o.questions and #o.questions > 0 then
        pool = U.deepCopy(o.questions)
    else
        pool = U.deepCopy((Config.Trivia or {})[o.questionSet] or (Config.Trivia or {}).general or {})
    end
    if o.shuffle then U.shuffle(pool) end
    local out = {}
    for i = 1, math.min(o.count, #pool) do out[i] = pool[i] end
    return out
end

local function ask(inst)
    local d = inst.data
    d.index = d.index + 1
    local q = d.questions[d.index]
    if not q then return inst:finishNow('questions_done') end
    d.phase = 'question'
    d.answers = {}
    d.sentAt = ES.now()
    d.closeAt = d.sentAt + inst.def.options.secondsPerQuestion * 1000
    inst:broadcast('mode', { trivia = {
        phase = 'question', index = d.index, total = #d.questions, text = q.q,
        answers = not q.numeric and q.answers or nil, numeric = q.numeric == true,
        remainingMs = inst.def.options.secondsPerQuestion * 1000,
    } })
end

local function reveal(inst)
    local d, o = inst.data, inst.def.options
    local q = d.questions[d.index]
    d.phase = 'reveal'
    local limit = o.secondsPerQuestion * 1000
    local gained = {}
    if q.numeric then
        local ranked = {}
        for p, a in pairs(d.answers) do ranked[#ranked + 1] = { p = p, diff = math.abs(a.value - q.answer), ms = a.ms } end
        table.sort(ranked, function(a, b) if a.diff ~= b.diff then return a.diff < b.diff end return a.ms < b.ms end)
        local table3 = { o.pointsCorrect, math.floor(o.pointsCorrect * 0.6), math.floor(o.pointsCorrect * 0.3) }
        for i, r in ipairs(ranked) do
            if table3[i] and table3[i] > 0 then gained[r.p] = table3[i] end
        end
    else
        for p, a in pairs(d.answers) do
            if a.choice == q.correct then
                gained[p] = o.pointsCorrect + math.floor(o.speedBonus * math.max(0, 1 - a.ms / limit))
            end
        end
    end
    for p, pts in pairs(gained) do
        if p.status == 'active' then
            inst:addScore(p, pts, 'trivia')
            inst:addStat(p, 'objectives', 1)
        end
    end
    local correctText = q.numeric and tostring(q.answer) or q.answers[q.correct]
    for _, p in ipairs(inst:activeParticipants()) do
        inst:push(p, 'mode', { trivia = { phase = 'reveal', index = d.index, correct = q.correct, correctText = correctText,
            gained = gained[p] or 0, answered = d.answers[p] ~= nil } })
    end
    for src in pairs(inst.spectators) do
        ES.push(src, 'mode', { trivia = { phase = 'reveal', index = d.index, correct = q.correct, correctText = correctText } })
    end
    d.nextAt = ES.now() + 4000
end

ES.RegisterMode('trivia', {
    label = 'Trivia',
    category = 'social',
    description = 'Server-timed multiple choice and closest-number questions with speed bonus.',
    teams = 'none',
    rankBy = 'score',
    arena = { none = true },
    objectiveKey = 'obj_trivia',
    rulesKey = 'rules_trivia',
    options = {
        questionSet = { type = 'string', maxLen = 32, default = 'general', label = 'Question set (config/trivia.lua)', order = 1 },
        questions = { type = 'list', item = 'table', maxItems = 100, optional = true, label = 'Inline questions (override set)', order = 2 },
        count = { type = 'integer', min = 1, max = 50, default = 10, label = 'Questions', order = 3 },
        secondsPerQuestion = { type = 'integer', min = 5, max = 60, default = 15, label = 'Seconds per question', order = 4 },
        pointsCorrect = { type = 'integer', min = 1, max = 100, default = 10, label = 'Points per correct answer', order = 5 },
        speedBonus = { type = 'integer', min = 0, max = 100, default = 5, label = 'Max speed bonus', order = 6 },
        shuffle = { type = 'boolean', default = true, label = 'Shuffle questions', order = 7 },
    },

    validate = function(def)
        local o = def.options
        if not (o.questions and #o.questions > 0) and not (Config.Trivia and Config.Trivia[o.questionSet]) then
            return false, 'unknown question set ' .. tostring(o.questionSet)
        end
        return true
    end,

    setup = function(inst)
        inst.data.questions = questionsFor(inst)
        inst.data.index = 0
    end,

    start = function(inst)
        inst.def.timing.duration = 0
        inst.deadline = nil
        ask(inst)
    end,

    tick = function(inst)
        local d = inst.data
        local now = ES.now()
        if d.phase == 'question' then
            local allAnswered = true
            for _, p in ipairs(inst:activeParticipants()) do if not d.answers[p] then allAnswered = false end end
            if now >= d.closeAt or allAnswered then reveal(inst) end
        elseif d.phase == 'reveal' and now >= d.nextAt then
            ask(inst)
        end
    end,

    onAction = function(inst, p, action, data)
        if action ~= 'answer' then return nil end
        local d = inst.data
        if d.phase ~= 'question' or p.status ~= 'active' then return false, 'closed' end
        if d.answers[p] then return false, 'already_answered' end
        local q = d.questions[d.index]
        local ms = ES.now() - d.sentAt
        if q.numeric then
            local v = tonumber(data.value)
            if not v or v ~= v or math.abs(v) > 1e9 then return false, 'bad_value' end
            d.answers[p] = { value = v, ms = ms }
        else
            local c = math.tointeger(data.choice)
            if not c or c < 1 or c > #q.answers then return false, 'bad_choice' end
            d.answers[p] = { choice = c, ms = ms }
        end
        return true
    end,

    hud = function(inst)
        return { question = inst.data.index or 0, questions = inst.data.questions and #inst.data.questions or 0 }
    end,
})
