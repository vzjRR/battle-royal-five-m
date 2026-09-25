-- EVENT STUDIO — UI / branding (shared)

Config.UI = {
    theme = 'default',               -- file in web/themes/<theme>.css
    brand = {
        title = 'Event Studio',       -- shown in browser/admin header; set to your community name
        subtitle = 'Community Events',
        logo = nil,                   -- optional https:// URL or nui://event_studio/web/img/logo.png
        accent = nil,                 -- optional CSS color override, e.g. '#7c5cff'
    },
    hudPosition = 'top-right',        -- top-right | top-left
    scoreboardHz = 1,                 -- max scoreboard pushes per second per instance
    scoreboardRows = 5,               -- rows shown in the compact HUD scoreboard
    markers = { drawDistance = 250.0, nextCount = 2 },
    dateFormat = 'en-GB',             -- Intl locale for dates in the NUI
    hour12 = false,
    categories = {                    -- icon (emoji or short text) + accent per category
        racing = { icon = '🏁', color = '#ff6b3d' },
        vehicle = { icon = '🚙', color = '#ffb020' },
        combat = { icon = '🎯', color = '#ff3d71' },
        objective = { icon = '🚩', color = '#3dd6ff' },
        survival = { icon = '🛡️', color = '#7cff6b' },
        hunt = { icon = '🧭', color = '#c36bff' },
        obstacle = { icon = '🧗', color = '#6b8cff' },
        social = { icon = '🎲', color = '#ff6bd6' },
        tournament = { icon = '🏆', color = '#ffd23d' },
    },
}
