#!/bin/bash
# install-all.sh - Complete noctalia-shell installation for Debian/Ubuntu/Pop_OS!
# Installs both Quickshell and noctalia-shell

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

echo "========================================"
echo "  Noctalia Shell - Complete Installer"
echo "========================================"
echo

# Step 1: Install Quickshell
log_info "Step 1/3: Installing Quickshell..."
"$SCRIPT_DIR/install-quickshell.sh"

# Step 2: Build noctalia-shell .deb
log_info "Step 2/3: Building noctalia-shell package..."
cd "$PROJECT_ROOT"

apt-get install -y debhelper devscripts rsync fakeroot
dpkg-buildpackage -us -uc -b

# Step 3: Install noctalia-shell
log_info "Step 3/3: Installing noctalia-shell..."
DEB_FILE=$(ls ../noctalia-shell_*.deb | head -1)
apt install -y "$DEB_FILE"

echo
log_info "Installation complete!"
log_info "Run 'noctalia-shell' to start the shell."
