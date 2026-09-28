-- EVENT STUDIO — localization

ES.Locales = ES.Locales or {}

---Register a locale table: ES.RegisterLocale('en', { key = 'text %s' })
function ES.RegisterLocale(code, strings)
    ES.Locales[code] = ES.Locales[code] or {}
    for k, v in pairs(strings) do ES.Locales[code][k] = v end
end

---Language in effect: the one picked in Admin Center → Appearance (ES.localeOverride, server side), else
---Config.General.locale, else English.
function ES.localeCode()
    local code = ES.localeOverride or (ES.Config.General and ES.Config.General.locale) or 'en'
    return ES.Locales[code] and code or 'en'
end

local function current()
    return ES.Locales[ES.localeCode()] or {}, ES.Locales.en or {}
end

---Installed languages for the language picker: { { code = 'en', name = 'English' }, ... }, English first.
function ES.availableLocales()
    local out = {}
    for code, strings in pairs(ES.Locales) do out[#out + 1] = { code = code, name = strings._name or code } end
    table.sort(out, function(a, b)
        if a.code == 'en' or b.code == 'en' then return a.code == 'en' end
        return a.code < b.code
    end)
    return out
end

---Translate a key with optional string.format arguments. Falls back to English, then to the key.
function L(key, ...)
    local cur, en = current()
    local s = cur[key] or en[key]
    if not s then return key end
    if select('#', ...) > 0 then
        local ok, res = pcall(string.format, s, ...)
        if ok then return res end
    end
    return s
end

local RTL = { ar = true, he = true, fa = true, ur = true }

---Active locale code and text direction ('ltr' / 'rtl'). A locale can force a direction with `_dir = 'rtl'`.
function ES.localeInfo()
    local code = ES.localeCode()
    local cur = ES.Locales[code] or {}
    return { code = code, dir = cur._dir or (RTL[code] and 'rtl') or 'ltr' }
end

---All strings whose key starts with 'ui.' (sent to the NUI once).
function ES.uiStrings()
    local cur, en = current()
    local out = {}
    for k, v in pairs(en) do if k:sub(1, 3) == 'ui.' then out[k:sub(4)] = v end end
    for k, v in pairs(cur) do if k:sub(1, 3) == 'ui.' then out[k:sub(4)] = v end end
    return out
end
