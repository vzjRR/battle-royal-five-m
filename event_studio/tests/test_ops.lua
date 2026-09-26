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
