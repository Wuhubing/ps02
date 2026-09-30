# Validation record

Checked on September 30, 2026, on macOS with the system Bash 3.2 and Gum 2.0.2.

## Automated, offline checks

`python3 -m unittest discover -s tests -v` passed all **14 tests**. The suite uses temporary databases, scripted UI choices, and a local HTTP double. No automated test sends a request to OpenAI or reads the user's credential file.

Coverage includes:

- CSV persistence with Chinese text, commas, and quoted titles; title/author/genre search.
- Duplicate detection, existence queries, state and rating updates, and rejection of invalid input.
- Open Library response parsing and the manual-entry fallback when lookup fails.
- Three agents starting before any finishes, sharing the same library snapshot, and reporting progress.
- Deduplication, removal of existing library books, a six-book limit, and source diversity.
- Empty libraries and empty candidate responses.
- Missing credentials and an explicitly selected local test credential file.
- One retry for HTTP 429/5xx, no retry for HTTP 401 or transport timeout.
- Rejection of malformed, refused, and incomplete model output without emitting partial data.
- Partial failures preserving successful results; all failures returning an error.
- SIGINT and SIGTERM cleanup of recommendation agents, HTTP children, and temporary directories.
- Cancelling an add form, manual fallback followed by an update, saving a recommendation through metadata review, and interrupting the UI while recommendations are running.

All application Bash files also passed `/bin/bash -n`; `git diff --check` reported no whitespace errors.

## Separate real integration checks

These were performed separately from the offline suite:

1. **Open Library:** queried Dune by Frank Herbert and received five metadata matches with work links.
2. **OpenAI:** loaded the locally configured credential file, used the default `gpt-4o-mini` model, and ran all three strategies against an isolated empty library. All three completed successfully; refinement returned six books spanning history, interests, and discovery. Credentials and raw authorization headers were not printed or committed.
3. **Real terminal UI:** launched the app from `/tmp` in a pseudo-terminal with real Gum and an isolated database; searched Open Library, selected Dune, reviewed fields, saved with `want_to_read`, returned to the menu, and exited. A separate database read confirmed the saved record.

The shipped library remains empty. These checks establish that the integration worked at the time of testing; future API availability and account access can vary.

## Narrated demo recording

The recorded video is available as `docs/demo.mp4`, with a visible link and thumbnail in the README. It shows adding a book, searching, and generating recommendations during an actual terminal session. Open Library and all three OpenAI strategies completed successfully during recording. The demo uses a separate database, leaving the shipped library empty.

The narration is synthetic English speech (macOS Samantha). English captions are visible in the video and supplied separately as `docs/demo.srt`. The video uses H.264 at 1920×1080 with AAC audio, runs approximately 1 minute 59 seconds, and is about 3 MB. Representative frames were visually reviewed for readable UI and subtitles; the audio stream was checked for audible level and clipping. The captured terminal output was checked to ensure it contains no API credential.

## Remaining assignment deliverable

The repository URL still needs to be entered in the class sign-up sheet. The video deliverable is now included.
