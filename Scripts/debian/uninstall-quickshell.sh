#!/bin/bash
# uninstall-quickshell.sh - Remove Quickshell and optionally Qt
# For Debian/Ubuntu/Pop_OS!

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

INSTALL_PREFIX="/usr/local"
QT_INSTALL_DIR="/opt/qt6.8.3"

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

echo "========================================"
echo "  Quickshell Uninstaller"
echo "========================================"
echo

# Confirm
read -p "This will remove Quickshell. Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Cancelled"
    exit 0
fi

log_info "Removing Quickshell..."

# Remove binaries
rm -f "$INSTALL_PREFIX/bin/qs"
rm -f "$INSTALL_PREFIX/bin/qs.real"
rm -f "$INSTALL_PREFIX/bin/quickshell"

# Remove desktop file and icons
rm -f "$INSTALL_PREFIX/share/applications/org.quickshell.desktop"
rm -f "$INSTALL_PREFIX/share/icons/hicolor/scalable/apps/org.quickshell.svg"

# Update library cache
ldconfig

log_info "Quickshell removed"

# Ask about Qt
if [[ -d "$QT_INSTALL_DIR" ]]; then
    echo
    read -p "Remove custom Qt installation ($QT_INSTALL_DIR)? This frees ~1GB. [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$QT_INSTALL_DIR"
        log_info "Qt installation removed"
    else
        log_info "Qt preserved at $QT_INSTALL_DIR"
    fi
fi

echo
log_info "Quickshell uninstalled!"
log_info "Run 'sudo apt remove noctalia-shell' to also remove noctalia-shell."
