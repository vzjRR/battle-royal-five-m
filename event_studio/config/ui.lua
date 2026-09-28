-- EVENT STUDIO — UI / branding (shared)
-- Everything here is the starting point. Staff with the 'ui.edit' permission can change the theme, layout,
-- colors and branding live from the Admin Center (Settings). Those changes are saved and override this file;
-- "Reset to config" in the Admin Center goes back to what is written here.

Config.UI = {
    -- Design: an id from shared/themes.lua — krovix-gilded | krovix-sapphire | krovix-obsidian | krovix-emerald |
    -- krovix-crimson | krovix-arctic | classic | light
    theme = 'krovix-gilded',

    -- Player event window (F7): 'compact' (small window in the middle) | 'docked' (panel on the right edge) | 'full' (large window)
    browserLayout = 'compact',
    -- Docked layout only: players can keep driving/walking while the window is open (mouse still shows).
    browserKeepMoving = false,

    brand = {
        title = 'Event Studio',       -- shown in the window headers; set to your community name
        subtitle = 'Community Events',
        logo = 'auto',                -- 'auto' = the theme's logo | false = initials | 'img/logo.png' (in web/) | https:// URL
    },

    -- Color overrides. Leave nil to use the theme's colors. Any CSS color: '#d4b26a', 'rgb(212,178,106)'.
    colors = {
        accent = nil,        -- buttons, active tabs, highlights
        accent2 = nil,       -- secondary highlight (gradients, charts)
        background = nil,    -- window background
        panel = nil,         -- cards and boxes
        text = nil,          -- main text
        good = nil, warn = nil, bad = nil,   -- status colors (open/live, starting, full/errors)
    },

    -- Panel background artwork: 'auto' = the theme's artwork | false = none | 'img/art/my.svg' | https:// URL
    artwork = 'auto',

    hudPosition = 'top-right',        -- top-right | top-left
    scoreboardHz = 1,                 -- max scoreboard pushes per second per instance
    scoreboardRows = 5,               -- rows shown in the compact HUD scoreboard
    markers = { drawDistance = 250.0, nextCount = 2 },
    dateFormat = 'en-GB',             -- Intl locale for dates in the NUI
    hour12 = false,

    -- Category icon + color. Icons are names from the built-in set (web/js/icons.js):
    -- flag car crosshair target shield compass mountain dice trophy anchor bolt star question users
    -- (an emoji or short text also works).
    categories = {
        racing = { icon = 'flag', color = '#ff6b3d' },
        vehicle = { icon = 'car', color = '#ffb020' },
        combat = { icon = 'crosshair', color = '#ff3d71' },
        objective = { icon = 'target', color = '#3dd6ff' },
        survival = { icon = 'shield', color = '#7cff6b' },
        hunt = { icon = 'compass', color = '#c36bff' },
        obstacle = { icon = 'mountain', color = '#6b8cff' },
        social = { icon = 'dice', color = '#ff6bd6' },
        tournament = { icon = 'trophy', color = '#ffd23d' },
    },

    -- Your own themes: { id = 'mytheme', name = 'My Theme', file = 'mytheme', shape = 'round', title = 'plain',
    --                    logo = false, art = false, preview = { '#000000', '#111111', '#ff0000', '#ffffff' } }
    extraThemes = {},
}
