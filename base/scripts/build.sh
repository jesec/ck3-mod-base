#!/bin/bash
# CK3 Mod Builder
# Symlinked from root: build.sh -> base/scripts/build.sh
# Delete the symlink and create your own if you need custom build logic

set -e

OUTPUT_DIR="out"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "      $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║                  CK3 Mod Builder                          ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check Git
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    error "Not a git repository"
    exit 1
fi

# Check for mod/descriptor.mod
if [ ! -f "mod/descriptor.mod" ]; then
    error "mod/descriptor.mod not found"
    echo ""
    info "Create mod/descriptor.mod with your mod metadata"
    exit 1
fi

# Auto-detect base version
echo "[1/5] Detecting base version..."

# Find most recent commit that modified base/.ck3-version.json
BASE_COMMIT=$(git log --format="%H" -1 -- base/.ck3-version.json 2>/dev/null || echo "")

if [ -z "$BASE_COMMIT" ]; then
    error "No base version found"
    echo ""
    info "Make sure you have the full git history"
    exit 1
fi

# Read version from the .ck3-version.json file at that commit
CK3_VERSION=$(git show "$BASE_COMMIT:base/.ck3-version.json" | grep -o '"version": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
BASE_TAG="base/$CK3_VERSION"

success "Found CK3 base: $BASE_TAG (commit ${BASE_COMMIT:0:8})"
echo ""

# Find mod files
echo "[2/5] Finding your mod files..."

# Check for modified/new files in base/game/
CHANGED=$(git diff --name-only "$BASE_COMMIT"...HEAD | grep "^base/game/" || echo "")
NEW=$(git ls-files --others --exclude-standard | grep "^base/game/" || echo "")

BASE_FILES_COUNT=$(echo -e "$CHANGED\n$NEW" | grep -v "^$" | wc -l)

# Check for files in mod/
MOD_FILES_COUNT=0
if [ -d "mod" ]; then
    MOD_FILES_COUNT=$(find mod -type f 2>/dev/null | wc -l)
fi

TOTAL_COUNT=$((BASE_FILES_COUNT + MOD_FILES_COUNT))

if [ $TOTAL_COUNT -eq 0 ]; then
    warn "No mod files found"
    echo ""
    info "You can do both:"
    info "  - Modify vanilla: base/game/common/decisions/00_decisions.txt"
    info "  - Add new content: mod/common/decisions/my_decisions.txt"
    exit 0
fi

success "Found $BASE_FILES_COUNT file(s) in base/, $MOD_FILES_COUNT file(s) in mod/"
echo ""

# Clean output
echo "[3/5] Preparing output..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
success "Created: $OUTPUT_DIR/"
echo ""

# Build mod
echo "[4/5] Building mod..."

EXPORTED=0

# Step 1: Export changed files from base/game/
export_base_file() {
    local src="$1"
    [ ! -f "$src" ] && return

    # Strip base/game/ prefix: base/game/common/... -> common/...
    local rel="${src#base/game/}"

    # Output directly to root: out/common/...
    local dst="$OUTPUT_DIR/$rel"

    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    EXPORTED=$((EXPORTED + 1))
}

# Process all changed base files
while IFS= read -r file; do
    [ -z "$file" ] && continue
    export_base_file "$file"
done <<< "$CHANGED"

while IFS= read -r file; do
    [ -z "$file" ] && continue
    export_base_file "$file"
done <<< "$NEW"

BASE_EXPORTED=$EXPORTED

# Step 2: Copy all files from mod/ (overwrites base/ if conflicts)
MOD_EXPORTED=0
if [ -d "mod" ]; then
    # Copy ALL files from mod/ directory
    while IFS= read -r src; do
        [ -z "$src" ] && continue
        # Strip mod/ prefix: mod/common/... -> common/...
        rel="${src#mod/}"
        dst="$OUTPUT_DIR/$rel"

        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        MOD_EXPORTED=$((MOD_EXPORTED + 1))
    done <<< "$(find mod -type f 2>/dev/null)"
fi

success "Exported: $BASE_EXPORTED from base/, $MOD_EXPORTED from mod/"
echo ""

# Finalize
echo "[5/5] Finalizing..."

# Build info
cat > "$OUTPUT_DIR/BUILD_INFO.txt" << EOF
CK3 Mod - Built $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Base: $CK3_VERSION (commit ${BASE_COMMIT:0:8})
Files: $BASE_EXPORTED from base/, $MOD_EXPORTED from mod/
EOF

success "Ready!"
echo ""

# Success
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║                   BUILD SUCCESSFUL!                       ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Your mod: $(pwd)/$OUTPUT_DIR/"
echo ""
echo "┌───────────────────────────────────────────────────────────┐"
echo "│ TO INSTALL IN CK3:                                        │"
echo "├───────────────────────────────────────────────────────────┤"
echo "│ Quick install:                                            │"
echo "│   bash install.sh                                         │"
echo "│                                                           │"
echo "│ Manual install:                                           │"
echo "│   1. Create your-mod.mod in CK3 mod directory            │"
echo "│   2. Copy descriptor.mod content + add path field        │"
echo "└───────────────────────────────────────────────────────────┘"
echo ""
