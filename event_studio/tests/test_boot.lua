-- Boot smoke test: the whole server loads from the manifest and registers everything.
local H = T
H.boot()

H.test('server boots and is ready', function()
    H.ok(ES.ready)
    H.eq(ES.Bridge.name, 'standalone', 'framework')
    H.eq(ES.Storage.adapter, 'kvp', 'storage')
end)

H.test('all modes registered', function()
    for _, m in ipairs({ 'race', 'deathmatch', 'gungame', 'sumo', 'koth', 'ctf', 'zone_survival', 'hunt', 'redlight', 'trivia', 'reaction', 'custom' }) do
        H.ok(ES.Modes[m], 'mode missing: ' .. m)
    end
end)

H.test('all config presets and arenas validate', function()
    H.eq(#ES.ConfigArenas, ES.Util.count(ES.Arenas.list), 'arenas loaded')
    for _, d in ipairs(ES.ConfigDefinitions) do
        H.ok(ES.Definitions.get(d.id), 'definition failed validation: ' .. d.id)
    end
end)

H.test('config schedules load', function()
    H.ok(ES.Scheduler.schedules.friday_street_race, 'schedule')
    H.ok(#ES.Scheduler.upcoming(10) >= 3, 'upcoming')
end)

H.test('exports registered', function()
    for _, n in ipairs({ 'CreateEvent', 'StartEvent', 'JoinPlayer', 'GivePoints', 'GetLeaderboard', 'RegisterRewardType' }) do
        H.ok(Sim.exports[n], 'export ' .. n)
    end
end)
