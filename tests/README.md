# Local verification

From the repository root:

```shell
python -m pip install --target .tools -r tests/requirements.txt
python tests/verify.py
python -m unittest discover -s tests -p 'test_*.py' -v
```

The Lua 5.1 harness reproduces the original empty-macro defect using the preserved
5.1.0 source, then verifies selection, secure macro conditions, combat deferral,
settings callbacks, saved stat priorities, item-data retries and error paths.
It includes public food tooltip text captured from Forever build 70374.

These tests simulate game APIs. Loading, protected actions, tooltips and visual
layout still require checks in the actual game client.

Package verification covers the installable folder, exact file list, source bytes,
WowUp Forever metadata, SHA256 checksums, deterministic builds and tag mismatch
rejection. See ../docs/RELEASING.md for the automatic build and release process.
