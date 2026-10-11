"""Malformed archive rejection checks; no compiler or registry writes."""
import pathlib
import subprocess
import tempfile
import unittest
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/test/moon-packed-consumer.py"


class ArchiveContract(unittest.TestCase):
    def reject(self, members, message):
        with tempfile.TemporaryDirectory() as directory:
            archive = pathlib.Path(directory) / "bad.zip"
            with zipfile.ZipFile(archive, "w") as z:
                for name, content in members:
                    z.writestr(name, content)
            result = subprocess.run(["python3", str(SCRIPT), str(archive)],
                                    text=True, capture_output=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(message, result.stderr)

    def test_unrelated_tooling_is_rejected(self):
        self.reject([("node/debug.log", b"debug")], "unexpected archive member")

    def test_missing_legal_text_is_rejected(self):
        self.reject([("moon.mod", (ROOT / "moon.mod").read_bytes()),
                     ("README.mooncakes.md", (ROOT / "README.mooncakes.md").read_bytes())],
                    "missing distribution/legal file: LICENSE")

    def test_modified_notice_is_rejected(self):
        self.reject([("NOTICE", b"truncated")], "packed source drift: NOTICE")

    def test_path_traversal_is_rejected(self):
        self.reject([("../LICENSE", b"bad")], "../LICENSE")

    def test_duplicate_members_are_rejected(self):
        self.reject([("LICENSE", b"first"), ("LICENSE", b"second")],
                    "duplicate archive members")


if __name__ == "__main__":
    unittest.main()
