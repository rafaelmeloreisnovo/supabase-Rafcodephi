"""Synthetic tests for an unexecuted PostgreSQL DRAFT candidate.

SQLite is a reference MODEL, not proof of PostgreSQL/RLS behavior.
No provider connections, real user records, secrets or external calls.
"""
from pathlib import Path
import sqlite3
import unittest

SQL_FILE = Path(__file__).resolve().parent.parent / "sql" / "rafaelia_metadata_dedup.v1.DRAFT.sql"


class DedupReferenceModel(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.db.execute("PRAGMA foreign_keys = ON")
        self.db.executescript("""
          CREATE TABLE entities (canonical_key TEXT PRIMARY KEY NOT NULL,
            entity_kind TEXT NOT NULL, CHECK(canonical_key <> 'TOKEN_VAZIO'));
          CREATE TABLE occurrences (provider TEXT NOT NULL,
            source_item_key TEXT NOT NULL, scope_key TEXT NOT NULL,
            source_revision TEXT NOT NULL DEFAULT 'unknown',
            relation_kind TEXT NOT NULL, canonical_key TEXT,
            UNIQUE(provider,source_item_key,scope_key,source_revision,relation_kind),
            FOREIGN KEY(canonical_key) REFERENCES entities(canonical_key));
        """)

    def ingest(self, rows):
        for paper, folder in rows:
            key = "arxiv:" + paper
            self.db.execute("INSERT OR IGNORE INTO entities VALUES (?, 'paper')", (key,))
            self.db.execute("""INSERT OR IGNORE INTO occurrences
              (provider,source_item_key,scope_key,relation_kind,canonical_key)
              VALUES ('alphaxiv',?,?,'MEMBER_OF',?)""", (paper,folder,key))

    def test_cross_folder_membership_is_not_lost(self):
        records = [("2601.00001", "folder_A"), ("2601.00001", "folder_B"),
                   ("2602.00002", "folder_B")]
        self.ingest(records)
        self.assertEqual(self.db.execute("SELECT count(*) FROM entities").fetchone()[0], 2)
        self.assertEqual(self.db.execute("SELECT count(*) FROM occurrences").fetchone()[0], 3)
        self.ingest(records)
        self.assertEqual(self.db.execute("SELECT count(*) FROM entities").fetchone()[0], 2)
        self.assertEqual(self.db.execute("SELECT count(*) FROM occurrences").fetchone()[0], 3)

    def test_legacy_arxiv_categories_are_distinct_stable_ids(self):
        # arXiv identifiers can also have legacy category prefixes.
        rows = [("math/9508209", "folder_A"), ("math/9508209", "folder_B"),
                ("quant-ph/0406196", "folder_B")]
        self.ingest(rows)
        self.ingest(rows)
        self.assertEqual(self.db.execute("SELECT count(*) FROM entities").fetchone()[0], 2)
        self.assertEqual(self.db.execute("SELECT count(*) FROM occurrences").fetchone()[0], 3)

    def test_orphan_reference_is_rejected(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("""INSERT INTO occurrences
              (provider,source_item_key,scope_key,relation_kind,canonical_key)
              VALUES ('alphaxiv','2603.00003','folder_A','MEMBER_OF','arxiv:unknown')""")

    def test_not_equal_empty_and_unknown(self):
        self.assertNotEqual("TOKEN_VAZIO", "")
        self.assertNotEqual("TOKEN_VAZIO", "0")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO entities VALUES('TOKEN_VAZIO', 'paper')")

    def test_draft_is_private_fail_closed(self):
        sql = SQL_FILE.read_text(encoding="utf-8")
        self.assertIn("UNIQUE NULLS NOT DISTINCT", sql)
        self.assertIn("ENABLE ROW LEVEL SECURITY", sql)
        self.assertIn("REVOKE ALL", sql)
        self.assertNotIn("CREATE POLICY", sql.upper())
        self.assertNotIn("GRANT SELECT", sql.upper())
        self.assertNotIn("supabase/migrations/", str(SQL_FILE))


if __name__ == "__main__":
    unittest.main()
