#!/bin/bash
# Shared path and defaults only; no application logic or storage access.
BOOK_MANAGER_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DEFAULT_INTERESTS='programming, AI, science fiction'

# Environment wins; otherwise use a local, gitignored one-line key file.
load_openai_key() {
    local key_file=${OPENAI_KEY_FILE:-"$BOOK_MANAGER_ROOT/token.txt"}
    if [ -z "${OPENAI_API_KEY:-}" ] && [ -f "$key_file" ]; then
        OPENAI_API_KEY=$(tr -d '\r\n' < "$key_file")
        export OPENAI_API_KEY
    fi
}
