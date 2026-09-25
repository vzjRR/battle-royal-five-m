-- EVENT STUDIO — client component: vehicles (seat fallback, exit lock, ghosting)

local V = { cfg = nil, net = nil, thread = false }

local function vehicleFromNet(net, timeout)
    local t = GetGameTimer()
    while not NetworkDoesNetworkIdExist(net) and GetGameTimer() - t < (timeout or 5000) do Wait(50) end
    if not NetworkDoesNetworkIdExist(net) then return 0 end
    return NetToVeh(net)
end

local function lockLoop()
    if V.thread then return end
    V.thread = true
    CreateThread(function()
        while V.cfg do
            local ped = PlayerPedId()
            if V.cfg.lock and IsPedInAnyVehicle(ped, false) then
                DisableControlAction(0, 75, true)   -- exit vehicle
                DisableControlAction(27, 75, true)
                Wait(0)
            else
                Wait(250)
            end
        end
        SetLocalPlayerAsGhost(false)
        V.thread = false
    end)
end

local function seat(data)
    CreateThread(function()
        -- the vehicle only streams in when we are near its spawn point
        if data.coords then
            local pos = GetEntityCoords(PlayerPedId())
            if #(pos - vector3(data.coords.x, data.coords.y, data.coords.z)) > 50.0 then
                ES.World.teleport(data.coords, data.heading, false)
            end
        end
        local veh = vehicleFromNet(data.net)
        if veh == 0 then return end
        local ped = PlayerPedId()
        local t = GetGameTimer()
        while GetVehiclePedIsIn(ped, false) ~= veh and GetGameTimer() - t < 3000 do
            TaskWarpPedIntoVehicle(ped, veh, -1)
            Wait(150)
        end
        SetVehicleOnGroundProperly(veh)
        SetVehicleEngineOn(veh, true, true, false)
        if ES.World.frozen then FreezeEntityPosition(veh, true) end
    end)
end

ES.RegisterClientComponent('vehicles', {
    setup = function(data)
        V.cfg = data
        if data.ghost then
            SetLocalPlayerAsGhost(true)
            SetGhostedEntityAlpha(180)
        end
        lockLoop()
    end,
    clear = function()
        V.cfg = nil
        V.net = nil
        SetLocalPlayerAsGhost(false)
    end,
})

ES.on('vehicle', function(data)
    V.cfg = V.cfg or { lock = data.lock, ghost = data.ghost }
    V.cfg.lock = data.lock
    V.net = data.net
    if data.ghost then SetLocalPlayerAsGhost(true) SetGhostedEntityAlpha(180) end
    lockLoop()
    seat(data)
end)
