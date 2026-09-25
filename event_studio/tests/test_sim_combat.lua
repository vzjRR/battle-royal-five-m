-- Simulation: combat (damage filter, kill attribution, lives, kill target, teams), disconnect/reconnect.
local H = T
H.boot()
H.recordRewards()

local function def(id, extra)
    local d = {
        id = id, name = id, mode = 'deathmatch', arena = 'docks_yard',
        players = { min = 2, max = 16 }, timing = { registration = 30, lobby = 1, countdown = 1, duration = 600, results = 3 },
        options = { killTarget = 3, respawnDelay = 1 },
        rewards = { placement = { [1] = { { type = 'test', amount = 100 } } } },
    }
    for k, v in pairs(extra or {}) do d[k] = v end
    assert(ES.Definitions.register(d))
end
def('test_ffa')
def('test_lms', { options = { lives = 1, killTarget = 0 } })
def('test_tdm', { players = { min = 2, max = 16, teams = { count = 2, auto = true } }, options = { killTarget = 2 } })

local pistol = GetHashKey('WEAPON_PISTOL')

---attacker damages victim (server weaponDamageEvent). Returns cancelled.
local function damage(attacker, victim, weapon)
    return Sim.dispatch('weaponDamageEvent', attacker, attacker, { hitGlobalId = GetPlayerPed(victim), weaponType = weapon or pistol })
end

local function kill(attacker, victim, fakeKiller)
    H.ok(not damage(attacker, victim), 'damage allowed')
    Sim.players[victim].health = 0
    H.ok((H.rpc(victim, 'event:action', { action = 'died', data = { killer = fakeKiller or attacker } })))
end

H.test('FFA: kills counted server-side, kill target ends event, winner paid once', function()
    H.paid = {}
    local a, b, c = table.unpack(H.players(3, 10))
    local inst = H.createAndJoin('test_ffa', { a, b, c })
    H.toActive(inst)
    kill(a, b)
    Sim.advance(1500) -- respawn
    H.eq(Sim.players[b].health, 200, 'victim respawned')
    kill(a, c)
    Sim.advance(1500)
    kill(a, b)
    H.ok(H.waitState(inst, 'ARCHIVED', 20000))
    H.eq(inst.results[1].src, a)
    H.eq(inst.results[1].kills, 3)
    H.eq(#H.paid, 1)
    H.eq(inst.stateReason ~= nil, true)
end)

H.test('kill attribution ignores a spoofed killer hint', function()
    local a, b, c = table.unpack(H.players(3, 20))
    local inst = H.createAndJoin('test_ffa', { a, b, c })
    H.toActive(inst)
    kill(a, b, c) -- b claims c killed him, but only a damaged him
    local pa = inst.participants[a]
    local pc = inst.participants[c]
    H.eq(pa.stats.kills, 1, 'real attacker credited')
    H.eq(pc.stats.kills, 0, 'spoofed killer not credited')
    inst:cancel('test') H.ok(H.waitState(inst, 'ARCHIVED', 5000))
end)

H.test('death hint without actual death is ignored', function()
    local a, b = table.unpack(H.players(2, 30))
    local inst = H.createAndJoin('test_ffa', { a, b })
    H.toActive(inst)
    H.rpc(b, 'event:action', { action = 'died', data = { killer = a } }) -- b is alive (health 200)
    Sim.advance(1000)
    H.eq(inst.participants[b].stats.deaths, 0, 'fake death rejected')
    H.eq(inst.participants[a].stats.kills, 0)
    inst:cancel('test') H.ok(H.waitState(inst, 'ARCHIVED', 5000))
end)

H.test('damage filter: weapon whitelist, cross-instance, outsiders, friendly fire', function()
    local a, b, c, d = table.unpack(H.players(4, 40))
    local inst = H.createAndJoin('test_ffa', { a, b })
    H.toActive(inst)
    H.ok(damage(a, b, GetHashKey('WEAPON_RPG')), 'non-whitelisted weapon cancelled')
    H.ok(damage(c, a), 'outsider damaging participant cancelled')
    H.ok(damage(a, c), 'participant damaging outsider cancelled')
    H.no(damage(c, d), 'outsiders unaffected')
    inst:cancel('test') H.ok(H.waitState(inst, 'ARCHIVED', 5000))

    local t = H.createAndJoin('test_tdm', H.players(4, 50))
    H.toActive(t)
    local p1, p2
    for _, p in pairs(t.participants) do
        if not p1 then p1 = p elseif p.team == p1.team and not p2 then p2 = p end
    end
    H.ok(damage(p1.src, p2.src), 'friendly fire cancelled')
    t:cancel('test') H.ok(H.waitState(t, 'ARCHIVED', 5000))
end)

H.test('last man standing: one life, survivor wins over higher-kill eliminated player', function()
    local a, b, c = table.unpack(H.players(3, 60))
    local inst = H.createAndJoin('test_lms', { a, b, c })
    H.toActive(inst)
    kill(b, c) -- b has a kill
    H.eq(inst.participants[c].status, 'eliminated')
    kill(a, b) -- a survives
    H.ok(H.waitState(inst, 'ARCHIVED', 20000))
    H.eq(inst.results[1].src, a, 'survivor first')
    H.eq(inst.results[2].src, b, 'last eliminated second')
end)

H.test('team deathmatch: team kill target, all winning team members placed 1st', function()
    local srcs = H.players(4, 70)
    local inst = H.createAndJoin('test_tdm', srcs)
    H.toActive(inst)
    local red, blue = {}, {}
    for _, p in pairs(inst.participants) do table.insert(p.team == 1 and red or blue, p.src) end
    H.eq(#red, 2) H.eq(#blue, 2)
    kill(red[1], blue[1])
    Sim.advance(1500)
    kill(red[2], blue[2])
    H.ok(H.waitState(inst, 'ARCHIVED', 20000))
    for _, r in ipairs(inst.results) do
        if r.team == 1 then H.eq(r.placement, 1) else H.eq(r.placement, 2) end
    end
end)

H.test('disconnect during active event → reconnect within grace restores the player', function()
    local a, b, c = table.unpack(H.players(3, 80))
    local inst = H.createAndJoin('test_ffa', { a, b, c })
    H.toActive(inst)
    local license = Sim.players[b].license
    Sim.removePlayer(b)
    H.eq(inst.departed[1].status, 'disconnected')
    H.eq(inst.state, 'ACTIVE')
    Sim.advance(5000)
    Sim.addPlayer(181, { license = license, name = 'Player80b' })
    local ok, res = H.rpc(181, 'client:ready', {})
    H.ok(ok) H.eq(res.recovery.rejoined, inst.id)
    H.eq(inst.participants[181].status, 'active')
    H.eq(Sim.players[181].bucket, inst.bucket, 'back in the instance bucket')
    inst:cancel('test') H.ok(H.waitState(inst, 'ARCHIVED', 5000))
end)

H.test('disconnect grace expiry marks player left and finishes when one remains', function()
    local a, b = table.unpack(H.players(2, 90))
    local inst = H.createAndJoin('test_ffa', { a, b })
    H.toActive(inst)
    Sim.removePlayer(b)
    Sim.advance(61000)
    H.ok(inst.state == 'RESULTS' or inst.state == 'REWARDS' or inst.state == 'ARCHIVED', 'finished, state=' .. inst.state)
    H.ok(H.waitState(inst, 'ARCHIVED', 20000))
    H.eq(inst.results[1].src, a)
end)

H.test('crash recovery: return point survives and is applied on next join', function()
    local a = H.players(1, 95)[1]
    H.setPos(a, 777.0, 888.0, 20.0)
    local inst = H.createAndJoin('test_ffa', { a, H.players(1, 96)[1] })
    H.toActive(inst)
    local license = Sim.players[a].license
    H.ok(ES.Storage.getReturnPoint(license), 'return point stored')
    -- simulate the player's game crashing and the instance finishing without them
    Sim.removePlayer(a)
    inst:cancel('test') H.ok(H.waitState(inst, 'ARCHIVED', 5000))
    Sim.addPlayer(195, { license = license })
    H.setPos(195, 0, 0, 0)
    local ok, res = H.rpc(195, 'client:ready', {})
    H.ok(ok) H.ok(res.recovery.recovered)
    H.eq(Sim.players[195].pos.x, 777.0, 'teleported back to pre-event position')
    H.eq(ES.Storage.getReturnPoint(license), nil, 'cleared')
end)
