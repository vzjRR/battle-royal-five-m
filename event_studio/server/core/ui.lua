-- EVENT STUDIO — live appearance settings (theme, layout, colors, branding) edited from the Admin Center.
-- Config.UI is the base; saved overrides (storage document setting/ui) are merged on top and pushed to every client.

local U, Log, RPC = ES.Util, ES.Log, ES.RPC

local UI = { overrides = {} }
ES.UI = UI

local COLOR_KEYS = { 'accent', 'accent2', 'background', 'panel', 'text', 'good', 'warn', 'bad' }
local LAYOUTS = { compact = true, docked = true, full = true }
local HUD_POS = { ['top-right'] = true, ['top-left'] = true }

-- Keys players may be given (FiveM keyboard mapping names). F8 (console), Esc and Enter are never offered.
local KEYS = {}
for i = 1, 12 do if i ~= 8 then KEYS['F' .. i] = true end end
for c in ('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'):gmatch('.') do KEYS[c] = true end
for i = 0, 9 do KEYS['NUMPAD' .. i] = true end
for _, k in ipairs({ 'HOME', 'END', 'INSERT', 'DELETE', 'PAGEUP', 'PAGEDOWN' }) do KEYS[k] = true end
UI.KEYS = KEYS
local KEY_ACTIONS = { browser = true, scoreboard = true, reset = true }

---Normalise a key name ('f7' -> 'F7'); nil if it is not allowed.
function UI.cleanKey(v)
    if type(v) ~= 'string' then return nil end
    v = v:upper():gsub('%s', '')
    return KEYS[v] and v or nil
end

local function isHex(v)
    return type(v) == 'string' and (v:match('^#%x%x%x$') or v:match('^#%x%x%x%x%x%x$') or v:match('^#%x%x%x%x%x%x%x%x$')) ~= nil
end

---Image reference: false/'auto', a file under web/img/, or an https URL without quotes, spaces or parentheses.
local function isImage(v)
    if v == false or v == 'auto' then return true end
    if type(v) ~= 'string' or #v > 300 then return false end
    if v:match('^img/[%w_%-/]+%.[%a]+$') and not v:find('..', 1, true) then
        local ext = v:match('%.(%a+)$'):lower()
        return ext == 'png' or ext == 'svg' or ext == 'webp' or ext == 'jpg' or ext == 'jpeg'
    end
    return v:match('^https://[%w%-%._~:/%%?#@!$&*+,;=]+$') ~= nil
end

local function cleanText(v, max)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('[%c]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #v == 0 or #v > max then return nil end
    return v
end

---Validate and normalise an overrides table. Returns clean table or nil, error.
function UI.validate(s)
    if type(s) ~= 'table' then return nil, 'invalid' end
    local out = {}
    if s.theme ~= nil then
        if type(s.theme) ~= 'string' or not ES.theme(s.theme) then return nil, 'unknown_theme' end
        out.theme = s.theme
    end
    if s.browserLayout ~= nil then
        if not LAYOUTS[s.browserLayout] then return nil, 'invalid_layout' end
        out.browserLayout = s.browserLayout
    end
    if s.browserKeepMoving ~= nil then
        if type(s.browserKeepMoving) ~= 'boolean' then return nil, 'invalid' end
        out.browserKeepMoving = s.browserKeepMoving
    end
    if s.locale ~= nil then
        if type(s.locale) ~= 'string' or s.locale:sub(1, 1) == '_' or not ES.Locales[s.locale] then return nil, 'unknown_locale' end
        out.locale = s.locale
    end
    if s.hudPosition ~= nil then
        if not HUD_POS[s.hudPosition] then return nil, 'invalid' end
        out.hudPosition = s.hudPosition
    end
    if s.artwork ~= nil then
        if not isImage(s.artwork) then return nil, 'invalid_image' end
        out.artwork = s.artwork
    end
    if s.brand ~= nil then
        if type(s.brand) ~= 'table' then return nil, 'invalid' end
        out.brand = {}
        if s.brand.title ~= nil then out.brand.title = cleanText(s.brand.title, 48) or nil end
        if s.brand.subtitle ~= nil then out.brand.subtitle = cleanText(s.brand.subtitle, 64) or nil end
        if s.brand.logo ~= nil then
            if not isImage(s.brand.logo) then return nil, 'invalid_image' end
            out.brand.logo = s.brand.logo
        end
    end
    if s.colors ~= nil then
        if type(s.colors) ~= 'table' then return nil, 'invalid' end
        out.colors = {}
        for _, k in ipairs(COLOR_KEYS) do
            local v = s.colors[k]
            if v ~= nil and v ~= '' then
                if not isHex(v) then return nil, 'invalid_color' end
                out.colors[k] = v:lower()
            end
        end
    end
    if s.keys ~= nil then
        if type(s.keys) ~= 'table' then return nil, 'invalid' end
        out.keys = {}
        for action, v in pairs(s.keys) do
            if not KEY_ACTIONS[action] then return nil, 'invalid' end
            if v == false and action ~= 'browser' then
                out.keys[action] = false            -- turned off (the events window key cannot be)
            elseif v ~= nil and v ~= '' then
                local key = UI.cleanKey(v)
                if not key then return nil, 'invalid_key' end
                out.keys[action] = key
            end
        end
        local used = {}
        for _, key in pairs(UI.keys(out.keys)) do
            if key then
                if used[key] then return nil, 'duplicate_key' end
                used[key] = true
            end
        end
    end
    if s.categories ~= nil then
        if type(s.categories) ~= 'table' then return nil, 'invalid' end
        out.categories = {}
        for cat, c in pairs(s.categories) do
            if type(cat) ~= 'string' or not Config.UI.categories[cat] or type(c) ~= 'table' then return nil, 'invalid' end
            local entry = {}
            if c.color ~= nil and c.color ~= '' then
                if not isHex(c.color) then return nil, 'invalid_color' end
                entry.color = c.color:lower()
            end
            if c.icon ~= nil and c.icon ~= '' then
                if type(c.icon) ~= 'string' or #c.icon > 24 or c.icon:find('[%c<>"\'`]') then return nil, 'invalid' end
                entry.icon = c.icon
            end
            out.categories[cat] = entry
        end
    end
    return out
end

local function merge(base, over)
    local out = U.deepCopy(base)
    for k, v in pairs(over or {}) do
        if type(v) == 'table' and type(out[k]) == 'table' then out[k] = merge(out[k], v) else out[k] = v end
    end
    return out
end

---Config.UI merged with the saved overrides, plus the theme list for the NUI.
function UI.effective()
    if UI.cache then return UI.cache end
    local ui = merge(Config.UI, UI.overrides)
    if not ES.theme(ui.theme) then ui.theme = 'krovix-gilded' end
    ui.keys = UI.keys()
    ui.locale = ES.localeCode()
    ui.locales = ES.availableLocales()
    ui.themes = ES.allThemes()
    ui.extraThemes = nil
    UI.cache = ui
    return ui
end

---Player keys in effect: Config.Commands.keys with the saved overrides (or `over`) on top.
---The events window always has a key.
function UI.keys(over)
    local base = (Config.Commands and Config.Commands.keys) or {}
    over = over or UI.overrides.keys or {}
    local out = {}
    for action in pairs(KEY_ACTIONS) do
        local v = over[action]
        if v == nil then v = base[action] end
        if v == false then out[action] = false else out[action] = UI.cleanKey(v) or false end
    end
    if not out.browser then out.browser = 'F7' end
    return out
end

---The key that opens the events window, for messages such as "press F7 to join".
function UI.menuKey() return UI.keys().browser end

function UI.load()
    local docs = ES.Storage.loadDocuments('setting') or {}
    local saved = docs.ui
    if saved then
        local clean, err = UI.validate(saved)
        if clean then UI.overrides = clean UI.cache = nil ES.localeOverride = clean.locale else Log.warn('Saved UI settings ignored: %s', tostring(err)) end
    end
end

local function broadcast()
    UI.cache = nil
    local before = ES.localeCode()
    ES.localeOverride = UI.overrides.locale
    ES.push(-1, 'ui', UI.effective())
    if ES.localeCode() ~= before then
        -- new language: every player gets the new texts and text direction
        ES.push(-1, 'locale', { strings = ES.uiStrings(), locale = ES.localeInfo() })
    end
end

function UI.save(overrides, actor)
    UI.overrides = overrides
    ES.Storage.saveDocument('setting', 'ui', overrides, actor)
    broadcast()
end

function UI.reset(actor)
    UI.overrides = {}
    ES.Storage.deleteDocument('setting', 'ui')
    broadcast()
end

RPC.register('admin:ui:get', { perm = 'admin.open', rate = { burst = 5, per = 10 } }, function()
    return { effective = UI.effective(), overrides = UI.overrides, base = Config.UI, baseKeys = UI.keys({}), baseLocale = (Config.General and Config.General.locale) or 'en' }
end)

RPC.register('admin:ui:save', { perm = 'ui.edit', schema = { settings = 'table' }, rate = { burst = 4, per = 10 } }, function(src, data)
    local clean, err = UI.validate(data.settings)
    if not clean then return false, err end
    UI.save(clean, Log.actorLabel(src))
    Log.audit('ui.saved', src, nil, { theme = clean.theme, layout = clean.browserLayout })
    return UI.effective()
end)

RPC.register('admin:ui:reset', { perm = 'ui.edit', confirm = true, rate = { burst = 2, per = 10 } }, function(src)
    UI.reset(Log.actorLabel(src))
    Log.audit('ui.reset', src)
    return UI.effective()
end)

return UI
