-- EVENT STUDIO — announcements (server only)
-- outputs: 'nui' (banner/toast), 'chat' (chat resource), 'notify' (framework notify), 'discord'

Config.Notifications = {
    -- Server-wide announcements (everyone online)
    global = {
        registrationOpen = { 'nui', 'chat' },
        startingSoon = { 'nui' },          -- sent `startingSoonSeconds` before registration closes
        started = { 'nui' },
        winner = { 'nui', 'chat' },
        cancelled = { 'nui' },
    },
    -- Instance announcements (participants + spectators)
    instance = {
        halfway = { 'nui' },
        finalMinute = { 'nui' },
        eliminated = { 'nui' },
        results = { 'nui' },
    },
    startingSoonSeconds = 30,
    chatPrefix = '^5[Events]^7',
}
