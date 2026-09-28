# EVENT STUDIO

A standalone, commercial event & competition platform for FiveM, developed by **vzjRR** and published by **Krovix Team**.

The resource lives in [`event_studio/`](event_studio/). Start with [`event_studio/README.md`](event_studio/README.md).

- Planning: [`docs/MASTER_PLAN.md`](event_studio/docs/MASTER_PLAN.md) · [`docs/RESEARCH.md`](event_studio/docs/RESEARCH.md) · [`docs/EVENT_CATALOG.md`](event_studio/docs/EVENT_CATALOG.md)
- Tests: `cd event_studio && lua5.4 tests/run.lua`
- `tools/gen_catalog.py` regenerates the event catalog from structured data.

## For developers and agents

Start with [HANDOVER.md](HANDOVER.md) (project state, decisions, next steps) and [AGENTS.md](AGENTS.md) (working rules). Run `sh tools/install_hooks.sh` once so the handover change log updates itself.
