# Mod Directory

> **Note:** This is a symlink to `base/docs/mod.md`. Delete it to create your own README to distribute with your mod.

This directory is for mod files you want to keep completely independent from base game files.

**Everything in `mod/` is always included in the build.**

## When to Use mod/

**Use `mod/` for:**
- New standalone content (decisions, events, traits, etc.)
- Files you always want to fully control
- Mod metadata: `descriptor.mod`, `thumbnail.png`, `README.md`

**Use `base/game/` for:**
- Modifying vanilla files (benefits from automatic merge when CK3 updates)
- Content you want to keep in sync with game updates

**You can use both!** Most mods will have some files in `base/game/` (vanilla modifications) and some in `mod/` (new content).

## Trade-off: mod/ vs base/game/

### Files in `mod/`
- **Always override** `base/game/` if same path exists
- **Never get merge conflicts** when CK3 updates are pulled to the repo
- **No automatic updates** - you don't benefit from git merge workflow

### Files in `base/game/`
- **Get automatic updates and diff view** when you merge CK3 updates
- **May have merge conflicts** that need manual resolution
- Only modified files are included in your mod

## Required Files

### descriptor.mod (REQUIRED)

Every mod needs this file:

```
version="1.0.0"
name="My Awesome Mod"
supported_version="1.18.0.*"
tags={
    "Gameplay"
    "Events"
}
```

### thumbnail.png (Recommended)

256x256 PNG for your mod icon on Steam Workshop.

### README.md (Optional)

Document your mod's features, credits, and compatibility notes. Delete the symlink and create your own.

## Directory Structure

```
mod/
├── descriptor.mod           ← Mod metadata (REQUIRED)
├── thumbnail.png            ← Mod icon (optional)
├── README.md                ← Your documentation (optional)
├── common/
│   ├── decisions/
│   ├── events/
│   └── traits/
├── localization/
│   └── english/
└── gfx/                     ← Your content
```
