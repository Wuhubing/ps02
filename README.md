# Tech & Sci-Fi Book Manager

A small Bash reading desk for programming, AI, science fiction, and discoveries beyond them. Built for PS2 from [onexi/ps02](https://github.com/onexi/ps02).

## Run

On macOS, install the dependencies:

```bash
brew install gum jq python
git clone https://github.com/Wuhubing/ps02.git
cd ps02
./book-manager/app.sh
```

Bash 3.2 or newer, curl, jq, Python 3, and [Gum](https://github.com/charmbracelet/gum) are required. On Linux, install the same commands using your package manager and Gum's installation instructions. Python is used only inside the database component for reliable CSV parsing; the application and its workflows are Bash programs.

Choose **Browse Library**, **Add Book**, **Search Library**, **Update Status / Rating**, or **Get Recommendations**. Arrow keys and Enter select an option; Esc cancels a prompt, and Ctrl+C exits. The shipped library is empty. Add books before requesting history-based recommendations, or start with the built-in technology and science-fiction preferences.

The entry point also works from another directory:

```bash
/absolute/path/to/ps02/book-manager/app.sh
```

## AI configuration

Put your OpenAI API key on a single line in `book-manager/token.txt`, or set `OPENAI_API_KEY` in your shell. The environment variable takes precedence. `token.txt` and `.env` files are ignored by Git; the application does not automatically source `.env` files. Do not include your key in recordings.

Optional settings:

```bash
export OPENAI_MODEL=gpt-4o-mini
export OPENAI_KEY_FILE=/absolute/path/to/a/private-key-file
```

The default model is `gpt-4o-mini`. Each recommendation run sends three requests to the [OpenAI Responses API](https://developers.openai.com/api/docs/guides/structured-outputs), with the library and interests as context. This requires API access and may incur API charges. Responses use a strict JSON schema. Missing credentials affect only recommendations; local library operations still work.

Book metadata comes from the [Open Library Search API](https://openlibrary.org/dev/docs/api/search). Pick one of up to five matches, review the fields, and save. If the lookup fails or finds nothing, the same form lets you enter everything manually. Recommended books go through this review before saving too. Model suggestions are not independently verified bibliographic records.

## Architecture

The application follows **UI → Workflows → Book / Recommendation Components → Data Layer → Storage**. UI scripts own Gum prompts and presentation. Workflows coordinate small programs, book components fetch metadata or search, and independent recommendation programs apply different prompts. Only the data component reads or writes the CSV, using Python's standard library inside its Bash entry point. Components exchange JSON Lines on stdout; diagnostics and progress use stderr, so pipes carry only data. The entry point stays small, and the shared API adapter keeps HTTP handling out of the recommendation strategies.

```text
book-manager/
├── app.sh
├── ui/
│   ├── main_menu.sh
│   ├── library_screen.sh
│   └── recommendations_screen.sh
├── workflows/
│   ├── manage_library.sh
│   └── get_recommendations.sh
├── books/
│   ├── fetch_book_metadata.sh
│   └── search_books.sh
├── recommendations/
│   ├── recommend_from_history.sh
│   ├── recommend_from_interests.sh
│   ├── recommend_for_discovery.sh
│   └── refine_recommendations.sh
├── data/
│   ├── book_database.sh
│   └── books.csv
└── lib/
    ├── common.sh
    └── openai_request.sh
```

For a complete recommendation trace: the UI collects interests, the workflow obtains one library snapshot through the data layer, and three programs start concurrently with `&`. Their PIDs are captured with `$!`; each program's state is shown as `running`, `done`, or `failed`, and `wait` collects its result. Successful outputs are concatenated and piped into refinement, which removes existing titles and duplicates and picks at most six books in source rotation. The UI shows the shortlist and can send a chosen book through the normal add workflow.

See [the file-by-file guide and command interfaces](docs/ARCHITECTURE.md) for inputs, outputs, and responsibilities.

## Personalization

This reading desk connects practical technical learning with imaginative reading. The initial interests are programming, AI, and science fiction, and they can be edited before every recommendation run. The history strategy looks at finished books, ratings, and saved titles; the interests strategy focuses on the current learning goals; the discovery strategy deliberately reaches into history, humanities, natural science, and literature. Source labels and short explanations make each suggestion understandable, while round-robin refinement gives unfamiliar topics space beside familiar ones.

## Test

```bash
python3 -m unittest discover -s tests -v
find book-manager -name '*.sh' -exec bash -n {} \;
```

The automated suite uses an isolated database and local curl/Gum doubles. It never uses your real API key or the network. It checks persistence, quoted CSV values and Unicode, duplicate handling, state updates, metadata fallback, actual concurrent starts, shared context, shortlist diversity, missing keys, HTTP errors, retry limits, invalid responses, UI cancellation, and process cleanup.

For a separate real API check, run **Get Recommendations** in the application after configuring your key. Automated fixtures and real checks are reported separately in [VALIDATION.md](docs/VALIDATION.md).

## Narrated demo — recording still required

The required narrated video has **not yet been recorded**. Use the [2–3 minute demo script](docs/DEMO.md) to record adding a book, searching/updating it, and generating/saving a recommendation. Then add the video to the repository or replace this paragraph with a clearly visible, accessible video link before submitting.

The final submission is this repository's URL in the class sheet's **Assignment No 2** column. The original assignment is preserved in [ASSIGNMENT.md](docs/ASSIGNMENT.md).

## Storage and limits

Books persist in the six-column CSV supplied by the assignment. The database validates status and rating, handles CSV escaping, and replaces files atomically. A title and author pair identifies a book after trimming surrounding whitespace and folding ASCII capitals. Different editions, alternate titles, or differently spelled author names can still appear separately. The app assumes one interactive instance writes the library at a time.

API requests time out after 45 seconds; HTTP 429 and 5xx are retried once. Partial recommendation failures preserve successful results and identify failed strategies. Fully failed runs return to the menu. Ctrl+C terminates active recommendation HTTP processes and removes temporary files. The application does not implement model token streaming: the assignment's progress requirement is fulfilled by live task status updates.

Starter code is used under the included [MIT license](LICENSE).
