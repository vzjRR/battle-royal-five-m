-- EVENT STUDIO — Discord webhooks (server only, optional)
-- Leave a webhook empty ('') to disable that channel.

Config.Discord = {
    enabled = false,
    username = 'Event Studio',
    avatar = nil,
    webhooks = {
        lifecycle = '',   -- created, scheduled, started, ended, cancelled
        results = '',     -- winner / top 3 / rewards
        players = '',     -- joined / left (noisy)
        admin = '',       -- admin actions (audit)
        security = '',    -- security violations
    },
    -- Which log actions go to which webhook
    routes = {
        ['instance.created'] = 'lifecycle', ['instance.state'] = 'lifecycle', ['schedule.created'] = 'lifecycle',
        ['instance.results'] = 'results', ['reward.paid'] = 'results',
        ['player.joined'] = 'players', ['player.left'] = 'players',
        audit = 'admin', security = 'security',
    },
    minIntervalMs = 1200,  -- per-webhook send spacing (Discord rate limits)
}
