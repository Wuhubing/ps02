#!/bin/bash
# Fan out with &, track with $!, synchronize with wait, then pipe into refinement.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_openai_key
if [ -z "${OPENAI_API_KEY:-}" ]; then
    printf 'Set OPENAI_API_KEY to enable AI recommendations.\n' >&2
    exit 1
fi
interests=${1:-$DEFAULT_INTERESTS}
temporary=$(mktemp -d) || exit 1
pids=()
names=(history interests discovery)
scripts=(recommend_from_history recommend_from_interests recommend_for_discovery)
finished=(0 0 0)
cleanup() {
    local index pid
    for index in 0 1 2; do
        pid=${pids[$index]:-}
        if [ -n "$pid" ] && [ "${finished[$index]}" -eq 0 ]; then
            kill "$pid" 2>/dev/null || true
        fi
    done
    for index in 0 1 2; do
        pid=${pids[$index]:-}
        if [ -n "$pid" ] && [ "${finished[$index]}" -eq 0 ]; then
            wait "$pid" 2>/dev/null || true
        fi
    done
    rm -rf "$temporary"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
"$BOOK_MANAGER_ROOT/data/book_database.sh" list > "$temporary/library" || exit 1
for i in 0 1 2; do
    "$BOOK_MANAGER_ROOT/recommendations/${scripts[$i]}.sh" "$temporary/library" "$interests" \
        > "$temporary/${names[$i]}" 2> "$temporary/${names[$i]}.error" &
    pids[$i]=$!
    printf '%s: running\n' "${names[$i]}" >&2
done

remaining=3
succeeded=0
while [ "$remaining" -gt 0 ]; do
    for i in 0 1 2; do
        if [ "${finished[$i]}" -eq 0 ] && ! kill -0 "${pids[$i]}" 2>/dev/null; then
            if wait "${pids[$i]}"; then
                succeeded=$((succeeded + 1))
                printf '%s: done\n' "${names[$i]}" >&2
            else
                # Failed agents never contribute partial output to the pipeline.
                : > "$temporary/${names[$i]}"
                printf '%s: failed\n' "${names[$i]}" >&2
                cat "$temporary/${names[$i]}.error" >&2
            fi
            finished[$i]=1
            remaining=$((remaining - 1))
        fi
    done
    if [ "$remaining" -gt 0 ]; then sleep 0.2; fi
done
if [ "$succeeded" -eq 0 ]; then
    printf 'All recommendation strategies failed. Please try again later.\n' >&2
    exit 1
fi
cat "$temporary/history" "$temporary/interests" "$temporary/discovery" |
    "$BOOK_MANAGER_ROOT/recommendations/refine_recommendations.sh"
