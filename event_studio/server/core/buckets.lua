-- EVENT STUDIO — routing bucket pool

local Buckets = { used = {} }
ES.Buckets = Buckets

function Buckets.acquire(instanceId)
    local cfg = Config.General.buckets
    for b = cfg.from, cfg.to do
        if not Buckets.used[b] then
            Buckets.used[b] = instanceId
            SetRoutingBucketPopulationEnabled(b, cfg.population == true)
            SetRoutingBucketEntityLockdownMode(b, cfg.lockdown or 'relaxed')
            return b
        end
    end
    return nil
end

function Buckets.release(bucket)
    if bucket then Buckets.used[bucket] = nil end
end

function Buckets.inUse() return ES.Util.count(Buckets.used) end

return Buckets
