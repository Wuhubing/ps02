#!/bin/bash
# Strategy: broaden the reader's usual topics, with an understandable connection.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
exec "$BOOK_MANAGER_ROOT/lib/openai_request.sh" discovery \
    'Explore outside the dominant library and stated interests. Consider history, humanities, natural science or literary fiction instead of more programming, AI or science fiction. Explain a surprising connection that makes each unfamiliar topic worthwhile.' \
    "$@"
