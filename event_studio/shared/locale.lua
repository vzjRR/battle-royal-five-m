-- EVENT STUDIO — localization

ES.Locales = ES.Locales or {}

---Register a locale table: ES.RegisterLocale('en', { key = 'text %s' })
function ES.RegisterLocale(code, strings)
    ES.Locales[code] = ES.Locales[code] or {}
    for k, v in pairs(strings) do ES.Locales[code][k] = v end
end

---Default language: Config.General.locale, else English. On a client, ES.localeOverride is the player's own choice
---(the flag switch in the event window); on the server each player's choice is kept in ES.PlayerLocales.
function ES.localeCode(code)
    code = code or ES.localeOverride or (ES.Config.General and ES.Config.General.locale) or 'en'
    return ES.Locales[code] and code or 'en'
end

---Translate a key in a given language (nil = default). Falls back to English, then to the key.
function ES.translate(code, key, ...)
    local cur, en = ES.Locales[ES.localeCode(code)] or {}, ES.Locales.en or {}
    local s = cur[key] or en[key]
    if not s then return key end
    if select('#', ...) > 0 then
        local ok, res = pcall(string.format, s, ...)
        if ok then return res end
    end
    return s
end

---Translate in the default language (the player's own language on a client).
function L(key, ...) return ES.translate(nil, key, ...) end

---Translate for one player (server): their chosen language, else the default.
function ES.Lp(src, key, ...)
    local code = ES.PlayerLocales and ES.PlayerLocales[tonumber(src) or src]
    return ES.translate(code, key, ...)
end

---A translatable message for the NUI: the text in `code`, plus the key and arguments so each client can show it in
---its own language. Arguments may themselves be { lkey = 'reason_x' } to translate nested words.
function ES.msg(code, key, ...)
    local args = { ... }
    local plain = {}
    for i = 1, select('#', ...) do
        local a = args[i]
        plain[i] = type(a) == 'table' and a.lkey and ES.translate(code, a.lkey) or a
    end
    return { text = ES.translate(code, key, table.unpack(plain, 1, select('#', ...))), lkey = key, largs = args }
end

---Announcement payload for one player (server): { text, kind, lkey, largs } in that player's language.
---`who` is a player id or a participant table with .src.
function ES.say(who, kind, key, ...)
    local src = type(who) == 'table' and who.src or who
    local m = ES.msg(ES.PlayerLocales and ES.PlayerLocales[tonumber(src) or src], key, ...)
    m.kind = kind
    return m
end

local RTL = { ar = true, he = true, fa = true, ur = true }

---Locale code and text direction ('ltr' / 'rtl'). A locale can force a direction with `_dir = 'rtl'`.
function ES.localeInfo(code)
    code = ES.localeCode(code)
    local cur = ES.Locales[code] or {}
    return { code = code, dir = cur._dir or (RTL[code] and 'rtl') or 'ltr' }
end

---All strings whose key starts with 'ui.' for the NUI, in `code` (nil = default).
function ES.uiStrings(code)
    local cur, en = ES.Locales[ES.localeCode(code)] or {}, ES.Locales.en or {}
    local out = {}
    for k, v in pairs(en) do if k:sub(1, 3) == 'ui.' then out[k:sub(4)] = v end end
    for k, v in pairs(cur) do if k:sub(1, 3) == 'ui.' then out[k:sub(4)] = v end end
    return out
end

---Languages players can switch between (the flag switch shows Arabic / English when both are installed).
function ES.availableLocales()
    local out = {}
    for code, strings in pairs(ES.Locales) do out[#out + 1] = { code = code, name = strings._name or code } end
    table.sort(out, function(a, b)
        if a.code == 'en' or b.code == 'en' then return a.code == 'en' end
        return a.code < b.code
    end)
    return out
end
