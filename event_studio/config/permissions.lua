-- EVENT STUDIO — permissions (server only)
--
-- Roles are levels. A player has the highest role any source grants:
--   ACE:        add_ace group.admin eventstudio.admin allow     (object = aceprefix .. role)
--   Framework:  groups listed under `framework` (ESX group / QBCore permission / Qbox group)
-- Console always counts as admin.

Config.Permissions = {
    sources = { ace = true, framework = true },
    acePrefix = 'eventstudio.',

    roles = {
        host = { level = 10, framework = {} },
        moderator = { level = 20, framework = { 'mod', 'moderator' } },
        manager = { level = 30, framework = {} },
        admin = { level = 40, framework = { 'admin', 'superadmin', 'god' } },
    },

    -- Minimum role for each action.
    actions = {
        ['admin.open'] = 'host',
        ['logs.view'] = 'moderator',

        ['definition.view'] = 'host',
        ['definition.edit'] = 'manager',
        ['definition.delete'] = 'admin',
        ['arena.edit'] = 'manager',

        ['schedule.view'] = 'host',
        ['schedule.edit'] = 'manager',
        ['director.toggle'] = 'manager',

        ['instance.create'] = 'host',
        ['instance.start'] = 'host',
        ['instance.pause'] = 'host',
        ['instance.stop'] = 'moderator',       -- force finish
        ['instance.cancel'] = 'moderator',
        ['instance.restart'] = 'moderator',
        ['instance.announce'] = 'host',
        ['instance.manualScore'] = 'moderator',

        ['player.add'] = 'host',
        ['player.remove'] = 'host',
        ['player.teleport'] = 'moderator',
        ['player.reset'] = 'host',
        ['player.disqualify'] = 'moderator',
        ['player.reward'] = 'admin',           -- manual extra reward

        ['spectate.any'] = 'host',
        ['tournament.edit'] = 'manager',
        ['debug'] = 'admin',
        ['ui.edit'] = 'admin',            -- theme, layout, colors, branding (Admin Center → Settings)
    },

    cacheSeconds = 30,
}
