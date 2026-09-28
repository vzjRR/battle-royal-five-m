-- EVENT STUDIO — Instance participants, teams, spectators, world entry/exit

local U = ES.Util
local S = ES.Lifecycle.States
local Lifecycle = ES.Lifecycle
local Log = ES.Log
local Instance = ES.Instance

local function newParticipant(src, seq)
    return {
        src = src,
        identifier = ES.Bridge.getIdentifier(src),
        license = ES.Bridge.getLicense(src),
        name = ES.Bridge.getName(src),
        status = 'registered',
        team = nil,
        role = nil,
        score = 0,
        points = 0,
        lives = nil,
        joinSeq = seq,
        stats = { kills = 0, deaths = 0, assists = 0, objectives = 0, checkpoints = 0, laps = 0, streak = 0, bestStreak = 0 },
    }
end

---Validate and register a player. force = admin/API (bypass capacity/visibility/invite, never state).
function Instance:addParticipant(src, force)
    local live = Lifecycle.isLive(self.state)
    if not force and self.state ~= S.REGISTRATION then return false, 'invalid_state' end
    if force and not (self.state == S.REGISTRATION or self.state == S.SCHEDULED or live) then return false, 'invalid_state' end
    if self.participants[src] then return false, 'already_joined' end
    if self.spectators[src] then return false, 'is_spectator' end
    if not force then
        if self.invite and not self.invite[src] then return false, 'invite_only' end
        if self.def.visibility ~= 'public' and not self.invite then return false, 'not_public' end
        if self:participantCount({ registered = true, active = true }) >= self.def.players.max then return false, 'full' end
    end
    local identifier = ES.Bridge.getIdentifier(src)
    local existing = self.byIdentifier[identifier] or self.byLicense[ES.Bridge.getLicense(src)]
    if existing then
        if existing.status == 'disconnected' then return self:rejoin(existing, src) end
        return false, 'already_joined'
    end
    if ES.Hooks and ES.Hooks.canJoin then
        local ok, why = ES.Hooks.canJoin(src, self)
        if ok == false then return false, why or 'blocked' end
    end
    self.joinSeq = self.joinSeq + 1
    local p = newParticipant(src, self.joinSeq)
    self.participants[src] = p
    self.byIdentifier[p.identifier] = p
    self.byLicense[p.license] = p
    if self.def.players.teams and self.def.players.teams.fixed then
        for t, members in ipairs(self.def.players.teams.fixed) do
            if U.contains(members, p.identifier) then p.team = t end
        end
    end
    if live then
        -- late add by admin/API
        if not p.team and #self.teams > 0 then p.team = self:smallestTeam() end
        p.status = 'active'
        p.everActive = true
        p.activeSince = ES.now()
        self:enterWorld(src)
        self:syncState(src)
        for _, obj in ipairs(self.componentOrder) do
            if obj.onJoin then pcall(obj.onJoin, obj, p) end
        end
        if self.mode.onLateJoin then pcall(self.mode.onLateJoin, self, p) end
        self:sendComponentSetup(p)
        if self.state ~= S.ACTIVE then self:push(p, 'freeze', { frozen = true }) end
    end
    self:dirty()
    self:syncState(src)
    TriggerEvent('event_studio:participantJoined', self.id, src)
    ES.Log.record('info', 'player.joined', src, self.id, { definition = self.def.id })
    return true
end

function Instance:smallestTeam()
    local counts = {}
    for i = 1, #self.teams do counts[i] = 0 end
    for _, p in pairs(self.participants) do
        if p.team and (p.status == 'active' or p.status == 'registered') then counts[p.team] = (counts[p.team] or 0) + 1 end
    end
    local best, bestN = 1, math.huge
    for i = 1, #self.teams do
        if counts[i] < bestN then best, bestN = i, counts[i] end
    end
    return best
end

---Assign teams at LOBBY: keep fixed/manual picks, balance the rest by join order.
function Instance:assignTeams()
    if #self.teams == 0 then return end
    local list = {}
    for _, p in pairs(self.participants) do
        if p.status == 'registered' then list[#list + 1] = p end
    end
    table.sort(list, function(a, b) return a.joinSeq < b.joinSeq end)
    for _, p in ipairs(list) do
        if not p.team then p.team = self:smallestTeam() end
    end
end

---Move a player into the instance world (bucket + return point).
function Instance:enterWorld(src, isSpectator)
    local ped = GetPlayerPed(src)
    local point = {
        coords = U.vec(GetEntityCoords(ped)),
        heading = GetEntityHeading(ped),
        bucket = GetPlayerRoutingBucket(src),
    }
    local license = ES.Bridge.getLicense(src)
    local existing = ES.Storage.getReturnPoint(license)
    if existing then point = existing end -- keep the original point on rejoin
    ES.Storage.setReturnPoint(license, point)
    if isSpectator then
        self.spectators[src].returnPoint = point
    else
        self.participants[src].returnPoint = point
    end
    SetPlayerRoutingBucket(src, self.bucket)
    Player(src).state:set('es:inEvent', self.id, true)
    ES.Manager.index(src, self)
end

---Return a player to the normal world.
function Instance:returnToWorld(src, point, reason)
    local license = ES.Bridge.getLicense(src)
    point = point or ES.Storage.getReturnPoint(license)
    local exit = Config.General.exit
    local coords, heading = point and point.coords, point and point.heading
    if exit.mode ~= 'return' and exit.coords then
        coords = U.vec(exit.coords)
        heading = exit.coords.w or 0.0
    end
    if GetPlayerName(tostring(src)) then
        SetPlayerRoutingBucket(src, (point and point.bucket) or 0)
        Player(src).state:set('es:inEvent', false, true)
        ES.push(src, 'left', { id = self.id, coords = coords, heading = heading, reason = reason })
    end
    ES.Storage.clearReturnPoint(license)
    ES.Manager.unindex(src, self)
end

---Voluntary leave / admin removal / timeout after disconnect.
function Instance:removeParticipant(src, reason)
    local p = self.participants[src]
    if not p then return false, 'not_joined' end
    local wasLive = Lifecycle.isLive(self.state)
    if self.state == S.REGISTRATION or self.state == S.SCHEDULED then
        -- simply unregister
        self.participants[src] = nil
        self.byIdentifier[p.identifier] = nil
        self.byLicense[p.license] = nil
        ES.Manager.unindex(src, self)
        ES.push(src, 'left', { id = self.id, reason = reason })
        self:dirty()
        TriggerEvent('event_studio:participantLeft', self.id, src, reason)
        return true
    end
    if p.status == 'active' or p.status == 'eliminated' or p.status == 'finished' then
        local prev = p.status
        if prev == 'active' then
            p.status = reason == 'disqualified' and 'disqualified' or 'left'
            p.leftAt = ES.now()
        elseif reason == 'disqualified' then
            p.status = 'disqualified'
        end
        if reason == 'removed' then p.removed = true end
        for _, obj in ipairs(self.componentOrder) do
            if obj.onLeave then pcall(obj.onLeave, obj, p, reason) end
        end
        if self.mode.onLeave then pcall(self.mode.onLeave, self, p, reason) end
    end
    if wasLive and GetPlayerName(tostring(src)) then
        self:returnToWorld(src, p.returnPoint, reason)
    else
        ES.Manager.unindex(src, self)
    end
    -- keep the participant record for results, but free the src slot
    self.participants[src] = nil
    p.src = nil
    self.departed = self.departed or {}
    self.departed[#self.departed + 1] = p
    self:dirty()
    TriggerEvent('event_studio:participantLeft', self.id, src, reason)
    ES.Log.record('info', 'player.left', src, self.id, { reason = reason })
    self:checkViability()
    return true
end

function Instance:disqualify(src, actor)
    local p = self.participants[src]
    if not p then return false, 'not_joined' end
    ES.push(src, 'announce', ES.say(src, 'error', 'you_disqualified'))
    return self:removeParticipant(src, 'disqualified')
end

---Player dropped from the server.
function Instance:onDisconnect(src)
    if self.spectators[src] then
        self.spectators[src] = nil
        return
    end
    local p = self.participants[src]
    if not p then return end
    if self.state == S.REGISTRATION or self.state == S.SCHEDULED then
        self.participants[src] = nil
        self.byIdentifier[p.identifier] = nil
        self.byLicense[p.license] = nil
        self:dirty()
        return
    end
    local prev = p.status
    self.participants[src] = nil
    p.src = nil
    p.disconnectedAt = ES.now()
    p.prevStatus = prev
    self.departed = self.departed or {}
    self.departed[#self.departed + 1] = p
    if prev == 'active' then
        p.status = 'disconnected'
        for _, obj in ipairs(self.componentOrder) do
            if obj.onLeave then pcall(obj.onLeave, obj, p, 'disconnect') end
        end
        if self.mode.onLeave then pcall(self.mode.onLeave, self, p, 'disconnect') end
    end
    self:dirty()
    TriggerEvent('event_studio:participantLeft', self.id, src, 'disconnect')
    ES.Log.record('info', 'player.left', nil, self.id, { reason = 'disconnect', name = p.name })
    local grace = self.def.players.reconnectGrace or 0
    if prev == 'active' and grace > 0 and self.mode.allowRejoin ~= false and Lifecycle.isLive(self.state) then
        -- viability is evaluated when the grace window expires (manager tick)
        return
    end
    if prev == 'active' then p.status = 'left' end
    self:checkViability()
end

---Reconnected player (same identifier) during grace window.
function Instance:rejoin(p, src)
    if not Lifecycle.isLive(self.state) then return false, 'invalid_state' end
    for i, d in ipairs(self.departed or {}) do
        if d == p then table.remove(self.departed, i) break end
    end
    p.src = src
    p.status = p.prevStatus == 'active' and 'active' or p.prevStatus or 'active'
    p.disconnectedAt = nil
    self.participants[src] = p
    self:enterWorld(src)
    self:syncState(src)
    for _, obj in ipairs(self.componentOrder) do
        if obj.onJoin then pcall(obj.onJoin, obj, p, true) end
    end
    if self.mode.onRejoin then pcall(self.mode.onRejoin, self, p) end
    self:sendComponentSetup(p)
    if self.state ~= S.ACTIVE then self:push(p, 'freeze', { frozen = true }) end
    self:syncState(src)
    self:dirty()
    self:push(p, 'announce', ES.say(p, 'success', 'you_rejoined'))
    Log.info('#%d %s rejoined', self.id, p.name)
    return true
end

---Called by manager each tick: expire disconnect grace windows.
function Instance:expireDisconnects()
    local grace = (self.def.players.reconnectGrace or 0) * 1000
    local changed = false
    for _, p in ipairs(self.departed or {}) do
        if p.status == 'disconnected' and p.disconnectedAt and ES.now() - p.disconnectedAt >= grace then
            p.status = 'left'
            changed = true
        end
    end
    if changed then
        self:dirty()
        self:checkViability()
    end
end

function Instance:hasPendingReconnect()
    for _, p in ipairs(self.departed or {}) do
        if p.status == 'disconnected' then return true end
    end
    return false
end

----------------------------------------------------------------------------
-- Eliminations / finish
----------------------------------------------------------------------------

function Instance:eliminate(p, reason, killer)
    if not p or p.status ~= 'active' then return false end
    p.status = 'eliminated'
    self.elimSeq = self.elimSeq + 1
    p.eliminatedAt = self.elimSeq
    p.eliminatedReason = reason
    for _, obj in ipairs(self.componentOrder) do
        if obj.onEliminated then pcall(obj.onEliminated, obj, p, reason) end
    end
    self:push(p, 'announce', ES.say(p, 'error', 'you_eliminated'))
    self:syncState(p.src)
    self:dirty()
    TriggerEvent('event_studio:eliminated', self.id, p.src, reason, killer and killer.src or nil)
    self:checkViability()
    return true
end

---Race-like completion.
function Instance:markFinished(p)
    if not p or p.status ~= 'active' then return false end
    p.status = 'finished'
    p.finishMs = self:elapsedMs()
    self:push(p, 'announce', ES.say(p, 'success', 'you_finished', U.fmtDuration(p.finishMs)))
    self:syncState(p.src)
    self:dirty()
    -- finish-line modes: the grace time starts when the podium is complete (flow.graceAfterPlace, default 3rd place)
    -- or when nobody is left racing
    if self.state == S.ACTIVE and self.mode.finishLine then
        local finished = 0
        for _, q in pairs(self.participants) do if q.status == 'finished' then finished = finished + 1 end end
        -- small races: the last place before the final racer counts (2 racers: 1st, 3 racers: 2nd)
        local place = (Config.General.flow and Config.General.flow.graceAfterPlace) or 3
        place = math.max(1, math.min(place, (self.startCount or place + 1) - 1))
        if finished >= place or #self:activeParticipants() == 0 then self:setState(S.FINISHING, 'podium') end
    end
    self:checkViability()
    return true
end

---Finish automatically when the event can no longer continue.
function Instance:checkViability()
    if self.state == S.FINISHING then
        -- everyone is done: results a short moment after the last one (flow.lastFinishWait)
        if #self:activeParticipants() == 0 and not self:hasPendingReconnect() and not self.flags.allDone then
            self.flags.allDone = true
            self.deadline = ES.now() + ((Config.General.flow and Config.General.flow.lastFinishWait) or 10) * 1000
            self:syncState()
        end
        return
    end
    if not (self.state == S.ACTIVE or self.state == S.PAUSED or self.state == S.LOBBY or self.state == S.COUNTDOWN) then
        return
    end
    local active = self:activeParticipants()
    if self.state == S.LOBBY or self.state == S.COUNTDOWN then
        if #active < math.max(1, self.def.players.min) and not self:hasPendingReconnect() then
            self:cancel('not_enough_players')
        end
        return
    end
    if self.mode.viability then
        local ok, keep = pcall(self.mode.viability, self)
        if ok and keep ~= nil then
            if keep == false then self:finishNow('not_viable') end
            return
        end
    end
    if #active == 0 then
        if self:hasPendingReconnect() then return end
        return self:finishNow('no_players')
    end
    if #self.teams > 0 then
        local alive = {}
        for _, p in ipairs(active) do if p.team then alive[p.team] = true end end
        if U.count(alive) <= 1 and (self.startCount or 0) > 1 and self.mode.lastTeamStanding then
            return self:finishNow('last_team')
        end
        if U.count(alive) <= 1 and (self.startCount or 0) > 1 and not self:hasPendingReconnect() and self.mode.endWhenOneTeamLeft ~= false then
            return self:finishNow('one_team_left')
        end
    elseif self.mode.lastStanding and #active <= 1 and (self.startCount or 0) > 1 then
        return self:finishNow('last_standing')
    end
end

----------------------------------------------------------------------------
-- Spectators
----------------------------------------------------------------------------

function Instance:addSpectator(src, admin)
    if not Lifecycle.isLive(self.state) and self.state ~= S.RESULTS then return false, 'not_live' end
    if self.participants[src] then return false, 'is_participant' end
    if self.spectators[src] then return false, 'already_spectating' end
    if not admin and not self.def.players.spectators then return false, 'spectators_disabled' end
    self.spectators[src] = { admin = admin == true }
    self:enterWorld(src, true)
    self:syncState(src)
    self:sendComponentSetup(src)
    ES.push(src, 'spectate', { start = true, targets = self:spectateTargets(), center = self.arena and self.arena.center })
    self:pushScoreboard(true)
    return true
end

function Instance:removeSpectator(src, reason)
    local s = self.spectators[src]
    if not s then return false, 'not_spectating' end
    self.spectators[src] = nil
    self:returnToWorld(src, s.returnPoint, reason or 'spectate_end')
    return true
end

function Instance:spectateTargets()
    local out = {}
    for src, p in pairs(self.participants) do
        if p.status == 'active' or p.status == 'finished' then
            out[#out + 1] = { src = src, name = p.name, team = p.team }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

----------------------------------------------------------------------------
-- Actions & deaths
----------------------------------------------------------------------------

---Validated player intent from the client (RPC 'event:action').
function Instance:handleAction(src, action, data)
    local p = self.participants[src]
    if not p then return false, 'not_participant' end
    for _, obj in ipairs(self.componentOrder) do
        if obj.onAction then
            local handled, res = obj:onAction(p, action, data)
            if handled ~= nil then return handled, res end
        end
    end
    if self.mode.onAction then
        local handled, res = self.mode.onAction(self, p, action, data)
        if handled ~= nil then return handled, res end
    end
    Log.security(src, 'unknown_action', { action = action, instanceId = self.id })
    return false, 'unknown_action'
end

---A confirmed death (from the combat component). killer may be nil.
function Instance:onDeath(victim, killer, weapon)
    victim.stats.deaths = victim.stats.deaths + 1
    victim.stats.streak = 0
    if killer and killer ~= victim then
        killer.stats.kills = killer.stats.kills + 1
        killer.stats.streak = killer.stats.streak + 1
        if killer.stats.streak > killer.stats.bestStreak then killer.stats.bestStreak = killer.stats.streak end
    end
    if self.mode.onDeath then
        local ok, err = pcall(self.mode.onDeath, self, victim, killer, weapon)
        if not ok then Log.error('#%d mode onDeath: %s', self.id, tostring(err)) end
    end
    self:dirty()
end

function Instance:respawn(p)
    local spawns = self:component('spawns')
    if spawns then spawns:respawn(p) end
    if self.mode.onRespawn then pcall(self.mode.onRespawn, self, p) end
end

function Instance:allParticipants()
    local out = {}
    for _, p in pairs(self.participants) do out[#out + 1] = p end
    for _, p in ipairs(self.departed or {}) do out[#out + 1] = p end
    return out
end
