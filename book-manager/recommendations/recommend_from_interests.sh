#!/bin/bash
# Strategy: focus on the interests entered for this run.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
exec "$BOOK_MANAGER_ROOT/lib/openai_request.sh" interests \
    'Prioritize the stated interests and learning goals. Include useful programming or AI books and imaginative science fiction when relevant. Explain how each book addresses an interest.' \
    "$@"
