# EVENT STUDIO — Development Guide

## 1. Requirements

- FXServer (recent artifact, OneSync enabled) for in-game testing.
- Lua 5.4 CLI for unit/simulation tests (`apt install lua5.4`, `brew install lua`).
- No Node.js needed — the NUI is plain ES modules.

## 2. Repository layout

The resource lives in `event_studio/`. Symlink or copy it into your server's `resources/` folder:

```
ensure oxmysql      # optional
ensure event_studio
```

## 3. Running tests

```
cd event_studio
lua5.4 tests/run.lua            # all unit + simulation tests
lua5.4 tests/run.lua scheduler  # filter by file name
```

Syntax check every Lua file:

```
find . -name '*.lua' -print0 | xargs -0 -n1 luac5.4 -p
```

## 4. Coding conventions

- `lua54 'yes'`; locals everywhere; no globals except the `ES` namespace and adapter tables set by the loader (`Bridge`, `Storage`).
- One responsibility per file; files < ~400 lines.
- Server code never calls framework APIs directly — use `Bridge`.
- No new server `RegisterNetEvent` — add an RPC (`server/core/rpc.lua`).
- All player-facing strings via `L('key', ...)` (Lua) or `t('key')` (NUI).
- Time: `ES.now()` (ms, monotonic, `GetGameTimer`) for durations; `os.time()` for wall clock.
- Every mode hook must tolerate participants disappearing (disconnect) between ticks.
- Keep client loops scoped: start in `onEnter`, stop in `onLeave`.

## 5. Load order (fxmanifest)

1. `shared/*` (namespace, utils, lifecycle, schema, locale) + `locales/*`
2. shared config (`general`, `commands`, `ui`, `scoring`)
3. server: server config → `integrations/framework/*/server.lua` → `server/core/*` in dependency order → `server/components/*` → `modes/*/server.lua` → `integrations/custom/hooks.lua` → `server/main.lua`
4. client: `integrations/framework/*/client.lua` → `client/core/*` → `client/components/*` → `modes/*/client.lua` → `integrations/custom/client_hooks.lua` → `client/main.lua`

## 6. Release build (escrow)

```
python3 tools/build_release.py        # checks + tests + dist/event_studio-<version>.zip
```

The build fails on version mismatch, missing `lua54`, over-broad `escrow_ignore`, secrets in config, forbidden licensing/remote-code/obfuscation patterns, syntax errors or failing tests. Upload the zip in the Cfx.re Portal (Created Assets), then attach it to a Tebex package. See PROTECTION.md §5.

## 7. Versioning & changelog

Semantic versioning starting at `0.1.0-alpha`. Update `CHANGELOG.md` and `fxmanifest.lua` `version` together.

## 7. Git workflow

Feature branches; each PR updates docs touched by the change (docs are part of Done).

## 8. Debugging

- `set es_debug 1` in server.cfg → verbose logs.
- `eventstudio status` / `eventstudio list` (console or admin) print adapter and instance summaries.
- NUI: open with F8 → `nui_devtools` (FiveM client) to inspect.
