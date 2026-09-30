#!/bin/bash
# Candidate JSON Lines on stdin -> diverse, deduplicated shortlist on stdout.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
library=$("$BOOK_MANAGER_ROOT/data/book_database.sh" list) || exit 1
jq -sc --argjson library "$(printf '%s\n' "$library" | jq -s '.')" '
    def identity: [.title, .author] | map(gsub("^\\s+|\\s+$"; "") | ascii_downcase) | tojson;
    ($library | map(identity)) as $owned
    | map(select((.title | type) == "string" and (.author | type) == "string"
          and (.reason | type) == "string" and (.genre | type) == "string"
          and (.source == "history" or .source == "interests" or .source == "discovery")))
    | map(select((identity as $id | $owned | index($id)) == null)) as $candidates
    | [ ["history", "interests", "discovery"][] as $source
        | [$candidates[] | select(.source == $source)] ] as $groups
    | [range(0; 5) as $rank | $groups[] | .[$rank] // empty]
    | reduce .[] as $book ({seen: [], books: []};
        ($book | identity) as $id
        | if (.seen | index($id)) == null
          then .seen += [$id] | .books += [$book] else . end)
    | .books[:6][]
    '
