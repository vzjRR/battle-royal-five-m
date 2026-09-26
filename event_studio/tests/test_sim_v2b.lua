-- Simulation: V2 pack 2 — bounty / assassin, package deliver / hold, vehicle tag, KOTH attack style, memory trivia.
local H = T
H.boot()

local function reg(d)
    d.timing = d.timing or {}
    d.timing.registration = 30 d.timing.lobby = 1 d.timing.countdown = 1 d.timing.results = 3
    d.timing.duration = d.timing.duration or 600
    d.players = d.players or { min = 2, max = 16 }
    d.name = d.name or d.id
    local ok, err = ES.Definitions.register(d)
    assert(ok, tostring(err))
end

local function kill(att, vic, weapon)
    Sim.dispatch('weaponDamageEvent', att, att, { hitGlobalId = GetPlayerPed(vic), weaponType = GetHashKey(weapon or 'WEAPON_PISTOL') })
    Sim.players[vic].health = 0
    H.rpc(vic, 'event:action', { action = 'died', data = { killer = att } })
end

local function archive(inst) H.ok(H.waitState(inst, 'ARCHIVED', 60000), 'archived, state=' .. inst.state) end

H.test('bounty: first kill puts the bounty on the leader; claiming it pays the bounty value', function()
    reg({ id = 'b_bounty', mode = 'bounty', arena = 'docks_yard', players = { min = 3, max = 8 },
          options = { style = 'bounty', bountyBase = 7, bountyGrowth = 3, scoreTarget = 0, respawnDelay = 1 } })
    local a, b, c = table.unpack(H.players(3, 100))
    local inst = H.createAndJoin('b_bounty', { a, b, c })
    H.toActive(inst)
    local pa, pb, pc = inst.participants[a], inst.participants[b], inst.participants[c]
    kill(a, b)
    H.eq(pa.score, 1, 'normal kill = 1 point')
    H.eq(inst.data.bountyOn, pa, 'leader carries the bounty')
    H.eq(H.lastPush(c, 'mode').markPlayer, a, 'everyone sees the marked leader')
    Sim.advance(1500)
    kill(a, c)
    H.eq(inst.data.bountyValue, 10, 'bounty grows when the target kills')
    Sim.advance(1500)
    kill(b, a)
    H.eq(pb.score, 10, 'claimer receives the bounty value')
    H.eq(inst.data.bountyOn, pb, 'bounty moves to the new leader')
    H.eq(pc.score, 0)
    inst:finishNow('test')
    archive(inst)
    H.eq(inst.results[1].src, b)
end)

H.test('assassin: each player only learns their own target; wrong kills cost points; targets are inherited', function()
    reg({ id = 'b_assassin', mode = 'bounty', arena = 'docks_yard', players = { min = 3, max = 8 },
          options = { style = 'assassin', targetPoints = 5, wrongKillPenalty = 3, scoreTarget = 0, respawnDelay = 1 } })
    local srcs = H.players(4, 150)
    local inst = H.createAndJoin('b_assassin', srcs)
    H.toActive(inst)
    local ring = inst.data.targetOf
    local seen = {}
    for _, s in ipairs(srcs) do
        local p = inst.participants[s]
        local t = ring[p]
        H.ok(t and t ~= p, 'everyone has a target that is not themselves')
        H.ok(not seen[t], 'targets form a ring (no duplicates)')
        seen[t] = true
        H.eq(H.lastPush(s, 'mode').markPlayer, t.src, 'private target push')
    end
    -- someone kills a non-target
    local p1 = inst.participants[srcs[1]]
    local target = ring[p1]
    local wrong
    for _, s in ipairs(srcs) do local q = inst.participants[s] if q ~= p1 and q ~= target then wrong = q break end end
    kill(p1.src, wrong.src)
    H.eq(p1.score, -3, 'wrong target penalty')
    Sim.advance(1500)
    -- now the real target
    local inherited = ring[target]
    kill(p1.src, target.src)
    H.eq(p1.score, 2, 'target points')
    H.eq(ring[p1], inherited, "killer inherits the victim's target")
    H.eq(H.lastPush(p1.src, 'mode').markPlayer, inherited.src)
    -- the inherited target leaves: the hunter is re-pointed along the ring
    local after = ring[inherited]
    H.rpc(inherited.src, 'event:leave', {})
    Sim.advance(600)
    if after ~= p1 then H.eq(ring[p1], after, 'ring skips the leaver') end
    inst:finishNow('test')
    archive(inst)
end)

H.test('package deliver: pick up at a target, carry to the drop zone, score and respawn the package', function()
    reg({ id = 'b_deliver', mode = 'package', arena = 'docks_yard', players = { min = 2, max = 8 },
          options = { style = 'deliver', packages = 1, pointsPerDelivery = 10, scoreTarget = 20 } })
    local a, b = table.unpack(H.players(2, 200))
    local inst = H.createAndJoin('b_deliver', { a, b })
    H.toActive(inst)
    local pk = inst.data.packages[1]
    H.setPos(b, 0, 0, 0)
    H.setPos(a, pk.pos.x, pk.pos.y, pk.pos.z)
    Sim.advance(600)
    H.eq(pk.carrier, inst.participants[a], 'picked up')
    H.eq(H.lastPush(b, 'mode').packages[1].carrier, a, 'carrier broadcast')
    local f = ES.Arenas.get('docks_yard').finish
    H.setPos(a, f.x, f.y, f.z)
    Sim.advance(600)
    H.eq(inst.participants[a].score, 10, 'delivered')
    H.eq(pk.carrier, nil, 'package respawned')
    -- second delivery, but the carrier dies first: package drops where they fell, then resets
    H.setPos(a, pk.pos.x, pk.pos.y, pk.pos.z)
    Sim.advance(600)
    H.eq(pk.carrier, inst.participants[a])
    H.setPos(a, 990, -3090, 5.9)
    Sim.advance(600)
    kill(b, a)
    H.eq(pk.carrier, nil, 'dropped on death')
    H.eq(pk.pos.x, 990, 'dropped where the carrier fell')
    H.eq(inst.participants[b].score, 2, 'carrier kill bonus')
    H.setPos(a, 0, 0, 0)
    Sim.advance(21000)
    H.ok(pk.pos.x ~= 990, 'dropped package reset to a spawn point')
    H.setPos(b, pk.pos.x, pk.pos.y, pk.pos.z)
    Sim.advance(600)
    H.setPos(b, f.x, f.y, f.z)
    Sim.advance(600)
    H.eq(inst.participants[b].score, 12)
    inst:finishNow('test')
    archive(inst)
end)

H.test('package hold: the carrier scores per second until the target', function()
    reg({ id = 'b_hold', mode = 'package', arena = 'docks_yard', players = { min = 2, max = 8 },
          options = { style = 'hold', pointsPerSecond = 2, scoreTarget = 10 } })
    local a, b = table.unpack(H.players(2, 250))
    local inst = H.createAndJoin('b_hold', { a, b })
    H.toActive(inst)
    local c = ES.Arenas.get('docks_yard').center
    H.setPos(b, 0, 0, 0)
    H.setPos(a, c.x, c.y, c.z)
    Sim.advance(600)
    H.eq(inst.data.packages[1].carrier, inst.participants[a])
    Sim.advance(6000)
    archive(inst)
    H.eq(inst.results[1].src, a)
    H.ok(inst.results[1].score >= 10, 'reached the target')
end)

H.test('package: deliver style refuses an arena without a drop zone', function()
    local ok = ES.Definitions.register({ id = 'b_bad', name = 'bad', mode = 'package', arena = 'lsia_derby',
        players = { min = 2, max = 8 }, options = { style = 'deliver' } })
    H.no(ok, 'no finish = invalid')
end)

H.test('vehicle tag: IT passes on contact, no tag-back, runners score', function()
    reg({ id = 'b_tag', mode = 'vehicle_tag', arena = 'lsia_derby', players = { min = 3, max = 8 },
          options = { tagDistance = 4.5, noTagBackSeconds = 2 } })
    local srcs = H.players(3, 300)
    local inst = H.createAndJoin('b_tag', srcs)
    H.toActive(inst)
    local roles = inst:component('roles')
    local it = inst.data.it
    H.ok(it, 'someone is IT')
    H.eq(roles:roleOf(it), 'it')
    local veh = inst:component('vehicles')
    local others = {}
    for _, s in ipairs(srcs) do if inst.participants[s] ~= it then others[#others + 1] = inst.participants[s] end end
    local function place(p, x, y) local e = Sim.vehicles[veh:entityOf(p)] e.pos = { x = x, y = y, z = 13.9 } end
    place(it, -1250, -3050) place(others[1], -1200, -3050) place(others[2], -1300, -3050)
    Sim.advance(3000)
    H.ok(others[1].score >= 2 and it.score == 0, 'runners score, IT does not')
    place(others[1], -1252, -3050)
    Sim.advance(600)
    H.eq(inst.data.it, others[1], 'tag passed')
    H.eq(roles:roleOf(it), 'runner')
    H.eq(it.stats.objectives, 1)
    H.eq(H.lastPush(others[2].src, 'mode').markPlayer, others[1].src, 'new IT is marked for everyone')
    -- the old IT is right next to the new one, but may not tag back
    Sim.advance(2500)
    H.eq(inst.data.it, others[1], 'no tag-back to the previous IT')
    Sim.advance(1000)
    H.eq(inst.data.it, it, 'tag-back allowed once the window ends')
    place(it, -1200, -3000)
    Sim.advance(2100)
    place(others[2], -1198, -3000)
    Sim.advance(600)
    H.eq(inst.data.it, others[2], 'a third player can be tagged')
    inst:finishNow('test')
    archive(inst)
end)

H.test('koth attack: attackers take zones in order; early captures do not count; completing wins', function()
    reg({ id = 'b_attack', mode = 'koth', arena = 'sandy_airfield', players = { min = 2, max = 8, teams = { count = 2 } },
          options = { style = 'attack', captureSeconds = 2, scoreTarget = 0 } })
    local a, d = table.unpack(H.players(2, 400))
    local inst = H.createAndJoin('b_attack', { a, d })
    H.toActive(inst)
    local pa, pd = inst.participants[a], inst.participants[d]
    if pa.team ~= 1 then a, d, pa, pd = d, a, pd, pa end
    local zones = inst:component('zones')
    for _, z in ipairs(zones.order) do H.eq(zones:ownerOf(z.id), 2, 'defenders own every point at start') end
    H.setPos(d, 0, 0, 0)
    -- try Bravo first: captured, but reset when it becomes active
    local A, B, C = zones.order[1], zones.order[2], zones.order[3]
    H.setPos(a, B.x, B.y, B.z)
    Sim.advance(2600)
    H.eq(inst.data.active, 1, 'still on Alpha')
    H.setPos(a, A.x, A.y, A.z)
    Sim.advance(2600)
    H.eq(inst.data.active, 2, 'Alpha taken, Bravo active')
    H.eq(zones:ownerOf(B.id), 2, 'early Bravo capture was reset')
    H.setPos(a, B.x, B.y, B.z)
    Sim.advance(2600)
    H.eq(inst.data.active, 3)
    H.setPos(a, C.x, C.y, C.z)
    Sim.advance(2600)
    archive(inst)
    H.eq(inst.teamResults[1].index, 1, 'attackers win')
end)

H.test('koth attack: time up means the defenders win; validation needs two teams', function()
    H.no(ES.Definitions.register({ id = 'b_attack_bad', name = 'x', mode = 'koth', arena = 'sandy_airfield',
        players = { min = 2, max = 8 }, options = { style = 'attack' } }), 'attack needs teams')
    reg({ id = 'b_attack2', mode = 'koth', arena = 'sandy_airfield', players = { min = 2, max = 8, teams = { count = 2 } },
          timing = { duration = 20 }, options = { style = 'attack', scoreTarget = 0 } })
    local inst = H.createAndJoin('b_attack2', H.players(2, 450))
    H.toActive(inst)
    for _, p in pairs(inst.participants) do H.setPos(p.src, 0, 0, 0) end
    Sim.advance(21000)
    archive(inst)
    H.eq(inst.teamResults[1].index, 2, 'defenders win on time')
end)

H.test('trivia memory: sequence shown first, then four orderings with the correct one hidden', function()
    reg({ id = 'b_memory', mode = 'trivia', options = { count = 1, secondsPerQuestion = 5, shuffle = false,
        questions = { { memory = { 'A', 'B', 'C', 'D' }, showSeconds = 2 } } } })
    local a, b = table.unpack(H.players(2, 500))
    local inst = H.createAndJoin('b_memory', { a, b })
    H.toActive(inst)
    local m = H.lastPush(a, 'mode').trivia
    H.eq(m.phase, 'memorize')
    H.eq(table.concat(m.items, ''), 'ABCD', 'items shown')
    H.no((H.rpc(a, 'event:action', { action = 'answer', data = { choice = 1 } })), 'no answers while memorizing')
    Sim.advance(2600)
    local q = H.lastPush(a, 'mode').trivia
    H.eq(q.phase, 'question')
    H.eq(#q.answers, 4, 'four orderings')
    H.eq(q.correct, nil, 'correct index not sent')
    local correct
    for i, s in ipairs(q.answers) do if s == 'A B C D' then correct = i end end
    H.ok(correct, 'correct ordering offered')
    H.ok((H.rpc(a, 'event:action', { action = 'answer', data = { choice = correct } })))
    H.ok((H.rpc(b, 'event:action', { action = 'answer', data = { choice = correct % 4 + 1 } })))
    Sim.advance(600)
    H.eq(H.lastPush(a, 'mode').trivia.phase, 'reveal')
    Sim.advance(5000)
    archive(inst)
    H.eq(inst.results[1].src, a)
    H.eq(inst.results[2].score, 0)
end)
