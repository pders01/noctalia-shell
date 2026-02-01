#!/bin/bash
# uninstall-hyprland.sh - Remove Hyprland compositor
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
echo "  Hyprland Uninstaller"
echo "========================================"
echo

# Confirm
read -p "This will remove Hyprland and its config. Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Cancelled"
    exit 0
fi

# Check if installed via package manager
if dpkg -l | grep -q "^ii.*hyprland"; then
    log_info "Removing Hyprland package..."
    apt-get remove -y hyprland
    apt-get autoremove -y
else
    # Remove manually installed files
    log_info "Removing manually installed Hyprland..."

    # Binaries
    rm -f /usr/local/bin/Hyprland
    rm -f /usr/local/bin/hyprctl
    rm -f /usr/local/bin/hyprpm

    # Libraries
    rm -f /usr/local/lib/libhyprland*.so*
    rm -rf /usr/local/lib/hyprland/

    # Includes
    rm -rf /usr/local/include/hyprland/

    # Share files
    rm -rf /usr/local/share/hyprland/
    rm -f /usr/local/share/wayland-sessions/hyprland.desktop
    rm -f /usr/local/share/applications/hyprland.desktop

    # Pkg-config
    rm -f /usr/local/lib/pkgconfig/hyprland*.pc
    rm -f /usr/local/share/pkgconfig/hyprland*.pc

    ldconfig
fi

# Remove session file
log_info "Removing session entry..."
rm -f /usr/share/wayland-sessions/hyprland-noctalia.desktop
rm -f /usr/share/wayland-sessions/hyprland.desktop

# Get the actual user
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
HYPR_CONFIG_DIR="$ACTUAL_HOME/.config/hypr"

# Ask about config
if [[ -d "$HYPR_CONFIG_DIR" ]]; then
    read -p "Remove Hyprland config ($HYPR_CONFIG_DIR)? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$HYPR_CONFIG_DIR"
        log_info "Config removed"
    else
        log_info "Config preserved at $HYPR_CONFIG_DIR"
    fi
fi

echo
log_info "Hyprland uninstalled!"
