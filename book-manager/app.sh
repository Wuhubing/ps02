#!/bin/bash
# Entry point: check dependencies and launch the UI from any directory.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
for dependency in gum curl jq python3; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        printf 'Missing dependency: %s. See the README installation steps.\n' "$dependency" >&2
        exit 1
    fi
done
exec "$ROOT/ui/main_menu.sh"
