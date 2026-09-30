#!/bin/bash
# Accept a term as an argument or one line of stdin; output matching JSON Lines.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
term=${1:-}
if [ "$#" -eq 0 ]; then IFS= read -r term || true; fi
exec "$BOOK_MANAGER_ROOT/data/book_database.sh" search "$term"
