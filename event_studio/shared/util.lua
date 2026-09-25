-- EVENT STUDIO — shared utilities (pure Lua, no natives)

local U = {}
ES.Util = U

function U.deepCopy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for k, v in pairs(value) do
        out[U.deepCopy(k, seen)] = U.deepCopy(v, seen)
    end
    return out
end

---Recursively merge `src` into a copy of `base` (src wins). Arrays are replaced, not merged.
function U.merge(base, src)
    local out = U.deepCopy(base or {})
    if type(src) ~= 'table' then return out end
    for k, v in pairs(src) do
        if type(v) == 'table' and type(out[k]) == 'table' and not U.isArray(v) and not U.isArray(out[k]) then
            out[k] = U.merge(out[k], v)
        else
            out[k] = U.deepCopy(v)
        end
    end
    return out
end

function U.isArray(t)
    if type(t) ~= 'table' then return false end
    local n = #t
    if n == 0 then return next(t) == nil end
    for k in pairs(t) do
        if type(k) ~= 'number' or k < 1 or k > n or k % 1 ~= 0 then return false end
    end
    return true
end

function U.count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function U.keys(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = k end
    return out
end

function U.values(t)
    local out = {}
    for _, v in pairs(t) do out[#out + 1] = v end
    return out
end

function U.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function U.round(v, decimals)
    local m = 10 ^ (decimals or 0)
    return math.floor(v * m + 0.5) / m
end

function U.shuffle(t, rng)
    rng = rng or math.random
    for i = #t, 2, -1 do
        local j = rng(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

function U.pick(t, rng)
    if #t == 0 then return nil end
    return t[(rng or math.random)(1, #t)]
end

---Distance between two {x,y,z} tables / vector3s.
function U.dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function U.dist2d(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

---Normalise vector-ish input to a plain table {x,y,z,w?}.
function U.vec(v)
    if not v then return nil end
    if type(v) == 'table' then
        if v.x then return { x = v.x + 0.0, y = v.y + 0.0, z = (v.z or 0) + 0.0, w = v.w or v.h } end
        return { x = v[1] + 0.0, y = v[2] + 0.0, z = (v[3] or 0) + 0.0, w = v[4] }
    end
    -- vector3/vector4 userdata
    return { x = v.x + 0.0, y = v.y + 0.0, z = v.z + 0.0, w = v.w }
end

function U.lerp(a, b, t) return a + (b - a) * t end

function U.startsWith(s, prefix) return s:sub(1, #prefix) == prefix end

function U.trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end

---Safe id: lowercase letters, digits, underscore, dash; 1-64 chars.
function U.isId(s)
    return type(s) == 'string' and #s >= 1 and #s <= 64 and s:match('^[%w_%-]+$') ~= nil
end

function U.slug(s)
    s = tostring(s or ''):lower():gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', '')
    if #s > 48 then s = s:sub(1, 48) end
    return s ~= '' and s or 'item'
end

function U.fmtDuration(ms)
    ms = math.max(0, math.floor(ms or 0))
    local s = ms // 1000
    local m = s // 60
    return string.format('%d:%02d.%03d', m, s % 60, ms % 1000)
end

function U.contains(list, value)
    for i = 1, #list do if list[i] == value then return true end end
    return false
end

function U.filter(list, fn)
    local out = {}
    for i = 1, #list do if fn(list[i], i) then out[#out + 1] = list[i] end end
    return out
end

function U.map(list, fn)
    local out = {}
    for i = 1, #list do out[i] = fn(list[i], i) end
    return out
end

---Tiny token bucket rate limiter.
function U.newBucket(burst, perSeconds)
    return { tokens = burst, burst = burst, rate = burst / perSeconds, last = nil }
end

function U.takeToken(bucket, nowMs)
    if bucket.last then
        local elapsed = (nowMs - bucket.last) / 1000
        bucket.tokens = math.min(bucket.burst, bucket.tokens + elapsed * bucket.rate)
    end
    bucket.last = nowMs
    if bucket.tokens >= 1 then
        bucket.tokens = bucket.tokens - 1
        return true
    end
    return false
end

return U
