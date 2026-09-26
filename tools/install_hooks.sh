#!/bin/sh
# Enable the repository's git hooks (automatic HANDOVER.md change log). Run once per clone.
cd "$(dirname "$0")/.." && git config core.hooksPath .githooks && chmod +x .githooks/* && echo "Hooks enabled: .githooks (HANDOVER.md updates itself after every commit)"
