-- Locales: every translation uses only known keys and keeps the English placeholders in the same order.
local H = T
H.boot()

local function placeholders(s)
    local out = {}
    for spec in tostring(s):gmatch('%%[%-%d%.]*[sdif]') do out[#out + 1] = spec:sub(-1) end
    return table.concat(out, ',')
end

H.test('every locale only uses English keys with matching placeholders', function()
    local en = ES.Locales.en
    local n = 0
    for code, strings in pairs(ES.Locales) do
        if code ~= 'en' then
            n = n + 1
            for k, v in pairs(strings) do
                if k:sub(1, 1) ~= '_' then
                    H.ok(en[k] ~= nil, ('%s: unknown key %s'):format(code, k))
                    H.eq(placeholders(v), placeholders(en[k]), ('%s.%s placeholders'):format(code, k))
                end
            end
        end
    end
    H.ok(n >= 1, 'at least one translation is shipped')
end)

H.test('arabic covers every English key and is right-to-left', function()
    local missing = {}
    for k in pairs(ES.Locales.en) do if not ES.Locales.ar[k] then missing[#missing + 1] = k end end
    table.sort(missing)
    H.eq(#missing, 0, 'missing: ' .. table.concat(missing, ', '))
    local prev = Config.General.locale
    Config.General.locale = 'ar'
    local info = ES.localeInfo()
    H.eq(info.dir, 'rtl')
    H.eq(L('announce_round', 2, 5), 'الجولة 2 من 5')
    H.ok(ES.uiStrings().join == 'انضمام', 'NUI strings follow the locale')
    Config.General.locale = prev
    H.eq(ES.localeInfo().dir, 'ltr')
end)

H.test('client:ready tells the NUI the text direction', function()
    local src = H.players(1, 900)[1]
    local ok, res = H.rpc(src, 'client:ready', {})
    H.ok(ok)
    H.eq(res.locale.code, 'en')
    H.eq(res.locale.dir, 'ltr')
end)
