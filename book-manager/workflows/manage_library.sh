#!/bin/bash
# Route library actions. UI owns prompts; components own lookups and storage.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
action=${1:-}
if [ "$#" -gt 0 ]; then shift; fi
case "$action" in
    list|add|update|exists) exec "$BOOK_MANAGER_ROOT/data/book_database.sh" "$action" "$@" ;;
    search) exec "$BOOK_MANAGER_ROOT/books/search_books.sh" "$@" ;;
    lookup) exec "$BOOK_MANAGER_ROOT/books/fetch_book_metadata.sh" "$@" ;;
    *) printf 'Usage: manage_library.sh list|add|update|exists|search|lookup [arguments]\n' >&2; exit 2 ;;
esac
