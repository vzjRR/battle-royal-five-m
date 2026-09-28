-- EVENT STUDIO — player RPCs (browser, join/leave, spectate, actions, leaderboards)

local U = ES.Util
local RPC = ES.RPC
local S = ES.Lifecycle.States
local Lifecycle = ES.Lifecycle

local function canSee(src, inst)
    if inst.invite then return inst.invite[src] == true or ES.Perm.level(src) > 0 end
    local v = inst.def.visibility
    if v == 'public' then return true end
    if v == 'staff' then return ES.Perm.level(src) > 0 end
    return false
end

---Browser card for an instance.
function ES.instanceCard(inst, src)
    local d = inst.def
    local ui = (ES.UI and ES.UI.effective().categories or Config.UI.categories)[d.category] or {}
    local count = inst:participantCount({ registered = true, active = true, finished = true, eliminated = true })
    local full = count >= d.players.max
    return {
        id = inst.id, definition = d.id, name = d.name, description = d.description, category = d.category,
        icon = d.icon or ui.icon, color = ui.color, banner = d.banner, mode = d.mode,
        modeLabel = inst.mode.label, difficulty = d.difficulty, state = inst.state,
        status = Lifecycle.publicStatus(inst.state, full), players = count, maxPlayers = d.players.max,
        minPlayers = d.players.min, remainingMs = inst:remainingMs(), duration = d.timing.duration,
        startAt = inst.startAt, reward = ES.Rewards.preview(d), teams = d.players.teams and d.players.teams.count or nil,
        spectators = d.players.spectators, joined = src and inst.participants[src] ~= nil or false,
        spectating = src and inst.spectators[src] ~= nil or false, invite = inst.invite ~= nil,
    }
end

-- Each player's language (the flag switch in the event window). Messages to that player use it.
ES.PlayerLocales = ES.PlayerLocales or {}
local function setLocale(src, code)
    if type(code) == 'string' and code:sub(1, 1) ~= '_' and ES.Locales[code] then ES.PlayerLocales[src] = code end
end
AddEventHandler('playerDropped', function() ES.PlayerLocales[source] = nil end)

RPC.register('player:locale', { public = true, schema = { code = { type = 'string', maxLen = 8 } }, rate = { burst = 4, per = 10 } }, function(src, data)
    if not ES.Locales[data.code] or data.code:sub(1, 1) == '_' then return false, 'unknown_locale' end
    setLocale(src, data.code)
    return { strings = ES.uiStrings(data.code), locale = ES.localeInfo(data.code) }
end)

RPC.register('client:ready', { public = true, schema = { locale = { type = 'string', maxLen = 8, optional = true } }, rate = { burst = 3, per = 30 } }, function(src, data)
    setLocale(src, data and data.locale)
    local code = ES.PlayerLocales[src]
    local level, role = ES.Perm.level(src)
    local recovery = ES.Manager.onClientReady(src)
    Citizen.CreateThread(function() Citizen.Wait(5000) ES.Rewards.deliverPending(src) end)
    Citizen.CreateThread(function() Citizen.Wait(3000) TriggerEvent('event_studio:clientReady', src) end)
    return {
        version = ES.version, ui = ES.UI.effective(), commands = level > 0 and Config.Commands or nil, strings = ES.uiStrings(code), locale = ES.localeInfo(code),
        framework = ES.Bridge.name, staff = level > 0, role = role, recovery = recovery,
        scoring = Config.Scoring.profiles,
    }
end)

RPC.register('browser:list', { public = true, rate = { burst = 6, per = 10 } }, function(src)
    local live = {}
    for _, inst in ipairs(ES.Manager.list()) do
        if inst.state ~= S.ARCHIVED and canSee(src, inst) then live[#live + 1] = ES.instanceCard(inst, src) end
    end
    local upcoming = {}
    for _, u in ipairs(ES.Scheduler.upcoming(12)) do
        if u.visibility == 'public' then upcoming[#upcoming + 1] = u end
    end
    local tournaments = {}
    for _, t in pairs(ES.Tournaments.list) do
        if t.status == 'registration' or t.status == 'running' then
            tournaments[#tournaments + 1] = { id = t.id, name = t.name, status = t.status, format = t.format,
                bestOf = t.bestOf, entrants = #t.entrants, registrationEndsAt = t.registrationEndsAt }
        end
    end
    local current = ES.Manager.ofPlayer(src)
    return { live = live, upcoming = upcoming, tournaments = tournaments, now = os.time(), current = current and current.id or nil }
end)

RPC.register('browser:details', { public = true, schema = { id = 'integer' }, rate = { burst = 8, per = 10 } }, function(src, data)
    local inst = ES.Manager.get(data.id)
    if not inst or not canSee(src, inst) then return false, 'not_found' end
    local card = ES.instanceCard(inst, src)
    local names = {}
    for _, p in ipairs(inst:allParticipants()) do
        names[#names + 1] = { name = p.name, team = p.team, status = p.status }
    end
    card.participants = names
    card.rules = inst.mode.rulesKey and L(inst.mode.rulesKey) or nil
    card.scoring = ES.Scoring.profile(inst.def)
    local rewards = {}
    local r = inst.def.rewards or {}
    for place = 1, 3 do
        local list = r.placement and (r.placement[place] or r.placement[tostring(place)])
        if list then rewards[#rewards + 1] = { label = '#' .. place, items = U.map(list, ES.Rewards.describe) } end
    end
    if r.participation then rewards[#rewards + 1] = { label = 'participation', items = U.map(r.participation, ES.Rewards.describe) } end
    card.rewards = rewards
    card.teamsInfo = #inst.teams > 0 and inst:publicTeams() or nil
    if inst.mode.personalBests then
        card.bests = ES.Stats.publicRows(ES.Stats.bests(inst.def.id, 5))
    end
    return card
end)

RPC.register('event:join', { public = true, schema = { id = 'integer?' }, rate = { burst = 4, per = 10 } }, function(src, data)
    local id = data.id
    if not id then
        local open = {}
        for _, inst in ipairs(ES.Manager.list()) do
            if inst.state == S.REGISTRATION and canSee(src, inst) and not inst.invite then open[#open + 1] = inst end
        end
        if #open == 0 then return false, 'none_open' end
        if #open > 1 then return false, 'multiple_open' end
        id = open[1].id
    end
    local inst = ES.Manager.get(id)
    if not inst or not canSee(src, inst) then return false, 'not_found' end
    local ok, err = ES.Manager.join(src, id)
    if not ok then return false, err end
    return true, { id = id }
end)

RPC.register('event:leave', { public = true, rate = { burst = 4, per = 10 } }, function(src)
    return ES.Manager.leave(src, 'left')
end)

RPC.register('event:spectate', { public = true, schema = { id = 'integer?' }, rate = { burst = 4, per = 10 } }, function(src, data)
    local id = data.id
    if not id then
        for _, inst in ipairs(ES.Manager.list()) do
            if Lifecycle.isLive(inst.state) and canSee(src, inst) and inst.def.players.spectators then id = inst.id break end
        end
        if not id then return false, 'none_live' end
    end
    local inst = ES.Manager.get(id)
    if not inst or not canSee(src, inst) then return false, 'not_found' end
    return ES.Manager.spectate(src, id, false)
end)

RPC.register('event:action', {
    public = true,
    schema = { action = { type = 'string', maxLen = 32, pattern = '^[%w_]+$' }, data = 'table?' },
    rate = { burst = 20, per = 4 },
}, function(src, data)
    local inst = ES.Manager.ofPlayer(src)
    if not inst then return false, 'not_in_event' end
    return inst:handleAction(src, data.action, data.data or {})
end)

RPC.register('event:team', { public = true, schema = { team = { type = 'integer', min = 1, max = 8 } }, rate = { burst = 4, per = 10 } },
function(src, data)
    local inst = ES.Manager.ofPlayer(src)
    local p = inst and inst.participants[src]
    if not p or inst.state ~= S.REGISTRATION then return false, 'invalid_state' end
    local t = inst.def.players.teams
    if not t or t.auto or data.team > t.count then return false, 'not_allowed' end
    local size = t.size or math.ceil(inst.def.players.max / t.count)
    local n = 0
    for _, other in pairs(inst.participants) do if other.team == data.team then n = n + 1 end end
    if n >= size then return false, 'team_full' end
    p.team = data.team
    inst:syncState(src)
    return true
end)

RPC.register('spectate:coords', { public = true, schema = { target = 'integer' }, rate = { burst = 8, per = 4 } }, function(src, data)
    local inst = ES.Manager.ofPlayer(src)
    if not inst then return false, 'not_in_event' end
    local isSpectator = inst.spectators[src] ~= nil
    local me = inst.participants[src]
    if not isSpectator and not (me and me.status ~= 'active') then return false, 'not_spectating' end
    local target = inst.participants[data.target]
    if not target then return false, 'bad_target' end
    local ped = GetPlayerPed(data.target)
    return U.vec(GetEntityCoords(ped))
end)

RPC.register('spectate:stop', { public = true, rate = { burst = 4, per = 10 } }, function(src)
    local inst = ES.Manager.ofPlayer(src)
    if not inst then return false, 'not_in_event' end
    if inst.spectators[src] then return inst:removeSpectator(src, 'spectate_end') end
    local p = inst.participants[src]
    if p and p.status ~= 'active' then return inst:removeParticipant(src, 'left_after_elimination') end
    return false, 'not_spectating'
end)

RPC.register('leaderboard:get', {
    public = true,
    schema = { category = { type = 'string', maxLen = 32, optional = true }, season = { type = 'string', maxLen = 16, optional = true } },
    rate = { burst = 5, per = 10 },
}, function(src, data)
    local category = data.category or '*'
    if category ~= '*' and not ES.Categories[category] then return false, 'bad_category' end
    local rows = ES.Stats.leaderboard(category, data.season, 25)
    local mine = ES.Stats.player(ES.Bridge.getIdentifier(src), data.season)
    return { rows = ES.Stats.publicRows(rows), season = data.season or ES.Scoring.season(), category = category, mine = mine }
end)

RPC.register('tournament:join', { public = true, schema = { id = { type = 'string', maxLen = 32 } }, rate = { burst = 3, per = 10 } },
function(src, data)
    return ES.Tournaments.join(data.id, src)
end)
