#!/bin/bash
# install-hyprland.sh - Install Hyprland compositor for use with noctalia-shell
# For Debian/Ubuntu/Pop_OS!

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

HYPRLAND_BUILD_DIR="/tmp/hyprland-build"
INSTALL_PREFIX="/usr/local"

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

echo "========================================"
echo "  Hyprland Installer for Debian/Ubuntu"
echo "========================================"
echo

# Check if Hyprland is already installed
if command -v Hyprland &> /dev/null; then
    log_info "Hyprland is already installed: $(Hyprland --version 2>&1 | head -1)"
    read -p "Reinstall anyway? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

log_info "Installing Hyprland build dependencies..."

apt-get update
apt-get install -y \
    git \
    meson \
    ninja-build \
    cmake \
    pkg-config \
    build-essential \
    libwayland-dev \
    wayland-protocols \
    libdrm-dev \
    libgbm-dev \
    libinput-dev \
    libxkbcommon-dev \
    libudev-dev \
    libpixman-1-dev \
    libcairo2-dev \
    libpango1.0-dev \
    libxcb-dri3-dev \
    libxcb-present-dev \
    libxcb-composite0-dev \
    libxcb-render-util0-dev \
    libxcb-ewmh-dev \
    libxcb-xinput-dev \
    libxcb-icccm4-dev \
    libxcb-res0-dev \
    libtomlplusplus-dev \
    libzip-dev \
    librsvg2-dev \
    libmagic-dev \
    libdisplay-info-dev \
    libliftoff-dev \
    libseat-dev \
    hwdata \
    xwayland \
    glslang-tools \
    libxcb-errors-dev \
    edid-decode \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libegl-dev \
    libgles-dev \
    libgbm-dev \
    libxcb-util-dev

# Try package manager first
if apt-cache show hyprland &> /dev/null; then
    log_info "Installing Hyprland from package manager..."
    apt-get install -y hyprland
else
    log_info "Building Hyprland from source..."

    rm -rf "$HYPRLAND_BUILD_DIR"
    mkdir -p "$HYPRLAND_BUILD_DIR"
    cd "$HYPRLAND_BUILD_DIR"

    # Clone Hyprland
    git clone --recursive https://github.com/hyprwm/Hyprland
    cd Hyprland

    # Build
    make all

    # Install
    make install

    log_info "Hyprland built and installed"
fi

# Install common Hyprland utilities
log_info "Installing Hyprland utilities..."
apt-get install -y \
    foot \
    wofi \
    wl-clipboard \
    grim \
    slurp \
    mako-notifier \
    || true  # Don't fail if some aren't available

# Create session file for display manager
log_info "Creating session entry for display manager..."
mkdir -p /usr/share/wayland-sessions
cat > /usr/share/wayland-sessions/hyprland-noctalia.desktop << 'EOF'
[Desktop Entry]
Name=Hyprland (Noctalia)
Comment=Hyprland compositor with Noctalia shell
Exec=Hyprland
Type=Application
DesktopNames=Hyprland
EOF

# Get the actual user (not root)
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)

# Create default Hyprland config for noctalia-shell
HYPR_CONFIG_DIR="$ACTUAL_HOME/.config/hypr"
mkdir -p "$HYPR_CONFIG_DIR"

if [[ ! -f "$HYPR_CONFIG_DIR/hyprland.conf" ]]; then
    log_info "Creating default Hyprland config with noctalia-shell..."
    cat > "$HYPR_CONFIG_DIR/hyprland.conf" << 'EOF'
# Hyprland config for noctalia-shell
# See https://wiki.hyprland.org/Configuring/

# Monitor config (adjust to your setup)
monitor=,preferred,auto,1

# Launch noctalia-shell on startup
exec-once = noctalia-shell

# Basic input config
input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = true
    }
}

# General settings
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(b4befeee) rgba(cba6f7ee) 45deg
    col.inactive_border = rgba(313244aa)
    layout = dwindle
}

# Decoration
decoration {
    rounding = 10
    blur {
        enabled = true
        size = 8
        passes = 2
    }
    drop_shadow = true
    shadow_range = 15
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
}

# Animations
animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Key bindings
$mainMod = SUPER

bind = $mainMod, Return, exec, foot
bind = $mainMod, Q, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, E, exec, nautilus
bind = $mainMod, V, togglefloating,
bind = $mainMod, R, exec, wofi --show drun
bind = $mainMod, F, fullscreen,

# Move focus
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d
bind = $mainMod, H, movefocus, l
bind = $mainMod, L, movefocus, r
bind = $mainMod, K, movefocus, u
bind = $mainMod, J, movefocus, d

# Workspaces
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5

# Move to workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5

# Mouse bindings
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow
EOF
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$HYPR_CONFIG_DIR"
else
    log_warn "Hyprland config already exists. Add this to your config to launch noctalia:"
    echo "    exec-once = noctalia-shell"
fi

# Cleanup build dir
read -p "Remove build directory ($HYPRLAND_BUILD_DIR)? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    rm -rf "$HYPRLAND_BUILD_DIR"
    log_info "Build directory removed"
fi

echo
log_info "Hyprland installed!"
log_info "Select 'Hyprland (Noctalia)' from your login screen."
log_info "Config: $HYPR_CONFIG_DIR/hyprland.conf"
