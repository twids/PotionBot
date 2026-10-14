import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("package_builder", ROOT / "scripts/build.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class PackageTests(unittest.TestCase):
    def test_installable_package_and_wowup_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            result = builder.build_package(ROOT, output)
            self.assertTrue(result["zip_filename"].endswith("-forever.zip"))
            with ZipFile(output / result["zip_filename"]) as archive:
                self.assertEqual(set(archive.namelist()), {f"PotionBot/{name}" for name in builder.FILES})
                toc = archive.read("PotionBot/PotionBot.toc").decode()
                self.assertIn("## Interface: 16001\n", toc)
                self.assertNotIn("110002", toc)
                self.assertEqual(archive.read("PotionBot/PotionBot.lua").decode(),
                                 (ROOT / "PotionBot.lua").read_text(encoding="utf-8"))
                self.assertIn("PotionBot/Bindings.xml", archive.namelist())
            metadata = json.loads((output / "release.json").read_text())
            self.assertEqual(metadata["releases"], [{"filename": result["zip_filename"],
                "nolib": False, "metadata": [{"flavor": "forever", "interface": 16001}]}])
            for line in (output / "SHA256SUMS.txt").read_text().splitlines():
                checksum, name = line.split("  ")
                self.assertEqual(checksum, hashlib.sha256((output / name).read_bytes()).hexdigest())

    def test_deterministic_build(self):
        with tempfile.TemporaryDirectory() as directory:
            first, second = Path(directory) / "a", Path(directory) / "b"
            result = builder.build_package(ROOT, first)
            builder.build_package(ROOT, second, f"v{result['version']}")
            for name in (result["zip_filename"], "release.json", "SHA256SUMS.txt"):
                self.assertEqual((first / name).read_bytes(), (second / name).read_bytes())

    def test_mismatched_release_tag_is_rejected_before_writing(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "output"
            with self.assertRaisesRegex(ValueError, "does not match TOC"):
                builder.build_package(ROOT, output, "v0.0.0")
            self.assertFalse(output.exists())

    def test_missing_toc_dependency_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "PotionBot.toc").write_text("## Interface: 16001\n## Version: 1.0.0\nMissing.lua\n")
            (root / "PotionBot.lua").write_text('local VERSION = "1.0.0"')
            with self.assertRaisesRegex(ValueError, "TOC dependency"):
                builder.build_package(root, root / "output")


if __name__ == "__main__":
    unittest.main()
