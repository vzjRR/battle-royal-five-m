-- Minimal JSON encode/decode for the test runtime (FiveM provides `json` natively).
local json = {}

local function kind(t)
    if next(t) == nil then return 'array' end
    local n = #t
    local count = 0
    for k in pairs(t) do
        if type(k) ~= 'number' then return 'object' end
        count = count + 1
    end
    return count == n and 'array' or 'object'
end

local escapes = { ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }

local function encode(v, seen)
    local t = type(v)
    if t == 'nil' then return 'null' end
    if t == 'boolean' then return tostring(v) end
    if t == 'number' then
        if v ~= v or v == math.huge or v == -math.huge then return 'null' end
        if math.type(v) == 'integer' then return tostring(v) end
        return string.format('%.14g', v)
    end
    if t == 'string' then
        return '"' .. v:gsub('[%c"\\]', function(c) return escapes[c] or string.format('\\u%04x', c:byte()) end) .. '"'
    end
    if t == 'table' then
        seen = seen or {}
        if seen[v] then error('cyclic table') end
        seen[v] = true
        local out = {}
        if kind(v) == 'array' then
            for i = 1, #v do out[i] = encode(v[i], seen) end
            seen[v] = nil
            return '[' .. table.concat(out, ',') .. ']'
        end
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local val = v[k]
            if val == nil then val = v[tonumber(k)] end
            if type(val) ~= 'function' then out[#out + 1] = encode(k) .. ':' .. encode(val, seen) end
        end
        seen[v] = nil
        return '{' .. table.concat(out, ',') .. '}'
    end
    return 'null'
end

function json.encode(v) return encode(v) end

function json.decode(s)
    local pos = 1
    local function ws() pos = s:find('[^%s]', pos) or #s + 1 end
    local value
    local function str()
        pos = pos + 1
        local out = {}
        while true do
            local c = s:sub(pos, pos)
            if c == '"' then pos = pos + 1 break end
            if c == '\\' then
                local n = s:sub(pos + 1, pos + 1)
                local map = { b = '\b', f = '\f', n = '\n', r = '\r', t = '\t', ['"'] = '"', ['\\'] = '\\', ['/'] = '/' }
                if n == 'u' then
                    out[#out + 1] = utf8.char(tonumber(s:sub(pos + 2, pos + 5), 16))
                    pos = pos + 6
                else
                    out[#out + 1] = map[n]
                    pos = pos + 2
                end
            else
                out[#out + 1] = c
                pos = pos + 1
            end
        end
        return table.concat(out)
    end
    function value()
        ws()
        local c = s:sub(pos, pos)
        if c == '{' then
            pos = pos + 1
            local t = {}
            ws()
            if s:sub(pos, pos) == '}' then pos = pos + 1 return t end
            while true do
                ws()
                local k = str()
                ws(); pos = pos + 1 -- :
                t[k] = value()
                ws()
                local d = s:sub(pos, pos)
                pos = pos + 1
                if d == '}' then return t end
            end
        elseif c == '[' then
            pos = pos + 1
            local t = {}
            ws()
            if s:sub(pos, pos) == ']' then pos = pos + 1 return t end
            while true do
                t[#t + 1] = value()
                ws()
                local d = s:sub(pos, pos)
                pos = pos + 1
                if d == ']' then return t end
            end
        elseif c == '"' then
            return str()
        elseif s:sub(pos, pos + 3) == 'true' then pos = pos + 4 return true
        elseif s:sub(pos, pos + 4) == 'false' then pos = pos + 5 return false
        elseif s:sub(pos, pos + 3) == 'null' then pos = pos + 4 return nil
        else
            local num = s:match('^-?%d+%.?%d*[eE]?[-+]?%d*', pos)
            pos = pos + #num
            return math.tointeger(tonumber(num)) or tonumber(num)
        end
    end
    return value()
end

return json
