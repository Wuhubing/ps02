#!/usr/bin/env python3
"""Behavioral acceptance tests; all HTTP calls are replaced by local fixtures."""
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import unittest

REPO = Path(__file__).resolve().parents[1]
APP = REPO / "book-manager"
FIXTURES = REPO / "tests" / "fixtures"


class BookManagerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="book-manager-test-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.events = self.directory / "events"
        self.events.mkdir()
        self.scratch = self.directory / "scratch"
        self.scratch.mkdir()
        self.env = dict(os.environ, PATH=str(FIXTURES) + os.pathsep + os.environ["PATH"],
            BOOK_DB_PATH=str(self.directory / "books.csv"), OPENAI_API_KEY="fixture-key",
            OPENAI_KEY_FILE=str(self.directory / "absent-key"), OPENAI_MODEL="fixture-model",
            MOCK_EVENTS=str(self.events), MOCK_HTTP="success", MOCK_BARRIER="0",
            TMPDIR=str(self.scratch))

    def run_script(self, script, *args, data=None, ok=True, env=None):
        process = subprocess.run([str(APP / script), *args], input=data, text=True,
            capture_output=True, env=env or self.env, cwd=self.directory, timeout=20)
        if ok:
            self.assertEqual(process.returncode, 0, process.stderr)
        return process

    def book(self, **changes):
        value = dict(title="Dune", author="Frank Herbert", genre="Science Fiction",
                     status="want_to_read", rating="", link="")
        value.update(changes)
        return value

    def add(self, book=None):
        return self.run_script("data/book_database.sh", "add", data=json.dumps(book or self.book()))

    def rows(self, output):
        return [json.loads(line) for line in output.splitlines() if line]

    def test_csv_roundtrip_unicode_commas_quotes_and_persistence(self):
        book = self.book(title='三体, "The Three-Body Problem"', author="刘慈欣")
        self.add(book)
        self.assertEqual(self.rows(self.run_script("data/book_database.sh", "list").stdout), [book])
        self.assertEqual(self.rows(self.run_script("books/search_books.sh", data="刘慈欣\n").stdout), [book])
        self.assertEqual(len(self.rows(self.run_script("books/search_books.sh", "science").stdout)), 1)

    def test_duplicate_update_exists_and_validation(self):
        self.add()
        duplicate = self.run_script("data/book_database.sh", "add", ok=False,
            data=json.dumps(self.book(title=" dune ", author="FRANK HERBERT")))
        self.assertEqual(duplicate.returncode, 2)
        changed = self.run_script("data/book_database.sh", "update", "Dune", "Frank Herbert",
            data=json.dumps({"status": "finished", "rating": "5"}))
        self.assertEqual(self.rows(changed.stdout)[0]["rating"], "5")
        self.run_script("data/book_database.sh", "exists", "DUNE", "Frank Herbert")
        self.assertEqual(self.run_script("data/book_database.sh", "exists", "Missing", "Author", ok=False).returncode, 1)
        for patch in ({"rating": "6"}, {"status": "broken"}, {"title": "Changed"}):
            self.assertNotEqual(self.run_script("data/book_database.sh", "update", "Dune", "Frank Herbert",
                data=json.dumps(patch), ok=False).returncode, 0)
        for book in (self.book(title=""), self.book(title="Bad\nTitle"), self.book(rating=True)):
            self.assertNotEqual(self.run_script("data/book_database.sh", "add",
                data=json.dumps(book), ok=False).returncode, 0)
        self.assertEqual(len(self.rows(self.run_script("data/book_database.sh", "list").stdout)), 1)

    def test_metadata_and_failure(self):
        result = self.run_script("workflows/manage_library.sh", "lookup", "Dune", "Frank Herbert")
        self.assertEqual(self.rows(result.stdout)[0]["link"], "https://openlibrary.org/works/OL893415W")
        self.env["MOCK_HTTP"] = "metadata_failure"
        failure = self.run_script("books/fetch_book_metadata.sh", "Dune", ok=False)
        self.assertNotEqual(failure.returncode, 0)
        self.assertEqual(failure.stdout, "")
        self.assertIn("manually", failure.stderr)

    def test_parallel_shared_snapshot_progress_dedup_and_diversity(self):
        self.add()
        self.env["MOCK_BARRIER"] = "1"
        result = self.run_script("workflows/get_recommendations.sh", "AI and fiction")
        books = self.rows(result.stdout)
        self.assertEqual(len(books), 6)
        keys = [(book["title"].strip().lower(), book["author"].strip().lower()) for book in books]
        self.assertEqual(len(keys), len(set(keys)))
        self.assertNotIn(("dune", "frank herbert"), keys)
        self.assertEqual({book["source"] for book in books}, {"history", "interests", "discovery"})
        starts = [float(file.read_text()) for file in self.events.glob("*.started")]
        ends = [float(file.read_text()) for file in self.events.glob("*.ended")]
        self.assertEqual(len(starts), 3)
        self.assertLess(max(starts), min(ends), "All agents must start before any finishes")
        contexts = [json.loads(file.read_text()) for file in self.events.glob("*.context")]
        self.assertTrue(all(context == contexts[0] for context in contexts))
        self.assertEqual(contexts[0]["library"], [self.book()])
        for name in ("history", "interests", "discovery"):
            self.assertIn(name + ": running", result.stderr)
            self.assertIn(name + ": done", result.stderr)
        self.assertFalse(list(self.scratch.iterdir()))

    def test_empty_library_and_empty_candidate_list(self):
        result = self.run_script("workflows/get_recommendations.sh")
        self.assertTrue(self.rows(result.stdout))
        self.assertTrue(all(json.loads(file.read_text())["library"] == [] for file in self.events.glob("*.context")))
        self.env["MOCK_HTTP"] = "empty"
        self.assertEqual(self.run_script("workflows/get_recommendations.sh").stdout, "")

    def test_partial_failure_preserves_successful_results(self):
        self.env["MOCK_HTTP"] = "fail_history"
        result = self.run_script("workflows/get_recommendations.sh")
        self.assertIn("history: failed", result.stderr)
        self.assertEqual({book["source"] for book in self.rows(result.stdout)}, {"interests", "discovery"})
        self.assertEqual((self.events / "history.count").read_text(), "2")

    def test_retry_once_on_rate_limit(self):
        self.env["MOCK_HTTP"] = "http429_once"
        self.run_script("workflows/get_recommendations.sh")
        self.assertTrue(all(file.read_text() == "2" for file in self.events.glob("*.count")))

    def test_missing_key_and_local_key_file(self):
        self.env["OPENAI_API_KEY"] = ""
        result = self.run_script("workflows/get_recommendations.sh", ok=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("OPENAI_API_KEY", result.stderr)
        self.assertFalse(list(self.events.iterdir()))
        local_key = Path(self.env["OPENAI_KEY_FILE"])
        local_key.write_text("local-fixture-key\n")
        result = self.run_script("workflows/get_recommendations.sh")
        self.assertNotIn("local-fixture-key", result.stdout + result.stderr)

    def test_api_errors_and_invalid_outputs_produce_no_partial_data(self):
        for mode in ("http401", "http500_always", "timeout", "bad_json", "refusal", "incomplete"):
            with self.subTest(mode=mode):
                for file in self.events.iterdir():
                    file.unlink()
                self.env["MOCK_HTTP"] = mode
                result = self.run_script("workflows/get_recommendations.sh", ok=False)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")
                self.assertIn("All recommendation strategies failed", result.stderr)
                expected_attempts = "2" if mode == "http500_always" else "1"
                self.assertTrue(all(file.read_text() == expected_attempts for file in self.events.glob("*.count")))

    def test_interrupt_stops_http_children_and_cleans_temporary_files(self):
        self.env["MOCK_HTTP"] = "long"
        for interrupt in (signal.SIGINT, signal.SIGTERM):
            with self.subTest(signal=interrupt):
                for file in self.events.iterdir():
                    file.unlink()
                process = subprocess.Popen([str(APP / "workflows/get_recommendations.sh")],
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=self.env, start_new_session=True)
                try:
                    deadline = time.monotonic() + 5
                    while len(list(self.events.glob("*.pid"))) < 3 and time.monotonic() < deadline:
                        time.sleep(0.05)
                    self.assertEqual(len(list(self.events.glob("*.pid"))), 3)
                    process.send_signal(interrupt)
                    process.communicate(timeout=5)
                    self.assertEqual(process.returncode, 128 + interrupt)
                    for file in self.events.glob("*.pid"):
                        with self.assertRaises(ProcessLookupError):
                            os.kill(int(file.read_text()), 0)
                    self.assertFalse(list(self.scratch.iterdir()))
                finally:
                    if process.poll() is None:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.communicate()

    def ui_steps(self, steps):
        script = self.directory / "gum-script.json"
        script.write_text(json.dumps(steps))
        self.env["MOCK_GUM_SCRIPT"] = str(script)
        result = self.run_script("app.sh")
        self.assertNotIn("Expected ", result.stderr)
        self.assertNotIn("Unexpected Gum", result.stderr)
        self.assertEqual(json.loads(script.read_text()), [])
        return result

    def test_ui_cancel_does_not_save(self):
        self.ui_steps([{"kind": "choose", "value": "Add Book"},
                       {"kind": "input", "value": "Dune"}, {"kind": "input", "value": "Frank Herbert"},
                       {"kind": "choose", "exit": 1}, {"kind": "input"}, {"kind": "choose", "value": "Quit"}])
        self.assertEqual(self.run_script("data/book_database.sh", "list").stdout, "")

    def test_ui_manual_fallback_and_update_from_other_directory(self):
        self.env["MOCK_HTTP"] = "metadata_failure"
        steps = [{"kind": "choose", "value": "Add Book"}]
        steps += [{"kind": "input", "value": value} for value in
                  ("Dune", "Frank Herbert", "Dune", "Frank Herbert", "Science Fiction", "")]
        steps += [{"kind": "choose", "value": "want_to_read"}, {"kind": "choose", "value": "Unrated"},
                  {"kind": "confirm"}, {"kind": "input"},
                  {"kind": "choose", "value": "Update Status / Rating"},
                  {"kind": "choose", "value": "1. Dune — Frank Herbert"},
                  {"kind": "choose", "value": "finished"}, {"kind": "choose", "value": "5"},
                  {"kind": "confirm"}, {"kind": "input"}, {"kind": "choose", "value": "Quit"}]
        self.ui_steps(steps)
        books = self.rows(self.run_script("data/book_database.sh", "list").stdout)
        self.assertEqual(books, [self.book(status="finished", rating="5")])

    def test_ui_recommendation_save_reuses_metadata_and_library_workflow(self):
        steps = [{"kind": "choose", "value": "Get Recommendations"},
                 {"kind": "input", "value": "programming, AI, science fiction"},
                 {"kind": "confirm"}, {"kind": "choose", "value": "1. Dune — Frank Herbert"},
                 {"kind": "input", "value": "Dune"}, {"kind": "input", "value": "Frank Herbert"},
                 {"kind": "choose", "value": "1. Dune — Frank Herbert"}]
        steps += [{"kind": "input", "value": value} for value in
                  ("Dune", "Frank Herbert", "Science Fiction", "https://openlibrary.org/works/OL893415W")]
        steps += [{"kind": "choose", "value": "want_to_read"}, {"kind": "choose", "value": "Unrated"},
                  {"kind": "confirm"}, {"kind": "input"}, {"kind": "choose", "value": "Quit"}]
        self.ui_steps(steps)
        books = self.rows(self.run_script("data/book_database.sh", "list").stdout)
        self.assertEqual(books, [self.book(link="https://openlibrary.org/works/OL893415W")])

    def test_ui_exit_terminates_active_recommendation_workflow(self):
        script = self.directory / "gum-script.json"
        script.write_text(json.dumps([{"kind": "choose", "value": "Get Recommendations"},
                                      {"kind": "input", "value": "AI"}]))
        self.env.update(MOCK_GUM_SCRIPT=str(script), MOCK_HTTP="long")
        process = subprocess.Popen([str(APP / "app.sh")], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, env=self.env, start_new_session=True)
        try:
            deadline = time.monotonic() + 5
            while len(list(self.events.glob("*.pid"))) < 3 and time.monotonic() < deadline:
                time.sleep(0.05)
            self.assertEqual(len(list(self.events.glob("*.pid"))), 3)
            process.send_signal(signal.SIGINT)
            process.communicate(timeout=5)
            self.assertEqual(process.returncode, 130)
            for file in self.events.glob("*.pid"):
                with self.assertRaises(ProcessLookupError):
                    os.kill(int(file.read_text()), 0)
            self.assertFalse(list(self.scratch.iterdir()))
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate()


if __name__ == "__main__":
    unittest.main(verbosity=2)
