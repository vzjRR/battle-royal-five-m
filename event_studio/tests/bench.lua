-- Offline server-tick benchmark (not a test).  Usage: lua5.4 tests/bench.lua
-- Measures the Lua CPU cost of EVENT STUDIO's engine tick in the mock runtime while players move.
-- Real FiveM natives cost more than the mock's, so treat numbers as a lower bound and use
-- `resmon` on a live server for final figures (docs/TESTING.md §3).

_G.Sim = { root = arg[0]:match('^(.*)/tests/bench%.lua$') or '.' }
local H = dofile(Sim.root .. '/tests/lib/harness.lua')
H.boot()

local nextSrc = 1000
local function players(n)
    local list = H.players(n, nextSrc)
    nextSrc = nextSrc + n
    return list
end

local function jitter(srcs)
    for _, s in ipairs(srcs) do
        local p = Sim.players[s].pos
        p.x, p.y = p.x + math.random() * 4 - 2, p.y + math.random() * 4 - 2
    end
end

---Average ms of Lua CPU per engine tick (all instances), measured over `ticks` ticks.
local function measure(allSrcs, ticks)
    local tickMs = Config.General.tickMs
    local total = 0
    for _ = 1, ticks do
        jitter(allSrcs)
        local t0 = os.clock()
        Sim.advance(tickMs, tickMs)
        total = total + (os.clock() - t0)
    end
    return total / ticks * 1000
end

local results = {}
local function scenario(name, specs)
    local all, insts = {}, {}
    for _, spec in ipairs(specs) do
        local srcs = players(spec[2])
        for _, s in ipairs(srcs) do all[#all + 1] = s end
        local inst = H.createAndJoin(spec[1], srcs, { registration = 30, overrides = { players = { max = 64, min = 1 } } })
        H.toActive(inst)
        insts[#insts + 1] = inst
    end
    local ms = measure(all, 200)
    results[#results + 1] = { name = name, players = #all, instances = #insts, ms = ms }
    for _, inst in ipairs(insts) do inst:cancel('bench') end
    Sim.advance(2000)
    for _, s in ipairs(all) do Sim.players[s] = nil end
end

-- idle: no instances → the engine loop is not running at all
local t0 = os.clock()
Sim.advance(100000, 500)
results[#results + 1] = { name = 'idle (no events)', players = 0, instances = 0, ms = (os.clock() - t0) / 200 * 1000 }

scenario('race, 16 players', { { 'street_circuit', 16 } })
scenario('team deathmatch, 32 players', { { 'team_deathmatch', 32 } })
scenario('king of the hill, 32 players', { { 'airfield_koth', 32 } })
scenario('shrinking zone, 64 players', { { 'shrinking_zone', 64 } })
scenario('3 simultaneous (16 race + 32 TDM + 16 KOTH)', { { 'street_circuit', 16 }, { 'team_deathmatch', 32 }, { 'airfield_koth', 16 } })

Sim.print(('%-48s %8s %9s %12s'):format('scenario', 'players', 'events', 'ms / tick'))
for _, r in ipairs(results) do
    Sim.print(('%-48s %8d %9d %12.3f'):format(r.name, r.players, r.instances, r.ms))
end
Sim.print(('tick interval: %d ms (engine runs only while events exist)'):format(Config.General.tickMs))
