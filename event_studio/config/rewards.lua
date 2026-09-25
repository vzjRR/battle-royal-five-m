-- EVENT STUDIO — rewards (server only)
--
-- Reward entry formats used in event definitions:
--   { type = 'cash', amount = 5000 }
--   { type = 'bank', amount = 5000 }
--   { type = 'item', name = 'trophy', count = 1, metadata = {} }
--   { type = 'xp', amount = 100 }                 -- handled by the 'xp' hook below
--   { type = 'command', command = 'givecar {src} adder' }  -- runs as console; {src} {identifier} {name}
--   { type = 'webhook', url = 'https://...' }     -- POSTs JSON describing the payout
--   { type = '<custom>' , ... }                   -- registered via RegisterRewardType
--
-- Definition reward block:
--   rewards = {
--     placement = { [1] = { {type='cash', amount=10000} }, [2] = {...}, [3] = {...} },
--     participation = { {type='cash', amount=500} },
--     winnerTeam = { {type='bank', amount=2500} },   -- each member of the winning team (team events)
--   }

Config.Rewards = {
    enabled = true,
    -- Only players who were active and did not leave/disconnect receive participation rewards.
    requireCompletionForParticipation = true,
    -- Hard safety limits applied to every single reward entry.
    limits = { cash = 250000, bank = 250000, itemCount = 50, xp = 100000 },

    -- Names of framework accounts.
    accounts = { cash = 'cash', bank = 'bank' },   -- ESX uses 'money' for cash; the ESX adapter maps it.

    -- Custom XP integration. Return true on success.
    xp = function(src, amount, context)
        -- Example: exports.my_xp:AddXP(src, amount)
        return false
    end,
}
