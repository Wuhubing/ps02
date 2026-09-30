# Narrated terminal demo

**[Watch the video](demo.mp4)** — 1:59, 1920×1080, H.264/AAC MP4, about 3 MB.

[English subtitles](demo.srt) · [Original terminal capture](demo.cast)

## What the video demonstrates

| Time | Operation |
| --- | --- |
| 00:17 | Add Dune through Open Library, review metadata, and save as want to read. |
| 00:42 | Search the saved library by the author Frank Herbert. |
| 00:55 | Enter interests, run three AI strategies concurrently, and review the refined shortlist. |

## Recording notes

The visuals come from an actual Bash/Gum session captured in a pseudo-terminal. Open Library and OpenAI were called live; the displayed application results are not mock responses. The terminal output was rendered with a readable font, chapter labels, and captions. The source capture is included in asciicast v2 format.

The English narration uses the macOS Samantha text-to-speech voice. It is synthetic narration, not a recording of the student's voice. The script describes the actual actions and the application architecture. A separate demo database was used, so the project's shipped library remains empty. No credential was displayed or included in the capture.

## Narration transcript

### 00:02 — Meet the reading desk

This is Tech and Sci-Fi Books, a personal book manager built from small Bash programs. The Gum interface makes it easy to organize a reading list and explore recommendations for programming, artificial intelligence, and science fiction.

### 00:17 — 01  /  Add a book

First, I will add Dune by Frank Herbert. The app searches Open Library and returns matching books. Instead of typing every detail, I can choose the correct result and review its metadata.

### 00:28 — 01  /  Review and save

I confirm the title, author, genre, and link, then keep the status as want to read. After I approve the entry, the database component saves it to a CSV file. Each layer has a separate responsibility.

### 00:42 — 02  /  Search the library

Next, I search for Frank Herbert. The saved book appears immediately, along with its reading status. Search works across titles, authors, and genres, and the library stays available after the app closes.

### 00:55 — 03  /  Request recommendations

Finally, I request recommendations. The starting interests are programming, AI, and science fiction, and I can change them for this run. The app will send the same library snapshot to three independent recommendation strategies.

### 01:10 — 03  /  Three strategies in parallel

All three strategies are now running at the same time. History uses saved books and ratings. Interests follows the topics I entered. Discovery explores outside the usual pattern. The status messages show each task finishing, while the Bash workflow waits for every process.

### 01:26 — 03  /  Read the shortlist

The workflow combines the results and pipes them into refinement. That step removes duplicates and books already in the library, then rotates among the strategies to produce a short list. Each suggestion shows its source and a reason for reading it.

### 01:40 — Small scripts. Clear data flow.

That is the complete demo: adding a book, searching the library, and generating recommendations. Small Bash files handle the layers, Gum handles interaction, and parallel processes and a pipe connect the recommendation workflow.

## Submission

The narrated video is included in the repository and linked near the top of the README. The repository URL still needs to be entered in the class sheet's **Assignment No 2** column.
