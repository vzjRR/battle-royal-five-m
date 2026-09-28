-- EVENT STUDIO — admin RPCs (every handler is permission-gated and audited)

local U = ES.Util
local RPC = ES.RPC
local Log = ES.Log
local Lifecycle = ES.Lifecycle

local function inst(id)
    local i = ES.Manager.get(id)
    if not i then return nil, 'not_found' end
    return i
end

local function liveDetail(i)
    local parts = {}
    for _, p in ipairs(i:allParticipants()) do
        parts[#parts + 1] = {
            src = p.src, name = p.name, status = p.status, team = p.team, score = p.score, lives = p.lives,
            stats = p.stats, progress = p.progress and U.round(p.progress, 2) or nil, finishMs = p.finishMs,
            ping = p.src and GetPlayerPing(tostring(p.src)) or nil,
        }
    end
    table.sort(parts, function(a, b) return (a.score or 0) > (b.score or 0) end)
    local specs = {}
    for src, s in pairs(i.spectators) do specs[#specs + 1] = { src = src, name = GetPlayerName(tostring(src)), admin = s.admin } end
    local rows = i:scoreRows()
    local zones
    local z = i:component('zones')
    if z then
        zones = {}
        for idx, zone in ipairs(z.order) do zones[idx] = z:publicZone(zone) end
    end
    return {
        card = ES.instanceCard(i), state = i.state, remainingMs = i:remainingMs(), elapsedMs = i:elapsedMs(),
        bucket = i.bucket, participants = parts, spectators = specs, teams = #i.teams > 0 and i:publicTeams() or nil,
        leader = rows[1] and rows[1].name or nil, zones = zones, results = i.results and U.map(i.results, function(r)
            return { name = r.name, placement = r.placement, points = r.points, score = r.score, status = r.status }
        end) or nil, createdBy = i.createdBy, tournament = i.tournament,
        awaitingStart = i.awaitingStart == true, countdown = (Config.General.flow and Config.General.flow.countdown) or 10,
    }
end

----------------------------------------------------------------------------
-- Bootstrap
----------------------------------------------------------------------------

RPC.register('admin:bootstrap', { perm = 'admin.open', rate = { burst = 4, per = 10 } }, function(src)
    local defs = {}
    for _, d in ipairs(ES.Definitions.all()) do defs[#defs + 1] = ES.Definitions.summary(d) end
    local arenas = {}
    for _, a in ipairs(ES.Arenas.all()) do
        arenas[#arenas + 1] = { id = a.id, name = a.name, source = ES.Arenas.source[a.id], route = ES.Arenas.routeType(a),
            checked = a.checked and { at = a.checked.at, problems = a.checked.problems } or nil,
            counts = { spawns = a.spawns and #a.spawns or 0, checkpoints = a.checkpoints and #a.checkpoints or 0,
                       zones = a.zones and #a.zones or 0, targets = a.targets and #a.targets or 0,
                       vehicleSpawns = a.vehicleSpawns and #a.vehicleSpawns or 0, objectives = a.objectives and #a.objectives or 0,
                       teamSpawns = a.teamSpawns and #a.teamSpawns or 0 } }
    end
    local instances = {}
    for _, i in ipairs(ES.Manager.list()) do instances[#instances + 1] = ES.instanceCard(i) end
    local level, role = ES.Perm.level(src)
    return {
        version = ES.version, role = role, level = level, perms = ES.Perm.allowedActions(src),
        modes = ES.describeModes(), definitions = defs, arenas = arenas, instances = instances,
        schedules = ES.Scheduler.list(), rotations = ES.Scheduler.rotations, upcoming = ES.Scheduler.upcoming(10),
        scoringProfiles = U.keys(Config.Scoring.profiles), categories = U.keys(ES.Categories),
        director = ES.Director.enabled, storage = ES.Storage.adapter, framework = ES.Bridge.name,
        inventory = ES.Bridge.inventory, season = ES.Scoring.season(),
        tournaments = U.map(U.values(ES.Tournaments.list), ES.Tournaments.public),
        definitionDefaults = Config.General.definitionDefaults,
    }
end)

RPC.register('admin:instances', { perm = 'admin.open', rate = { burst = 10, per = 10 } }, function()
    local out = {}
    for _, i in ipairs(ES.Manager.list()) do out[#out + 1] = ES.instanceCard(i) end
    return out
end)

RPC.register('admin:players:online', { perm = 'admin.open', rate = { burst = 5, per = 10 } }, function()
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        local i = ES.Manager.ofPlayer(s)
        out[#out + 1] = { src = s, name = GetPlayerName(id), inEvent = i and i.id or nil }
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end)

RPC.register('admin:history', { perm = 'definition.view', rate = { burst = 4, per = 10 } }, function()
    return ES.Storage.recentInstances(25) or {}
end)

RPC.register('admin:logs', {
    perm = 'logs.view',
    schema = { limit = { type = 'integer', min = 1, max = 300, default = 100 }, level = { type = 'string', maxLen = 16, optional = true } },
    rate = { burst = 4, per = 10 },
}, function(_, data)
    return ES.Storage.recentLogs(data.limit, data.level) or {}
end)

----------------------------------------------------------------------------
-- Definitions & arenas
----------------------------------------------------------------------------

RPC.register('admin:definition:get', { perm = 'definition.view', schema = { id = 'id' } }, function(_, data)
    local d = ES.Definitions.get(data.id)
    if not d then return false, 'not_found' end
    return U.deepCopy(d)
end)

RPC.register('admin:definition:save', { perm = 'definition.edit', schema = { def = 'table' }, rate = { burst = 5, per = 10 } },
function(src, data)
    local ok, idOrErr = ES.Definitions.register(data.def, 'storage')
    if not ok then return false, idOrErr end
    local d = ES.Definitions.get(idOrErr)
    ES.Storage.saveDocument('definition', d.id, d, Log.actorLabel(src))
    Log.audit('definition.saved', src, nil, { id = d.id, name = d.name })
    return true, ES.Definitions.summary(d)
end)

RPC.register('admin:definition:toggle', { perm = 'definition.edit', schema = { id = 'id', enabled = 'boolean' } }, function(src, data)
    local d = ES.Definitions.get(data.id)
    if not d then return false, 'not_found' end
    d.enabled = data.enabled
    ES.Definitions.source[d.id] = 'storage'
    ES.Storage.saveDocument('definition', d.id, d, Log.actorLabel(src))
    Log.audit('definition.toggled', src, nil, { id = d.id, enabled = d.enabled })
    return true
end)

RPC.register('admin:definition:delete', { perm = 'definition.delete', confirm = true, schema = { id = 'id' } }, function(src, data)
    local d = ES.Definitions.get(data.id)
    if not d then return false, 'not_found' end
    ES.Storage.deleteDocument('definition', d.id)
    local fromConfig
    for _, cd in ipairs(ES.ConfigDefinitions) do if cd.id == d.id then fromConfig = cd end end
    if fromConfig then
        -- revert to the config preset instead of removing it
        ES.Definitions.register(fromConfig, 'config')
    else
        ES.Definitions.remove(d.id)
    end
    Log.audit('definition.deleted', src, nil, { id = d.id })
    return true
end)

RPC.register('admin:arena:get', { perm = 'definition.view', schema = { id = 'id' } }, function(_, data)
    local a = ES.Arenas.get(data.id)
    if not a then return false, 'not_found' end
    return U.deepCopy(a)
end)

RPC.register('admin:arena:save', { perm = 'arena.edit', schema = { arena = 'table' }, rate = { burst = 5, per = 10 } }, function(src, data)
    local ok, idOrErr = ES.Arenas.register(data.arena, 'storage')
    if not ok then return false, idOrErr end
    ES.Storage.saveDocument('arena', idOrErr, ES.Arenas.get(idOrErr), Log.actorLabel(src))
    Log.audit('arena.saved', src, nil, { id = idOrErr })
    return true, idOrErr
end)

---Builder helper: the admin's own position (for "add point here").
RPC.register('admin:position', { perm = 'arena.edit', rate = { burst = 20, per = 10 } }, function(src)
    local ped = GetPlayerPed(src)
    local c = U.vec(GetEntityCoords(ped))
    local veh = GetVehiclePedIsIn(ped, false)
    c.w = U.round(veh ~= 0 and GetEntityHeading(veh) or GetEntityHeading(ped), 1)
    c.x, c.y, c.z = U.round(c.x, 2), U.round(c.y, 2), U.round(c.z, 2)
    return c
end)

----------------------------------------------------------------------------
-- Scheduler / director
----------------------------------------------------------------------------

RPC.register('admin:schedule:save', { perm = 'schedule.edit', schema = { schedule = 'table' } }, function(src, data)
    local ok, idOrErr = ES.Scheduler.put(data.schedule, 'storage')
    if not ok then return false, idOrErr end
    local s = ES.Scheduler.schedules[idOrErr]
    local doc = { id = s.id, enabled = s.enabled, definition = s.definition, rotation = s.rotation, rule = s.rule,
                  leadMinutes = s.leadMinutes, label = s.label }
    ES.Storage.saveDocument('schedule', s.id, doc, Log.actorLabel(src))
    Log.audit('schedule.saved', src, nil, doc)
    Log.record('lifecycle', 'schedule.created', src, nil, doc)
    return true, ES.Scheduler.list()
end)

RPC.register('admin:schedule:toggle', { perm = 'schedule.edit', schema = { id = 'id', enabled = 'boolean' } }, function(src, data)
    local s = ES.Scheduler.schedules[data.id]
    if not s then return false, 'not_found' end
    s.enabled = data.enabled
    s.nextAt = nil
    ES.Storage.saveDocument('schedule', s.id, { id = s.id, enabled = s.enabled, definition = s.definition, rotation = s.rotation,
        rule = s.rule, leadMinutes = s.leadMinutes, label = s.label }, Log.actorLabel(src))
    Log.audit('schedule.toggled', src, nil, { id = s.id, enabled = s.enabled })
    return true
end)

RPC.register('admin:schedule:delete', { perm = 'schedule.edit', confirm = true, schema = { id = 'id' } }, function(src, data)
    local s = ES.Scheduler.schedules[data.id]
    if not s then return false, 'not_found' end
    if s.source == 'config' then return false, 'config_schedule' end
    ES.Scheduler.remove(data.id)
    ES.Storage.deleteDocument('schedule', data.id)
    Log.audit('schedule.deleted', src, nil, { id = data.id })
    return true
end)

RPC.register('admin:director:toggle', { perm = 'director.toggle', schema = { enabled = 'boolean' } }, function(src, data)
    ES.Director.setEnabled(data.enabled)
    Log.audit('director.toggled', src, nil, { enabled = data.enabled })
    return true
end)

----------------------------------------------------------------------------
-- Live instance control
----------------------------------------------------------------------------

RPC.register('admin:instance:create', {
    perm = 'instance.create',
    schema = { definition = 'id', registration = { type = 'integer', min = 5, max = 86400, optional = true } },
    rate = { burst = 4, per = 10 },
}, function(src, data)
    local ok, id = ES.Manager.create(data.definition, { registration = data.registration, createdBy = src, allowDraft = true })
    if not ok then return false, id end
    Log.audit('instance.created', src, id, { definition = data.definition })
    return true, { id = id }
end)

RPC.register('admin:instance:detail', { perm = 'admin.open', schema = { id = 'integer' }, rate = { burst = 10, per = 5 } }, function(_, data)
    local i, err = inst(data.id)
    if not i then return false, err end
    return liveDetail(i)
end)

local function control(name, perm, confirm, fn)
    RPC.register('admin:instance:' .. name, { perm = perm, confirm = confirm, schema = { id = 'integer' } }, function(src, data)
        local i, err = inst(data.id)
        if not i then return false, err end
        local ok, res = fn(i, src)
        if ok == false then return false, res end
        Log.audit('instance.' .. name, src, i.id, { definition = i.def.id })
        return true
    end)
end

control('start', 'instance.start', false, function(i) return i:start(false) end)
control('forceStart', 'instance.start', true, function(i) return i:start(true) end)
control('go', 'instance.start', false, function(i) return i:go() end) -- the host starts the countdown

---The host key / `/eventstart [id]` (outside the Admin Center): closes registration, and when the players are in the
---arena starts the countdown. Without an id it picks the event the host is in, else the only one waiting.
local function startTarget(src, id)
    if id then return ES.Manager.get(id) end
    local mine = ES.Manager.ofPlayer(src)
    if mine and (mine.awaitingStart or mine.state == ES.Lifecycle.States.REGISTRATION) then return mine end
    local waiting, open = {}, {}
    for _, i in pairs(ES.Manager.instances) do
        if i.state == ES.Lifecycle.States.LOBBY and i.awaitingStart then waiting[#waiting + 1] = i end
        if i.state == ES.Lifecycle.States.REGISTRATION then open[#open + 1] = i end
    end
    if #waiting == 1 then return waiting[1] end
    if #waiting > 1 then return nil, 'multiple_waiting' end
    if #open == 1 then return open[1] end
    if #open > 1 then return nil, 'multiple_waiting' end
    return nil, 'nothing_to_start'
end

RPC.register('host:start', { perm = 'instance.start', schema = { id = 'integer?' }, rate = { burst = 3, per = 5 } }, function(src, data)
    local i, err = startTarget(src, data.id)
    if not i then return false, err or 'not_found' end
    local ok, res, step
    if i.state == ES.Lifecycle.States.REGISTRATION or i.state == ES.Lifecycle.States.SCHEDULED then
        ok, res = i:start(false)
        step = 'registration_closed'
    else
        ok, res = i:go()
        step = 'countdown'
    end
    if ok == false then return false, res end
    Log.audit('instance.host_start', src, i.id, { step = step })
    return { id = i.id, name = i.def.name, step = step }
end)

-- staff who join while an event waits for Start get its card too
AddEventHandler('event_studio:clientReady', function(src)
    if not ES.Perm.can(src, 'instance.start') then return end
    for _, i in pairs(ES.Manager.instances) do
        if i.state == ES.Lifecycle.States.LOBBY and i.awaitingStart then ES.push(src, 'hostPrompt', i:hostPrompt()) end
    end
end)
control('pause', 'instance.pause', false, function(i) return i:pause() end)
control('resume', 'instance.pause', false, function(i) return i:resume() end)
control('stop', 'instance.stop', true, function(i) return i:finishNow('admin') end)
control('cancel', 'instance.cancel', true, function(i) return i:cancel('admin') end)
control('restart', 'instance.restart', true, function(i, src)
    local players = {}
    for s in pairs(i.participants) do players[#players + 1] = s end
    local defId = i.def.id
    i:cancel('restart')
    local ok, newId = ES.Manager.create(defId, { registration = 20, createdBy = src, allowDraft = true })
    if not ok then return false, newId end
    -- players are returned on archive (next tick); re-register them after that
    SetTimeout(1500, function()
        for _, s in ipairs(players) do ES.Manager.join(s, newId, true) end
    end)
    return true
end)

RPC.register('admin:instance:announce', {
    perm = 'instance.announce',
    schema = { id = 'integer?', text = { type = 'string', maxLen = 200, minLen = 1 }, chat = 'boolean?' },
    rate = { burst = 3, per = 10 },
}, function(src, data)
    local text = data.text:gsub('[<>]', '')
    if data.id then
        local i, err = inst(data.id)
        if not i then return false, err end
        ES.Announce.custom(i:audience(), text, { 'nui' })
    else
        ES.Announce.custom(-1, text, data.chat and { 'nui', 'chat' } or { 'nui' })
    end
    Log.audit('announce', src, data.id, { text = text })
    return true
end)

RPC.register('admin:instance:score', {
    perm = 'instance.manualScore',
    schema = { id = 'integer', target = 'integer', amount = { type = 'integer', min = -10000, max = 10000 },
               reason = { type = 'string', maxLen = 64, optional = true } },
}, function(src, data)
    local i, err = inst(data.id)
    if not i then return false, err end
    local p = i.participants[data.target]
    if not p then return false, 'not_participant' end
    i:addScore(p, data.amount, 'manual')
    Log.audit('score.manual', src, i.id, { target = p.name, amount = data.amount, reason = data.reason })
    return true
end)

----------------------------------------------------------------------------
-- Player management inside an instance
----------------------------------------------------------------------------

local function playerAction(name, perm, confirm, fn)
    RPC.register('admin:player:' .. name, {
        perm = perm, confirm = confirm,
        schema = { id = 'integer', target = 'integer', to = { type = 'enum', values = { 'spawn', 'me', 'target' }, optional = true } },
    }, function(src, data)
        local i, err = inst(data.id)
        if not i then return false, err end
        if not GetPlayerName(tostring(data.target)) then return false, 'player_offline' end
        local ok, res = fn(i, src, data.target, data)
        if ok == false then return false, res end
        Log.audit('player.' .. name, src, i.id, { target = GetPlayerName(tostring(data.target)) })
        return true
    end)
end

playerAction('add', 'player.add', false, function(i, _, target) return ES.Manager.join(target, i.id, true) end)
playerAction('remove', 'player.remove', true, function(i, _, target)
    if i.spectators[target] then return i:removeSpectator(target, 'removed') end
    return i:removeParticipant(target, 'removed')
end)
playerAction('disqualify', 'player.disqualify', true, function(i, src, target) return i:disqualify(target, src) end)
playerAction('reset', 'player.reset', false, function(i, _, target)
    local p = i.participants[target]
    if not p or p.status ~= 'active' then return false, 'not_active' end
    i:respawn(p)
    local veh = i:component('vehicles')
    if veh then veh:provision(p, p.spawnPoint) end
    local combat = i:component('combat')
    if combat then combat.alive[p] = true combat:giveLoadout(p) end
    return true
end)
playerAction('teleport', 'player.teleport', false, function(i, src, target, data)
    local p = i.participants[target]
    if not p then return false, 'not_participant' end
    if data.to == 'me' then
        if ES.Manager.ofPlayer(src) ~= i then return false, 'admin_not_in_instance' end
        local c = U.vec(GetEntityCoords(GetPlayerPed(src)))
        ES.push(target, 'teleport', { coords = c, heading = GetEntityHeading(GetPlayerPed(src)) })
    else
        local spawns = i:component('spawns')
        if not spawns then return false, 'no_spawns' end
        spawns:teleport(p, p.spawnPoint)
    end
    return true
end)

RPC.register('admin:player:reward', {
    perm = 'player.reward', confirm = true,
    schema = { target = 'integer', reward = { type = 'object', fields = {
        type = { type = 'enum', values = { 'cash', 'bank', 'item', 'xp' } },
        amount = { type = 'integer', min = 1, max = 10000000, optional = true },
        name = { type = 'string', maxLen = 64, optional = true },
        count = { type = 'integer', min = 1, max = 1000, optional = true },
    } }, reason = { type = 'string', maxLen = 64, optional = true } },
    rate = { burst = 3, per = 10 },
}, function(src, data)
    if not GetPlayerName(tostring(data.target)) then return false, 'player_offline' end
    local identifier = ES.Bridge.getIdentifier(data.target)
    local key = ('manual:%d:%s:%d'):format(os.time(), identifier, src)
    if not ES.Storage.claimPayout(key, 0, identifier, data.reward) then return false, 'duplicate' end
    local ok = ES.Rewards.pay(data.target, data.reward, { reason = data.reason or 'event manual reward', identifier = identifier,
        name = GetPlayerName(tostring(data.target)) })
    ES.Storage.markPayout(key, ok and 'paid' or 'failed')
    Log.audit('reward.manual', src, nil, { target = GetPlayerName(tostring(data.target)), reward = data.reward, ok = ok })
    if not ok then return false, 'reward_failed' end
    ES.push(data.target, 'announce', ES.say(data.target, 'success', 'reward_received', ES.Rewards.describe(data.reward)))
    return true
end)

RPC.register('admin:spectate', { perm = 'spectate.any', schema = { id = 'integer' } }, function(src, data)
    local i, err = inst(data.id)
    if not i then return false, err end
    local ok, res = ES.Manager.spectate(src, i.id, true)
    if ok then Log.audit('spectate', src, i.id) end
    return ok, res
end)

----------------------------------------------------------------------------
-- Tournaments
----------------------------------------------------------------------------

RPC.register('admin:tournament:create', {
    perm = 'tournament.edit',
    schema = {
        name = { type = 'string', maxLen = 64, optional = true },
        definitionId = 'id',
        format = { type = 'enum', values = { 'single_elimination', 'double_elimination', 'round_robin', 'swiss' }, default = 'single_elimination' },
        swissRounds = { type = 'integer', min = 1, max = 15, optional = true },
        bestOf = { type = 'enum', values = { 1, 3, 5 }, default = 1 },
        seeding = { type = 'enum', values = { 'registration', 'random' }, default = 'registration' },
        registrationSeconds = { type = 'integer', min = 30, max = 3600, default = 180 },
    },
}, function(src, data)
    return ES.Tournaments.create(data, src)
end)

RPC.register('admin:tournament:begin', { perm = 'tournament.edit', schema = { id = { type = 'string', maxLen = 32 } } }, function(src, data)
    local ok, err = ES.Tournaments.begin(data.id)
    if ok then Log.audit('tournament.begin', src, nil, { id = data.id }) end
    return ok, err
end)

RPC.register('admin:leaderboard', {
    perm = 'admin.open',
    schema = { category = { type = 'string', maxLen = 32, default = '*' }, season = { type = 'string', maxLen = 16, optional = true } },
}, function(_, data)
    return { rows = ES.Stats.publicRows(ES.Stats.leaderboard(data.category, data.season, 50)), season = data.season or ES.Scoring.season() }
end)

----------------------------------------------------------------------------
-- Arena ground-height fixer (live-server bring-up helper)
----------------------------------------------------------------------------

local pointKeys = { 'spawns', 'vehicleSpawns', 'checkpoints', 'zones', 'objectives', 'targets', 'spectator' }

---Flatten every positioned point of an arena for probing.
function ES.arenaPoints(a)
    local out = {}
    local function add(key, index, p, team)
        out[#out + 1] = { key = key, index = index, team = team, x = p.x, y = p.y, z = p.z }
    end
    if a.center then add('center', nil, a.center) end
    if a.finish then add('finish', nil, a.finish) end
    for _, key in ipairs(pointKeys) do
        for i, p in ipairs(a[key] or {}) do add(key, i, p) end
    end
    for t, list in ipairs(a.teamSpawns or {}) do
        for i, p in ipairs(list) do add('teamSpawns', i, p, t) end
    end
    return out
end

---Apply validated Z fixes to an arena copy. Returns ok, arenaOrError, appliedCount.
function ES.applyArenaZ(a, fixes)
    local copy = U.deepCopy(a)
    local applied = 0
    for _, f in ipairs(fixes) do
        local target
        if f.key == 'center' or f.key == 'finish' then
            target = copy[f.key]
        elseif f.key == 'teamSpawns' then
            target = copy.teamSpawns and copy.teamSpawns[f.team or 0] and copy.teamSpawns[f.team][f.index or 0]
        elseif U.contains(pointKeys, f.key) then
            target = copy[f.key] and copy[f.key][f.index or 0]
        end
        if not target then return false, ('unknown point %s[%s]'):format(tostring(f.key), tostring(f.index)) end
        if type(f.z) ~= 'number' or f.z ~= f.z or math.abs(f.z - target.z) > 60 then
            return false, ('fix for %s[%s] out of range'):format(f.key, tostring(f.index))
        end
        target.z = U.round(f.z, 2)
        applied = applied + 1
    end
    return true, copy, applied
end

RPC.register('admin:arena:probe', { perm = 'arena.edit', schema = { id = 'id' } }, function(_, data)
    local a = ES.Arenas.get(data.id)
    if not a then return false, 'not_found' end
    local points = ES.arenaPoints(a)
    for _, p in ipairs(points) do
        local src = p.key == 'center' and a.center or p.key == 'finish' and a.finish
            or p.key == 'teamSpawns' and a.teamSpawns[p.team][p.index] or a[p.key][p.index]
        p.w = src and src.w or nil
    end
    return { id = a.id, name = a.name, route = ES.Arenas.routeType(a), points = points }
end)

local MAX_MOVE, MAX_RISE = 300.0, 120.0

---Apply validated position fixes (x, y, z and optional heading) to an arena copy.
---Each point may move at most MAX_MOVE metres sideways and MAX_RISE metres up or down.
function ES.applyArenaFix(a, fixes)
    local copy = U.deepCopy(a)
    local applied = 0
    for _, f in ipairs(fixes) do
        local target
        if f.key == 'center' or f.key == 'finish' then
            target = copy[f.key]
        elseif f.key == 'teamSpawns' then
            target = copy.teamSpawns and copy.teamSpawns[f.team or 0] and copy.teamSpawns[f.team][f.index or 0]
        elseif U.contains(pointKeys, f.key) then
            target = copy[f.key] and copy[f.key][f.index or 0]
        end
        if not target then return false, ('unknown point %s[%s]'):format(tostring(f.key), tostring(f.index)) end
        for _, k in ipairs({ 'x', 'y', 'z' }) do
            if type(f[k]) ~= 'number' or f[k] ~= f[k] or math.abs(f[k]) > 20000 then
                return false, ('fix for %s[%s] has an invalid %s'):format(f.key, tostring(f.index), k)
            end
        end
        local dx, dy = f.x - target.x, f.y - target.y
        if math.sqrt(dx * dx + dy * dy) > MAX_MOVE or math.abs(f.z - target.z) > MAX_RISE then
            return false, ('fix for %s[%s] moves the point too far'):format(f.key, tostring(f.index))
        end
        target.x, target.y, target.z = U.round(f.x, 2), U.round(f.y, 2), U.round(f.z, 2)
        if type(f.w) == 'number' and f.w == f.w then target.w = U.round(f.w % 360, 1) end
        applied = applied + 1
    end
    return true, copy, applied
end

RPC.register('admin:arena:applyFix', {
    perm = 'arena.edit',
    schema = { id = 'id', problems = { type = 'integer', min = 0, max = 10000, default = 0 },
        fixes = { type = 'list', maxItems = 512, item = { type = 'object', fields = {
            key = { type = 'string', maxLen = 16 }, index = 'integer?', team = 'integer?', x = 'number', y = 'number', z = 'number', w = 'number?',
        } } } },
    rate = { burst = 3, per = 10 },
}, function(src, data)
    local a = ES.Arenas.get(data.id)
    if not a then return false, 'not_found' end
    local ok, res, applied = ES.applyArenaFix(a, data.fixes)
    if not ok then return false, res end
    res.checked = { at = os.time(), by = Log.actorLabel(src), problems = data.problems }
    local okR, err = ES.Arenas.register(res, 'storage')
    if not okR then return false, err end
    ES.Storage.saveDocument('arena', a.id, ES.Arenas.get(a.id), Log.actorLabel(src))
    Log.audit('arena.routefix', src, nil, { id = a.id, applied = applied, problems = data.problems })
    return true, { applied = applied }
end)

RPC.register('admin:arena:applyZ', {
    perm = 'arena.edit',
    schema = { id = 'id', fixes = { type = 'list', maxItems = 512, item = { type = 'object', fields = {
        key = { type = 'string', maxLen = 16 }, index = 'integer?', team = 'integer?', z = 'number',
    } } } },
    rate = { burst = 3, per = 10 },
}, function(src, data)
    local a = ES.Arenas.get(data.id)
    if not a then return false, 'not_found' end
    local ok, res, applied = ES.applyArenaZ(a, data.fixes)
    if not ok then return false, res end
    local okR, err = ES.Arenas.register(res, 'storage')
    if not okR then return false, err end
    ES.Storage.saveDocument('arena', a.id, ES.Arenas.get(a.id), Log.actorLabel(src))
    Log.audit('arena.groundfix', src, nil, { id = a.id, applied = applied })
    return true, { applied = applied }
end)
