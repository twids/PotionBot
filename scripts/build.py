"""Build the installable Forever addon and WowUp release metadata."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

FILES = (
    "Bindings.xml", "Bindings/Bindings_Mainline.lua", "CHANGELOG.md",
    "PotionBot.lua", "PotionBot.toc", "README.md", "logo.png",
)
VERSION_PATTERN = r"\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?"


def build_package(root: Path, output: Path, tag: str = "") -> dict:
    toc = (root / "PotionBot.toc").read_text(encoding="utf-8")
    match = re.search(r"^## Version: (.+)$", toc, re.MULTILINE)
    if not match or not re.fullmatch(VERSION_PATTERN, match[1]):
        raise ValueError("PotionBot.toc must contain a valid release version")
    version = match[1]
    if tag and tag != f"v{version}":
        raise ValueError(f"Tag {tag!r} does not match TOC version v{version}")
    source = (root / "PotionBot.lua").read_text(encoding="utf-8")
    if f'local VERSION = "{version}"' not in source:
        raise ValueError("Lua and TOC versions must match")
    interfaces = re.search(r"^## Interface: (.+)$", toc, re.MULTILINE)
    if not interfaces or "16001" not in interfaces[1].replace(" ", "").split(","):
        raise ValueError("TOC must support Forever Interface 16001")
    # This release advertises only the client flavor it packages and targets.
    toc = re.sub(r"^## Interface: .+$", "## Interface: 16001", toc, flags=re.MULTILINE)
    files = list(FILES)
    if (root / "LICENSE").is_file():
        files.append("LICENSE")
    for line in toc.splitlines():
        line = line.strip()
        if line and not line.startswith("#") and line.replace("\\", "/") not in files:
            raise ValueError(f"TOC dependency is missing from package: {line}")
    payload = {}
    for name in sorted(files):
        path = root / name
        if path.is_symlink():
            raise ValueError(f"Package source cannot be a symlink: {name}")
        data = path.read_bytes()
        if name == "PotionBot.toc":
            data = toc.encode("utf-8")
        elif path.suffix in {".lua", ".xml", ".md", ".txt"} or name == "LICENSE":
            data = data.replace(b"\r\n", b"\n")
        payload[f"PotionBot/{name}"] = data
    filename = f"PotionBot-{version}-forever.zip"
    output.mkdir(parents=True, exist_ok=True)
    archive_path = output / filename
    with ZipFile(archive_path, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in payload.items():
            entry = ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            entry.compress_type = ZIP_DEFLATED
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, data)
    with ZipFile(archive_path) as archive:
        if archive.testzip() or set(archive.namelist()) != set(payload):
            raise ValueError("Package verification failed")
        for name, data in payload.items():
            if archive.read(name) != data:
                raise ValueError(f"Packaged file differs from source: {name}")
    metadata = {"releases": [{"filename": filename, "nolib": False,
        "metadata": [{"flavor": "forever", "interface": 16001}]}]}
    metadata_path = output / "release.json"
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    checksums = []
    for path in (archive_path, metadata_path):
        checksums.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}")
    (output / "SHA256SUMS.txt").write_text("\n".join(checksums) + "\n", encoding="utf-8")
    return {"version": version, "zip_filename": filename,
            "prerelease": "true" if "-" in version else "false"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path(".artifacts/build"))
    parser.add_argument("--tag", default="")
    args = parser.parse_args()
    result = build_package(Path(__file__).resolve().parents[1], args.output, args.tag)
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as outputs:
            for key, value in result.items():
                outputs.write(f"{key}={value}\n")
    print(f"Verified {args.output / result['zip_filename']}")


if __name__ == "__main__":
    main()
