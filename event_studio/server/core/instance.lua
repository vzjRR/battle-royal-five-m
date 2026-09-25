-- EVENT STUDIO — Instance: one running occurrence of a definition (state machine, clock, sync)

local U = ES.Util
local S = ES.Lifecycle.States
local Lifecycle = ES.Lifecycle
local Log = ES.Log

local Instance = {}
Instance.__index = Instance
ES.Instance = Instance

---@param id integer
---@param def table validated definition
---@param opts table { startAt? (os.time), registration? (s), invite? {src}, tournament?, createdBy?, match? }
function Instance.new(id, def, opts)
    opts = opts or {}
    local mode = ES.Modes[def.mode]
    local self = setmetatable({
        id = id,
        def = U.deepCopy(def),
        mode = mode,
        arena = def.arena and U.deepCopy(ES.Arenas.get(def.arena)) or nil,
        state = S.REGISTRATION,
        stateSince = ES.now(),
        deadline = nil,
        participants = {},      -- [src] = participant
        byIdentifier = {},      -- [identifier] = participant
        byLicense = {},         -- [license] = participant (reconnect matching before characters load)
        teams = {},
        spectators = {},        -- [src] = { returnPoint, admin }
        components = {},        -- [name] = component object (ordered list below)
        componentOrder = {},
        data = {},              -- mode-private
        entities = {},          -- server-created entity handles to delete
        invite = nil,
        tournament = opts.tournament,
        match = opts.match,
        createdBy = opts.createdBy,
        createdAt = os.time(),
        startAt = opts.startAt,
        clock = { startedAt = nil, pausedAt = nil, pausedTotal = 0 },
        joinSeq = 0,
        elimSeq = 0,
        flags = {},
        scoreDirty = true,
        lastScorePush = 0,
        lastScoreJson = nil,
        results = nil,
    }, Instance)

    if opts.invite then
        self.invite = {}
        for _, src in ipairs(opts.invite) do self.invite[src] = true end
    end
    if opts.registration then self.def.timing.registration = opts.registration end

    local t = self.def.players.teams
    if t then
        for i = 1, t.count do
            self.teams[i] = { index = i, name = t.names[i], color = t.colors[i], score = 0 }
        end
    end

    local now = ES.now()
    if self.startAt and self.startAt - os.time() > self.def.timing.registration then
        self.state = S.SCHEDULED
        self.deadline = now + (self.startAt - os.time() - self.def.timing.registration) * 1000
    else
        if self.startAt then
            self.def.timing.registration = math.max(5, self.startAt - os.time())
        end
        self.deadline = now + self.def.timing.registration * 1000
    end
    return self
end

----------------------------------------------------------------------------
-- Clock
----------------------------------------------------------------------------

function Instance:elapsedMs()
    local c = self.clock
    if not c.startedAt then return 0 end
    local now = c.pausedAt or ES.now()
    return now - c.startedAt - c.pausedTotal
end

function Instance:remainingMs()
    if self.state == S.PAUSED then return self.pausedRemaining end
    if not self.deadline then return nil end
    return math.max(0, self.deadline - ES.now())
end

function Instance:isState(...)
    for i = 1, select('#', ...) do
        if self.state == select(i, ...) then return true end
    end
    return false
end

----------------------------------------------------------------------------
-- Components
----------------------------------------------------------------------------

---Attach a component. Returns the component object.
function Instance:use(name, cfg)
    local c = ES.Components[name]
    assert(c, 'unknown component ' .. tostring(name))
    local obj = c.attach(self, cfg or {})
    obj.__name = name
    self.components[name] = obj
    self.componentOrder[#self.componentOrder + 1] = obj
    return obj
end

function Instance:component(name) return self.components[name] end

function Instance:sendComponentSetup(p)
    local target = type(p) == 'table' and p.src or p
    for _, obj in ipairs(self.componentOrder) do
        if obj.clientSetup then
            local payload = obj:clientSetup(type(p) == 'table' and p or nil)
            if payload then ES.push(target, 'component', { name = obj.__name, setup = payload }) end
        end
    end
end

----------------------------------------------------------------------------
-- Sync
----------------------------------------------------------------------------

---Players that should receive instance pushes (connected participants + spectators).
function Instance:audience()
    local out = {}
    for src, p in pairs(self.participants) do
        if p.status ~= 'disconnected' and p.status ~= 'left' and p.status ~= 'disqualified' then out[#out + 1] = src end
    end
    for src in pairs(self.spectators) do out[#out + 1] = src end
    return out
end

function Instance:push(p, topic, data)
    ES.push(type(p) == 'table' and p.src or p, topic, data)
end

function Instance:broadcast(topic, data)
    ES.push(self:audience(), topic, data)
end

function Instance:dirty() self.scoreDirty = true end

function Instance:publicTeams()
    local out = {}
    for i, t in ipairs(self.teams) do out[i] = { index = i, name = t.name, color = t.color, score = t.score } end
    return out
end

---Snapshot pushed on every state change.
function Instance:snapshot(src)
    local p = self.participants[src]
    local snap = {
        id = self.id, name = self.def.name, mode = self.def.mode, category = self.def.category, selfSrc = src,
        state = self.state, remainingMs = self:remainingMs(), elapsedMs = self:elapsedMs(),
        role = p and 'participant' or (self.spectators[src] and 'spectator' or nil),
        teams = #self.teams > 0 and self:publicTeams() or nil,
        spectateOnEliminate = self.def.players.spectateOnEliminate,
        gameplay = { health = self.def.gameplay.health, armor = self.def.gameplay.armor,
                     restoreWeapons = self.def.gameplay.restoreWeapons, blockInventoryWeapons = self.def.gameplay.blockInventoryWeapons },
        objective = self.mode.objectiveKey and L(self.mode.objectiveKey) or nil,
    }
    local rp = (p and p.returnPoint) or (self.spectators[src] and self.spectators[src].returnPoint)
    if rp then snap.returnPoint = { coords = rp.coords, heading = rp.heading } end
    if p then
        snap.you = { status = p.status, team = p.team, score = p.score, lives = p.lives, stats = p.stats, role = p.role }
        if self.mode.hud then
            local ok, hud = pcall(self.mode.hud, self, p)
            if ok then snap.hud = hud end
        end
    end
    return snap
end

function Instance:syncState(src)
    if src then
        ES.push(src, 'state', self:snapshot(src))
        return
    end
    for _, s in ipairs(self:audience()) do ES.push(s, 'state', self:snapshot(s)) end
end

---Live ranked rows for the scoreboard.
function Instance:scoreRows()
    local list = self:allParticipants()
    local ranked
    if self.mode.rankBy == 'custom' and self.mode.rank then
        ranked = self.mode.rank(self, list)
    else
        ranked = ES.Scoring.rankParticipants(list, self.mode.rankBy)
    end
    local rows = {}
    for i, p in ipairs(ranked) do
        rows[i] = {
            src = p.src, name = p.name, team = p.team, status = p.status, score = p.score,
            placement = p.placement, kills = p.stats.kills, deaths = p.stats.deaths,
            finishMs = p.finishMs, extra = self.mode.rowExtra and self.mode.rowExtra(self, p) or nil,
        }
    end
    return rows
end

function Instance:pushScoreboard(force)
    local now = ES.now()
    local minGap = 1000 / math.max(0.2, Config.UI.scoreboardHz or 1)
    if not force and (not self.scoreDirty or now - self.lastScorePush < minGap) then return end
    self.scoreDirty = false
    self.lastScorePush = now
    local payload = { rows = self:scoreRows(), teams = #self.teams > 0 and self:publicTeams() or nil }
    local encoded = json.encode(payload)
    if encoded == self.lastScoreJson and not force then return end
    self.lastScoreJson = encoded
    self:broadcast('scoreboard', payload)
end

---Localized announcement to the instance audience.
function Instance:announce(key, kind, ...)
    self:broadcast('announce', { text = L(key, ...), kind = kind or 'info' })
end

----------------------------------------------------------------------------
-- Scoring helpers for modes
----------------------------------------------------------------------------

---noTeam = true: individual contribution only (team score handled by the mode)
function Instance:addScore(p, amount, reason, noTeam)
    if not p or amount == 0 then return end
    p.score = p.score + amount
    p.scoreAt = self:elapsedMs()
    if not noTeam and p.team and self.teams[p.team] then self.teams[p.team].score = self.teams[p.team].score + amount end
    self:dirty()
    Log.debug('#%d %s +%s (%s)', self.id, p.name, amount, reason or '')
end

function Instance:addTeamScore(teamIndex, amount)
    local t = self.teams[teamIndex]
    if t then t.score = t.score + amount; self:dirty() end
end

function Instance:addStat(p, key, n)
    p.stats[key] = (p.stats[key] or 0) + (n or 1)
    self:dirty()
end

function Instance:activeParticipants(filterTeam)
    local out = {}
    for _, p in pairs(self.participants) do
        if p.status == 'active' and (not filterTeam or p.team == filterTeam) then out[#out + 1] = p end
    end
    return out
end

function Instance:participantCount(statuses)
    local n = 0
    for _, p in pairs(self.participants) do
        if not statuses or statuses[p.status] then n = n + 1 end
    end
    return n
end

----------------------------------------------------------------------------
-- State machine
----------------------------------------------------------------------------

local enter = {}

function Instance:setState(new, reason)
    local old = self.state
    if old == new then return true end
    if not Lifecycle.canTransition(old, new) then
        Log.warn('#%d illegal transition %s -> %s (%s)', self.id, old, new, tostring(reason))
        return false
    end
    self.state = new
    self.stateSince = ES.now()
    self.deadline = nil
    self.stateReason = reason
    Log.debug('#%d %s -> %s (%s)', self.id, old, new, tostring(reason))
    local handler = enter[new]
    if handler then
        local ok, err = pcall(handler, self, old, reason)
        if not ok then Log.error('#%d error entering %s: %s', self.id, new, tostring(err)) end
    end
    if self.state == new then -- handler may have moved on already
        self:syncState()
    end
    TriggerEvent('event_studio:instanceState', self.id, new, old, { reason = reason, definitionId = self.def.id })
    ES.Log.record('lifecycle', 'instance.state', nil, self.id, { from = old, to = new, reason = reason, definition = self.def.id })
    return true
end

local function secs(n) return ES.now() + (n or 0) * 1000 end

enter[S.REGISTRATION] = function(self)
    self.deadline = secs(self.def.timing.registration)
    self.flags.startingSoon = false
    if self.def.visibility == 'public' and not self.invite then
        ES.Announce.global('registrationOpen', 'announce_registration_open', self.def.name, self.id)
    end
end

enter[S.LOBBY] = function(self)
    local bucket = ES.Buckets.acquire(self.id)
    if not bucket then
        Log.error('#%d no free routing bucket', self.id)
        return self:cancel('no_bucket')
    end
    self.bucket = bucket
    self:assignTeams()
    for _, p in pairs(self.participants) do
        if p.status == 'registered' then
            p.status = 'active'
            p.everActive = true
            p.activeSince = ES.now()
            self:enterWorld(p.src)
        end
    end
    -- clients learn they are in an event (weapon snapshot etc.) before any loadout/vehicle arrives
    self:syncState()
    if self.mode.setup then self.mode.setup(self) end
    for _, p in pairs(self.participants) do
        if p.status == 'active' then
            self:sendComponentSetup(p)
            self:push(p, 'freeze', { frozen = true })
        end
    end
    self.startCount = self:participantCount({ active = true })
    self.deadline = secs(self.def.timing.lobby)
    self:dirty()
end

enter[S.COUNTDOWN] = function(self)
    self.deadline = secs(self.def.timing.countdown)
end

enter[S.ACTIVE] = function(self, old)
    if old == S.PAUSED then
        self.clock.pausedTotal = self.clock.pausedTotal + (ES.now() - self.clock.pausedAt)
        self.clock.pausedAt = nil
        if self.pausedRemaining then self.deadline = ES.now() + self.pausedRemaining end
        self.pausedRemaining = nil
        self:broadcast('freeze', { frozen = false })
        if self.mode.onResume then self.mode.onResume(self) end
        return
    end
    self.clock.startedAt = ES.now()
    self.startedAtWall = os.time()
    local d = self.def.timing.duration
    self.deadline = (d and d > 0) and secs(d) or nil
    self:broadcast('freeze', { frozen = false })
    if self.mode.start then self.mode.start(self) end
    if self.def.visibility == 'public' and not self.invite then
        ES.Announce.global('started', 'announce_started', self.def.name)
    end
    self:dirty()
end

enter[S.PAUSED] = function(self)
    self.clock.pausedAt = ES.now()
    self.pausedRemaining = self.deadline and math.max(0, self.deadline - ES.now()) or nil
    self.deadline = nil
    self:broadcast('freeze', { frozen = true })
    self:announce('announce_paused', 'warn')
end

enter[S.FINISHING] = function(self)
    local g = self.def.timing.grace or 0
    if g <= 0 then return self:setState(S.RESULTS, 'grace_skipped') end
    self.deadline = secs(g)
end

enter[S.RESULTS] = function(self)
    self:broadcast('freeze', { frozen = true })
    self:computeResults()
    self.deadline = secs(self.def.timing.results)
end

enter[S.REWARDS] = function(self)
    -- rewards may await storage; run in a thread, then archive
    Citizen.CreateThread(function()
        local ok, err = pcall(ES.Rewards.distribute, self)
        if not ok then Log.error('#%d reward distribution error: %s', self.id, tostring(err)) end
        self:setState(S.ARCHIVED, 'rewarded')
    end)
end

enter[S.CANCELLED] = function(self, old, reason)
    self.cancelledFrom = old
    if self.def.visibility == 'public' and not self.invite then
        ES.Announce.global('cancelled', 'announce_cancelled', self.def.name, L('reason_' .. tostring(reason)))
    end
    self.deadline = ES.now() -- archive on next tick
end

enter[S.ARCHIVED] = function(self)
    self:cleanup()
end

----------------------------------------------------------------------------
-- Public controls
----------------------------------------------------------------------------

---Close registration and move to LOBBY (force = ignore min players).
function Instance:start(force)
    if self.state == S.SCHEDULED then self:setState(S.REGISTRATION, 'forced') end
    if self.state ~= S.REGISTRATION then return false, 'invalid_state' end
    local n = self:participantCount({ registered = true })
    if n == 0 then return false, 'no_players' end
    if not force and n < self.def.players.min then return false, 'not_enough_players' end
    return self:setState(S.LOBBY, force and 'forced' or 'start')
end

function Instance:pause()
    if self.state ~= S.ACTIVE then return false, 'invalid_state' end
    return self:setState(S.PAUSED, 'admin')
end

function Instance:resume()
    if self.state ~= S.PAUSED then return false, 'invalid_state' end
    return self:setState(S.ACTIVE, 'admin')
end

---Winner decided: FINISHING (grace) if the mode wants it, else RESULTS.
function Instance:finish(reason)
    if self.state ~= S.ACTIVE and self.state ~= S.PAUSED then return false, 'invalid_state' end
    if self.state == S.PAUSED then self:setState(S.ACTIVE, 'finish') end
    if self.mode.graceOnFinish then return self:setState(S.FINISHING, reason) end
    return self:setState(S.RESULTS, reason)
end

function Instance:finishNow(reason)
    if self.state == S.FINISHING then return self:setState(S.RESULTS, reason) end
    if self.state == S.ACTIVE or self.state == S.PAUSED then return self:setState(S.RESULTS, reason) end
    if self.state == S.LOBBY or self.state == S.COUNTDOWN then return self:cancel(reason) end
    return false, 'invalid_state'
end

function Instance:cancel(reason)
    if not Lifecycle.isCancellable(self.state) then return false, 'invalid_state' end
    return self:setState(S.CANCELLED, reason or 'cancelled')
end

----------------------------------------------------------------------------
-- Tick
----------------------------------------------------------------------------

function Instance:update(dt)
    local now = ES.now()
    local st = self.state

    if st == S.REGISTRATION and self.deadline then
        local soon = (Config.Notifications.startingSoonSeconds or 30) * 1000
        if not self.flags.startingSoon and self.deadline - now <= soon and self.def.timing.registration * 1000 > soon then
            self.flags.startingSoon = true
            if self.def.visibility == 'public' and not self.invite then
                ES.Announce.global('startingSoon', 'announce_starting_soon', self.def.name, math.ceil((self.deadline - now) / 1000))
            end
        end
    end

    if st == S.ACTIVE then
        for _, obj in ipairs(self.componentOrder) do
            if obj.tick then
                local ok, err = pcall(obj.tick, obj, dt)
                if not ok then Log.error('#%d component %s tick: %s', self.id, obj.__name, tostring(err)) end
            end
        end
        if self.state == S.ACTIVE and self.mode.tick then
            local ok, err = pcall(self.mode.tick, self, dt)
            if not ok then Log.error('#%d mode tick: %s', self.id, tostring(err)) end
        end
        self:timeAnnouncements()
    elseif st == S.FINISHING then
        -- keep components alive for finishing racers
        for _, obj in ipairs(self.componentOrder) do
            if obj.tick and obj.tickWhileFinishing then pcall(obj.tick, obj, dt) end
        end
    end

    if self.deadline and now >= self.deadline and self.state == st then
        self:onDeadline()
    end

    if Lifecycle.isLive(self.state) then self:pushScoreboard(false) end
end

function Instance:timeAnnouncements()
    local d = self.def.timing.duration
    if not d or d <= 0 or not self.deadline then return end
    local remaining = self.deadline - ES.now()
    if not self.flags.halfway and remaining <= d * 500 and d >= 120 then
        self.flags.halfway = true
        self:announce('announce_halfway', 'info')
    end
    if not self.flags.finalMinute and remaining <= 60000 and d > 90 then
        self.flags.finalMinute = true
        self:announce('announce_final_minute', 'warn')
    end
end

function Instance:onDeadline()
    local st = self.state
    if st == S.SCHEDULED then
        self:setState(S.REGISTRATION, 'scheduled')
    elseif st == S.REGISTRATION then
        local n = self:participantCount({ registered = true })
        if n >= self.def.players.min then
            self:setState(S.LOBBY, 'registration_closed')
        elseif (self.def.timing.extendOnce or 0) > 0 and not self.flags.extended then
            self.flags.extended = true
            self.deadline = ES.now() + self.def.timing.extendOnce * 1000
            self:syncState()
            if self.def.visibility == 'public' and not self.invite then
                ES.Announce.global('registrationOpen', 'announce_registration_extended', self.def.name, self.def.players.min - n)
            end
        else
            self:cancel('not_enough_players')
        end
    elseif st == S.LOBBY then
        self:setState(S.COUNTDOWN, 'lobby_done')
    elseif st == S.COUNTDOWN then
        self:setState(S.ACTIVE, 'countdown_done')
    elseif st == S.ACTIVE then
        if self.mode.onTimeUp then self.mode.onTimeUp(self) else self:finishNow('time') end
    elseif st == S.FINISHING then
        self:setState(S.RESULTS, 'grace_over')
    elseif st == S.RESULTS then
        self:setState(S.REWARDS, 'results_done')
    elseif st == S.CANCELLED then
        self:setState(S.ARCHIVED, 'cancelled')
    end
end

return Instance
