#!/bin/bash
# Render workflow progress as it arrives, then offer a recommendation to save.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

recommendations_progress() {
    local line color
    while IFS= read -r line; do
        case "$line" in *': done') color=82 ;; *': running') color=212 ;; *) color=214 ;; esac
        gum style --foreground "$color" "$line" >&2
    done
}

recommendations_screen() {
    local interests results book result_code
    interests=$(gum input --prompt 'Interests: ' --value "$DEFAULT_INTERESTS") || return 0
    [ -n "$interests" ] || interests=$DEFAULT_INTERESTS
    UI_TEMP=$(mktemp -d) || return 0
    "$BOOK_MANAGER_ROOT/workflows/get_recommendations.sh" "$interests" \
        > "$UI_TEMP/results" 2> >(recommendations_progress) &
    UI_CHILD=$!
    if wait "$UI_CHILD"; then result_code=0; else result_code=$?; fi
    UI_CHILD=''
    results=$(cat "$UI_TEMP/results")
    rm -rf "$UI_TEMP"
    UI_TEMP=''
    [ "$result_code" -eq 0 ] || return 0
    if [ -z "$results" ]; then printf 'No new recommendations this time. Try different interests.\n'; return 0; fi
    printf '%s\n' "$results" | jq -r '"\n[\(.source)] \(.title) — \(.author)\n\(.reason)"'
    gum confirm 'Choose a recommendation to add to your reading list?' || return 0
    book=$(choose_book "$results" 'Choose a recommendation') || return 0
    library_add "$book"
}
