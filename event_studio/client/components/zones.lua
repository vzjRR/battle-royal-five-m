-- EVENT STUDIO — client components: zones (capture / safe zone) and bounds (arena limits)

local U = ES.Util

local Z = { zones = nil, blips = {}, thread = false, activeZone = nil, damage = 0, outsideSince = nil }

local function hexToRgb(hex)
    hex = tostring(hex or '#3dd6ff'):gsub('#', '')
    return tonumber(hex:sub(1, 2), 16) or 61, tonumber(hex:sub(3, 4), 16) or 214, tonumber(hex:sub(5, 6), 16) or 255
end

local function teamColor(owner)
    local cur = ES.Client.current
    if cur and cur.teams and cur.teams[owner] then return cur.teams[owner].color end
    return nil
end

local function clearBlips()
    for _, b in ipairs(Z.blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    Z.blips = {}
end

local function refreshBlips()
    clearBlips()
    if not Z.zones then return end
    for _, z in ipairs(Z.zones.zones) do
        local r = AddBlipForRadius(z.x, z.y, z.z, z.radius)
        SetBlipAlpha(r, 90)
        SetBlipColour(r, Z.zones.safe and 2 or (z.contested and 1 or 3))
        Z.blips[#Z.blips + 1] = r
        if not Z.zones.safe then
            local b = AddBlipForCoord(z.x, z.y, z.z)
            SetBlipSprite(b, 164)
            SetBlipScale(b, 0.8)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(z.label or z.id)
            EndTextCommandSetBlipName(b)
            Z.blips[#Z.blips + 1] = b
        end
    end
end

local function currentRadius(z)
    local s = z.shrink
    if not s then return z.radius, z.x, z.y end
    local t = U.clamp((GetGameTimer() - s.start) / s.durationMs, 0, 1)
    local r = U.lerp(s.from, s.to, t)
    local x, y = z.x, z.y
    if s.toCenter then
        x = U.lerp(s.fromCenter.x, s.toCenter.x, t)
        y = U.lerp(s.fromCenter.y, s.toCenter.y, t)
    end
    if t >= 1 then
        z.radius, z.x, z.y, z.shrink = r, x, y, nil
        refreshBlips()
    end
    return r, x, y
end

local function loop()
    if Z.thread then return end
    Z.thread = true
    CreateThread(function()
        local lastDamage = 0
        while Z.zones do
            local sleep = 250
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local st = ES.Client.current and ES.Client.current.state
            local isParticipant = ES.Client.current and ES.Client.current.role == 'participant'
                and ES.Client.current.you and ES.Client.current.you.status == 'active'
            for _, z in ipairs(Z.zones.zones) do
                local r, x, y = currentRadius(z)
                local dist = #(vector2(pos.x, pos.y) - vector2(x, y))
                if Z.zones.safe then
                    if dist < r + 250.0 then
                        sleep = 0
                        local cr, cg, cb = hexToRgb(Z.zones.color or '#7cff6b')
                        DrawMarker(1, x, y, z.z - 60.0, 0, 0, 0, 0, 0, 0, r * 2, r * 2, 180.0, cr, cg, cb, 40, false, false, 2, false, nil, nil, false)
                    end
                    if isParticipant and st == 'ACTIVE' then
                        if dist > r then
                            Z.outsideSince = Z.outsideSince or GetGameTimer()
                            if Z.damage > 0 and GetGameTimer() - lastDamage >= 1000 then
                                lastDamage = GetGameTimer()
                                ApplyDamageToPed(ped, Z.damage, false)
                            end
                        elseif Z.outsideSince then
                            Z.outsideSince = nil
                        end
                    end
                elseif dist < 200.0 and (not Z.activeZone or Z.activeZone == z.id) then
                    sleep = 0
                    local color = z.owner and teamColor(z.owner) or (z.contested and '#ff3d5e' or (Z.zones.color or '#3dd6ff'))
                    local cr, cg, cb = hexToRgb(color)
                    DrawMarker(1, x, y, z.z - 1.0, 0, 0, 0, 0, 0, 0, r * 2, r * 2, 3.0, cr, cg, cb, 70, false, false, 2, false, nil, nil, false)
                end
            end
            ES.NUI.send('zoneWarning', { outside = Z.outsideSince ~= nil })
            Wait(sleep)
        end
        Z.thread = false
    end)
end

ES.RegisterClientComponent('zones', {
    setup = function(data)
        Z.zones = data
        refreshBlips()
        loop()
        ES.NUI.send('zones', { zones = data.zones, safe = data.safe })
    end,
    update = function(u)
        if not Z.zones then return end
        if u.zone then
            for i, z in ipairs(Z.zones.zones) do
                if z.id == u.zone.id then Z.zones.zones[i] = u.zone end
            end
            refreshBlips()
            ES.NUI.send('zones', { zones = Z.zones.zones })
        end
        if u.shrink then
            for _, z in ipairs(Z.zones.zones) do
                if z.id == u.shrink.id then
                    z.shrink = { from = u.shrink.from, to = u.shrink.to, durationMs = u.shrink.durationMs, start = GetGameTimer(),
                                 fromCenter = u.shrink.fromCenter, toCenter = u.shrink.toCenter }
                end
            end
        end
        if u.progress then ES.NUI.send('zoneProgress', u.progress) end
    end,
    clear = function()
        Z.zones = nil
        Z.outsideSince = nil
        Z.activeZone = nil
        clearBlips()
        ES.NUI.send('zoneWarning', { outside = false })
    end,
})

ES.on('mode', function(d)
    if d.activeZone then Z.activeZone = d.activeZone end
    if d.zoneDamage then Z.damage = d.zoneDamage end
end)

-- Bounds --------------------------------------------------------------------

local B = { data = nil, thread = false, blip = nil }

ES.RegisterClientComponent('bounds', {
    setup = function(data)
        B.data = data
        if B.blip and DoesBlipExist(B.blip) then RemoveBlip(B.blip) end
        B.blip = AddBlipForRadius(data.center.x, data.center.y, data.center.z, data.radius)
        SetBlipColour(B.blip, 1)
        SetBlipAlpha(B.blip, 60)
        if B.thread then return end
        B.thread = true
        CreateThread(function()
            while B.data do
                local d = B.data
                local r = d.radius
                if d.shrink then
                    local t = U.clamp((GetGameTimer() - d.shrink.start) / d.shrink.durationMs, 0, 1)
                    r = U.lerp(d.shrink.from, d.shrink.to, t)
                    if t >= 1 then d.radius, d.shrink = r, nil end
                end
                local pos = GetEntityCoords(PlayerPedId())
                local dist = #(vector2(pos.x, pos.y) - vector2(d.center.x, d.center.y))
                if dist < r + 150.0 then
                    DrawMarker(1, d.center.x, d.center.y, d.center.z - 2.0, 0, 0, 0, 0, 0, 0, r * 2, r * 2, 1.5, 255, 60, 90, 60, false, false, 2, false, nil, nil, false)
                    Wait(0)
                else
                    Wait(500)
                end
            end
            B.thread = false
        end)
    end,
    update = function(u)
        if not B.data then return end
        if u.shrink then B.data.shrink = { from = u.shrink.from, to = u.shrink.to, durationMs = u.shrink.durationMs, start = GetGameTimer() } end
        if u.radius then B.data.radius = u.radius end
        if u.outside ~= nil then ES.NUI.send('boundsWarning', { outside = u.outside, graceMs = u.graceMs }) end
    end,
    clear = function()
        B.data = nil
        if B.blip and DoesBlipExist(B.blip) then RemoveBlip(B.blip) end
        B.blip = nil
        ES.NUI.send('boundsWarning', { outside = false })
    end,
})
