# Events app for phones and tablets

Players get an **Events** app in their phone or tablet with everything the events window (F7) has: live and open events, upcoming events, the leaderboard, tournaments, and sign up, join, leave and spectate. The app is added automatically when a supported phone is started; there is nothing to install. F7 keeps working.

| Phone / tablet | Resource name | How the app is added |
|---|---|---|
| LB Phone | `lb-phone` | `AddCustomApp` (client) |
| LB Tablet | `lb-tablet` | `AddCustomApp` (client), wide layout |
| Quasar Smartphone PRO | `qs-smartphone-pro` | `addCustomApp` (client) |
| YSeries | `yseries`, `yphone` or `yflip-phone` | `AddCustomApp` (client), all YSeries models |
| 17mov Phone | `17mov_Phone` | `AddApplication` (client) |
| GKSPhone | `gksphone` | `AddCustomApp` (client) |
| NPWD 4 or newer | `npwd` | `RegisterExternalApp` (server) |
| NPWD 3 | `npwd` | not possible: NPWD 3 only loads outside apps built with its own toolchain; players use F7 |
| qb-phone (QBCore default) | `qb-phone` | not possible: qb-phone keeps its apps in its own files; players use F7 |

## Settings (`config/phone.lua`)

```lua
Config.Phone = {
    enabled = true,                    -- false = no app anywhere
    name = 'Events',                   -- app name
    description = 'See events, sign up and join.',
    icon = 'web/img/app-icon.png',     -- a file in this resource or an https:// link
    preinstalled = true,               -- false = players install it from the phone's app store
    devices = { lbPhone = true, lbTablet = true, quasar = true, yseries = true, mov17 = true, gks = true, npwd = true },
}
```

## How it works

- The app is the page `web/phone.html`, shown by the phone in its own frame. It is the same event window as F7, laid out for a phone (a narrow list, swipeable tabs, no close button) or a tablet (the wider list).
- The page talks to Event Studio directly (`phone:init`, `rpc`), and every action goes through the same server checks as F7. The app gives players no new rights.
- Design and colors follow Admin Center → Appearance; the app picks up changes within a few seconds.
- When an event moves the player (start, respawn), LB Phone and LB Tablet are closed automatically. Other phones have no documented close function; players close them as usual.
- A phone started after Event Studio (or restarted) gets the app again automatically.

## Troubleshooting

| Problem | What to check |
|---|---|
| No Events app | The phone's resource name must match the table above. The F8 console prints `could not add the Events app to …` with the phone's reason. `preinstalled = false` means players install it from the phone's app store. |
| The app is empty | Event Studio must be started and the player loaded (the app waits for the server's first answer). |
| Clicks do nothing | Make sure the phone is up to date; very old phone versions may not support outside apps. |
