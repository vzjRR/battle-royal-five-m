-- EVENT STUDIO — buyer hooks (server). This file is meant to be edited (escrow-ignored).
-- Return values are documented per hook. Keep these fast: they run inside engine calls.

ES.Hooks = ES.Hooks or {}

---Extra join validation. Return false, 'reason' to block (reason is shown via locale key 'err_<reason>' if present).
---@param src number
---@param inst table Instance (read-only use recommended)
ES.Hooks.canJoin = function(src, inst)
    -- Example: block players who are handcuffed in your framework
    -- if Player(src).state.isCuffed then return false, 'blocked' end
    return true
end

-- Example custom reward type:
-- ES.Rewards.registerType('vip_days', function(src, reward, ctx)
--     return exports.my_vip:AddDays(src, reward.days or 1)
-- end)

-- Example custom announcement output (phone app, etc.):
-- ES.Announce.registerOutput('phone', function(target, text, kind)
--     TriggerClientEvent('myphone:notify', target, { app = 'events', text = text })
-- end)
