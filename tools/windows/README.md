# Updating a local test server (Windows)

For the developer's own test servers. Customers get updates from the Cfx Portal.

## Once

1. Install **Git for Windows**: https://git-scm.com/download/win (all defaults).
2. Open **Command Prompt** and run:
   ```
   git clone -b claude/event-studio-fivem-x11r93 https://github.com/vzjRR/battle-royal-five-m.git C:\event-studio-src
   ```
   Git opens a browser window to sign in to GitHub the first time (the repository is private).
3. Double-click `C:\event-studio-src\tools\windows\update_server.bat`. It asks for:
   - the full path of the `event_studio` folder on your server, e.g. `C:\FiveMServer\txData\QBCore_7D4232.base\resources\[local]\event_studio`
   - optional: an rcon password, so it can restart the resource on the running server by itself. Put `rcon_password "your-password"` in `server.cfg` and restart the server once.

## Every update

- **Once:** double-click `update_server.bat`. It downloads the newest version, copies it to the server and restarts the resource (or tells you to type `ensure event_studio` in the txAdmin console).
- **Automatic:** double-click `watch_server.bat` and leave the window open. Every minute it checks GitHub; each new change is copied to the server and the resource restarts on its own.

Options: `update_server.bat -Setup` (change the saved paths), `-KeepConfig` (keep your own edits in the server's `config` folder), `watch_server.bat -Every 30` (check every 30 seconds).

After a restart of the resource, reconnect to the server if the UI looks stale.
