-- EVENT STUDIO — persistence (server only)

Config.Database = {
    -- 'auto' (oxmysql if started, else kvp) | 'oxmysql' | 'kvp' | 'none'
    adapter = 'auto',
    runMigrations = true,
    logRetentionDays = 30,
    kvpLogLimit = 500,           -- logs kept when using the kvp adapter
    leaderboardCacheSeconds = 60,
}
