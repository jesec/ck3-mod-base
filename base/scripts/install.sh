#!/bin/bash
# CK3 Mod Installer
# Symlinked from root: install.sh -> base/scripts/install.sh
# Delete the symlink and create your own if you need custom install logic
# Usage: bash install.sh [copy|link|uninstall]

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "      $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
prompt() { echo -e "${CYAN}?${NC} $1"; }

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║                  CK3 Mod Installer                        ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check for out/ directory
if [ ! -d "out" ]; then
    error "out/ directory not found"
    echo ""
    info "Run: bash build.sh"
    exit 1
fi

# Check for mod/descriptor.mod
if [ ! -f "mod/descriptor.mod" ]; then
    error "mod/descriptor.mod not found"
    exit 1
fi

# Detect CK3 mod directory
# Handles: WSL, Git Bash (MINGW), macOS, native Linux
CK3_MOD_DIR=""

# WSL (Windows Subsystem for Linux)
# Check for WSL-specific environment variables
if [ -n "$WSL_DISTRO_NAME" ] || [ -n "$WSL_INTEROP" ]; then
    # Get actual Windows username (may differ from WSL username)
    WINDOWS_USER=$(powershell.exe -NoProfile -Command '$env:USERNAME' 2>/dev/null | tr -d '\r\n')

    # Fallback: try to detect from /mnt/c/Users
    if [ -z "$WINDOWS_USER" ] && [ -d "/mnt/c/Users" ]; then
        POSSIBLE_USER=$(ls -td /mnt/c/Users/*/ 2>/dev/null | grep -v "Public\|Default\|All Users" | head -1 | xargs basename)
        [ -n "$POSSIBLE_USER" ] && WINDOWS_USER="$POSSIBLE_USER"
    fi

    # Final fallback: use WSL username
    [ -z "$WINDOWS_USER" ] && WINDOWS_USER="$USER"

    CK3_MOD_DIR="/mnt/c/Users/$WINDOWS_USER/Documents/Paradox Interactive/Crusader Kings III/mod"

# Git Bash / MINGW / MSYS (Windows)
# Check for MSYSTEM environment variable
elif [ -n "$MSYSTEM" ]; then
    if [ -n "$USERPROFILE" ]; then
        # Use cygpath if available to convert Windows paths
        CK3_MOD_DIR="$(cygpath -u "$USERPROFILE" 2>/dev/null || echo "$USERPROFILE" | sed 's|\\|/|g' | sed 's|C:|/c|')/Documents/Paradox Interactive/Crusader Kings III/mod"
    else
        # Fallback to /c/ style path
        CK3_MOD_DIR="/c/Users/$USER/Documents/Paradox Interactive/Crusader Kings III/mod"
    fi

# macOS
elif [ "$(uname -s)" == "Darwin" ]; then
    CK3_MOD_DIR="$HOME/Documents/Paradox Interactive/Crusader Kings III/mod"

# Native Linux (fallback)
else
    CK3_MOD_DIR="$HOME/.local/share/Paradox Interactive/Crusader Kings III/mod"
fi

if [ -z "$CK3_MOD_DIR" ]; then
    error "Could not detect CK3 mod directory"
    echo ""
    info "Please specify manually:"
    read -p "CK3 mod directory: " CK3_MOD_DIR
fi

if [ ! -d "$CK3_MOD_DIR" ]; then
    warn "CK3 mod directory not found: $CK3_MOD_DIR"
    read -p "Create it? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$CK3_MOD_DIR"
        success "Created: $CK3_MOD_DIR"
    else
        exit 1
    fi
fi

# Get mod name from descriptor.mod
MOD_NAME=$(grep -o 'name="[^"]*"' mod/descriptor.mod | sed 's/name="\(.*\)"/\1/' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
if [ -z "$MOD_NAME" ]; then
    MOD_NAME="my-mod"
    warn "Could not detect mod name, using: $MOD_NAME"
fi

# Determine install mode
INSTALL_MODE="$1"

if [ -z "$INSTALL_MODE" ]; then
    # Interactive mode
    echo ""
    prompt "Choose action:"
    echo ""
    info "  1. Copy install"
    info "     Copies files to CK3 mod folder"
    info "     Use for: final testing, sharing with others"
    echo ""
    info "  2. Link install (faster for active development)"
    info "     Points to your build output directly"
    info "     Use for: rapid iteration, just rebuild and reload"
    echo ""
    info "  3. Uninstall"
    info "     Removes mod from CK3"
    echo ""
    read -p "Mode (1/2/3): " -n 1 -r
    echo ""

    if [[ $REPLY == "1" ]]; then
        INSTALL_MODE="copy"
    elif [[ $REPLY == "2" ]]; then
        INSTALL_MODE="link"
    elif [[ $REPLY == "3" ]]; then
        INSTALL_MODE="uninstall"
    else
        error "Invalid choice"
        exit 1
    fi
fi

# Validate mode
if [ "$INSTALL_MODE" != "copy" ] && [ "$INSTALL_MODE" != "link" ] && [ "$INSTALL_MODE" != "uninstall" ]; then
    error "Invalid mode: $INSTALL_MODE"
    info "Usage: bash install.sh [copy|link|uninstall]"
    exit 1
fi

MOD_FILE="$CK3_MOD_DIR/$MOD_NAME.mod"
MOD_CONTENT_DIR="$CK3_MOD_DIR/$MOD_NAME"

# Perform action based on mode
if [ "$INSTALL_MODE" == "uninstall" ]; then
    # Uninstall
    echo ""
    echo "Uninstalling: $MOD_NAME"
    info "Target: $CK3_MOD_DIR"
    echo ""

    REMOVED_COUNT=0

    if [ -f "$MOD_FILE" ]; then
        rm "$MOD_FILE"
        success "Removed: $MOD_FILE"
        REMOVED_COUNT=$((REMOVED_COUNT + 1))
    fi

    if [ -d "$MOD_CONTENT_DIR" ]; then
        rm -rf "$MOD_CONTENT_DIR"
        success "Removed: $MOD_CONTENT_DIR"
        REMOVED_COUNT=$((REMOVED_COUNT + 1))
    fi

    if [ $REMOVED_COUNT -eq 0 ]; then
        warn "Mod not found (already uninstalled)"
    else
        echo ""
        echo "╔═══════════════════════════════════════════════════════════╗"
        echo "║                                                           ║"
        echo "║                UNINSTALL SUCCESSFUL!                      ║"
        echo "║                                                           ║"
        echo "╚═══════════════════════════════════════════════════════════╝"
        echo ""
    fi
else
    # Install
    echo ""
    echo "Installing: $MOD_NAME"
    info "Mode: $INSTALL_MODE"
    info "Target: $CK3_MOD_DIR"
    echo ""

    if [ "$INSTALL_MODE" == "copy" ]; then
        # Copy install
        echo "Installing (copy mode)..."

        # Create/update .mod file with relative path
        cat mod/descriptor.mod > "$MOD_FILE"
        echo "path=\"mod/$MOD_NAME\"" >> "$MOD_FILE"
        success "Created: $MOD_FILE"

        # Copy out/ contents
        rm -rf "$MOD_CONTENT_DIR"
        mkdir -p "$MOD_CONTENT_DIR"
        cp -r out/* "$MOD_CONTENT_DIR/"

        FILE_COUNT=$(find "$MOD_CONTENT_DIR" -type f | wc -l)
        success "Copied $FILE_COUNT file(s) to: $MOD_CONTENT_DIR"

    elif [ "$INSTALL_MODE" == "link" ]; then
        # Link install
        echo "Installing (link mode)..."

        OUTPUT_PATH="$(pwd)/out"

        # For WSL/Git Bash: need Windows path, check if repo is accessible from Windows
        if [ -n "$WSL_DISTRO_NAME" ] || [ -n "$WSL_INTEROP" ]; then
            # WSL: Check if on Windows drive
            case "$(pwd)" in
                /mnt/*)
                    # On Windows drive, convert to Windows path
                    if command -v wslpath &>/dev/null; then
                        OUTPUT_PATH=$(wslpath -w "$(pwd)/out")
                    else
                        # Fallback: manual conversion /mnt/c/path -> C:\path
                        OUTPUT_PATH=$(echo "$(pwd)/out" | sed 's|^/mnt/\([a-z]\)/|\1:/|' | sed 's|^\(.\):/|\U\1:/|' | sed 's|/|\\|g')
                    fi
                    ;;
                *)
                    # On Linux filesystem - CK3 cannot access this
                    error "Link mode not supported: repository is on WSL Linux filesystem"
                    echo ""
                    info "CK3 running on Windows cannot access WSL's native filesystem"
                    info "Solutions:"
                    info "  1. Use copy mode instead: bash install.sh copy"
                    info "  2. Move repository to Windows drive (e.g., /mnt/c/...)"
                    exit 1
                    ;;
            esac
        elif [ -n "$MSYSTEM" ]; then
            # Git Bash: Check if on Windows drive
            case "$(pwd)" in
                /[a-z]/*)
                    # Convert /c/path -> C:\path
                    if command -v cygpath &>/dev/null; then
                        OUTPUT_PATH=$(cygpath -w "$(pwd)/out")
                    else
                        # Fallback: manual conversion /c/path -> C:\path
                        OUTPUT_PATH=$(echo "$(pwd)/out" | sed 's|^/\([a-z]\)/|\1:/|' | sed 's|^\(.\):/|\U\1:/|' | sed 's|/|\\|g')
                    fi
                    ;;
                *)
                    error "Link mode not supported: unknown path format"
                    info "Use copy mode instead: bash install.sh copy"
                    exit 1
                    ;;
            esac
        fi

        # Create/update .mod file with absolute path
        cat mod/descriptor.mod > "$MOD_FILE"
        echo "path=\"$OUTPUT_PATH\"" >> "$MOD_FILE"
        success "Created: $MOD_FILE"

        info "Pointing to: $OUTPUT_PATH"
        warn "Remember to run 'bash build.sh' after making changes"
    fi

    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║                 INSTALL SUCCESSFUL!                       ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    info "Launch CK3 and enable '$MOD_NAME' in the launcher"
    echo ""
fi
