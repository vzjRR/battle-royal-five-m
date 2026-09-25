fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'event_studio'
author 'Krovix Store'
description 'EVENT STUDIO — event & competition platform for FiveM'
version '0.1.0-alpha'

dependencies {
    '/onesync',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/*.css',
    'web/themes/*.css',
    'web/js/*.js',
    'web/js/admin/*.js',
    'web/img/*',
}

shared_scripts {
    'shared/init.lua',
    'shared/util.lua',
    'shared/lifecycle.lua',
    'shared/schema.lua',
    'shared/locale.lua',
    'locales/*.lua',
    'config/general.lua',
    'config/commands.lua',
    'config/ui.lua',
    'config/scoring.lua',
    'config/framework.lua',
}

server_scripts {
    -- server-only configuration (never sent to clients)
    'config/permissions.lua',
    'config/database.lua',
    'config/rewards.lua',
    'config/notifications.lua',
    'config/discord.lua',
    'config/scheduler.lua',
    'config/director.lua',
    'config/trivia.lua',
    'config/arenas/*.lua',
    'config/events/*.lua',

    -- framework adapters
    'integrations/framework/standalone/server.lua',
    'integrations/framework/esx/server.lua',
    'integrations/framework/qbcore/server.lua',
    'integrations/framework/qbox/server.lua',

    -- engine
    'server/core/log.lua',
    'server/core/storage.lua',
    'server/core/bridge.lua',
    'server/core/permissions.lua',
    'server/core/rpc.lua',
    'server/core/registry.lua',
    'server/core/arenas.lua',
    'server/core/definitions.lua',
    'server/core/buckets.lua',
    'server/core/scoring.lua',
    'server/core/instance.lua',
    'server/core/participants.lua',
    'server/core/results.lua',
    'server/core/manager.lua',
    'server/core/rewards.lua',
    'server/core/stats.lua',
    'server/core/announce.lua',
    'server/core/discord.lua',
    'server/core/scheduler.lua',
    'server/core/director.lua',
    'server/core/tournament.lua',
    'server/core/player.lua',
    'server/core/admin.lua',
    'server/core/api.lua',
    'server/core/commands.lua',

    -- components & modes
    'server/components/*.lua',
    'modes/*/server.lua',

    'integrations/custom/hooks.lua',
    'server/main.lua',
}

client_scripts {
    'client/core/rpc.lua',
    'client/core/nui.lua',
    'client/core/state.lua',
    'client/core/world.lua',
    'integrations/custom/client_hooks.lua',
    'integrations/framework/client.lua',
    'client/components/*.lua',
    'modes/*/client.lua',
    'client/main.lua',
}

-- Files a buyer is expected to edit stay readable if the resource is escrowed.
escrow_ignore {
    'config/*.lua',
    'config/**/*.lua',
    'locales/*.lua',
    'integrations/custom/*.lua',
    'web/themes/*.css',
    'migrations/*.sql',
}
