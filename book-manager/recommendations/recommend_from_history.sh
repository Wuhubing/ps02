#!/bin/bash
# Strategy: use reading history and ratings; keep HTTP mechanics in the adapter.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
exec "$BOOK_MANAGER_ROOT/lib/openai_request.sh" history \
    'Prioritize patterns in finished and highly rated books, then saved books. Avoid themes of low-rated books. If the library is empty, use programming, AI and science fiction as starting preferences and say this is a starting suggestion.' \
    "$@"
