-- EVENT STUDIO — client: mark a player with a blip (bounty target, assassin target, VIP …)
-- Driven by server 'mode' pushes { markPlayer = serverId | false, markLabel = text }.

local mark = { src = nil, label = nil, blip = nil, running = false }

local function clear()
    if mark.blip and DoesBlipExist(mark.blip) then RemoveBlip(mark.blip) end
    mark.blip = nil
end

local function loop()
    if mark.running then return end
    mark.running = true
    CreateThread(function()
        while mark.src and ES.Client.current do
            local player = GetPlayerFromServerId(mark.src)
            local ped = player ~= -1 and GetPlayerPed(player) or 0
            if ped ~= 0 and DoesEntityExist(ped) then
                if not mark.blip or not DoesBlipExist(mark.blip) or GetBlipInfoIdEntityIndex(mark.blip) ~= ped then
                    clear()
                    mark.blip = AddBlipForEntity(ped)
                    SetBlipSprite(mark.blip, 303)
                    SetBlipColour(mark.blip, 1)
                    SetBlipScale(mark.blip, 1.0)
                    BeginTextCommandSetBlipName('STRING')
                    AddTextComponentString(mark.label or 'Target')
                    EndTextCommandSetBlipName(mark.blip)
                end
            else
                clear() -- not streamed in; the HUD still shows the target's name
            end
            Wait(1000)
        end
        clear()
        mark.running = false
    end)
end

ES.on('mode', function(d)
    if d.markPlayer == nil then return end
    clear()
    mark.src = d.markPlayer or nil
    mark.label = d.markLabel
    if mark.src then loop() end
end)

ES.on('left', function()
    mark.src = nil
    clear()
end)
