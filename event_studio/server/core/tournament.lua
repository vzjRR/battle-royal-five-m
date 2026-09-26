-- EVENT STUDIO — tournaments: single elimination & round robin, best-of-N series.
-- Every match is a normal Event Engine instance (invite-only) of the tournament's definition.

local U = ES.Util
local Log = ES.Log

local T = { list = {} }
ES.Tournaments = T

----------------------------------------------------------------------------
-- Pure bracket logic
----------------------------------------------------------------------------

local function nextPow2(n)
    local p = 1
    while p < n do p = p * 2 end
    return p
end

---Standard seeding positions for a bracket of size n (1 vs n, 2 vs n-1 ... interleaved).
function T.seedOrder(n)
    local order = { 1 }
    while #order < n do
        local size = #order * 2
        local nextOrder = {}
        for _, s in ipairs(order) do
            nextOrder[#nextOrder + 1] = s
            nextOrder[#nextOrder + 1] = size + 1 - s
        end
        order = nextOrder
    end
    return order
end

local function newMatch(id, round, a, b)
    return { id = id, round = round, a = a, b = b, winner = nil, wins = { a = 0, b = 0 }, status = 'pending', games = {} }
end

---Build a single elimination bracket. entrants = ordered by seed: { {key, name, members}, ... }
function T.buildSingleElimination(entrants)
    local size = nextPow2(math.max(2, #entrants))
    local order = T.seedOrder(size)
    local rounds = {}
    local first = {}
    for i = 1, size, 2 do
        local a, b = entrants[order[i]], entrants[order[i + 1]]
        first[#first + 1] = newMatch(('r1m%d'):format(#first + 1), 1, a and a.key or nil, b and b.key or nil)
    end
    rounds[1] = first
    local count, r = #first, 1
    while count > 1 do
        r = r + 1
        count = count // 2
        local list = {}
        for m = 1, count do list[m] = newMatch(('r%dm%d'):format(r, m), r, nil, nil) end
        rounds[r] = list
    end
    return rounds
end

---Circle-method round robin. Returns rounds of matches (byes skipped).
function T.buildRoundRobin(entrants)
    local keys = {}
    for i, e in ipairs(entrants) do keys[i] = e.key end
    if #keys % 2 == 1 then keys[#keys + 1] = false end
    local n = #keys
    local rounds = {}
    for r = 1, n - 1 do
        local list = {}
        for i = 1, n // 2 do
            local a, b = keys[i], keys[n + 1 - i]
            if a and b then list[#list + 1] = newMatch(('r%dm%d'):format(r, #list + 1), r, a, b) end
        end
        rounds[r] = list
        -- rotate all but the first
        local last = table.remove(keys)
        table.insert(keys, 2, last)
    end
    return rounds
end

----------------------------------------------------------------------------
-- Double elimination: winners bracket + losers bracket + grand final (with bracket reset).
-- Matches are a graph: winTo / loseTo point to { id, slot }. Slot values: nil = waiting,
-- key = entrant, false = nobody will ever arrive (bye / void).
----------------------------------------------------------------------------

function T.buildDoubleElimination(entrants)
    local size = nextPow2(math.max(2, #entrants))
    local k = 0
    while (1 << k) < size do k = k + 1 end
    local order = T.seedOrder(size)
    local rounds, labels = {}, {}
    local function mk(id) return newMatch(id, #rounds + 1, nil, nil) end
    for r = 1, k do
        local list = {}
        for i = 1, size >> r do list[i] = mk(('w%dm%d'):format(r, i)) end
        rounds[#rounds + 1] = list
        labels[#labels + 1] = ('Winners %d'):format(r)
    end
    local lbCount = 2 * (k - 1)
    for j = 1, lbCount do
        local list = {}
        for i = 1, size >> ((j + 1) // 2 + 1) do list[i] = mk(('l%dm%d'):format(j, i)) end
        rounds[#rounds + 1] = list
        labels[#labels + 1] = ('Losers %d'):format(j)
    end
    rounds[#rounds + 1] = { mk('gf1') }
    labels[#labels + 1] = 'Grand final'
    rounds[#rounds + 1] = { mk('gf2') }
    labels[#labels + 1] = 'Grand final (reset)'
    local function slot(i) return i % 2 == 1 and 'a' or 'b' end
    for r = 1, k do
        for i, m in ipairs(rounds[r]) do
            m.winTo = r < k and { id = ('w%dm%d'):format(r + 1, (i + 1) // 2), slot = slot(i) } or { id = 'gf1', slot = 'a' }
            if k == 1 then
                m.loseTo = { id = 'gf1', slot = 'b' }
            elseif r == 1 then
                m.loseTo = { id = ('l1m%d'):format((i + 1) // 2), slot = slot(i) }
            else
                m.loseTo = { id = ('l%dm%d'):format(2 * r - 2, i), slot = 'b' }
            end
        end
    end
    for j = 1, lbCount do
        for i, m in ipairs(rounds[k + j]) do
            if j == lbCount then m.winTo = { id = 'gf1', slot = 'b' }
            elseif j % 2 == 1 then m.winTo = { id = ('l%dm%d'):format(j + 1, i), slot = 'a' }
            else m.winTo = { id = ('l%dm%d'):format(j + 1, (i + 1) // 2), slot = slot(i) } end
        end
    end
    for i, m in ipairs(rounds[1]) do
        local ea, eb = entrants[order[2 * i - 1]], entrants[order[2 * i]]
        m.a, m.b = ea and ea.key or false, eb and eb.key or false
    end
    return rounds, labels
end

local findMatch

local function resolveGraph(t, m)
    if m.status ~= 'pending' or m.a == nil or m.b == nil or (m.a and m.b) then return end
    if m.a then T.setWinner(t, m, m.a, 'bye')
    elseif m.b then T.setWinner(t, m, m.b, 'bye')
    else T.setWinner(t, m, nil, 'void') end
end

local function place(t, dest, value)
    local d = findMatch(t, dest.id)
    if not d then return end
    d[dest.slot] = value
    resolveGraph(t, d)
end

local function advanceGraph(t, m, key)
    local loser = false
    if key ~= nil then
        -- explicit branch: `x and false or y` would turn a false ("nobody") slot into y
        if m.a == key then loser = m.b else loser = m.a end
        if loser == nil then loser = false end
    end
    if m.id == 'gf1' then
        local gf2 = findMatch(t, 'gf2')
        if key and key == m.a then
            gf2.status, gf2.reason = 'void', 'not_needed'
            t.winner, t.status = key, 'complete'
        elseif key then
            gf2.a, gf2.b = m.a, key -- bracket reset: the winners-bracket champion's first loss
        end
        return
    elseif m.id == 'gf2' then
        t.winner, t.status = key, 'complete'
        return
    end
    place(t, m.winTo, key or false)
    if m.loseTo then place(t, m.loseTo, loser) end
end

function T.resolveGraphByes(t)
    for _, m in ipairs(t.rounds[1]) do resolveGraph(t, m) end
end

----------------------------------------------------------------------------
-- Swiss: pair players with similar scores each round, no rematches, byes for odd counts.
----------------------------------------------------------------------------

local function standing(t, key)
    t.standings[key] = t.standings[key] or { points = 0, wins = 0, losses = 0, draws = 0 }
    return t.standings[key]
end

---Buchholz tie-break: sum of the points of everyone the entrant played.
function T.buchholz(t, key)
    local sum = 0
    for opp in pairs((t.played or {})[key] or {}) do sum = sum + standing(t, opp).points end
    return sum
end

---Entrant keys ordered by points, Buchholz, wins, then seed.
function T.standingsOrder(t)
    local keys = {}
    for i, e in ipairs(t.entrants) do keys[#keys + 1] = { key = e.key, seed = i } end
    table.sort(keys, function(x, y)
        local a, b = standing(t, x.key), standing(t, y.key)
        if a.points ~= b.points then return a.points > b.points end
        local ba, bb = T.buchholz(t, x.key), T.buchholz(t, y.key)
        if ba ~= bb then return ba > bb end
        if a.wins ~= b.wins then return a.wins > b.wins end
        return x.seed < y.seed
    end)
    return U.map(keys, function(x) return x.key end)
end

---Create the next Swiss round (appended to t.rounds).
function T.swissNextRound(t)
    t.played = t.played or {}
    t.byes = t.byes or {}
    local r = #t.rounds + 1
    local unpaired = T.standingsOrder(t)
    local list = {}
    if #unpaired % 2 == 1 then
        local idx = #unpaired
        for i = #unpaired, 1, -1 do if not t.byes[unpaired[i]] then idx = i break end end
        local bye = table.remove(unpaired, idx)
        t.byes[bye] = true
        local s = standing(t, bye)
        s.points, s.wins = s.points + 3, s.wins + 1
        local m = newMatch(('r%dbye'):format(r), r, bye, nil)
        m.status, m.winner, m.reason = 'done', bye, 'bye'
        list[#list + 1] = m
    end
    while #unpaired > 0 do
        local a = table.remove(unpaired, 1)
        local pick = 1
        for i = 1, #unpaired do
            if not (t.played[a] and t.played[a][unpaired[i]]) then pick = i break end
        end
        local b = table.remove(unpaired, pick)
        t.played[a] = t.played[a] or {}
        t.played[b] = t.played[b] or {}
        t.played[a][b], t.played[b][a] = true, true
        list[#list + 1] = newMatch(('r%dm%d'):format(r, #list + 1), r, a, b)
    end
    t.rounds[r] = list
    t.currentRound = r
    return list
end

findMatch = function(t, id)
    for ri, round in ipairs(t.rounds) do
        for mi, m in ipairs(round) do
            if m.id == id then return m, ri, mi end
        end
    end
end
T.findMatch = findMatch

---Resolve byes in round 1 of single elimination (and propagate).
function T.resolveByes(t)
    if t.format ~= 'single_elimination' then return end
    for _, m in ipairs(t.rounds[1]) do
        if m.status == 'pending' and ((m.a and not m.b) or (m.b and not m.a)) then
            T.setWinner(t, m, m.a or m.b, 'bye')
        elseif m.status == 'pending' and not m.a and not m.b then
            m.status = 'void'
            T.setWinner(t, m, nil, 'void')
        end
    end
end

---Set match winner and advance (single elimination) / score (round robin).
function T.setWinner(t, m, key, reason)
    m.winner = key
    m.status = (reason == 'void') and 'void' or 'done'
    m.reason = reason
    if t.format == 'double_elimination' then
        return advanceGraph(t, m, key)
    end
    if t.format == 'single_elimination' then
        local _, ri, mi = findMatch(t, m.id)
        local nextRound = t.rounds[ri + 1]
        if nextRound then
            local nm = nextRound[(mi + 1) // 2]
            if mi % 2 == 1 then nm.a = key else nm.b = key end
            -- a void/bye feeding into a match with one entrant → auto-advance when the other side is settled
            local sibling = t.rounds[ri][mi % 2 == 1 and mi + 1 or mi - 1]
            if sibling and (sibling.status == 'done' or sibling.status == 'void') then
                if nm.a and not nm.b then T.setWinner(t, nm, nm.a, 'bye')
                elseif nm.b and not nm.a then T.setWinner(t, nm, nm.b, 'bye')
                elseif not nm.a and not nm.b then T.setWinner(t, nm, nil, 'void') end
            end
        else
            t.winner = key
            t.status = 'complete'
        end
    else
        if key then
            t.standings[key] = t.standings[key] or { points = 0, wins = 0, losses = 0, draws = 0 }
            t.standings[key].points = t.standings[key].points + 3
            t.standings[key].wins = t.standings[key].wins + 1
            local loser = (key == m.a) and m.b or m.a
            if loser then
                t.standings[loser] = t.standings[loser] or { points = 0, wins = 0, losses = 0, draws = 0 }
                t.standings[loser].losses = t.standings[loser].losses + 1
            end
        elseif reason == 'draw' then
            for _, k in ipairs({ m.a, m.b }) do
                t.standings[k] = t.standings[k] or { points = 0, wins = 0, losses = 0, draws = 0 }
                t.standings[k].points = t.standings[k].points + 1
                t.standings[k].draws = t.standings[k].draws + 1
            end
        end
        local allDone = true
        for _, round in ipairs(t.rounds) do
            for _, mm in ipairs(round) do if mm.status ~= 'done' and mm.status ~= 'void' then allDone = false end end
        end
        if allDone and t.format == 'swiss' then
            if (t.currentRound or 0) >= (t.totalRounds or 0) then
                t.winner = T.standingsOrder(t)[1]
                t.status = 'complete'
            end
        elseif allDone then
            local best, bestPts
            for k, s in pairs(t.standings) do
                if not bestPts or s.points > bestPts or (s.points == bestPts and s.wins > t.standings[best].wins) then
                    best, bestPts = k, s.points
                end
            end
            t.winner = best
            t.status = 'complete'
        end
    end
end

---Record one game of a series. Returns true when the series is decided.
function T.recordGame(t, m, winnerKey)
    m.games[#m.games + 1] = winnerKey or 'draw'
    local need = (t.bestOf or 1) // 2 + 1
    if winnerKey == m.a then m.wins.a = m.wins.a + 1 elseif winnerKey == m.b then m.wins.b = m.wins.b + 1 end
    if m.wins.a >= need then T.setWinner(t, m, m.a, 'series') return true end
    if m.wins.b >= need then T.setWinner(t, m, m.b, 'series') return true end
    if #m.games >= (t.bestOf or 1) * 2 then
        -- too many draws: higher wins, else a (higher seed)
        T.setWinner(t, m, m.wins.b > m.wins.a and m.b or m.a, 'draw_limit')
        return true
    end
    if (t.format == 'round_robin' or t.format == 'swiss') and (t.bestOf or 1) == 1 and not winnerKey then
        T.setWinner(t, m, nil, 'draw')
        return true
    end
    return false
end

---Matches ready to be played.
function T.readyMatches(t)
    local out = {}
    for ri, round in ipairs(t.rounds) do
        if (t.format == 'round_robin' or t.format == 'swiss') and ri ~= t.currentRound then goto continue end
        for _, m in ipairs(round) do
            if m.status == 'pending' and m.a and m.b then out[#out + 1] = m end
        end
        ::continue::
    end
    return out
end

----------------------------------------------------------------------------
-- Runner
----------------------------------------------------------------------------

local function entrantByKey(t, key)
    for _, e in ipairs(t.entrants) do if e.key == key then return e end end
end

local function onlineSrcOf(identifier)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if ES.Bridge.getIdentifier(src) == identifier then return src end
    end
end

local function save(t)
    Citizen.CreateThread(function() pcall(ES.Storage.saveDocument, 'tournament', t.id, T.public(t)) end)
end

function T.public(t)
    return {
        id = t.id, name = t.name, definitionId = t.definitionId, format = t.format, bestOf = t.bestOf,
        status = t.status, winner = t.winner, entrants = U.map(t.entrants, function(e) return { key = e.key, name = e.name } end),
        rounds = t.rounds, roundLabels = t.roundLabels, standings = t.standings, currentRound = t.currentRound,
        totalRounds = t.totalRounds, registrationEndsAt = t.registrationEndsAt,
        createdAt = t.createdAt,
    }
end

---Create a tournament. cfg = { id?, name, definitionId, format, bestOf, seeding, registrationSeconds, entrants? }
function T.create(cfg, actor)
    local def = ES.Definitions.get(cfg.definitionId)
    if not def then return false, 'unknown_definition' end
    local id = cfg.id or ('t' .. os.time() .. math.random(100, 999))
    local t = {
        id = id, name = cfg.name or def.name .. ' Cup', definitionId = def.id,
        format = ({ round_robin = true, double_elimination = true, swiss = true })[cfg.format] and cfg.format or 'single_elimination',
        swissRounds = tonumber(cfg.swissRounds),
        bestOf = (cfg.bestOf == 3 or cfg.bestOf == 5) and cfg.bestOf or 1,
        seeding = cfg.seeding or 'registration',
        teamSize = def.players.teams and (def.players.teams.size or 1) or 1,
        entrants = {}, rounds = {}, standings = {}, status = 'registration',
        createdAt = os.time(), matchInstances = {},
    }
    t.registrationEndsAt = os.time() + (cfg.registrationSeconds or 180)
    for _, e in ipairs(cfg.entrants or {}) do t.entrants[#t.entrants + 1] = e end
    T.list[id] = t
    save(t)
    Log.audit('tournament.created', actor, nil, { id = id, name = t.name })
    if t.registrationEndsAt > os.time() then
        ES.Announce.global('registrationOpen', 'announce_tournament_open', t.name, ES.UI.menuKey())
    end
    return true, id
end

---Player registers as a solo entrant.
function T.join(id, src)
    local t = T.list[id]
    if not t or t.status ~= 'registration' then return false, 'not_open' end
    local identifier = ES.Bridge.getIdentifier(src)
    for _, e in ipairs(t.entrants) do
        if e.key == identifier or U.contains(e.members or {}, identifier) then return false, 'already_joined' end
    end
    t.entrants[#t.entrants + 1] = { key = identifier, name = ES.Bridge.getName(src), members = { identifier } }
    save(t)
    return true
end

function T.begin(id)
    local t = T.list[id]
    if not t or t.status ~= 'registration' then return false, 'invalid_state' end
    if #t.entrants < 2 then
        t.status = 'cancelled'
        save(t)
        return false, 'not_enough_entrants'
    end
    if t.seeding == 'random' then U.shuffle(t.entrants) end
    if t.format == 'single_elimination' then
        t.rounds = T.buildSingleElimination(t.entrants)
        t.status = 'running'
        T.resolveByes(t)
    elseif t.format == 'double_elimination' then
        t.rounds, t.roundLabels = T.buildDoubleElimination(t.entrants)
        t.status = 'running'
        T.resolveGraphByes(t)
    elseif t.format == 'swiss' then
        local log2 = 0
        while (1 << log2) < #t.entrants do log2 = log2 + 1 end
        t.totalRounds = math.max(1, math.min(t.swissRounds or log2, #t.entrants - 1))
        t.rounds = {}
        t.status = 'running'
        T.swissNextRound(t)
    else
        t.rounds = T.buildRoundRobin(t.entrants)
        t.currentRound = 1
        t.status = 'running'
    end
    save(t)
    T.launchReady(t)
    return true
end

---Create instances for all ready matches.
function T.launchReady(t)
    if t.status ~= 'running' then return end
    if t.format == 'swiss' then
        local round = t.rounds[t.currentRound]
        local done = true
        for _, m in ipairs(round or {}) do if m.status ~= 'done' and m.status ~= 'void' then done = false end end
        if done and t.currentRound < t.totalRounds then T.swissNextRound(t) end
    elseif t.format == 'round_robin' then
        local round = t.rounds[t.currentRound]
        local done = true
        for _, m in ipairs(round or {}) do if m.status ~= 'done' and m.status ~= 'void' then done = false end end
        if done and t.rounds[t.currentRound + 1] then t.currentRound = t.currentRound + 1 end
    end
    for _, m in ipairs(T.readyMatches(t)) do
        if not t.matchInstances[m.id] then T.launchMatch(t, m) end
    end
end

function T.launchMatch(t, m)
    local ea, eb = entrantByKey(t, m.a), entrantByKey(t, m.b)
    local srcA, srcB = {}, {}
    for _, ident in ipairs(ea.members or { ea.key }) do local s = onlineSrcOf(ident) if s then srcA[#srcA + 1] = s end end
    for _, ident in ipairs(eb.members or { eb.key }) do local s = onlineSrcOf(ident) if s then srcB[#srcB + 1] = s end end
    if #srcA == 0 or #srcB == 0 then
        local winner = (#srcA > 0) and m.a or ((#srcB > 0) and m.b or m.a)
        Log.info('Tournament %s match %s forfeit (%s absent)', t.id, m.id, #srcA == 0 and ea.name or eb.name)
        T.setWinner(t, m, winner, 'forfeit')
        save(t)
        return T.launchReady(t)
    end
    local invite = {}
    for _, s in ipairs(srcA) do invite[#invite + 1] = s end
    for _, s in ipairs(srcB) do invite[#invite + 1] = s end
    local overrides = { players = { min = 2, max = #invite } }
    local def = ES.Definitions.get(t.definitionId)
    if def.players.teams then
        overrides.players.teams = { count = 2, auto = false, fixed = { ea.members or { ea.key }, eb.members or { eb.key } } }
    end
    local ok, instId = ES.Manager.create(t.definitionId, {
        overrides = overrides, invite = invite, registration = 45, tournament = t.id, match = m.id,
        createdBy = 'tournament:' .. t.id,
    })
    if not ok then
        Log.error('Tournament %s failed to create match %s: %s', t.id, m.id, tostring(instId))
        return
    end
    t.matchInstances[m.id] = instId
    m.status = 'live'
    for _, s in ipairs(invite) do
        ES.Manager.join(s, instId, true)
        ES.push(s, 'announce', { text = L('tournament_match_ready', t.name), kind = 'info' })
    end
    ES.Manager.get(instId):start(true)
    save(t)
end

---Instance finished → record the game.
AddEventHandler('event_studio:results', function(instanceId, rows)
    local inst = ES.Manager.get(instanceId)
    if not inst or not inst.tournament then return end
    local t = T.list[inst.tournament]
    if not t then return end
    local m = findMatch(t, inst.match)
    if not m then return end
    local winnerKey
    if inst.teamResults and inst.teamResults[1] and inst.teamResults[1].placement == 1
        and not (inst.teamResults[2] and inst.teamResults[2].placement == 1) then
        winnerKey = inst.teamResults[1].index == 1 and m.a or m.b
    elseif rows[1] and rows[1].placement == 1 and not (rows[2] and rows[2].placement == 1) then
        local ea = entrantByKey(t, m.a)
        winnerKey = U.contains(ea.members or { ea.key }, rows[1].identifier) and m.a or m.b
    end
    t.matchInstances[m.id] = nil
    m.status = 'pending'
    local decided = T.recordGame(t, m, winnerKey)
    save(t)
    SetTimeout(((inst.def.timing.results or 15) + 5) * 1000, function()
        if decided then T.launchReady(t) else T.launchMatch(t, m) end
        if t.status == 'complete' then
            local w = entrantByKey(t, t.winner)
            ES.Announce.global('winner', 'announce_tournament_winner', w and w.name or '?', t.name)
            save(t)
        end
    end)
end)

---Registration deadline watcher.
function T.start()
    Citizen.CreateThread(function()
        while true do
            Wait(5000)
            for id, t in pairs(T.list) do
                if t.status == 'registration' and os.time() >= t.registrationEndsAt then
                    local ok, err = T.begin(id)
                    if not ok then Log.warn('Tournament %s did not start: %s', id, tostring(err)) end
                end
            end
        end
    end)
end

function T.loadAll()
    for id, t in pairs(ES.Storage.loadDocuments('tournament') or {}) do
        -- running tournaments cannot resume live matches after a restart; keep them for history
        if t.status == 'running' or t.status == 'registration' then t.status = 'interrupted' end
        t.matchInstances = {}
        T.list[id] = t
    end
end

return T
