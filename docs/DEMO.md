# Narrated terminal demo

**[Watch the video](demo.mp4)** — 2:09, 1920×1080, H.264/AAC MP4, about 3 MB.

[English subtitles](demo.srt) · [Original terminal capture](demo.cast)

## What the video demonstrates

| Time | Operation |
| --- | --- |
| 00:16 | Add Dune through Open Library, review metadata, and save as want to read. |
| 00:44 | Search the saved library by the author Frank Herbert. |
| 01:00 | Enter interests, run three AI strategies concurrently, and review the refined shortlist. |

## Recording notes

The visuals come from an actual Bash/Gum session captured in a pseudo-terminal. Open Library and OpenAI were called live; the displayed application results are not mock responses. The terminal output was rendered with a readable font, chapter labels, and captions. The original source capture is included in asciicast v2 format; its timestamps reflect the original run rather than the edited video.

The English narration is the student's own voice recording. Fourteen long pauses were shortened, and the volume was normalized; the speaker's voice, pitch, and speaking speed were preserved. The existing terminal footage was retimed to follow this narration. Captions and the transcript below use corrected technical spellings and punctuation. A separate demo database was used, so the project's shipped library remains empty. No credential was displayed or included in the capture.

## Narration transcript

### 00:00 — Meet the reading desk

Hi, this is my personal book manager for technology and science fiction. It runs in the terminal and uses Gum for menus. And I will demonstrate three operations: adding a book, searching my library, and getting recommendations.

### 00:16 — 01  /  Add a book

First, I'll add Dune by Frank Herbert. The app searches Open Library and shows matching results.

### 00:26 — 01  /  Review and save

I select the correct book and review the title, author, genre, and link. I'll mark it as want to read and leave the rating empty. After I confirm, the app saves the book. Only the database component reads and writes the CSV file.

### 00:44 — 02  /  Search the library

Next, I'll search for Frank Herbert. The book I just added appears with its reading status. I can also search by title and genre. The data is saved locally, so my library stays available after I close the app.

### 01:00 — 03  /  Request recommendations

Finally, I'll get recommendations. I'll keep the default interests: programming, AI, and science fiction.

### 01:10 — 03  /  Three strategies in parallel

Three recommendation scripts now run in parallel. History uses my saved books and ratings. Interests focuses on the topics I entered. Discovery suggests books outside my usual interests. The progress messages show when each script is running and when it's finished.

### 01:31 — 03  /  Read the shortlist

The workflow waits for all scripts, combines their results, and sends them through a pipe to the refinement script. The script removes duplicates and books already in my library, then produces a shortlist. Each recommendation includes a source and a short explanation.

### 01:52 — Small scripts. Clear data flow.

The project is organized into small Bash files, with separate layers for the interface, workflows, book components, and data storage. That's my book manager. Thanks so much for watching.

## Submission

The narrated video is included in the repository and linked near the top of the README. The repository URL has been entered in the class sheet's **PS2 Site URL** column (verified October 2, 2026).
