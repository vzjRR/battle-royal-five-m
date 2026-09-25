-- EVENT STUDIO — framework integration (server + client)

Config.Framework = {
    -- 'auto' | 'standalone' | 'esx' | 'qbcore' | 'qbox'
    adapter = 'auto',

    -- Items: 'auto' (ox_inventory if started, else framework) | 'ox_inventory' | 'framework' | 'none'
    inventory = 'auto',

    -- Identifier used for stats in standalone mode (first match wins).
    standaloneIdentifiers = { 'license', 'license2', 'fivem', 'discord', 'steam' },

    -- Use the framework character identifier (citizenid / ESX identifier) for stats instead of the license.
    useCharacterIdentifier = true,

    -- Resource names, only change if you renamed them.
    resources = {
        esx = 'es_extended', qbcore = 'qb-core', qbox = 'qbx_core', ox_inventory = 'ox_inventory',
    },
}
