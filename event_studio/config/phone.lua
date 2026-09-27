-- EVENT STUDIO — "Events" app for phones and tablets
--
-- When one of these resources is started, players get an "Events" app with everything the events window (F7) has:
-- live & open events, upcoming, leaderboard, tournaments, sign up, join, leave and spectate.
-- Nothing to install: the app is added automatically. F7 keeps working as well.

Config.Phone = {
    enabled = true,                    -- false = no app in any phone or tablet

    name = 'Events',                   -- app name on the phone
    description = 'See events, sign up and join.',
    icon = 'web/img/app-icon.png',     -- a file in this resource, or an https:// link
    preinstalled = true,               -- true = on every phone already; false = players install it from the phone's app store

    devices = {                        -- turn off a single phone or tablet here
        lbPhone = true,                -- LB Phone (lb-phone)
        lbTablet = true,               -- LB Tablet (lb-tablet)
        quasar = true,                 -- Quasar Smartphone PRO (qs-smartphone-pro)
        yseries = true,                -- YSeries (yseries, yphone, yflip-phone)
        mov17 = true,                  -- 17mov Phone (17mov_Phone)
        gks = true,                    -- GKSPhone (gksphone)
        npwd = true,                   -- NPWD 4 or newer (npwd); NPWD 3 cannot load outside apps this way
    },
    -- qb-phone (QBCore's default phone) has no way for another resource to add an app: players use F7 there.
}
