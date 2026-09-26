-- Operations tooling: live self test, arena ground-height fixer (server side).
local H = T
H.boot()

H.test('selftest runs all checks and passes in a healthy environment', function()
    local admin = H.players(1, 10)[1]
    H.admin(admin)
    local results
    Sim.runNow(function() results = ES.SelfTest.run() end)
    Sim.advance(4000)
    H.ok(results, 'selftest finished')
    local byName, fails = {}, 0
    for _, r in ipairs(results) do
        byName[r.name] = r
        if r.level == 'FAIL' then fails = fails + 1 end
    end
    H.eq(fails, 0, 'no failures: ' .. (function() local s = '' for _, r in ipairs(results) do if r.level == 'FAIL' then s = s .. r.name .. ': ' .. r.detail .. '; ' end end return s end)())
    H.eq(byName['Server vehicle spawn'].level, 'PASS')
    H.eq(byName['Permissions'].level, 'PASS')
    H.eq(ES.Util.count(Sim.vehicles), 0, 'probe vehicle deleted')
    H.eq(ES.Buckets.inUse(), 0, 'probe bucket released')
end)

H.test('selftest reports a bucket-range conflict and a missing OneSync', function()
    local p = H.players(1, 20)[1]
    Sim.players[p].bucket = Config.General.buckets.from + 3
    Sim.convars.onesync = 'off'
    local results
    Sim.runNow(function() results = ES.SelfTest.run() end)
    Sim.advance(4000)
    local levels = {}
    for _, r in ipairs(results) do levels[r.name] = r.level end
    H.eq(levels['OneSync'], 'FAIL')
    H.eq(levels['Bucket range'], 'WARN')
    Sim.convars.onesync = 'on'
    Sim.players[p].bucket = 0
end)

H.test('eventstudio selftest command is permission gated', function()
    local p = H.players(1, 30)[1]
    H.clear(p)
    Sim.commands.eventstudio(p, { 'selftest' })
    Sim.advance(4000)
    H.eq(#H.pushes(p, 'notify'), 0, 'non-staff gets nothing')
end)

H.test('eventstudio perms (console) shows role, identifiers and the grant line; players cannot run it', function()
    local a, b = table.unpack(H.players(2, 35))
    H.admin(a)
    local n = #Sim.logs
    Sim.commands.eventstudio(0, { 'perms' })
    local out = table.concat({ table.unpack(Sim.logs, n + 1) }, '\n')
    H.ok(out:find(('[%d] Player%d → role: admin'):format(a, a), 1, true), 'admin resolved')
    H.ok(out:find(('[%d] Player%d → role: none'):format(b, b), 1, true), 'non-staff resolved')
    H.ok(out:find('add_ace identifier.' .. Sim.players[b].license .. ' eventstudio.admin allow', 1, true), 'grant line for non-staff')
    H.no(out:find('ip:', 1, true), 'IP addresses are never printed')
    H.clear(a)
    Sim.commands.eventstudio(a, { 'perms' })
    H.eq(H.lastPush(a, 'notify').text, 'Run this in the server console.')
end)

H.test('arena probe lists every point; applyZ validates and persists', function()
    local admin = H.players(1, 40)[1]
    H.admin(admin)
    local ok, probe = H.rpc(admin, 'admin:arena:probe', { id = 'sandy_airfield' })
    H.ok(ok)
    local keys = {}
    for _, p in ipairs(probe.points) do keys[p.key] = (keys[p.key] or 0) + 1 end
    H.eq(keys.center, 1) H.eq(keys.finish, 1) H.eq(keys.zones, 3) H.eq(keys.objectives, 2) H.eq(keys.teamSpawns, 8)
    local okA, res = H.rpc(admin, 'admin:arena:applyZ', { id = 'sandy_airfield', fixes = {
        { key = 'zones', index = 2, z = 42.0 }, { key = 'teamSpawns', team = 2, index = 1, z = 41.3 }, { key = 'center', z = 40.9 } } })
    H.ok(okA, tostring(res))
    H.eq(res.applied, 3)
    local a = ES.Arenas.get('sandy_airfield')
    H.eq(a.zones[2].z, 42.0) H.eq(a.teamSpawns[2][1].z, 41.3) H.eq(a.center.z, 40.9)
    H.ok(ES.Storage.loadDocuments('arena').sandy_airfield, 'saved as storage override')
    -- rejects nonsense
    local bad1 = H.rpc(admin, 'admin:arena:applyZ', { id = 'sandy_airfield', fixes = { { key = 'zones', index = 99, z = 1.0 } } })
    local bad2 = H.rpc(admin, 'admin:arena:applyZ', { id = 'sandy_airfield', fixes = { { key = 'zones', index = 1, z = 900.0 } } })
    local bad3 = H.rpc(admin, 'admin:arena:applyZ', { id = 'sandy_airfield', fixes = { { key = 'rules', index = 1, z = 1.0 } } })
    H.no(bad1) H.no(bad2) H.no(bad3)
    -- a normal player can't
    local user = H.players(1, 41)[1]
    local okU, err = H.rpc(user, 'admin:arena:probe', { id = 'sandy_airfield' })
    H.no(okU) H.eq(err, 'forbidden')
    -- presets on this arena still validate after the change
    H.ok(ES.Definitions.validate(ES.Util.deepCopy(ES.Definitions.get('airfield_ctf'))))
end)

H.test('after an event ends, "left" is the last message a participant gets (no snapshot brings the HUD back)', function()
    local d = { id = 'o_end', name = 'o_end', mode = 'deathmatch', arena = 'docks_yard', players = { min = 2, max = 4 },
        timing = { registration = 30, lobby = 1, countdown = 1, duration = 600, results = 3 } }
    assert(ES.Definitions.register(d))
    local srcs = H.players(2, 60)
    local inst = H.createAndJoin('o_end', srcs)
    H.toActive(inst)
    inst:finishNow('test')
    H.ok(H.waitState(inst, 'ARCHIVED', 60000))
    Sim.advance(2000)
    for _, s in ipairs(srcs) do
        local last
        for _, m in ipairs(Sim.outbox[s] or {}) do
            if m.name == 'es:push' and (m.args[1] == 'state' or m.args[1] == 'left') then last = m.args[1] end
        end
        H.eq(last, 'left', 'no state push after left')
        for _, st in ipairs(H.pushes(s, 'state')) do H.no(st.state == 'ARCHIVED', 'ARCHIVED snapshot sent') end
    end
end)
