# CK3 Mod Base

**Git-versioned CK3 base game files for mod development**

> **Note:** This is a symlink to `base/docs/repo.md`. Delete it to create your own README to customize what users see when browsing your mod repository on GitHub.

This repository provides CK3 base game files in a Git-friendly format, enabling automatic merge workflows for mod updates.

## 🚀 Quick Start

```bash
# 1. Clone this repository
git clone https://github.com/jesec/ck3-mod-base.git name-of-my-mod
cd name-of-my-mod

# 2. Create your mod files
#    Modify vanilla files (you can do both)
code base/game/common/decisions/00_decisions.txt

#    Add new files in mod/ (if you want to keep some stuff separate, or always overriding)
#    NOTE: mod/ always override base/, meaning that you would not benefit from git merging / diff based flow
mkdir -p mod/common/decisions
code mod/common/decisions/my_decisions.txt

# 3. Configure your mod
code mod/descriptor.mod

# 4. Build
bash build.sh

# 5. Install
bash install.sh
# Copy install: Copies files to CK3 mod folder
# Link install: Points to your build output directly
```

## 📁 Structure

```
name-of-my-mod/
├── base/
│   └── game/                    ← Base game files
│       └── common/, etc.        ← Modify/add your content
├── mod/                         ← Your mod files (overrides base/game/)
│   ├── descriptor.mod           ← Mod metadata (required)
│   ├── thumbnail.png            ← Mod icon (optional)
│   └── common/, etc.            ← Your content
├── out/                         ← Build output (git ignored)
├── build.sh / build.bat         ← Build scripts
└── install.sh / install.bat     ← Install scripts
```

**Key concept:**
- Edit `base/game/` to modify vanilla files (only modified files are included in your mod)
- Add files to `mod/` to keep content independent / always overriding
- `mod/` files **always override** `base/` files if same path
- Build detects and copies modified files in `base/` + all of `mod/` → `out/`

## 📖 Documentation

- **[mod/README.md](mod/README.md)** - About the mod/ directory and workflow options

## 💬 Support

- **Issues**: [GitHub Issues](https://github.com/jesec/ck3-mod-base/issues)
- **Discussions**: [GitHub Discussions](https://github.com/jesec/ck3-mod-base/discussions)

## 🔄 When CK3 Updates

```bash
# 1. Fetch updates
git fetch origin

# 2. Merge new CK3 version
git merge base/1.19.0

# 3. Resolve conflicts (if any) and rebuild
bash build.sh
```

## 📄 License

**Your mod content is yours.** You own all your modifications and new content.

**Base game files** (`base/game/`) are copyrighted by Paradox Interactive. See [base/LICENSE-GAME-CONTENT](base/LICENSE-GAME-CONTENT) for details.

**Automation and documentation** provided in this repository are freely available for modding purposes. See [base/LICENSE](base/LICENSE) for details.
