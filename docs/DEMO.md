# Narrated demo guide (about 2–3 minutes)

Record the terminal at a readable font size. Keep the API key and credential files off screen. Configure the key before recording, ensure the terminal has at least 90 columns, and launch `./book-manager/app.sh`. Use your own voice; adapt the wording below to your actual preferences.

## 0:00–0:15 — Introduce the app

Show the title and menu.

“This is my personal book manager for technology and science fiction. It uses small Bash programs and a Gum interface. I can track books, look up metadata, and compare recommendations from three different strategies.”

## 0:15–0:55 — Add a book

Choose **Add Book**, enter **Dune** and **Frank Herbert**, choose the matching result, review the fields, keep `want_to_read`, and save. If Dune is already in your library, choose another book you actually want to read.

“The app looks up this title on Open Library. I select a match and review its details before saving. The UI collects the input, a workflow coordinates the operation, and only the database component writes the CSV. If the network is unavailable, I can type the details manually.”

## 0:55–1:25 — Search and update

Search for the book by title or author. Return to the menu, choose **Update Status / Rating**, select it, and set the reading state and rating honestly. For a prepared demonstration, explain when you are using example values.

“Search works across titles, authors, and genres. I can update the status and my rating, and the changes persist when the app closes. Ratings and reading history also provide context for recommendations.”

## 1:25–2:20 — Recommend and save

Choose **Get Recommendations**, review the default interests, and start the run. Keep the `running` / `done` messages visible. Show each recommendation's source and reason, then select one and complete its metadata review to save it.

“These three scripts run at the same time. History uses my past reading, Interests follows my current goals, and Discovery explores unfamiliar topics. The workflow starts them with ampersands, stores their process IDs, and waits for completion. Their results flow through a pipe into refinement, which removes duplicates and books I already own. The final list rotates among the three strategies.”

## 2:20–2:40 — Explain the structure

Briefly show the project tree or point to the architecture section in the README.

“The folders show the architecture: UI, workflows, book and recommendation components, then the data layer. The entry point is small. Each file has one responsibility, and I can trace a user's selection through the workflow to its final result.”

## Before submitting

- Record a real narrated terminal demonstration; this script is not the video deliverable.
- Upload the recording to the repository or a link the instructor can access.
- Replace the pending-video paragraph in the README with the recording or link.
- Open the repository and video link while signed out to check instructor access.
- Put the repository URL in the class sheet's **Assignment No 2** column.
