-- EVENT STUDIO — buyer hooks (client). Meant to be edited (escrow-ignored).

ES.ClientHooks = ES.ClientHooks or {}

---Called once when the local player enters an event world (lobby).
ES.ClientHooks.onEnterEvent = function(snapshot)
    -- Example: close your phone, disable a job HUD
    -- exports['my_phone']:close()
end

---Called when the local player leaves the event world (after teleport back).
ES.ClientHooks.onLeaveEvent = function(data)
end

---Override the framework revive (clear your ambulance/death script state). Leave nil to use the default adapter.
ES.ClientHooks.revive = nil
