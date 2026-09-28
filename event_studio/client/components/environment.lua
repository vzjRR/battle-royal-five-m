-- EVENT STUDIO — time of day and weather inside an event (definition gameplay.clockHour / gameplay.weather).
-- Applied only for the players in the event, re-applied every second (weather sync resources may reset it) and
-- cleared when they leave.

local active = nil   -- { hour, weather }

local function clear()
    if not active then return end
    active = nil
    NetworkClearClockTimeOverride()
    ClearOverrideWeather()
    ClearWeatherTypePersist()
end

local function loop()
    CreateThread(function()
        while active do
            if active.hour then NetworkOverrideClockTime(active.hour, 0, 0) end
            if active.weather then
                SetWeatherTypeNowPersist(active.weather)
                SetOverrideWeather(active.weather)
            end
            Wait(1000)
        end
    end)
end

ES.on('state', function(snap)
    local g = snap and snap.gameplay
    local inside = snap and (snap.role == 'participant' or snap.role == 'spectator') and snap.state ~= 'ARCHIVED'
    if not inside or not g or (g.clockHour == nil and g.weather == nil) then return clear() end
    local wasActive = active ~= nil
    active = { hour = g.clockHour, weather = g.weather }
    if not wasActive then loop() end
end)

ES.on('left', clear)
AddEventHandler('onResourceStop', function(name) if name == GetCurrentResourceName() then clear() end end)
