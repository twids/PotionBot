# Builds and releases

The Build and package workflow runs on pull requests, main pushes, version tags,
and manual dispatch. Every successful build tests the addon and creates an
Actions artifact containing:

- PotionBot-VERSION-forever.zip, with a single installable PotionBot folder
- release.json, identifying the ZIP as WowUp's forever flavor / Interface 16001
- SHA256SUMS.txt, covering the ZIP and release metadata

The package uses an explicit file list. Git metadata, tests, historical fixtures,
tools, backups and development scripts are excluded. A LICENSE file is included
if present. The packaged TOC advertises only Forever; source compatibility entries
for other clients are not advertised as release support.

## Build locally

```shell
python -m pip install --target .tools -r tests/requirements.txt
python tests/verify.py
python -m unittest discover -s tests -p 'test_*.py' -v
python scripts/build.py
```

Output is written to .artifacts/build. Packaging verifies every archived file
against its source and normalizes ZIP timestamps and text line endings.

## Publish a version

1. Update the version in PotionBot.lua and PotionBot.toc to the same value.
2. Update CHANGELOG.md, open a PR, and wait for Build and package to pass.
3. Squash-merge the PR and update your local main checkout.
4. Create and push an annotated vVERSION tag on that merged commit. For the
   current version the tag would be v5.5.0-forever-beta.

```shell
git switch main
git pull --ff-only origin main
git tag -a v5.5.0-forever-beta -m "PotionBot 5.5.0 Forever beta"
git push origin v5.5.0-forever-beta
```

A tag triggers the same tests and package build. A mismatch between the tag,
TOC version and Lua version fails the build. After success, the release job
downloads that exact build artifact, checks its hashes, creates a draft GitHub
Release with all three assets, and publishes it after upload. Versions containing
a hyphen are marked as prereleases. No manually prepared ZIP or personal API
token is required; publishing uses the job's GitHub token with contents: write.
PR/build jobs have read-only repository permissions and cannot publish.

Published releases are not overwritten on workflow reruns. If publishing failed
after creating the draft, inspect the draft and assets before deciding whether to
publish it or remove the incomplete draft and rerun the workflow.

## Install through WowUp

After the first tagged release is published, select the Forever installation in
WowUp and use Install from URL with https://github.com/twids/PotionBot. This is a
GitHub provider installation, not a separate WowUp catalog listing. Use the Beta
channel where necessary for prereleases. A direct ZIP URL does not provide the
same release tracking as the repository URL.

Passing the workflow does not establish in-game compatibility. Check loading,
macro activation, combat conditions, food buffs and the options panel in the
intended client before promoting a beta to a stable release.
