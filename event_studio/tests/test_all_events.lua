-- Every shipped event (config/events) runs from registration to the end without an engine error:
-- close registration, host Start, 10 s countdown, pause + resume, play until time is up (nobody does anything), results,
-- rewards, and everyone back where they were.
local H = T
H.boot()
H.recordRewards()

local function errorsSince(n)
    local out = {}
    for i = n + 1, #Sim.logs do
        local l = Sim.logs[i]
        if l:find(':error]', 1, true) or l:find('SCRIPT ERROR', 1, true) then out[#out + 1] = l end
    end
    return out
end

local base = 20000
for _, d in ipairs(ES.ConfigDefinitions) do
    H.test(('event runs start to finish: %s (%s)'):format(d.id, d.mode), function()
        local def = ES.Definitions.get(d.id)
        H.ok(def, 'definition loaded')
        local teams = def.players.teams and def.players.teams.count or 0
        local n = math.max(def.players.min, teams > 0 and teams * 2 or 2)
        base = base + 100
        local srcs = H.players(n, base)
        for _, s in ipairs(srcs) do H.setPos(s, 500.0, 500.0, 30.0) end
        local logStart = #Sim.logs
        local inst = H.createAndJoin(d.id, srcs)
        H.toActive(inst)
        H.eq(inst.state, 'ACTIVE')
        -- an admin pauses for a moment and resumes
        Sim.advance(5000)
        if inst.state == 'ACTIVE' then
            local before = inst.deadline and (inst.deadline - ES.now())
            H.ok(inst:pause())
            Sim.advance(6000)
            H.eq(inst.state, 'PAUSED')
            H.ok(inst:resume())
            if before then
                local after = inst.deadline and (inst.deadline - ES.now())
                H.ok(after and math.abs(after - before) < 1000, ('timer kept across pause: %s -> %s'):format(before, tostring(after)))
            end
        end
        local limit = ((def.timing.duration or 0) > 0 and def.timing.duration or 900) + 400
        H.ok(H.waitState(inst, 'ARCHIVED', limit * 1000), ('%s ended, state=%s'):format(d.id, inst.state))
        local errs = errorsSince(logStart)
        H.eq(#errs, 0, 'engine errors: ' .. table.concat(errs, ' | '))
        for _, s in ipairs(srcs) do
            H.eq(Sim.players[s].bucket, 0, 'player back in the normal world')
            H.eq(ES.Manager.ofPlayer(s), nil, 'player no longer in the event')
            Sim.players[s] = nil
        end
        H.eq(ES.Manager.get(inst.id), nil, 'instance removed')
        H.eq(ES.Buckets.inUse(), 0, 'routing bucket released')
        H.eq(ES.Util.count(Sim.vehicles), 0, 'no vehicles left behind')
    end)
end
