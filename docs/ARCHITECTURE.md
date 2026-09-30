# Architecture and explanation guide

Every component has one job. UI scripts are sourced by the menu; executable components can also be called independently from a shell. Paths resolve relative to the script, not the caller's current directory.

## File responsibilities

Paths below are relative to `book-manager/`.

| File | Input | Output / responsibility |
| --- | --- | --- |
| `app.sh` | Launch command | Checks dependencies and starts the menu. |
| `ui/main_menu.sh` | Gum menu choice | Dispatches to screens; handles exit and active workflow cleanup. |
| `ui/library_screen.sh` | User text and selections | Library forms, confirmation, lists, and details; calls the library workflow. |
| `ui/recommendations_screen.sh` | Interests and chosen recommendation | Renders progress and results; reuses the add form to save. |
| `workflows/manage_library.sh` | Action plus arguments or stdin | Routes to metadata, search, or data operations. |
| `workflows/get_recommendations.sh` | Optional interests string | Runs agents in parallel, reports progress, pipes results into refinement. |
| `books/fetch_book_metadata.sh` | Title and optional author | Up to five metadata JSON objects from Open Library; no prompts. |
| `books/search_books.sh` | Search term argument or stdin line | Matching library JSON Lines through the database API. |
| `recommendations/recommend_from_history.sh` | Snapshot path and interests | History-oriented prompt and candidates from the common HTTP adapter. |
| `recommendations/recommend_from_interests.sh` | Snapshot path and interests | Current-interest prompt and candidates. |
| `recommendations/recommend_for_discovery.sh` | Snapshot path and interests | Exploratory prompt and candidates outside typical interests. |
| `recommendations/refine_recommendations.sh` | Candidate JSON Lines on stdin | At most six unique, unowned books, rotating among sources. |
| `data/book_database.sh` | Command, arguments, optional JSON stdin | Sole CSV reader/writer; validates and persists records. |
| `data/books.csv` | Managed by the database component | Persistent six-column storage. |
| `lib/common.sh` | Optional environment settings | Shared project root, initial interests, local credential loading. |
| `lib/openai_request.sh` | Source, strategy text, snapshot path, interests | OpenAI request construction, bounded retries, validated candidate output. |

## Data contract

Records exchanged by the library components are JSON objects with six string fields:

```json
{"title":"Dune","author":"Frank Herbert","genre":"Science Fiction","status":"want_to_read","rating":"","link":""}
```

`title` and `author` are required. `status` is `owned`, `want_to_read`, `reading`, or `finished`. `rating` is an empty string or `1`–`5`; the database also accepts an integer rating and normalizes it to a string. Links are empty or HTTP(S). Control characters are rejected to preserve single-line terminal fields. CSV quoting is delegated to Python's `csv` module, not split on commas in Bash.

List and search emit one JSON object per line. Add and update read one JSON object from stdin and emit the saved record. Empty searches/lists succeed with empty stdout. Diagnostics go to stderr. `exists` returns 0 for a match, 1 for no match, and 2 for invalid input or a database error. Other database errors return 2.

From the repository root:

```bash
./book-manager/workflows/manage_library.sh list
./book-manager/books/search_books.sh 'science'
printf 'Frank Herbert\n' | ./book-manager/books/search_books.sh

printf '%s\n' '{"title":"Dune","author":"Frank Herbert","genre":"Science Fiction","status":"want_to_read","rating":"","link":""}' |
  ./book-manager/workflows/manage_library.sh add

printf '%s\n' '{"status":"finished","rating":"5"}' |
  ./book-manager/workflows/manage_library.sh update 'Dune' 'Frank Herbert'

./book-manager/workflows/manage_library.sh exists 'Dune' 'Frank Herbert'
```

`BOOK_DB_PATH=/absolute/path/to/test.csv` selects another database for all components. Test setup and demo data should still be added through the data API rather than editing the file directly.

Recommendation records have five fields:

```json
{"title":"Example","author":"Author","genre":"History","reason":"A useful new perspective.","source":"discovery"}
```

Each agent emits no more than five candidates in preference order. Refinement trims and folds titles/authors for comparison, removes library matches, rotates history → interests → discovery, and keeps the first six unique candidates. It uses no extra model call. Comparison keys are encoded as JSON strings to preserve the boundary between title and author.

## Trace an add operation

1. Main menu calls the library form.
2. The form collects title/author and calls the workflow's `lookup` action.
3. The workflow delegates to the metadata component, which returns data without displaying a menu.
4. The UI lets the user select, edit, and confirm the complete book object. Cancelling any form leaves storage untouched.
5. The UI pipes the object to the workflow's `add` action.
6. The workflow delegates to the data component, which validates, rejects duplicates, writes an atomic replacement, and returns the saved object.
7. The UI displays the saved record.

## Explain the concurrency

The recommendation workflow first obtains a snapshot through `book_database.sh list`. All three agents receive the same snapshot, so they work independently without accessing the CSV. `&` starts each process immediately, `$!` captures its PID, and `wait` collects its exit status. The status loop polls process completion every 0.2 seconds. Completed agents can report `done` while other agents are still `running`.

Each agent writes to a separate temporary result file, so concurrent output cannot interleave. Failed output is cleared before `cat` combines successful files and sends them through `|` to refinement. Status messages use stderr and are styled by the UI. On interrupt, the workflow terminates agents; each agent's HTTP adapter terminates its curl child. Temporary directories are removed on both normal exit and cancellation.

## Why two small shared files?

`common.sh` avoids repeating path resolution and local key loading. `openai_request.sh` avoids duplicating schema construction, HTTP retries, and response validation across the three strategy files. These helpers support the required layers; they do not replace or merge them.
