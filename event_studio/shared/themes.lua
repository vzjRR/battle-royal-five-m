-- EVENT STUDIO — UI theme registry (shared). One entry per web/themes/<file>.css.
-- The Admin Center lists these; the server only accepts ids from this table.
-- To add your own theme: copy a CSS file in web/themes/, then add an entry below (or in config/ui.lua via Config.UI.extraThemes).
--
--   file     CSS file name in web/themes/ (without .css)
--   shape    'round' (rounded corners) | 'cut' (chamfered corners)
--   title    'metal' (gradient display titles) | 'plain'
--   logo     default logo when Config.UI.brand.logo = 'auto' (path relative to web/)
--   art      panel background artwork (path relative to web/), false for none
--   preview  four colors shown in the theme picker: background, panel, accent, accent 2

ES.Themes = {
    { id = 'krovix-gilded', name = 'Krovix Gilded', file = 'krovix-gilded', shape = 'round', title = 'metal',
      logo = 'img/krovix-mark.png', art = 'img/art/gilded.svg', preview = { '#05080F', '#0E1A2E', '#D4B26A', '#F1DDA6' } },
    { id = 'krovix-sapphire', name = 'Krovix Sapphire', file = 'krovix-sapphire', shape = 'round', title = 'plain',
      logo = 'img/krovix-badge.png', art = 'img/art/sapphire.svg', preview = { '#06142B', '#0E2C52', '#3FB6C9', '#D9B870' } },
    { id = 'krovix-obsidian', name = 'Krovix Obsidian', file = 'krovix-obsidian', shape = 'cut', title = 'plain',
      logo = 'img/krovix-mark.png', art = 'img/art/grid.svg', preview = { '#05070A', '#0B0F16', '#C9A96A', '#E3C98F' } },
    { id = 'krovix-emerald', name = 'Krovix Emerald', file = 'krovix-emerald', shape = 'round', title = 'metal',
      logo = 'img/krovix-mark.png', art = 'img/art/gilded.svg', preview = { '#04100C', '#0B2019', '#D4B26A', '#5FD39A' } },
    { id = 'krovix-crimson', name = 'Krovix Crimson', file = 'krovix-crimson', shape = 'cut', title = 'plain',
      logo = 'img/krovix-mark.png', art = 'img/art/grid.svg', preview = { '#0C0507', '#1A0C10', '#E0484F', '#F2B45A' } },
    { id = 'krovix-arctic', name = 'Krovix Arctic', file = 'krovix-arctic', shape = 'round', title = 'plain',
      logo = 'img/krovix-badge.png', art = 'img/art/sapphire.svg', preview = { '#EEF3F8', '#FFFFFF', '#1D4E89', '#B8913F' } },
    { id = 'classic', name = 'Classic', file = 'classic', shape = 'round', title = 'plain',
      logo = false, art = false, preview = { '#0C0E14', '#161922', '#7C5CFF', '#3DD6FF' } },
    { id = 'light', name = 'Light', file = 'light', shape = 'round', title = 'plain',
      logo = false, art = false, preview = { '#F4F6FA', '#FFFFFF', '#5B3DF5', '#0FA3C8' } },
}

---Theme entry by id (includes Config.UI.extraThemes).
function ES.theme(id)
    for _, t in ipairs(ES.allThemes()) do if t.id == id then return t end end
end

function ES.allThemes()
    local list = {}
    for _, t in ipairs(ES.Themes) do list[#list + 1] = t end
    for _, t in ipairs((Config.UI and Config.UI.extraThemes) or {}) do list[#list + 1] = t end
    return list
end
