# CK3 Mod Base

This directory contains the CK3 base game files for modding and automation tooling for tracking game updates.

## Contents

- **`game/`** - CK3 base game files with binaries as placeholders
- **`release-notes/`** - Markdown patch notes for each CK3 version
- **`.ck3-version.json`** - Current version metadata and depot information
- **`scripts/`** - Automation tooling (see `scripts/README.md` for details)

## Current Version

Check `.ck3-version.json` for the current tracked version and depot manifests.

## Automation

All automation scripts and documentation are in the `scripts/automation/` directory. See `scripts/automation/README.md` for:
- How to check for updates
- How to download and extract game files
- How to run automation locally

## Binary Placeholders

Binary files in `game/` are replaced with JSON metadata:
```json
{
  "size": 242128,
  "sha256": "5c4f6f9dfadd608eb303e10f02a6308e5d2b090707f9f5db0979d11405aaadf6",
  "note": "Binary file excluded from repository. Metadata only."
}
```

This keeps the repository small (~100MB) while tracking when binary files change.
