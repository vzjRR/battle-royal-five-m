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
