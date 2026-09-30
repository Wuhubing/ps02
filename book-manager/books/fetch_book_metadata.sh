#!/bin/bash
# Look up a title and optional author; emit up to five metadata objects.
set -uo pipefail
title=${1:-}
author=${2:-}
if [ -z "$title" ]; then printf 'A title is required.\n' >&2; exit 2; fi
temporary=$(mktemp -d) || exit 1
child=''
cleanup() {
    if [ -n "$child" ]; then kill "$child" 2>/dev/null || true; wait "$child" 2>/dev/null || true; fi
    rm -rf "$temporary"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
query=(--data-urlencode "title=$title")
if [ -n "$author" ]; then query+=(--data-urlencode "author=$author"); fi
curl --silent --show-error --fail --connect-timeout 5 --max-time 15 \
    --user-agent 'TechSciFiBookManager/1.0 (student CLI project)' \
    --get 'https://openlibrary.org/search.json' "${query[@]}" \
    --data-urlencode 'fields=key,title,author_name,subject' --data-urlencode 'limit=5' \
    --output "$temporary/response" 2> "$temporary/error" &
child=$!
if ! wait "$child"; then
    child=''
    printf 'Book lookup unavailable. You can enter the details manually.\n' >&2
    exit 1
fi
child=''
if ! jq -c '
    def clean: gsub("[[:cntrl:]]"; " ");
    def genre:
        (.subject // []) as $topics
        | if any($topics[]; test("science fiction"; "i")) then "Science Fiction"
          elif any($topics[]; test("artificial intelligence"; "i")) then "AI"
          elif any($topics[]; test("programming"; "i")) then "Programming"
          else $topics[0] // "" end;
    if (.docs | type) != "array" then error("Missing search results") else .docs[:5][] end
    | select((.title | type) == "string")
    | {title: (.title | clean), author: ((.author_name[0] // "") | clean),
       genre: (genre | clean),
       link: (if (.key // "" | test("^/works/[A-Za-z0-9]+$"))
              then "https://openlibrary.org" + .key else "" end)}
    ' "$temporary/response" > "$temporary/books" 2>/dev/null; then
    printf 'Book lookup returned invalid data. You can enter the details manually.\n' >&2
    exit 1
fi
cat "$temporary/books"
