-- Security fuzzing: every RPC with hostile payloads, and random actions inside every mode.
local H = T
H.boot()

local seed = tonumber(os.getenv('ES_SEED') or '') or 1337
math.randomseed(seed)

local function errorsLogged()
    local n = 0
    for _, l in ipairs(Sim.logs) do
        if l:find('event_studio:error', 1, true) then n = n + 1 end
    end
    return n
end

local junk = {
    function() return nil end,
    function() return math.random(-1e9, 1e9) end,
    function() return math.random() * 1e12 end,
    function() return 0 / 0 end,
    function() return math.huge end,
    function() return true end,
    function() return string.rep('A', math.random(0, 5000)) end,
    function() return '<script>alert(1)</script>' end,
    function() return "'; DROP TABLE es_logs; --" end,
    function() return { 1, 2, 3 } end,
    function() return { x = 1e9, y = -1e9, z = 'z' } end,
    function() return {} end,
}
local function randomValue(depth)
    depth = depth or 0
    if depth < 2 and math.random() < 0.25 then
        local t = {}
        for _ = 1, math.random(0, 4) do t[('k%d'):format(math.random(1, 9))] = randomValue(depth + 1) end
        return t
    end
    return junk[math.random(#junk)]()
end
local keys = { 'id', 'target', 'definition', 'def', 'arena', 'schedule', 'action', 'data', 'text', 'amount', 'enabled',
               'confirm', 'reward', 'registration', 'team', 'category', 'season', 'limit', 'level', 'force', 'to', 'index' }
local function randomPayload()
    local p = {}
    for _ = 1, math.random(0, 6) do p[keys[math.random(#keys)]] = randomValue() end
    return p
end

H.test('every RPC survives 60 hostile payloads from a normal player (no errors, no privilege leak)', function()
    local p = H.players(1, 10)[1]
    local list = ES.RPC.list()
    H.ok(#list >= 45, 'expected many RPCs, got ' .. #list)
    local before = errorsLogged()
    for _, r in ipairs(list) do
        for _ = 1, 60 do
            ES.RPC.clear(p) -- defeat the rate limiter so every payload reaches validation
            local ok, err = ES.RPC.dispatch(p, r.name, 1, randomPayload())
            if r.perm and ES.Config.Permissions.actions[r.perm] then
                H.no(ok, ('%s succeeded for a non-staff player'):format(r.name))
                H.eq(err == 'forbidden' or tostring(err):find('invalid') ~= nil or err == 'invalid', true,
                    ('%s: unexpected rejection %s'):format(r.name, tostring(err)))
            end
            H.eq(err ~= 'error', true, ('%s raised a Lua error'):format(r.name))
        end
    end
    Sim.advance(2000)
    H.eq(errorsLogged(), before, 'no error logs produced')
    H.ok(ES.ready)
end)

H.test('admin RPCs survive hostile payloads from an admin (validation, not crashes)', function()
    local a = H.players(1, 20)[1]
    H.admin(a)
    local before = errorsLogged()
    local created = {}
    for _, r in ipairs(ES.RPC.list()) do
        if r.name:find('^admin:') and r.name ~= 'admin:instance:restart' then
            for _ = 1, 40 do
                ES.RPC.clear(a)
                local _, err = ES.RPC.dispatch(a, r.name, 1, randomPayload())
                H.eq(err ~= 'error', true, ('%s raised a Lua error'):format(r.name))
            end
        end
    end
    Sim.advance(3000)
    H.eq(errorsLogged(), before, 'no error logs produced')
    for _, inst in pairs(ES.Manager.instances) do inst:cancel('fuzz') end
    Sim.advance(2000)
end)

local modes = {
    { 'street_circuit' }, { 'docks_ffa' }, { 'gun_game' }, { 'sumo_classic' }, { 'airfield_koth' },
    { 'airfield_ctf', teams = true }, { 'shrinking_zone' }, { 'city_scavenger' }, { 'red_light_green_light' },
    { 'trivia_night' }, { 'reaction_test' }, { 'staff_challenge' },
    { 'juggernaut_docks' }, { 'protect_the_vip' }, { 'hunters_vs_runners' }, { 'keep_moving_airport' }, { 'musical_chairs' },
    { 'bounty_hunt' }, { 'assassin_hunt' }, { 'deliver_the_package' }, { 'hold_the_package' }, { 'vehicle_tag' }, { 'airfield_assault' }, { 'memory_challenge' },
}
local actions = { 'checkpoint', 'reset', 'died', 'answer', 'react', 'pickup', 'capture', 'x', '__index', 'finish', 'win' }

for _, m in ipairs(modes) do
    H.test(('mode %s: 300 random actions from participants cause no errors and no illegitimate score'):format(m[1]), function()
        local srcs = H.players(4, 100 + #modes * 10 + math.random(1, 100000))
        local inst = H.createAndJoin(m[1], srcs)
        H.toActive(inst)
        local before = errorsLogged()
        for _ = 1, 300 do
            local s = srcs[math.random(#srcs)]
            ES.RPC.clear(s)
            ES.RPC.dispatch(s, 'event:action', 1, { action = actions[math.random(#actions)], data = randomPayload() })
            if math.random() < 0.05 then Sim.advance(100) end
        end
        Sim.advance(1000)
        H.eq(errorsLogged(), before, 'no error logs produced')
        -- nobody can have won or scored kills through random client input alone
        for _, p in ipairs(inst:allParticipants()) do
            H.eq(p.stats.kills, 0, 'no kills from fake death hints')
            H.no(p.status == 'finished' and m[1] == 'street_circuit', 'no fake race finish')
        end
        if inst.state ~= 'ARCHIVED' then inst:cancel('fuzz') end
        Sim.advance(2000)
        for _, s in ipairs(srcs) do Sim.players[s] = nil end
    end)
end
