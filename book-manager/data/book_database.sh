#!/bin/bash
# The only application component allowed to open the CSV. JSON in/out, CSV inside.
# Python's standard CSV parser handles quoted commas, quotes and Unicode correctly.
set -uo pipefail
DATABASE=${BOOK_DB_PATH:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/books.csv"}
exec python3 -c '
import csv
import json
import os
from pathlib import Path
import sys
import tempfile

path = Path(sys.argv[1]).expanduser()
args = sys.argv[2:]
fields = ["title", "author", "genre", "status", "rating", "link"]
statuses = {"owned", "want_to_read", "reading", "finished"}

def fail(message):
    raise ValueError(message)

def key(book):
    # Match the refinement component: trim whitespace and fold ASCII capitals.
    table = str.maketrans("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz")
    return tuple(book[field].strip().translate(table) for field in ("title", "author"))

def validate(book):
    if not isinstance(book, dict) or set(book) - set(fields):
        fail("Expected a book object with only the six documented fields.")
    result = {field: book.get(field, "") for field in fields}
    if isinstance(result["rating"], int) and not isinstance(result["rating"], bool):
        result["rating"] = str(result["rating"])
    for field, value in result.items():
        if not isinstance(value, str) or any(ord(c) < 32 or ord(c) == 127 for c in value):
            fail("Book fields must be single-line strings without control characters.")
        result[field] = value.strip()
    if not result["title"] or not result["author"]:
        fail("Title and author are required.")
    if result["status"] not in statuses:
        fail("Status must be owned, want_to_read, reading or finished.")
    if result["rating"] not in {"", "1", "2", "3", "4", "5"}:
        fail("Rating must be empty or an integer from 1 to 5.")
    if result["link"] and not result["link"].startswith(("https://", "http://")):
        fail("Link must start with https:// or http://, or be empty.")
    return result

def read_books():
    if not path.exists():
        return []
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != fields:
            fail("Unexpected CSV header; database was not changed.")
        return [validate(row) for row in reader]

def write_books(books):
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".books-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=fields)
            writer.writeheader()
            writer.writerows(books)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)

def emit(book):
    print(json.dumps(book, ensure_ascii=False))

try:
    if not args:
        fail("Usage: book_database.sh list|search TERM|exists TITLE AUTHOR|add|update TITLE AUTHOR")
    command, params = args[0], args[1:]
    arities = {"list": 0, "search": 1, "exists": 2, "add": 0, "update": 2}
    if command not in arities or len(params) != arities[command]:
        fail("Unknown command or incorrect argument count.")
    books = read_books()
    if command == "list":
        for book in books:
            emit(book)
    elif command == "search":
        term = params[0].casefold()
        for book in books:
            if any(term in book[field].casefold() for field in ("title", "author", "genre")):
                emit(book)
    elif command == "exists":
        wanted = key(dict(zip(("title", "author"), params)))
        sys.exit(0 if any(key(book) == wanted for book in books) else 1)
    elif command == "add":
        book = validate(json.load(sys.stdin))
        if any(key(existing) == key(book) for existing in books):
            fail("That title and author are already in your library.")
        write_books(books + [book])
        emit(book)
    elif command == "update":
        patch = json.load(sys.stdin)
        if not isinstance(patch, dict) or not patch or set(patch) - {"status", "rating"}:
            fail("Update accepts only status and/or rating.")
        wanted = key(dict(zip(("title", "author"), params)))
        index = next((i for i, book in enumerate(books) if key(book) == wanted), None)
        if index is None:
            fail("Book not found.")
        books[index] = validate(dict(books[index], **patch))
        write_books(books)
        emit(books[index])
except (ValueError, OSError, csv.Error) as error:
    print("Database: " + str(error), file=sys.stderr)
    sys.exit(2)
' "$DATABASE" "$@"
