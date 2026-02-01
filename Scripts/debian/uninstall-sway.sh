#!/bin/bash
# uninstall-sway.sh - Remove Sway compositor
# For Debian/Ubuntu/Pop_OS!

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

echo "========================================"
echo "  Sway Uninstaller"
echo "========================================"
echo

# Confirm
read -p "This will remove Sway and related packages. Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Cancelled"
    exit 0
fi

log_info "Removing Sway and utilities..."
apt-get remove -y \
    sway \
    swaylock \
    swayidle \
    swaybg \
    || true

apt-get autoremove -y

# Remove session file
log_info "Removing session entry..."
rm -f /usr/share/wayland-sessions/sway-noctalia.desktop

# Get the actual user
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
SWAY_CONFIG_DIR="$ACTUAL_HOME/.config/sway"

# Ask about config
if [[ -d "$SWAY_CONFIG_DIR" ]]; then
    read -p "Remove Sway config ($SWAY_CONFIG_DIR)? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$SWAY_CONFIG_DIR"
        log_info "Config removed"
    else
        log_info "Config preserved at $SWAY_CONFIG_DIR"
    fi
fi

echo
log_info "Sway uninstalled!"
