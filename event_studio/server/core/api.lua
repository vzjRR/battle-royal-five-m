-- EVENT STUDIO — exports for third-party resources (see docs/API.md)

local U = ES.Util
local Log = ES.Log

local function publicState(inst)
    if not inst then return nil end
    local parts = {}
    for _, p in ipairs(inst:allParticipants()) do
        parts[#parts + 1] = { src = p.src, name = p.name, team = p.team, status = p.status, score = p.score,
                              placement = p.placement, stats = U.deepCopy(p.stats) }
    end
    return {
        id = inst.id, definitionId = inst.def.id, name = inst.def.name, mode = inst.def.mode, category = inst.def.category,
        state = inst.state, remainingMs = inst:remainingMs(), elapsedMs = inst:elapsedMs(),
        participants = parts, teams = #inst.teams > 0 and inst:publicTeams() or nil,
    }
end

local function withInstance(id, fn)
    local inst = ES.Manager.get(id)
    if not inst then return false, 'not_found' end
    return fn(inst)
end

local api = {}

-- Definitions & arenas
function api.RegisterDefinition(def) return ES.Definitions.register(def, 'api') end
function api.SaveDefinition(def)
    local ok, id = ES.Definitions.register(def, 'storage')
    if ok then ES.Storage.saveDocument('definition', id, ES.Definitions.get(id), GetInvokingResource()) end
    return ok, id
end
function api.GetDefinition(id) return U.deepCopy(ES.Definitions.get(id)) end
function api.GetDefinitions()
    local out = {}
    for _, d in ipairs(ES.Definitions.all()) do out[#out + 1] = ES.Definitions.summary(d) end
    return out
end
function api.RegisterArena(arena) return ES.Arenas.register(arena, 'api') end
function api.GetArena(id) return U.deepCopy(ES.Arenas.get(id)) end
function api.GetModes() return ES.describeModes() end

-- Instances
function api.CreateEvent(definitionId, opts)
    opts = opts or {}
    local startAt = opts.startIn and (os.time() + opts.startIn) or nil
    local ok, id = ES.Manager.create(definitionId, {
        registration = opts.registration, startAt = startAt, invite = opts.invite, overrides = opts.overrides,
        createdBy = 'api:' .. tostring(GetInvokingResource()), allowDraft = opts.allowDraft,
    })
    return ok, id
end
function api.StartEvent(id, force) return withInstance(id, function(i) return i:start(force == true) end) end
function api.StopEvent(id, reason) return withInstance(id, function(i) return i:finishNow(reason or 'api') end) end
function api.FinishEvent(id, reason) return withInstance(id, function(i) return i:finish(reason or 'api') end) end
function api.CancelEvent(id, reason) return withInstance(id, function(i) return i:cancel(reason or 'api') end) end
function api.PauseEvent(id) return withInstance(id, function(i) return i:pause() end) end
function api.ResumeEvent(id) return withInstance(id, function(i) return i:resume() end) end
function api.GetEventState(id) return publicState(ES.Manager.get(id)) end
function api.GetActiveEvents()
    local out = {}
    for _, i in ipairs(ES.Manager.list()) do out[#out + 1] = publicState(i) end
    return out
end
function api.GetPlayerEvent(src)
    local i = ES.Manager.ofPlayer(tonumber(src))
    return i and i.id or nil
end

-- Participants
function api.JoinPlayer(id, src, force) return ES.Manager.join(tonumber(src), id, force == true) end
function api.RemovePlayer(id, src, reason)
    return withInstance(id, function(i) return i:removeParticipant(tonumber(src), reason or 'removed') end)
end
function api.GetParticipants(id)
    local s = publicState(ES.Manager.get(id))
    return s and s.participants or nil
end
function api.SetTeam(id, src, team)
    return withInstance(id, function(i)
        local p = i.participants[tonumber(src)]
        if not p then return false, 'not_participant' end
        if i.state ~= 'REGISTRATION' and i.state ~= 'LOBBY' then return false, 'invalid_state' end
        if not i.teams[team] then return false, 'bad_team' end
        p.team = team
        i:dirty()
        return true
    end)
end

-- Gameplay
function api.GivePoints(id, src, amount, reason)
    return withInstance(id, function(i)
        local p = i.participants[tonumber(src)]
        if not p then return false, 'not_participant' end
        if type(amount) ~= 'number' then return false, 'bad_amount' end
        i:addScore(p, math.floor(amount), reason or 'api')
        Log.record('audit', 'api.points', GetInvokingResource(), i.id, { target = p.name, amount = amount, reason = reason })
        return true
    end)
end
function api.CompleteObjective(id, src, objectiveId, points)
    return withInstance(id, function(i)
        local p = i.participants[tonumber(src)]
        if not p or p.status ~= 'active' then return false, 'not_active' end
        i:addStat(p, 'objectives', 1)
        if points then i:addScore(p, math.floor(points), 'objective:' .. tostring(objectiveId)) end
        return true
    end)
end
function api.EliminatePlayer(id, src, reason)
    return withInstance(id, function(i) return i:eliminate(i.participants[tonumber(src)], reason or 'api') end)
end
function api.FinishPlayer(id, src)
    return withInstance(id, function(i) return i:markFinished(i.participants[tonumber(src)]) end)
end

-- Stats
function api.GetLeaderboard(category, season, limit) return ES.Stats.publicRows(ES.Stats.leaderboard(category, season, limit)) end
function api.GetPlayerStats(who, season)
    local identifier = type(who) == 'number' and ES.Bridge.getIdentifier(who) or who
    return ES.Stats.player(identifier, season)
end
function api.GetPersonalBests(defId, limit) return ES.Stats.bests(defId, limit) end

-- Rewards
function api.GiveReward(src, reward, reason)
    if type(reward) ~= 'table' then return false, 'bad_reward' end
    local ok = ES.Rewards.pay(tonumber(src), reward, { reason = reason or 'api', identifier = ES.Bridge.getIdentifier(src),
        name = GetPlayerName(tostring(src)) })
    Log.record('audit', 'api.reward', GetInvokingResource(), nil, { target = src, reward = reward, ok = ok })
    return ok
end
function api.RegisterRewardType(name, handler) return ES.Rewards.registerType(name, handler) end

-- Tournaments
function api.CreateTournament(cfg) return ES.Tournaments.create(cfg, 'api:' .. tostring(GetInvokingResource())) end
function api.GetTournament(id)
    local t = ES.Tournaments.list[id]
    return t and ES.Tournaments.public(t) or nil
end

for name, fn in pairs(api) do exports(name, fn) end
ES.API = api
