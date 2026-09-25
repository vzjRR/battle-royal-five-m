-- EVENT STUDIO — Event Director (server only, optional)
-- Automatically starts events when nothing is running.

Config.Director = {
    enabled = false,
    checkEverySeconds = 60,
    minMinutesBetweenEvents = 20,     -- global cooldown after any event ends
    definitionCooldownMinutes = 90,   -- same definition won't repeat within this window
    activeHours = { from = '12:00', to = '02:00' },
    registrationSeconds = 120,

    -- Player-count bands → allowed categories and weights (first matching band wins)
    bands = {
        { min = 1, max = 3, categories = { social = 3, hunt = 2, obstacle = 2, racing = 1 }, maxPlayersAtLeast = 2 },
        { min = 4, max = 7, categories = { racing = 3, vehicle = 2, social = 2, combat = 1 } },
        { min = 8, max = 19, categories = { combat = 3, objective = 3, racing = 2, vehicle = 2 }, preferTeams = true },
        { min = 20, max = 2048, categories = { survival = 3, combat = 2, objective = 2, racing = 1 }, minMaxPlayers = 20 },
    },

    -- Definitions the director may use (empty = all public, enabled definitions)
    pool = {},
    exclude = { 'pistol_duel_cup' },
}
