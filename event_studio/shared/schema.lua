-- EVENT STUDIO — tiny declarative schema validator (pure)
--
-- Field spec forms:
--   'integer' | 'number' | 'string' | 'boolean' | 'id' | 'table' | 'any'   (append '?' for optional)
--   { type = 'number', min = 0, max = 10, default = 1, optional = true, label = '...', help = '...' }
--   { type = 'enum', values = { 'a', 'b' } }
--   { type = 'list', item = <spec>, maxItems = 64 }
--   { type = 'object', fields = { key = <spec>, ... } }
--   { type = 'vec3' }         -- {x,y,z} or {1,2,3}
--   { type = 'string', maxLen = 128, pattern = '^[%w_]+$' }
-- Unknown keys in objects are dropped (never passed to handlers).

local U = ES.Util
local Schema = {}
ES.Schema = Schema

local function normalize(spec)
    if type(spec) == 'string' then
        local optional = spec:sub(-1) == '?'
        local t = optional and spec:sub(1, -2) or spec
        return { type = t, optional = optional }
    end
    return spec
end

local validate

local validators = {}

function validators.any(v) return true, v end

function validators.boolean(v)
    if type(v) ~= 'boolean' then return false, 'expected boolean' end
    return true, v
end

function validators.number(v, spec)
    if type(v) ~= 'number' or v ~= v or v == math.huge or v == -math.huge then return false, 'expected number' end
    if spec.min and v < spec.min then return false, ('must be >= %s'):format(spec.min) end
    if spec.max and v > spec.max then return false, ('must be <= %s'):format(spec.max) end
    return true, v
end

function validators.integer(v, spec)
    local ok, err = validators.number(v, spec)
    if not ok then return false, err end
    if v % 1 ~= 0 then return false, 'expected integer' end
    return true, math.tointeger(v) or v
end

function validators.string(v, spec)
    if type(v) ~= 'string' then return false, 'expected string' end
    local maxLen = spec.maxLen or 256
    if #v > maxLen then return false, ('too long (max %d)'):format(maxLen) end
    if spec.minLen and #v < spec.minLen then return false, ('too short (min %d)'):format(spec.minLen) end
    if spec.pattern and not v:match(spec.pattern) then return false, 'invalid format' end
    return true, v
end

function validators.id(v)
    if not U.isId(v) then return false, 'invalid id' end
    return true, v
end

function validators.enum(v, spec)
    for i = 1, #spec.values do
        if spec.values[i] == v then return true, v end
    end
    return false, 'invalid value'
end

function validators.vec3(v)
    if type(v) ~= 'table' then return false, 'expected vector' end
    local vec = U.vec(v)
    if type(vec.x) ~= 'number' or type(vec.y) ~= 'number' or type(vec.z) ~= 'number' then
        return false, 'expected vector'
    end
    if math.abs(vec.x) > 20000 or math.abs(vec.y) > 20000 or math.abs(vec.z) > 5000 then
        return false, 'vector out of world bounds'
    end
    return true, vec
end

function validators.table(v)
    if type(v) ~= 'table' then return false, 'expected table' end
    return true, v
end

function validators.list(v, spec, path)
    if type(v) ~= 'table' or not U.isArray(v) then return false, 'expected list' end
    local maxItems = spec.maxItems or 256
    if #v > maxItems then return false, ('too many items (max %d)'):format(maxItems) end
    if spec.minItems and #v < spec.minItems then return false, ('needs at least %d items'):format(spec.minItems) end
    local out = {}
    if not spec.item then
        for i = 1, #v do out[i] = v[i] end
        return true, out
    end
    for i = 1, #v do
        local ok, res = validate(v[i], spec.item, path .. '[' .. i .. ']')
        if not ok then return false, res end
        out[i] = res
    end
    return true, out
end

function validators.object(v, spec, path)
    if type(v) ~= 'table' then return false, 'expected object' end
    local out = {}
    for key, fieldSpec in pairs(spec.fields or {}) do
        local ok, res = validate(v[key], fieldSpec, path == '' and key or (path .. '.' .. key))
        if not ok then return false, res end
        out[key] = res
    end
    return true, out
end

function validate(value, spec, path)
    spec = normalize(spec)
    path = path or ''
    if value == nil then
        if spec.default ~= nil then return true, U.deepCopy(spec.default) end
        if spec.optional then return true, nil end
        return false, (path ~= '' and path .. ': ' or '') .. 'required'
    end
    local fn = validators[spec.type]
    if not fn then return false, (path .. ': unknown schema type ' .. tostring(spec.type)) end
    local ok, res = fn(value, spec, path)
    if not ok then
        -- nested validators already prefix their path
        if type(res) == 'string' and not res:find(':', 1, true) and path ~= '' then
            res = path .. ': ' .. res
        end
        return false, res
    end
    return true, res
end

---Validate `value` against `spec`. Returns ok, cleanedValueOrError.
function Schema.validate(value, spec)
    return validate(value, spec, '')
end

---Validate a flat table against a map of field specs (object shorthand).
function Schema.validateFields(value, fields)
    return validate(value or {}, { type = 'object', fields = fields }, '')
end

---Produce defaults for a map of field specs.
function Schema.defaults(fields)
    local out = {}
    for k, spec in pairs(fields or {}) do
        spec = normalize(spec)
        if spec.default ~= nil then
            out[k] = U.deepCopy(spec.default)
        elseif spec.type == 'object' and spec.fields then
            out[k] = Schema.defaults(spec.fields)
        end
    end
    return out
end

---JSON-safe description of a field map for the NUI builder.
function Schema.describe(fields)
    local out = {}
    for k, spec in pairs(fields or {}) do
        spec = normalize(spec)
        local d = {
            key = k, type = spec.type, label = spec.label or k, help = spec.help,
            min = spec.min, max = spec.max, default = spec.default, values = spec.values,
            optional = spec.optional, order = spec.order or 100, maxLen = spec.maxLen,
        }
        if spec.item then d.item = normalize(spec.item).type end
        if spec.type == 'object' and spec.fields then d.fields = Schema.describe(spec.fields) end
        out[#out + 1] = d
    end
    table.sort(out, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.key < b.key
    end)
    return out
end

return Schema
