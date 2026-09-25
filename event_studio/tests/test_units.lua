-- Unit tests for pure modules: lifecycle, schema, scoring, scheduler, tournament, rate limiter.
local H = T
H.boot()
local U = ES.Util

H.test('lifecycle transitions', function()
    local L = ES.Lifecycle
    H.ok(L.canTransition('REGISTRATION', 'LOBBY'))
    H.ok(L.canTransition('ACTIVE', 'PAUSED'))
    H.ok(L.canTransition('PAUSED', 'ACTIVE'))
    H.ok(L.canTransition('RESULTS', 'REWARDS'))
    H.no(L.canTransition('RESULTS', 'CANCELLED'), 'no cancel after results')
    H.no(L.canTransition('REGISTRATION', 'ACTIVE'), 'no skipping lobby')
    H.no(L.canTransition('ARCHIVED', 'REGISTRATION'))
    H.ok(L.isCancellable('COUNTDOWN'))
    H.no(L.isCancellable('REWARDS'))
    H.eq(L.publicStatus('REGISTRATION', true), 'full')
    H.eq(L.publicStatus('ACTIVE'), 'live')
end)

H.test('schema validation', function()
    local S = ES.Schema
    local ok, v = S.validateFields({ a = 5, junk = 'x' }, { a = { type = 'integer', min = 1, max = 10 }, b = { type = 'boolean', default = true } })
    H.ok(ok) H.eq(v.a, 5) H.eq(v.b, true) H.eq(v.junk, nil, 'unknown keys dropped')
    H.no((S.validateFields({ a = 11 }, { a = { type = 'integer', max = 10 } })))
    H.no((S.validateFields({ a = 1.5 }, { a = 'integer' })))
    H.no((S.validateFields({ a = 0 / 0 }, { a = 'number' })), 'NaN rejected')
    H.no((S.validateFields({ id = 'bad id!' }, { id = 'id' })))
    H.no((S.validateFields({ s = string.rep('x', 300) }, { s = 'string' })), 'long string rejected')
    H.ok((S.validateFields({}, { o = 'integer?' })))
    local okL, list = S.validate({ 1, 2, 3 }, { type = 'list', item = 'integer' })
    H.ok(okL) H.eq(#list, 3)
    H.no((S.validate({ 1, 'x' }, { type = 'list', item = 'integer' })))
    H.no((S.validate({ x = 1e9, y = 0, z = 0 }, { type = 'vec3' })), 'vector bounds')
end)

H.test('ranking with ties, statuses and placements', function()
    local list = {
        { name = 'a', status = 'active', score = 10, stats = { kills = 1 } },
        { name = 'b', status = 'active', score = 10, stats = { kills = 1 } },
        { name = 'c', status = 'eliminated', score = 50, eliminatedAt = 2, stats = {} },
        { name = 'd', status = 'eliminated', score = 0, eliminatedAt = 1, stats = {} },
        { name = 'e', status = 'left', score = 99, stats = {} },
        { name = 'f', status = 'disqualified', score = 100, stats = {} },
    }
    local r = ES.Scoring.rankParticipants(list, 'score')
    H.eq(r[1].placement, 1) H.eq(r[2].placement, 1, 'tie shares placement')
    H.eq(r[3].name, 'c') H.eq(r[3].placement, 3, 'later elimination ranks higher')
    H.eq(r[4].name, 'd')
    H.eq(r[5].name, 'e') H.eq(r[5].placement, nil, 'leaver unplaced')
    H.eq(r[6].placement, nil, 'disqualified unplaced')
end)

H.test('finish ranking: finished by time, then progress', function()
    local list = {
        { name = 'slow', status = 'finished', finishMs = 90000, stats = {} },
        { name = 'fast', status = 'finished', finishMs = 60000, stats = {} },
        { name = 'dnf2', status = 'active', progress = 3.5, stats = {} },
        { name = 'dnf1', status = 'active', progress = 7.2, stats = {} },
    }
    local r = ES.Scoring.rankParticipants(list, 'finish')
    H.eq(r[1].name, 'fast') H.eq(r[2].name, 'slow') H.eq(r[3].name, 'dnf1') H.eq(r[4].name, 'dnf2')
end)

H.test('season points from profile', function()
    local profile = Config.Scoring.profiles.standard
    local p = { status = 'finished', placement = 1, stats = { kills = 2, objectives = 1, bestStreak = 3 } }
    -- 100 placement + 10 participation + 2*5 kills + 10 objective + 5 streak
    H.eq(ES.Scoring.points(profile, p, { everActive = true }), 135)
    H.eq(ES.Scoring.points(profile, { status = 'left', stats = {} }, { everActive = true }), -10, 'abandon penalty')
    H.eq(ES.Scoring.points(profile, { status = 'disqualified', stats = {} }, {}), -25, 'dq penalty')
end)

H.test('team ranking', function()
    local teams = { { index = 1, score = 5 }, { index = 2, score = 9 } }
    local parts = { { team = 1, status = 'active' }, { team = 2, status = 'active' } }
    local r = ES.Scoring.rankTeams(teams, parts)
    H.eq(r[1].index, 2)
    parts[2].status = 'eliminated'
    parts[2].eliminatedAt = 1
    r = ES.Scoring.rankTeams({ { index = 1, score = 5 }, { index = 2, score = 9 } }, parts)
    H.eq(r[1].index, 1, 'surviving team beats higher score eliminated team')
end)

H.test('scheduler: rule validation', function()
    local S = ES.Scheduler
    H.ok(S.validateRule({ type = 'daily', time = '20:00' }))
    H.no(S.validateRule({ type = 'daily', time = '25:00' }))
    H.no(S.validateRule({ type = 'weekly', days = { 8 }, time = '10:00' }))
    H.ok(S.validateRule({ type = 'interval', minutes = 90, from = '14:00', to = '23:30' }))
    H.no(S.validateRule({ type = 'interval', minutes = 1 }))
    H.no(S.validateRule({ type = 'nope' }))
end)

H.test('scheduler: next occurrence (UTC offset 0)', function()
    local S = ES.Scheduler
    -- 2026-09-25 is a Friday. now = 2026-09-25 12:00 UTC
    local now = os.time({ year = 2026, month = 9, day = 25, hour = 12, min = 0, sec = 0, isdst = false })
        + (os.time(os.date('*t', 86400)) - os.time(os.date('!*t', 86400)))
    local function fmt(ts) return os.date('!%Y-%m-%d %H:%M %a', ts) end
    H.eq(fmt(S.nextOccurrence({ type = 'daily', time = '20:00' }, now, 0)), '2026-09-25 20:00 Fri')
    H.eq(fmt(S.nextOccurrence({ type = 'daily', time = '11:00' }, now, 0)), '2026-09-26 11:00 Sat')
    H.eq(fmt(S.nextOccurrence({ type = 'weekly', days = { 5 }, time = '21:00' }, now, 0)), '2026-09-25 21:00 Fri')
    H.eq(fmt(S.nextOccurrence({ type = 'weekly', days = { 5 }, time = '09:00' }, now, 0)), '2026-10-02 09:00 Fri')
    H.eq(fmt(S.nextOccurrence({ type = 'weekly', days = { 1, 3 }, time = '18:00' }, now, 0)), '2026-09-28 18:00 Mon')
    H.eq(fmt(S.nextOccurrence({ type = 'monthly', day = 1, time = '19:00' }, now, 0)), '2026-10-01 19:00 Thu')
    H.eq(fmt(S.nextOccurrence({ type = 'monthly', day = 31, time = '19:00' }, now, 0)), '2026-09-30 19:00 Wed', 'clamped to last day')
    H.eq(fmt(S.nextOccurrence({ type = 'once', date = '2026-12-31', time = '23:00' }, now, 0)), '2026-12-31 23:00 Thu')
    H.eq(S.nextOccurrence({ type = 'once', date = '2026-01-01', time = '23:00' }, now, 0), nil, 'past once')
    H.eq(fmt(S.nextOccurrence({ type = 'interval', minutes = 90, from = '14:00', to = '23:30' }, now, 0)), '2026-09-25 14:00 Fri')
    H.eq(fmt(S.nextOccurrence({ type = 'daily', time = '10:00' }, now, 120)), '2026-09-26 08:00 Sat', 'UTC+2 10:00 = 08:00Z')
end)

H.test('tournament: seed order and single elimination byes', function()
    local T8 = ES.Tournaments.seedOrder(8)
    H.eq(table.concat(T8, ','), '1,8,4,5,2,7,3,6')
    local entrants = {}
    for i = 1, 5 do entrants[i] = { key = 'p' .. i, name = 'P' .. i } end
    local t = { format = 'single_elimination', bestOf = 1, entrants = entrants, standings = {} }
    t.rounds = ES.Tournaments.buildSingleElimination(entrants)
    H.eq(#t.rounds, 3, 'rounds for 8 slots')
    ES.Tournaments.resolveByes(t)
    local ready = ES.Tournaments.readyMatches(t)
    H.eq(#ready, 2, '4v5 and (bye-advanced) 2v3 are ready')
    H.eq(ready[1].a, 'p4') H.eq(ready[1].b, 'p5')
    H.eq(t.rounds[2][1].a, 'p1', 'seed 1 advanced by bye')
    local games = 0
    while t.status ~= 'complete' and games < 10 do
        local m = ES.Tournaments.readyMatches(t)[1]
        ES.Tournaments.recordGame(t, m, m.b)
        games = games + 1
    end
    H.eq(games, 4, '5 entrants need 4 played matches')
    H.eq(t.status, 'complete')
    H.ok(t.winner)
end)

H.test('tournament: best of 3 series', function()
    local e = { { key = 'a' }, { key = 'b' } }
    local t = { format = 'single_elimination', bestOf = 3, entrants = e, standings = {} }
    t.rounds = ES.Tournaments.buildSingleElimination(e)
    local m = t.rounds[1][1]
    H.no(ES.Tournaments.recordGame(t, m, 'a'))
    H.no(ES.Tournaments.recordGame(t, m, 'b'))
    H.ok(ES.Tournaments.recordGame(t, m, 'b'))
    H.eq(t.winner, 'b')
end)

H.test('tournament: round robin', function()
    local e = {}
    for i = 1, 4 do e[i] = { key = 'k' .. i } end
    local rounds = ES.Tournaments.buildRoundRobin(e)
    H.eq(#rounds, 3)
    local pairsSeen, total = {}, 0
    for _, r in ipairs(rounds) do
        for _, m in ipairs(r) do
            local k = m.a < m.b and (m.a .. m.b) or (m.b .. m.a)
            H.no(pairsSeen[k], 'duplicate pairing ' .. k)
            pairsSeen[k] = true
            total = total + 1
        end
    end
    H.eq(total, 6)
    local t = { format = 'round_robin', bestOf = 1, entrants = e, standings = {}, rounds = rounds, currentRound = 1 }
    for _, r in ipairs(rounds) do for _, m in ipairs(r) do ES.Tournaments.recordGame(t, m, m.a < m.b and m.a or m.b) end end
    H.eq(t.status, 'complete')
    H.eq(t.winner, 'k1', 'k1 won all its games')
end)

H.test('token bucket rate limiter', function()
    local b = U.newBucket(3, 3)
    H.ok(U.takeToken(b, 0)) H.ok(U.takeToken(b, 0)) H.ok(U.takeToken(b, 0))
    H.no(U.takeToken(b, 0), 'burst exhausted')
    H.ok(U.takeToken(b, 1100), 'refilled after 1.1s')
end)

H.test('util merge/deepCopy/isArray', function()
    local m = U.merge({ a = { b = 1, c = 2 }, l = { 1, 2 } }, { a = { c = 3 }, l = { 9 } })
    H.eq(m.a.b, 1) H.eq(m.a.c, 3) H.eq(#m.l, 1, 'arrays replaced')
    H.ok(U.isArray({ 1, 2 })) H.no(U.isArray({ a = 1 }))
end)
