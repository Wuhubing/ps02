#!/bin/bash
# Library interaction only. Every operation goes through the library workflow.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

library_action() { "$BOOK_MANAGER_ROOT/workflows/manage_library.sh" "$@"; }

show_book() {
    local text
    text=$(printf '%s\n' "$1" | jq -r '
        "\(.title) — \(.author)\nGenre: \(.genre)\nStatus: \(.status)\nRating: "
        + (if .rating == "" then "unrated" else .rating + "/5" end)
        + (if .link == "" then "" else "\n\(.link)" end)')
    gum style --border rounded --padding '1 2' "$text"
}

show_books() {
    if [ -z "$1" ]; then printf 'No books found.\n'; return; fi
    printf '%s\n' "$1" | jq -r '
        "• \(.title) — \(.author) [\(.status)]"
        + (if .rating == "" then "" else " ★\(.rating)" end)'
}

# Numbered labels are display-only; retrieve the selected original JSON object.
choose_book() {
    local books=$1 header=$2 choice index
    choice=$(printf '%s\n' "$books" | jq -sr '
        to_entries[] | "\(.key + 1). \(.value.title) — \(.value.author)"' |
        gum choose --header "$header") || return 1
    index=${choice%%.*}
    printf '%s\n' "$books" | jq -sc --argjson index "$index" '.[$index - 1]'
}

choose_status() { gum choose --header 'Reading status' --selected "${1:-want_to_read}" owned want_to_read reading finished; }
choose_rating() {
    local selected=${1:-Unrated} rating
    rating=$(gum choose --header 'Your rating' --selected "$selected" Unrated 1 2 3 4 5) || return 1
    if [ "$rating" != 'Unrated' ]; then printf '%s\n' "$rating"; fi
}

library_browse() {
    local books book
    books=$(library_action list) || return 0
    show_books "$books"
    [ -n "$books" ] || return 0
    book=$(choose_book "$books" 'Select a book for details (Esc to return)') || return 0
    show_book "$book"
}

library_search() {
    local term books
    term=$(gum input --prompt 'Search title, author or genre: ') || return 0
    books=$(library_action search "$term") || return 0
    show_books "$books"
}

# Optional seed is a recommendation object. It still goes through metadata review.
library_add() {
    local seed=${1:-'{}'} title author matches selection index book genre link status rating saved
    title=$(gum input --prompt 'Title: ' --value "$(printf '%s' "$seed" | jq -r '.title // ""')") || return 0
    [ -n "$title" ] || { printf 'Title is required.\n' >&2; return 0; }
    author=$(gum input --prompt 'Author (optional for lookup): ' --value "$(printf '%s' "$seed" | jq -r '.author // ""')") || return 0
    printf 'Looking up book information...\n' >&2
    matches=$(library_action lookup "$title" "$author") || matches=''
    book=$(jq -n --arg title "$title" --arg author "$author" '{title:$title, author:$author, genre:"", link:""}')
    if [ -n "$matches" ]; then
        selection=$({ printf '%s\n' "$matches" | jq -sr '
            to_entries[] | "\(.key + 1). \(.value.title) — \(.value.author)"';
            printf 'Enter manually\n'; } | gum choose --header 'Choose a matching book') || return 0
        if [ "$selection" != 'Enter manually' ]; then
            index=${selection%%.*}
            book=$(printf '%s\n' "$matches" | jq -sc --argjson index "$index" '.[$index - 1]')
        fi
    else
        printf 'No online match selected. Enter the book details below.\n' >&2
    fi
    title=$(gum input --prompt 'Confirm title: ' --value "$(printf '%s' "$book" | jq -r '.title')") || return 0
    author=$(gum input --prompt 'Confirm author: ' --value "$(printf '%s' "$book" | jq -r '.author')") || return 0
    genre=$(gum input --prompt 'Genre: ' --value "$(printf '%s' "$book" | jq -r '.genre')") || return 0
    link=$(gum input --prompt 'Link (optional): ' --value "$(printf '%s' "$book" | jq -r '.link')") || return 0
    status=$(choose_status want_to_read) || return 0
    rating=$(choose_rating) || return 0
    book=$(jq -n --arg title "$title" --arg author "$author" --arg genre "$genre" \
        --arg link "$link" --arg status "$status" --arg rating "$rating" \
        '{title:$title, author:$author, genre:$genre, status:$status, rating:$rating, link:$link}')
    show_book "$book"
    gum confirm 'Save this book?' || return 0
    saved=$(printf '%s\n' "$book" | library_action add) || return 0
    printf 'Saved to your library.\n'
    show_book "$saved"
}

library_update() {
    local books book title author status rating patch saved
    books=$(library_action list) || return 0
    if [ -z "$books" ]; then printf 'Your library is empty. Add a book first.\n'; return 0; fi
    book=$(choose_book "$books" 'Choose a book to update') || return 0
    title=$(printf '%s' "$book" | jq -r '.title')
    author=$(printf '%s' "$book" | jq -r '.author')
    status=$(choose_status "$(printf '%s' "$book" | jq -r '.status')") || return 0
    rating=$(choose_rating "$(printf '%s' "$book" | jq -r '.rating')") || return 0
    patch=$(jq -n --arg status "$status" --arg rating "$rating" '{status:$status,rating:$rating}')
    gum confirm 'Save this status and rating?' || return 0
    saved=$(printf '%s\n' "$patch" | library_action update "$title" "$author") || return 0
    printf 'Updated.\n'
    show_book "$saved"
}
