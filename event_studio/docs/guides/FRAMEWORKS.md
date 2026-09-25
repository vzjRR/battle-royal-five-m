# Framework integration

`Config.Framework.adapter = 'auto'` detects, in order: **Qbox** (`qbx_core`) → **QBCore** (`qb-core`) → **ESX** (`es_extended`) → **standalone**.

| Feature | Standalone | ESX | QBCore | Qbox |
|---|---|---|---|---|
| Identifier for stats | license | `xPlayer.identifier` | `citizenid` | `citizenid` |
| Display name | FiveM name | `xPlayer.getName()` | charinfo | charinfo |
| Staff roles | ACE | ACE + ESX group | ACE + QBCore permission | ACE (recommended by Qbox) |
| Cash / bank rewards | ✗ (use `command` or a custom type) | `addAccountMoney` (`money`/`bank`) | `AddMoney` | `exports.qbx_core:AddMoney` |
| Item rewards | ox_inventory if running | ox_inventory or `addInventoryItem` | ox_inventory or `AddItem` | ox_inventory |
| Notifications | NUI toast | `esx:showNotification` | `QBCore:Notify` | `qbx_core:Notify` |
| Revive after event death | native resurrect | + `esx_ambulancejob:revive` | + `hospital:client:Revive` | + `qbx_medical` event (check your version) |

Reconnect matching and crash-recovery always use the **license** identifier, so they work before a character is loaded.

## Death / ambulance scripts

Ambulance resources react to any death. Inside an event, EVENT STUDIO resurrects the player itself and then calls the adapter's `revive` so the ambulance script's state is cleared. If your server uses a different medical resource, override it here:

```lua
-- integrations/custom/client_hooks.lua
ES.ClientHooks.revive = function()
    TriggerEvent('my_medical:client:revive')
end
```

## Weapons & inventories

- The player's weapons are **snapshotted when they enter** an event and **restored when they leave** (`gameplay.restoreWeapons`).
- With **ox_inventory**, the resource calls `exports.ox_inventory:weaponWheel(true)` and sets `invBusy` for the duration of the event, so native event weapons work and inventory weapons can't be used; both are switched back afterwards.
- For other inventories that remove "unknown" weapons, turn that check off for players whose state bag `es:inEvent` is set, or use the `onEnterEvent`/`onLeaveEvent` hooks.

## Other resources

Every player in an event has the state bag `Player(src).state['es:inEvent']` set to the instance id. Use it to block phones, jobs, `/me` animations and so on:

```lua
if LocalPlayer.state['es:inEvent'] then return end
```

## Writing a new adapter

Copy `integrations/framework/standalone/server.lua`, implement `detect, init, getIdentifier, getName, getGroups, addMoney, addItem, notify`, register it as `ES.Bridges.<name>`, add the file to `fxmanifest.lua` and set `Config.Framework.adapter = '<name>'`.
