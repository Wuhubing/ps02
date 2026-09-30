#!/bin/bash
# Top-level terminal interaction; screens delegate all work to workflows.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/library_screen.sh"
source "$(dirname "${BASH_SOURCE[0]}")/recommendations_screen.sh"
UI_CHILD=''
UI_TEMP=''
ui_cleanup() {
    if [ -n "$UI_CHILD" ]; then kill "$UI_CHILD" 2>/dev/null || true; wait "$UI_CHILD" 2>/dev/null || true; fi
    if [ -n "$UI_TEMP" ]; then rm -rf "$UI_TEMP"; fi
}
trap ui_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

gum style --border rounded --padding '1 3' --foreground 212 'TECH & SCI-FI BOOKS' 'Read deeply. Explore widely.'
while :; do
    action=$(gum choose --header 'Your personal reading desk' \
        'Browse Library' 'Add Book' 'Search Library' 'Update Status / Rating' 'Get Recommendations' 'Quit') || break
    case "$action" in
        'Browse Library') library_browse ;;
        'Add Book') library_add ;;
        'Search Library') library_search ;;
        'Update Status / Rating') library_update ;;
        'Get Recommendations') recommendations_screen ;;
        'Quit') break ;;
    esac
    gum input --prompt 'Press Enter to return to the menu ' --placeholder '' >/dev/null || break
done
printf 'Happy reading!\n'
