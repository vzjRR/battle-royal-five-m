-- Simulation: security gateway, permissions, ledger, parallel instances, resource stop, scheduler, tournaments.
local H = T
H.boot()
H.recordRewards()

assert(ES.Definitions.register({
    id = 't_ffa', name = 'T FFA', mode = 'deathmatch', arena = 'docks_yard',
    players = { min = 2, max = 8 }, timing = { registration = 20, lobby = 1, countdown = 1, duration = 60, results = 3, extendOnce = 0 },
    options = { killTarget = 1, respawnDelay = 1 },
    rewards = { placement = { [1] = { { type = 'test', amount = 100 } } }, participation = { { type = 'test', amount = 1 } } },
}))

H.test('RPC gateway rejects malformed, unknown, oversized and wrongly typed requests', function()
    local p = H.players(1, 10)[1]
    local ok, err = H.rpc(p, 'does:not:exist', {})
    H.no(ok) H.eq(err, 'unknown')
    ok, err = H.rpc(p, 'event:join', 'not a table')
    H.no(ok) H.eq(err, 'bad_payload')
    ok, err = H.rpc(p, 'event:join', { id = 'abc' })
    H.no(ok) H.ok(tostring(err):find('invalid'), 'type validation')
    ok, err = H.rpc(p, 'event:action', { action = string.rep('a', 100) })
    H.no(ok)
    ok, err = H.rpc(p, 'event:action', { action = 'bad action!' })
    H.no(ok)
    Sim.dispatch('es:rpc', p, 12345, 1, {}) -- non-string name must not crash
end)

H.test('rate limiting kicks in on floods', function()
    local p = H.players(1, 20)[1]
    local limited = false
    for _ = 1, 20 do
        local ok, err = H.rpc(p, 'browser:list', {})
        if not ok and err == 'rate_limited' then limited = true break end
    end
    H.ok(limited, 'flood rate limited')
end)

H.test('admin RPCs require permission; dangerous ones require confirmation', function()
    local user, admin = table.unpack(H.players(2, 30))
    local ok, err = H.rpc(user, 'admin:bootstrap', {})
    H.no(ok) H.eq(err, 'forbidden')
    ok, err = H.rpc(user, 'admin:instance:create', { definition = 't_ffa' })
    H.no(ok) H.eq(err, 'forbidden')
    H.admin(admin)
    local okB, boot = H.rpc(admin, 'admin:bootstrap', {})
    H.ok(okB) H.ok(#boot.modes >= 12) H.ok(boot.perms['instance.cancel'])
    local okC, res = H.rpc(admin, 'admin:instance:create', { definition = 't_ffa' })
    H.ok(okC)
    ok, err = H.rpc(admin, 'admin:instance:cancel', { id = res.id })
    H.no(ok) H.eq(err, 'confirm_required')
    H.ok((H.rpc(admin, 'admin:instance:cancel', { id = res.id, confirm = true })))
    Sim.advance(1000)
    H.eq(ES.Manager.get(res.id), nil, 'cancelled + archived')
end)

H.test('moderator role mapping: host cannot force finish, moderator can', function()
    local host, mod = table.unpack(H.players(2, 40))
    Sim.players[host].aces['eventstudio.host'] = true
    Sim.players[mod].aces['eventstudio.moderator'] = true
    local okC, res = H.rpc(host, 'admin:instance:create', { definition = 't_ffa' })
    H.ok(okC, 'host can create')
    local ok, err = H.rpc(host, 'admin:instance:stop', { id = res.id, confirm = true })
    H.no(ok) H.eq(err, 'forbidden')
    H.ok((H.rpc(mod, 'admin:instance:cancel', { id = res.id, confirm = true })))
end)

H.test('builder: admin saves a definition that persists (kvp) and validates', function()
    local admin = H.players(1, 50)[1]
    H.admin(admin)
    local ok, err = H.rpc(admin, 'admin:definition:save', { def = { id = 'bad', name = 'Bad', mode = 'race', arena = 'docks_yard' } })
    H.no(ok) H.ok(tostring(err):find('checkpoints'), 'arena requirements enforced: ' .. tostring(err))
    ok = H.rpc(admin, 'admin:definition:save', { def = { id = 'my_race', name = 'My Race', mode = 'race', arena = 'downtown_circuit', options = { laps = 2 } } })
    H.ok(ok)
    H.ok(ES.Storage.loadDocuments('definition').my_race, 'persisted')
    ok, err = H.rpc(admin, 'admin:definition:save', { def = { id = 'greedy', name = 'G', mode = 'custom',
        rewards = { placement = { [1] = { { type = 'cash', amount = 99999999 } } } } } })
    H.no(ok) H.ok(tostring(err):find('limit'), 'reward limits enforced')
end)

H.test('join rules: capacity, duplicate, other event, dead, not enough players cancels', function()
    local ps = H.players(10, 60)
    local okA, idA = ES.Manager.create('t_ffa', { registration = 20 })
    local okB, idB = ES.Manager.create('t_ffa', { registration = 20 })
    H.ok(okA and okB)
    Sim.advance(11000) -- cooldown / fresh
    H.ok((H.rpc(ps[1], 'event:join', { id = idA })))
    local ok, err = H.rpc(ps[1], 'event:join', { id = idA })
    H.no(ok) H.eq(err, 'already_joined')
    ok, err = H.rpc(ps[1], 'event:join', { id = idB })
    H.no(ok) H.eq(err, 'in_other_event')
    Sim.players[ps[2]].health = 0
    ok, err = H.rpc(ps[2], 'event:join', { id = idA })
    H.no(ok) H.eq(err, 'dead')
    for i = 3, 9 do H.ok((H.rpc(ps[i], 'event:join', { id = idA })), 'join ' .. i) end
    ok, err = H.rpc(ps[10], 'event:join', { id = idA })
    H.no(ok) H.eq(err, 'full')
    -- B has nobody → cancelled at registration end
    local instB = ES.Manager.get(idB)
    Sim.advance(21000)
    H.eq(ES.Manager.get(idB), nil, 'B cancelled and archived (' .. tostring(instB.state) .. ')')
    ES.Manager.get(idA):cancel('test')
    Sim.advance(1000)
end)

H.test('payout ledger prevents duplicate rewards even if distribution re-runs', function()
    H.paid = {}
    local a, b = table.unpack(H.players(2, 80))
    local inst = H.createAndJoin('t_ffa', { a, b })
    H.toActive(inst)
    Sim.dispatch('weaponDamageEvent', a, a, { hitGlobalId = GetPlayerPed(b), weaponType = GetHashKey('WEAPON_PISTOL') })
    Sim.players[b].health = 0
    H.rpc(b, 'event:action', { action = 'died', data = { killer = a } })
    H.ok(H.waitState(inst, 'ARCHIVED', 20000))
    local before = #H.paid
    H.eq(before, 3, 'winner + 2 participation')
    ES.Rewards.distribute(inst) -- simulate a crash/replay
    H.eq(#H.paid, before, 'no duplicate payouts')
end)

H.test('parallel instances are isolated in different buckets', function()
    local ps = H.players(6, 90)
    local i1 = H.createAndJoin('t_ffa', { ps[1], ps[2] })
    local i2 = H.createAndJoin('t_ffa', { ps[3], ps[4] })
    local i3 = H.createAndJoin('street_circuit', { ps[5], ps[6] })
    H.toActive(i1) H.toActive(i2) H.toActive(i3)
    H.ok(i1.bucket ~= i2.bucket and i2.bucket ~= i3.bucket and i1.bucket ~= i3.bucket, 'distinct buckets')
    H.eq(Sim.players[ps[1]].bucket, i1.bucket) H.eq(Sim.players[ps[3]].bucket, i2.bucket) H.eq(Sim.players[ps[5]].bucket, i3.bucket)
    local cancelled = Sim.dispatch('weaponDamageEvent', ps[1], ps[1], { hitGlobalId = GetPlayerPed(ps[3]), weaponType = GetHashKey('WEAPON_PISTOL') })
    H.ok(cancelled, 'cross-instance damage cancelled')
    H.eq(ES.Buckets.inUse(), 3)
    -- scoreboard pushes only go to own audience
    H.clear(ps[3])
    ES.Manager.get(i1.id):addScore(i1.participants[ps[1]], 1, 'x')
    Sim.advance(1500)
    for _, m in ipairs(H.pushes(ps[3], 'scoreboard')) do
        for _, r in ipairs(m.rows) do H.no(r.src == ps[1], 'leaked row from other instance') end
    end
    i1:cancel('t') i2:cancel('t') i3:cancel('t')
    Sim.advance(1000)
    H.eq(ES.Buckets.inUse(), 0)
end)

H.test('pause freezes the clock; resume continues', function()
    local a, b = table.unpack(H.players(2, 100))
    local inst = H.createAndJoin('t_ffa', { a, b })
    H.toActive(inst)
    Sim.advance(5000)
    H.ok(inst:pause())
    local elapsed, remaining = inst:elapsedMs(), inst:remainingMs()
    Sim.advance(20000)
    H.eq(inst:elapsedMs(), elapsed, 'elapsed frozen')
    H.eq(inst:remainingMs(), remaining, 'remaining frozen')
    H.ok(inst:resume())
    Sim.advance(1000)
    H.ok(inst:elapsedMs() > elapsed)
    inst:cancel('t') Sim.advance(1000)
end)

H.test('resource stop resets buckets, deletes vehicles, clears return points', function()
    local ps = H.players(2, 110)
    local inst = H.createAndJoin('street_circuit', ps)
    H.toActive(inst)
    H.ok(ES.Util.count(Sim.vehicles) > 0)
    Sim.dispatch('onResourceStop', nil, 'event_studio')
    H.eq(ES.Util.count(Sim.vehicles), 0, 'vehicles deleted')
    for _, s in ipairs(ps) do
        H.eq(Sim.players[s].bucket, 0, 'bucket reset')
        H.eq(ES.Storage.getReturnPoint(Sim.players[s].license), nil, 'return point cleared (client restores)')
    end
    ES.Manager.remove(inst)
    ES.Buckets.release(inst.bucket)
end)

H.test('scheduler creates an instance at lead time and skips duplicates', function()
    local startAt = os.time() + 10 * 60
    local d = os.date('*t', startAt)
    local ok = ES.Scheduler.put({ id = 't_sched', definition = 't_ffa', leadMinutes = 5,
        rule = { type = 'once', date = ('%04d-%02d-%02d'):format(d.year, d.month, d.day), time = ('%02d:%02d'):format(d.hour, d.min) } }, 'test')
    H.ok(ok)
    local before = ES.Util.count(ES.Manager.instances)
    ES.Scheduler.tick()
    H.eq(ES.Util.count(ES.Manager.instances), before, 'not yet (10 min away)')
    Sim.advance(6 * 60 * 1000, 1000)
    ES.Scheduler.tick()
    local created
    for _, i in pairs(ES.Manager.instances) do if i.createdBy == 'scheduler:t_sched' then created = i end end
    H.ok(created, 'instance created by scheduler')
    H.ok(created.state == 'SCHEDULED' or created.state == 'REGISTRATION')
    ES.Scheduler.tick()
    local n = 0
    for _, i in pairs(ES.Manager.instances) do if i.createdBy == 'scheduler:t_sched' then n = n + 1 end end
    H.eq(n, 1, 'no duplicate')
    created:cancel('t') Sim.advance(1000)
    ES.Scheduler.remove('t_sched')
end)

H.test('director picks definitions matching player count', function()
    local id = ES.Director.pick(2, os.time(), function() return 0.5 end)
    H.ok(id, 'picked something for 2 players')
    local d = ES.Definitions.get(id)
    H.ok(d.players.min <= 2)
    H.ok(Config.Director.bands[1].categories[d.category], 'category allowed for small band')
end)

H.test('tournament end-to-end: 4 players knockout via match instances', function()
    local ps = H.players(4, 120)
    local ok, tid = ES.Tournaments.create({ name = 'Cup', definitionId = 'pistol_duel_cup', registrationSeconds = 30 }, 0)
    H.ok(ok)
    for _, s in ipairs(ps) do H.ok((H.rpc(s, 'tournament:join', { id = tid }))) end
    H.ok(ES.Tournaments.begin(tid))
    local t = ES.Tournaments.list[tid]
    local function playLive()
        for _, inst in pairs(ES.Manager.instances) do
            if inst.tournament == tid and inst.state == 'LOBBY' and inst.awaitingStart then inst:go() end -- the host starts each match
            if inst.tournament == tid and inst.state == 'ACTIVE' then
                local list = {}
                for s in pairs(inst.participants) do list[#list + 1] = s end
                table.sort(list)
                local a, b = list[1], list[2]
                -- lower id always wins each round
                Sim.dispatch('weaponDamageEvent', a, a, { hitGlobalId = GetPlayerPed(b), weaponType = GetHashKey('WEAPON_PISTOL') })
                Sim.players[b].health = 0
                H.rpc(b, 'event:action', { action = 'died', data = { killer = a } })
            end
        end
    end
    for _ = 1, 80 do
        if t.status == 'complete' then break end
        playLive()
        Sim.advance(1000)
        for _, s in ipairs(ps) do if Sim.players[s].health == 0 and not ES.Manager.ofPlayer(s) then Sim.players[s].health = 200 end end
    end
    H.eq(t.status, 'complete', 'tournament complete')
    H.eq(t.winner, Sim.players[120].license, 'lowest id wins every match')
end)

H.test('browser list hides hidden/invite events from normal players', function()
    local p = H.players(1, 130)[1]
    local okH, hid = ES.Manager.create('pistol_duel_cup', { registration = 60 })
    local okP, pub = ES.Manager.create('t_ffa', { registration = 60, invite = { 999 } })
    local okV, vis = ES.Manager.create('docks_ffa', { registration = 60 })
    local ok, res = H.rpc(p, 'browser:list', {})
    H.ok(ok)
    local seen = {}
    for _, c in ipairs(res.live) do seen[c.id] = true end
    H.no(seen[hid], 'hidden definition not listed')
    H.no(seen[pub], 'invite-only not listed')
    H.ok(seen[vis], 'public listed')
    H.eq(res.live[1].status, 'open')
    for _, id in ipairs({ hid, pub, vis }) do ES.Manager.get(id):cancel('t') end
    Sim.advance(1000)
end)
