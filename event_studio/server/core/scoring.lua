-- EVENT STUDIO — ranking, placement and season points (pure functions)

local Scoring = {}
ES.Scoring = Scoring

-- Status groups for ranking (lower = better)
local group = {
    finished = 1, active = 1, registered = 1,
    eliminated = 2,
    disconnected = 3, left = 3,
    disqualified = 4,
}
Scoring.statusGroup = group

---Current season identifier.
function Scoring.season(t)
    local s = Config.Scoring.season or 'monthly'
    t = t or os.time()
    if s == 'monthly' then return os.date('%Y-%m', t) end
    if s == 'yearly' then return os.date('%Y', t) end
    if s == 'quarterly' then
        local m = tonumber(os.date('%m', t))
        return ('%s-Q%d'):format(os.date('%Y', t), (m - 1) // 3 + 1)
    end
    return tostring(s)
end

function Scoring.profile(def)
    local s = def.scoring
    if type(s) == 'table' then
        return ES.Util.merge(Config.Scoring.profiles[Config.Scoring.defaultProfile] or {}, s)
    end
    return Config.Scoring.profiles[s] or Config.Scoring.profiles[Config.Scoring.defaultProfile] or {}
end

---Sort key tuple for a participant. Lower tuple = better. Equal tuples = tie.
function Scoring.key(p, strategy)
    local g = group[p.status] or 3
    if g == 1 then
        if strategy == 'finish' then
            if p.finishMs then return { 1, 0, p.finishMs, 0 } end
            return { 1, 1, -(p.progress or 0), -(p.score or 0) }
        end
        return { 1, -(p.score or 0), -(p.stats and p.stats.kills or 0), (p.scoreAt or 0) }
    elseif g == 2 then
        if strategy == 'finish' then
            return { 2, -(p.eliminatedAt or 0), -(p.progress or 0), 0 }
        end
        return { 2, -(p.eliminatedAt or 0), -(p.score or 0), 0 }
    elseif g == 3 then
        return { 3, -(p.score or 0), 0, 0 }
    end
    return { 4, 0, 0, 0 }
end

local function lessTuple(a, b)
    for i = 1, math.max(#a, #b) do
        local x, y = a[i] or 0, b[i] or 0
        if x ~= y then return x < y end
    end
    return false
end
Scoring.lessTuple = lessTuple

local function equalTuple(a, b)
    return not lessTuple(a, b) and not lessTuple(b, a)
end

---Rank a list of entries with a key function; assigns `placement` (ties share, 1,1,3). Disqualified → nil.
---@return table ordered list
function Scoring.rank(entries, keyFn)
    local keyed = {}
    for i, e in ipairs(entries) do keyed[i] = { e = e, k = keyFn(e), i = i } end
    table.sort(keyed, function(a, b)
        if lessTuple(a.k, b.k) then return true end
        if lessTuple(b.k, a.k) then return false end
        return a.i < b.i
    end)
    local out = {}
    local place = 0
    for idx, item in ipairs(keyed) do
        if item.k[1] >= 3 then
            -- left / disconnected / disqualified are listed but never placed
            item.e.placement = nil
        else
            if idx == 1 or not equalTuple(item.k, keyed[idx - 1].k) then place = idx end
            item.e.placement = place
        end
        out[idx] = item.e
    end
    return out
end

function Scoring.rankParticipants(list, strategy)
    return Scoring.rank(list, function(p) return Scoring.key(p, strategy) end)
end

---Team ranking: teams with a living member rank first by score; fully eliminated teams by elimination time.
function Scoring.rankTeams(teams, participants)
    for _, t in ipairs(teams) do
        local alive, lastElim, members = false, 0, 0
        for _, p in pairs(participants) do
            if p.team == t.index then
                members = members + 1
                local g = group[p.status] or 3
                if g == 1 then alive = true end
                if p.eliminatedAt and p.eliminatedAt > lastElim then lastElim = p.eliminatedAt end
            end
        end
        t.alive = alive
        t.lastElim = lastElim
        t.members = members
    end
    return Scoring.rank(teams, function(t)
        if t.members == 0 then return { 3, 0, 0 } end
        if t.alive then return { 1, -(t.score or 0), 0 } end
        return { 2, -(t.lastElim or 0), -(t.score or 0) }
    end)
end

---Season points for one participant after ranking.
---ctx = { everActive = bool, activeMs = number }
function Scoring.points(profile, p, ctx)
    local pts = 0
    local st = p.stats or {}
    if p.status == 'disqualified' then
        return profile.disqualifyPenalty or 0
    end
    local abandoned = (p.status == 'left' or p.status == 'disconnected')
    if abandoned then
        return profile.abandonPenalty or 0
    end
    if p.placement and profile.placement then
        pts = pts + (profile.placement[p.placement] or 0)
    end
    if ctx and ctx.everActive then pts = pts + (profile.participation or 0) end
    pts = pts + (profile.kill or 0) * (st.kills or 0)
    pts = pts + (profile.assist or 0) * (st.assists or 0)
    pts = pts + (profile.death or 0) * (st.deaths or 0)
    pts = pts + (profile.objective or 0) * (st.objectives or 0)
    pts = pts + (profile.checkpoint or 0) * (st.checkpoints or 0)
    pts = pts + (profile.lap or 0) * (st.laps or 0)
    if profile.survivalPerMinute and ctx and ctx.activeMs then
        pts = pts + math.floor(ctx.activeMs / 60000) * profile.survivalPerMinute
    end
    if profile.streak and profile.streak.every and profile.streak.every > 0 then
        pts = pts + ((st.bestStreak or 0) // profile.streak.every) * (profile.streak.bonus or 0)
    end
    if profile.timeBonus and p.finishMs then
        local tb = profile.timeBonus
        local under = (tb.targetSeconds * 1000 - p.finishMs) / 1000
        if under > 0 then pts = pts + math.min(tb.max or math.huge, math.floor(under * (tb.perSecondUnder or 1))) end
    end
    return math.floor(pts)
end

return Scoring
