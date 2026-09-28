-- Simulation: full race lifecycle at different player counts, validation, rewards, cleanup.
local H = T
H.boot()
H.recordRewards()

assert(ES.Definitions.register({
    id = 'test_race', name = 'Test Race', mode = 'race', arena = 'downtown_circuit',
    players = { min = 1, max = 64 }, timing = { registration = 30, lobby = 2, countdown = 2, duration = 600, grace = 20, results = 3 },
    options = { laps = 1 },
    rewards = { placement = { [1] = { { type = 'test', amount = 100 } } }, participation = { { type = 'test', amount = 1 } } },
}))

local arena = ES.Arenas.get('downtown_circuit')

local function drive(inst, srcs)
    for i, cp in ipairs(arena.checkpoints) do
        Sim.advance(2000) -- plausible travel time between checkpoints
        for _, s in ipairs(srcs) do
            H.setPos(s, cp.x, cp.y, cp.z)
            local ok, res = H.rpc(s, 'event:action', { action = 'checkpoint', data = { index = i } })
            H.ok(ok, ('checkpoint %d for %d rejected: %s'):format(i, s, tostring(res)))
            if i == #arena.checkpoints then Sim.advance(20) end
        end
    end
end

for _, n in ipairs({ 1, 2, 4, 8, 16, 32, 64 }) do
    H.test(('race with %d player(s): lifecycle, results, rewards, cleanup'):format(n), function()
        H.paid = {}
        local srcs = H.players(n, 100 * n)
        for _, s in ipairs(srcs) do H.setPos(s, 500.0, 500.0, 30.0) end
        local inst = H.createAndJoin('test_race', srcs)
        H.toActive(inst)
        H.ok(inst.bucket, 'bucket allocated')
        for _, s in ipairs(srcs) do
            H.eq(Sim.players[s].bucket, inst.bucket, 'player moved into bucket')
            H.ok(Sim.players[s].vehicle ~= 0, 'player seated in a vehicle')
        end
        drive(inst, srcs)
        H.ok(H.waitState(inst, 'ARCHIVED', 60000), 'archived, state=' .. inst.state)
        H.eq(inst.results[1].src, srcs[1], 'first finisher wins')
        H.eq(inst.results[1].placement, 1)
        if n > 1 then H.eq(inst.results[2].placement, 2) end
        local winnerPaid, participation = 0, 0
        for _, p in ipairs(H.paid) do
            if p.amount == 100 then winnerPaid = winnerPaid + 1 else participation = participation + 1 end
        end
        H.eq(winnerPaid, 1, 'exactly one winner payout')
        H.eq(participation, n, 'participation for everyone')
        for _, s in ipairs(srcs) do
            H.eq(Sim.players[s].bucket, 0, 'player returned to bucket 0')
            H.eq(Sim.players[s].pos.x, 500.0, 'player returned to original position')
            H.eq(ES.Manager.ofPlayer(s), nil, 'player unindexed')
        end
        H.eq(ES.Manager.get(inst.id), nil, 'instance removed')
        H.eq(ES.Buckets.inUse(), 0, 'bucket released')
        H.eq(ES.Util.count(Sim.vehicles), 0, 'vehicles deleted')
        for _, s in ipairs(srcs) do Sim.players[s] = nil end
    end)
end

H.test('checkpoint validation: wrong order, too far, too fast', function()
    local srcs = H.players(2, 5000)
    local inst = H.createAndJoin('test_race', srcs)
    H.toActive(inst)
    local a = srcs[1]
    local cp1, cp2 = arena.checkpoints[1], arena.checkpoints[2]
    -- wrong order
    H.setPos(a, cp2.x, cp2.y, cp2.z)
    local ok, err = H.rpc(a, 'event:action', { action = 'checkpoint', data = { index = 2 } })
    H.no(ok) H.eq(err, 'wrong_order')
    -- too far: claims checkpoint 1 while standing elsewhere
    H.setPos(a, cp1.x + 300, cp1.y, cp1.z)
    ok, err = H.rpc(a, 'event:action', { action = 'checkpoint', data = { index = 1 } })
    H.no(ok) H.eq(err, 'too_far')
    -- valid
    Sim.advance(3000)
    H.setPos(a, cp1.x, cp1.y, cp1.z)
    ok = H.rpc(a, 'event:action', { action = 'checkpoint', data = { index = 1 } })
    H.ok(ok, 'cp1 accepted')
    -- teleport to cp2 instantly (too fast)
    H.setPos(a, cp2.x, cp2.y, cp2.z)
    ok, err = H.rpc(a, 'event:action', { action = 'checkpoint', data = { index = 2 } })
    H.no(ok) H.eq(err, 'too_fast')
    inst:cancel('test')
    H.ok(H.waitState(inst, 'ARCHIVED', 5000))
end)

H.test('elimination race eliminates last place over time', function()
    assert(ES.Definitions.register({
        id = 'test_elim_race', name = 'Elim', mode = 'race', arena = 'downtown_circuit',
        players = { min = 2, max = 8 }, timing = { registration = 30, lobby = 1, countdown = 1, duration = 600, grace = 5, results = 3 },
        options = { laps = 3, eliminateEvery = 10 },
    }))
    local srcs = H.players(3, 6000)
    local inst = H.createAndJoin('test_elim_race', srcs)
    H.toActive(inst)
    -- src 6001 & 6002 progress a bit, 6000 stays behind
    Sim.advance(2000)
    for _, s in ipairs({ 6001, 6002 }) do
        local cp = arena.checkpoints[1]
        H.setPos(s, cp.x, cp.y, cp.z)
        H.ok((H.rpc(s, 'event:action', { action = 'checkpoint', data = { index = 1 } })))
    end
    Sim.advance(9000)
    H.eq(inst.byLicense[Sim.players[6000].license].status, 'eliminated', 'last place eliminated')
    Sim.advance(10500)
    local active = inst:activeParticipants()
    H.eq(#active, 1, 'second elimination leaves one')
    inst:finishNow('test')
    H.ok(H.waitState(inst, 'ARCHIVED', 30000))
end)

H.test('leaving mid-race returns the player and keeps the race running', function()
    local srcs = H.players(3, 7000)
    for _, s in ipairs(srcs) do H.setPos(s, 111.0, 222.0, 33.0) end
    local inst = H.createAndJoin('test_race', srcs)
    H.toActive(inst)
    local ok = H.rpc(7000, 'event:leave', {})
    H.ok(ok)
    H.eq(Sim.players[7000].bucket, 0)
    H.eq(Sim.players[7000].pos.x, 111.0)
    H.eq(inst.state, 'ACTIVE', 'race continues')
    H.eq(inst.departed[1].status, 'left')
    inst:finishNow('test')
    H.ok(H.waitState(inst, 'ARCHIVED', 30000))
    local leaver
    for _, r in ipairs(inst.results) do if r.name == Sim.players[7000].name then leaver = r end end
    H.eq(leaver.placement, nil, 'leaver unplaced')
    H.eq(leaver.points, -10, 'abandon penalty')
end)

H.test('a winner who disconnects after finishing is paid automatically when they come back', function()
    H.paid = {}
    local a, b = table.unpack(H.players(2, 7100))
    local license = Sim.players[a].license
    local inst = H.createAndJoin('test_race', { a, b })
    H.toActive(inst)
    drive(inst, { a })                 -- only a finishes
    Sim.removePlayer(a)                -- then crashes before the results
    H.ok(H.waitState(inst, 'ARCHIVED', 120000), 'archived after the finish grace, state=' .. inst.state)
    H.eq(inst.results[1].placement, 1)
    H.eq(inst.results[1].status, 'finished')
    for _, p in ipairs(H.paid) do H.ok(p.src ~= a, 'nothing paid to an offline player') end
    local waiting = ES.Rewards.pendingFor(license)
    H.eq(#waiting, 2, 'win and participation are kept for later')
    -- a second distribute (e.g. restart) must not queue or pay twice
    ES.Rewards.distribute(inst)
    H.eq(#ES.Rewards.pendingFor(license), 2)
    -- back online with a new server id
    local a2 = 7150
    Sim.addPlayer(a2, { license = license })
    H.ok((H.rpc(a2, 'client:ready', {})))
    Sim.advance(6000)
    local got = 0
    for _, p in ipairs(H.paid) do if p.src == a2 then got = got + p.amount end end
    H.eq(got, 101, 'winner and participation paid on return')
    H.eq(#ES.Rewards.pendingFor(license), 0, 'queue cleared')
    H.ok(H.lastPush(a2, 'announce'), 'player told about the late reward')
    Sim.advance(61000)
    local again = 0
    for _, p in ipairs(H.paid) do if p.src == a2 then again = again + 1 end end
    H.eq(again, 2, 'retry loop does not pay twice')
    Sim.players[a2], Sim.players[b] = nil, nil
end)

H.test('a reward that fails (framework not ready) is retried until it succeeds', function()
    local fail = true
    local got = {}
    ES.Rewards.registerType('flaky', function(src, e) if fail then return false end got[#got + 1] = src return true end)
    assert(ES.Definitions.register({ id = 'test_race_flaky', name = 'Flaky', mode = 'race', arena = 'downtown_circuit',
        players = { min = 1, max = 8 }, timing = { registration = 30, lobby = 2, countdown = 2, duration = 600, grace = 5, results = 3 },
        options = { laps = 1 }, rewards = { placement = { [1] = { { type = 'flaky', amount = 5 } } } } }))
    local a = H.players(1, 7200)[1]
    local inst = H.createAndJoin('test_race_flaky', { a })
    H.toActive(inst)
    drive(inst, { a })
    H.ok(H.waitState(inst, 'ARCHIVED', 60000))
    H.eq(#got, 0)
    H.eq(#ES.Rewards.pendingFor(Sim.players[a].license), 1, 'failed payout queued')
    fail = false
    Sim.advance(61000)                 -- retry loop
    H.eq(#got, 1, 'paid by the retry loop')
    H.eq(#ES.Rewards.pendingFor(Sim.players[a].license), 0)
    Sim.players[a] = nil
end)

H.test('HUD: checkpoint and lap counts update after every checkpoint (2 laps)', function()
    assert(ES.Definitions.register({
        id = 'test_race_laps', name = 'Test Race Laps', mode = 'race', arena = 'downtown_circuit',
        players = { min = 1, max = 8 }, timing = { registration = 30, lobby = 2, countdown = 2, duration = 900, grace = 20, results = 3 },
        options = { laps = 2 },
    }))
    local s = H.players(1, 7100)[1]
    H.setPos(s, 500.0, 500.0, 30.0)
    local inst = H.createAndJoin('test_race_laps', { s })
    H.toActive(inst)
    local n = #arena.checkpoints
    local function hud()
        local st = H.lastPush(s, 'state')
        return st and st.hud or {}
    end
    H.eq(hud().checkpoint, 0, 'nothing passed at the start')
    H.eq(hud().lap, 1) H.eq(hud().laps, 2)
    for lap = 1, 2 do
        for i, cp in ipairs(arena.checkpoints) do
            Sim.advance(2000)
            H.setPos(s, cp.x, cp.y, cp.z)
            H.clear(s)
            local ok, res = H.rpc(s, 'event:action', { action = 'checkpoint', data = { index = i } })
            H.ok(ok, ('lap %d checkpoint %d rejected: %s'):format(lap, i, tostring(res)))
            local h = hud()
            if lap == 1 and i < n then
                H.eq(h.checkpoint, i, ('HUD shows %d passed after checkpoint %d'):format(i, i))
                H.eq(h.lap, 1)
            elseif lap == 1 and i == n then
                H.eq(h.lap, 2, 'lap 2 after the last checkpoint of lap 1')
                H.eq(h.checkpoint, 0, 'lap 2 starts at 0 passed')
            elseif lap == 2 and i < n then
                H.eq(h.checkpoint, i) H.eq(h.lap, 2)
            end
            H.eq(res.passed, (lap == 1 and i == n) and 0 or i, 'the checkpoint answer carries the same count')
        end
    end
    H.ok(H.waitState(inst, 'ARCHIVED', 60000), 'race finished after 2 laps')
    H.eq(inst.results[1].src, s)
    Sim.players[s] = nil
end)

H.test('start: players wait in the arena until the host presses Start, then a 10 s countdown', function()
    local s = H.players(1, 7200)[1]
    H.setPos(s, 500.0, 500.0, 30.0)
    local inst = H.createAndJoin('test_race', { s })
    H.eq(select(2, inst:go()), 'close_registration_first', 'Start needs the players in the arena first')
    H.ok(inst:start(true))
    H.eq(inst.state, 'LOBBY') H.ok(inst.awaitingStart)
    H.clear(s)
    Sim.advance(30000)
    H.eq(inst.state, 'LOBBY', 'still waiting: nobody pressed Start')
    local admin = H.players(1, 7201)[1]
    H.admin(admin)
    H.ok((H.rpc(admin, 'admin:instance:go', { id = inst.id })))
    H.eq(inst.state, 'COUNTDOWN')
    Sim.advance(9000)
    H.eq(inst.state, 'COUNTDOWN', 'countdown lasts 10 seconds')
    Sim.advance(1500)
    H.eq(inst.state, 'ACTIVE')
    inst:cancel('test')
    Sim.advance(1000)
    Sim.players[s], Sim.players[admin] = nil, nil
end)

H.test('start: without a host the event begins after flow.lobbyWaitMax; tournament matches wait for the host too', function()
    local s = H.players(1, 7300)[1]
    H.setPos(s, 500.0, 500.0, 30.0)
    local inst = H.createAndJoin('test_race', { s })
    H.ok(inst:start(true))
    Sim.advance((Config.General.flow.lobbyWaitMax or 300) * 1000 + 500)
    H.eq(inst.state, 'COUNTDOWN', 'waited long enough, countdown started')
    inst:cancel('test')
    Sim.advance(1000)
    local ok, id = ES.Manager.create('test_race', { registration = 30, tournament = 'T1' })
    H.ok(ok)
    H.no(ES.Manager.get(id).autoStart, 'tournament match waits for the host')
    ES.Manager.get(id):cancel('test')
    Sim.advance(1000)
    Sim.players[s] = nil
end)

H.test('finish: 2 racers: grace after the 1st; everyone finished -> results 10 s after the last one', function()
    local a, b = table.unpack(H.players(2, 7400))
    for _, s in ipairs({ a, b }) do H.setPos(s, 500.0, 500.0, 30.0) end
    local inst = H.createAndJoin('test_race', { a, b })
    H.toActive(inst)
    drive(inst, { a })
    H.eq(inst.state, 'FINISHING', 'grace starts with the winner')
    local left = inst.deadline - ES.now()
    H.ok(left <= 60000 and left > 55000, 'grace is 60 s, got ' .. left)
    Sim.advance(30000)
    H.eq(inst.state, 'FINISHING', 'still waiting for b')
    -- b arrives within the grace: the race ends at once
    local cp = inst:component('checkpoints')
    for i, pt in ipairs(arena.checkpoints) do
        Sim.advance(2000)
        H.setPos(b, pt.x, pt.y, pt.z)
        H.ok((H.rpc(b, 'event:action', { action = 'checkpoint', data = { index = i } })))
    end
    H.eq(inst.state, 'FINISHING', 'everyone finished: short wait first')
    local wait = inst.deadline - ES.now()
    H.ok(wait <= 10000 and wait > 9000, '10 s after the last finisher, got ' .. wait)
    Sim.advance(10500)
    H.eq(inst.state, 'RESULTS')
    H.eq(inst.results[2].status, 'finished')
    H.ok(H.waitState(inst, 'ARCHIVED', 30000))
    Sim.players[a], Sim.players[b] = nil, nil
end)

H.test('finish: 5 racers: the 60 s grace starts at 3rd place, not at the winner', function()
    local srcs = H.players(5, 7500)
    for _, s in ipairs(srcs) do H.setPos(s, 500.0, 500.0, 30.0) end
    local inst = H.createAndJoin('test_race', srcs)
    H.toActive(inst)
    drive(inst, { srcs[1] })
    H.eq(inst.state, 'ACTIVE', 'winner in: race goes on')
    drive(inst, { srcs[2] })
    H.eq(inst.state, 'ACTIVE', '2nd in: race goes on')
    drive(inst, { srcs[3] })
    H.eq(inst.state, 'FINISHING', '3rd in: the last minute starts')
    local left = inst.deadline - ES.now()
    H.ok(left <= 60000 and left > 55000, 'grace 60 s, got ' .. left)
    H.ok(H.waitState(inst, 'RESULTS', 61000), 'results after the minute')
    H.eq(inst.results[4].status, 'active', 'still racing at the end: unfinished but ranked')
    H.ok(H.waitState(inst, 'ARCHIVED', 60000))
    for _, s in ipairs(srcs) do Sim.players[s] = nil end
end)

H.test('host key / /eventstart: 1st press closes registration, 2nd starts the countdown; staff get the card', function()
    local racer, host, player = table.unpack(H.players(3, 7600))
    H.admin(host)
    H.setPos(racer, 500.0, 500.0, 30.0)
    local inst = H.createAndJoin('test_race', { racer })
    local okP, errP = H.rpc(player, 'host:start', {})
    H.no(okP) H.eq(errP, 'forbidden', 'players cannot start events')
    H.clear(host)
    local ok, res = H.rpc(host, 'host:start', {})
    H.ok(ok, tostring(res)) H.eq(res.step, 'registration_closed')
    H.eq(inst.state, 'LOBBY') H.ok(inst.awaitingStart)
    local card = H.lastPush(host, 'hostPrompt')
    H.ok(card and card.id == inst.id and not card.clear, 'staff see the "ready to start" card')
    H.eq(H.lastPush(racer, 'hostPrompt'), nil, 'racers do not')
    Sim.advance(2000)
    ok, res = H.rpc(host, 'host:start', {})
    H.ok(ok, tostring(res)) H.eq(res.step, 'countdown')
    H.eq(inst.state, 'COUNTDOWN')
    card = H.lastPush(host, 'hostPrompt')
    H.ok(card.clear, 'card removed when the countdown starts')
    inst:cancel('test')
    Sim.advance(1000)
    for _, s in ipairs({ racer, host, player }) do Sim.players[s] = nil end
end)
