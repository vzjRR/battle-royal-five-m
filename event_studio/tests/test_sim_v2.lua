-- Simulation: V2 pack — roles component, juggernaut, protect the VIP, hunters vs runners, keep moving, musical chairs.
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
    Sim.dispatch('weaponDamageEvent', att, att, { hitGlobalId = GetPlayerPed(vic), weaponType = GetHashKey(weapon) })
    Sim.players[vic].health = 0
    H.rpc(vic, 'event:action', { action = 'died', data = { killer = att } })
end

local function archive(inst) H.ok(H.waitState(inst, 'ARCHIVED', 60000), 'archived, state=' .. inst.state) end

H.test('juggernaut: one juggernaut with role health; killer takes the role; juggernaut scores over time', function()
    reg({ id = 'v_jug', mode = 'juggernaut', arena = 'docks_yard', players = { min = 3, max = 8 },
          options = { scoreTarget = 0, respawnDelay = 1 } })
    local srcs = H.players(3, 100)
    local inst = H.createAndJoin('v_jug', srcs)
    H.toActive(inst)
    local roles = inst:component('roles')
    local jugs = roles:members('juggernaut', true)
    H.eq(#jugs, 1, 'exactly one juggernaut')
    local jug = jugs[1]
    local rolePush = H.lastPush(jug.src, 'role')
    H.eq(rolePush.role, 'juggernaut')
    H.eq(rolePush.health, 800, 'juggernaut health pushed')
    Sim.advance(3000)
    H.ok(jug.score >= 2, 'juggernaut earns points per second')
    local attacker
    for _, p in pairs(inst.participants) do if p ~= jug then attacker = p break end end
    kill(attacker.src, jug.src, 'WEAPON_PISTOL')
    H.eq(roles:roleOf(attacker), 'juggernaut', 'killer becomes juggernaut')
    H.eq(roles:roleOf(jug), 'attacker', 'old juggernaut demoted')
    H.eq(#roles:members('juggernaut', true), 1)
    H.ok(attacker.score >= 10, 'takedown points')
    -- attacker-only weapons: a juggernaut weapon used by an attacker is still allowed (whitelist = union), but role loadouts differ
    Sim.advance(1500)
    H.eq(Sim.players[jug.src].health, 200, 'old juggernaut respawns with normal health')
    inst:finishNow('test')
    archive(inst)
end)

H.test('protect the VIP: extraction wins the round for the defenders; VIP death wins for attackers', function()
    reg({ id = 'v_vip', mode = 'vip', arena = 'sandy_airfield', players = { min = 2, max = 8, teams = { count = 2 } },
          options = { rounds = 3, swapSides = false } })
    local srcs = H.players(4, 200)
    local inst = H.createAndJoin('v_vip', srcs)
    H.toActive(inst)
    local vip = inst.data.vip
    H.ok(vip, 'VIP chosen')
    H.eq(vip.team, 1, 'VIP from defending team')
    H.eq(inst:component('roles'):roleOf(vip), 'vip')
    -- round 1: extraction
    local f = ES.Arenas.get('sandy_airfield').finish
    H.setPos(vip.src, f.x, f.y, f.z)
    Sim.advance(600)
    H.eq(inst.teams[1].score, 1, 'defenders won round 1')
    Sim.advance(4500)
    H.eq(inst.data.round, 2, 'round 2 started')
    -- round 2: VIP killed by an attacker
    local vip2 = inst.data.vip
    local attacker
    for _, p in pairs(inst.participants) do if p.team == 2 then attacker = p end end
    H.setPos(vip2.src, 0, 0, 0)
    kill(attacker.src, vip2.src, 'WEAPON_SMG')
    H.eq(inst.teams[2].score, 1, 'attackers won round 2')
    Sim.advance(4500)
    -- round 3: extraction decides the match
    local vip3 = inst.data.vip
    H.setPos(vip3.src, f.x, f.y, f.z)
    Sim.advance(600)
    archive(inst)
    H.eq(inst.teamResults[1].index, 1, 'defending team wins 2-1')
end)

H.test('protect the VIP: round timeout goes to the attackers', function()
    reg({ id = 'v_vip2', mode = 'vip', arena = 'sandy_airfield', players = { min = 2, max = 8, teams = { count = 2 } },
          options = { rounds = 1, roundSeconds = 30 } })
    local inst = H.createAndJoin('v_vip2', H.players(2, 250))
    H.toActive(inst)
    H.setPos(inst.data.vip.src, 0, 0, 0)
    Sim.advance(31000)
    archive(inst)
    H.eq(inst.teamResults[1].index, 2, 'attackers win on timeout')
end)

H.test('hunters vs runners: infection converts caught runners; all caught ends the game', function()
    reg({ id = 'v_hunt', mode = 'hunters', arena = 'docks_yard', players = { min = 3, max = 16 },
          options = { hunterRatio = 0.25, infect = true, hunterReleaseSeconds = 2 } })
    local srcs = H.players(4, 300)
    local inst = H.createAndJoin('v_hunt', srcs)
    H.toActive(inst)
    local roles = inst:component('roles')
    local hunters = roles:members('hunter', true)
    H.eq(#hunters, 1, '25% of 4 = 1 hunter')
    H.eq(H.lastPush(hunters[1].src, 'freeze').frozen, true, 'hunter frozen during head start')
    Sim.advance(2600)
    H.eq(H.lastPush(hunters[1].src, 'freeze').frozen, false, 'hunter released')
    local runners = roles:members('runner', true)
    H.eq(#runners, 3)
    H.ok(runners[1].score >= 2, 'runners score while alive')
    for _, r in ipairs(runners) do
        kill(hunters[1].src, r.src, 'WEAPON_KNIFE')
        Sim.advance(1500)
    end
    archive(inst)
    H.eq(inst.stateReason ~= nil, true)
    H.ok(hunters[1].stats.objectives == 3, 'three catches credited')
end)

H.test('hunters vs runners: survivors get the bonus at time up', function()
    reg({ id = 'v_hunt2', mode = 'hunters', arena = 'docks_yard', players = { min = 3, max = 16 }, timing = { duration = 20 },
          options = { hunterReleaseSeconds = 0, surviveBonus = 100 } })
    local inst = H.createAndJoin('v_hunt2', H.players(4, 350))
    H.toActive(inst)
    Sim.advance(21000)
    archive(inst)
    local roles = inst:component('roles')
    local top = inst.results[1]
    H.ok(top.score >= 100, 'surviving runner got the bonus, score=' .. tostring(top.score))
end)

H.test('keep moving: too slow is eliminated after grace; fast driver wins', function()
    reg({ id = 'v_move', mode = 'keep_moving', arena = 'lsia_time_trial', players = { min = 2, max = 4 },
          options = { minKmh = 40, graceSeconds = 2, startGrace = 2, increaseKmh = 0 } })
    local a, b = table.unpack(H.players(2, 400))
    local inst = H.createAndJoin('v_move', { a, b })
    H.toActive(inst)
    local veh = inst:component('vehicles')
    Sim.vehicles[veh:entityOf(inst.participants[a])].vel = { x = 20.0, y = 0.0, z = 0.0 } -- 72 km/h
    Sim.vehicles[veh:entityOf(inst.participants[b])].vel = { x = 5.0, y = 0.0, z = 0.0 }  -- 18 km/h
    Sim.advance(1500)
    H.eq(inst.participants[b].status, 'active', 'start grace protects everyone')
    Sim.advance(3000)
    archive(inst)
    H.eq(inst.results[1].src, a)
end)

H.test('musical chairs: one chair fewer than players; player without a chair is out', function()
    reg({ id = 'v_chairs', mode = 'musical_chairs', arena = 'lsia_runway_field', players = { min = 2, max = 8 },
          options = { musicMin = 3, musicMax = 3, seatSeconds = 3 } })
    local a, b, c = table.unpack(H.players(3, 500))
    local inst = H.createAndJoin('v_chairs', { a, b, c })
    H.toActive(inst)
    Sim.advance(3100)
    H.eq(inst.data.phase, 'stop')
    local zones = inst:component('zones')
    H.eq(#zones.order, 2, 'two chairs for three players')
    H.setPos(a, zones.order[1].x, zones.order[1].y, zones.order[1].z)
    H.setPos(b, zones.order[2].x, zones.order[2].y, zones.order[2].z)
    H.setPos(c, zones.order[1].x + 0.8, zones.order[1].y, zones.order[1].z) -- same chair, further from center
    Sim.advance(3100)
    H.eq(inst.byLicense[Sim.players[c].license].status, 'eliminated', 'loser of the shared chair is out')
    H.eq(inst.data.phase, 'music', 'next round')
    Sim.advance(3100)
    H.eq(#zones.order, 1, 'one chair for two players')
    H.setPos(b, zones.order[1].x, zones.order[1].y, zones.order[1].z)
    H.setPos(a, 0, 0, 0)
    Sim.advance(3100)
    archive(inst)
    H.eq(inst.results[1].src, b)
end)
