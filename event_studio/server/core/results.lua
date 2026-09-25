-- EVENT STUDIO — Instance results, persistence and cleanup

local U = ES.Util
local S = ES.Lifecycle.States
local Log = ES.Log
local Instance = ES.Instance

---Freeze ranking, compute placements and season points, persist, push results.
function Instance:computeResults()
    local all = self:allParticipants()
    -- still-active racers at time-up keep 'active' (ranked by progress); nobody is dropped
    local ranked
    local teamRanking
    if #self.teams > 0 then
        teamRanking = ES.Scoring.rankTeams(U.deepCopy(self.teams), all)
        local placeOf = {}
        for _, t in ipairs(teamRanking) do placeOf[t.index] = t.placement end
        for _, p in ipairs(all) do
            if p.status == 'disqualified' then p.placement = nil
            elseif p.status == 'left' or p.status == 'disconnected' then p.placement = nil
            else p.placement = p.team and placeOf[p.team] or nil end
        end
        ranked = all
        table.sort(ranked, function(a, b)
            local pa, pb = a.placement or 999, b.placement or 999
            if pa ~= pb then return pa < pb end
            return a.score > b.score
        end)
    elseif self.mode.rankBy == 'custom' and self.mode.rank then
        ranked = self.mode.rank(self, all)
    else
        ranked = ES.Scoring.rankParticipants(all, self.mode.rankBy)
    end

    local profile = ES.Scoring.profile(self.def)
    local rows = {}
    for _, p in ipairs(ranked) do
        if p.removed then
            p.points = 0
        else
            local activeMs = p.activeSince and ((p.leftAt or p.disconnectedAt or ES.now()) - p.activeSince) or 0
            p.points = ES.Scoring.points(profile, p, { everActive = p.everActive, activeMs = activeMs })
        end
        rows[#rows + 1] = {
            src = p.src, identifier = p.identifier, name = p.name, team = p.team, placement = p.placement,
            status = p.status, score = p.score, points = p.points,
            kills = p.stats.kills, deaths = p.stats.deaths, objectives = p.stats.objectives,
            bestStreak = p.stats.bestStreak, finishMs = p.finishMs, everActive = p.everActive, removed = p.removed,
        }
    end
    self.results = rows
    self.teamResults = teamRanking

    local winner
    if teamRanking and teamRanking[1] and teamRanking[1].placement == 1 then
        winner = teamRanking[1].name
    elseif rows[1] and rows[1].placement == 1 then
        winner = rows[1].name
    end
    self.winner = winner

    -- public results payload (no identifiers)
    local public = {}
    for i, r in ipairs(rows) do
        public[i] = { name = r.name, team = r.team, placement = r.placement, status = r.status, score = r.score,
                      points = r.points, kills = r.kills, deaths = r.deaths, finishMs = r.finishMs, src = r.src }
    end
    self:broadcast('results', {
        id = self.id, name = self.def.name, winner = winner, rows = public,
        teams = teamRanking and U.map(teamRanking, function(t)
            return { index = t.index, name = t.name, color = t.color, score = t.score, placement = t.placement }
        end) or nil,
        remainingMs = self.def.timing.results * 1000,
    })

    if winner and self.def.visibility == 'public' and not self.invite then
        ES.Announce.global('winner', 'announce_winner', winner, self.def.name)
    end

    TriggerEvent('event_studio:results', self.id, rows)
    Citizen.CreateThread(function()
        local ok, err = pcall(ES.Stats.record, self, rows)
        if not ok then Log.error('#%d stats record failed: %s', self.id, tostring(err)) end
    end)
end

function Instance:summary()
    return {
        id = self.id, definitionId = self.def.id, name = self.def.name, mode = self.def.mode, category = self.def.category,
        finalState = self.state == S.ARCHIVED and (self.cancelledFrom and 'CANCELLED' or 'COMPLETED') or self.state,
        startedAt = self.startedAtWall, endedAt = os.time(), participants = #self:allParticipants(),
        winner = self.winner, tournamentId = self.tournament, reason = self.stateReason,
    }
end

---Final cleanup when entering ARCHIVED.
function Instance:cleanup()
    for i = #self.componentOrder, 1, -1 do
        local obj = self.componentOrder[i]
        if obj.detach then
            local ok, err = pcall(obj.detach, obj)
            if not ok then Log.error('#%d component %s detach: %s', self.id, obj.__name, tostring(err)) end
        end
    end
    if self.mode.cleanup then pcall(self.mode.cleanup, self) end
    for _, ent in ipairs(self.entities) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    self.entities = {}
    for src, p in pairs(self.participants) do
        if self.bucket and p.returnPoint then
            self:returnToWorld(src, p.returnPoint, 'ended')
        else
            ES.Manager.unindex(src, self)
            ES.push(src, 'left', { id = self.id, reason = 'ended' })
        end
    end
    for src, s in pairs(self.spectators) do
        self:returnToWorld(src, s.returnPoint, 'ended')
    end
    self.spectators = {}
    -- disconnected players who never came back: their return point stays in KVP for next join
    ES.Buckets.release(self.bucket)
    self.bucket = nil
    if self.cancelledFrom and not self.results then
        Citizen.CreateThread(function()
            pcall(ES.Storage.recordInstance, self:summary(), {})
        end)
    end
    ES.Manager.remove(self)
end
