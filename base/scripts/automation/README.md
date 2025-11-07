# CK3 Mod Base - Automation Scripts

This directory contains all the automation infrastructure for managing CK3 base files.

## Setup

1. **Install Node.js dependencies:**
   ```bash
   cd base/scripts
   npm install
   ```

2. **Install DepotDownloader** (for manual use - GitHub Actions automates this):
   ```bash
   # Clone and checkout specific commit
   git clone https://github.com/SteamRE/DepotDownloader.git /tmp/depot
   cd /tmp/depot
   git checkout 007857c13fa3b32c30d20ee078dd6f1ea0075402

   # Apply our 2FA automation patch
   git apply /path/to/ck3-base/base/scripts/depotdownloader.patch

   # Build for your platform
   dotnet publish -c Release -r linux-x64 --self-contained -o ./out

   # Add to PATH or copy binary
   cp ./out/DepotDownloader /usr/local/bin/
   ```

## Usage

The `index.js` script provides four commands:

### 1. Check for Updates
```bash
node index.js check          # Print latest CK3 version
node index.js check 1.18.0.2 # Compare against version
```

### 2. Download Game Files
```bash
# Set credentials via environment variables
STEAM_USERNAME=myuser STEAM_PASSWORD=mypass \
  node index.js download 1.18.0.2 /tmp/ck3

# For CI/automation with TOTP (generates 2FA codes automatically)
STEAM_USERNAME=myuser STEAM_PASSWORD=mypass STEAM_TOTP_SECRET=your_shared_secret \
  node index.js download 1.18.0.2 /tmp/ck3
```

### 3. Parse Metadata
```bash
node index.js parse /tmp/ck3 .. ../release-notes
```
This will:
- Parse depot manifests to extract version info
- Fetch DLC names from Steam API
- Download and convert release notes to Markdown
- Create `.ck3-version.json` metadata file in `base/`

### 4. Extract Game Files
```bash
node index.js extract /tmp/ck3 ../game
```
This will:
- Copy all text files (`.txt`, `.yml`, `.csv`, `.gui`, etc.)
- Replace binary files with JSON placeholders containing SHA256 + size
- Keep original file extensions for placeholders
- Output to `base/game/`

## Binary Placeholders

Binary files are replaced with JSON metadata files that keep the original extension:

```json
{
  "size": 242128,
  "sha256": "5c4f6f9dfadd608eb303e10f02a6308e5d2b090707f9f5db0979d11405aaadf6",
  "note": "Binary file excluded from repository. Metadata only."
}
```

This approach:
- Keeps repository size small (~100MB vs ~4GB)
- Maintains directory structure
- Allows tracking when binary files change (via SHA256)
- Makes all changes diffable in Git

## GitHub Actions

The workflow in `../../.github/workflows/` automates the entire process:
1. Builds patched DepotDownloader (cached by commit + patch hash)
2. Checks for CK3 updates daily at 12:00 UTC
3. Downloads, parses, and extracts files
4. Commits changes automatically

Required secrets (configured in repository settings):
- `STEAM_USERNAME` - Steam account username
- `STEAM_PASSWORD` - Steam account password
- `STEAM_TOTP_SECRET` - Steam shared secret for TOTP generation

The workflow runs all commands from this directory (`base/scripts/`).

## Version Metadata Format

`../.ck3-version.json` (in `base/`) contains:
```json
{
  "version": "1.18.0.2",
  "version_name": "Crane",
  "updated": "2025-11-04T11:40:05.000Z",
  "release_notes": {
    "title": "1.18.0.2",
    "date": "2025-11-04",
    "file": "release-notes/1_18_0_2_2025-11-04.md",
    "url": "https://store.steampowered.com/..."
  },
  "depots": {
    "1158311": {
      "manifest": "8204785996215130844",
      "updated": "2025-11-03T17:56:13.000Z"
    },
    ...
  }
}
```

## Dependencies

- **protobufjs**: Parse depot manifest files
- **@bbob/html** + **@bbob/preset-html5**: Convert BBCode to HTML
- **turndown**: Convert HTML to Markdown
