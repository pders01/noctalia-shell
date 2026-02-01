#!/bin/bash
# install-sway.sh - Install Sway compositor for use with noctalia-shell
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
echo "  Sway Installer for Debian/Ubuntu"
echo "========================================"
echo

# Check if Sway is already installed
INSTALL_SWAY=true
if command -v sway &> /dev/null; then
    log_info "Sway is already installed: $(sway --version 2>&1)"
    read -p "Reinstall Sway packages? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        INSTALL_SWAY=false
    fi
fi

if [[ "$INSTALL_SWAY" == "true" ]]; then
    log_info "Installing Sway and utilities..."
    apt-get update
    apt-get install -y \
        sway \
        swaylock \
        swayidle \
        swaybg \
        foot \
        wofi \
        waybar \
        wl-clipboard \
        grim \
        slurp \
        mako-notifier \
        xwayland
fi

# Create session file for display manager (always, even if Sway packages were skipped)
log_info "Creating session entry for display manager..."
cat > /usr/share/wayland-sessions/sway-noctalia.desktop << 'EOF'
[Desktop Entry]
Name=Sway (Noctalia)
Comment=Sway compositor with Noctalia shell
Exec=sway
Type=Application
DesktopNames=sway
EOF

# Get the actual user (not root)
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)

# Create default Sway config for noctalia-shell
SWAY_CONFIG_DIR="$ACTUAL_HOME/.config/sway"
mkdir -p "$SWAY_CONFIG_DIR"

if [[ ! -f "$SWAY_CONFIG_DIR/config" ]]; then
    log_info "Creating default Sway config with noctalia-shell..."
    cat > "$SWAY_CONFIG_DIR/config" << 'EOF'
# Sway config for noctalia-shell
# See `man 5 sway` for reference

# Logo key as modifier
set $mod Mod4

# Terminal
set $term foot

# Noctalia shell path
set $noctalia /usr/share/noctalia-shell

# Application launcher (noctalia)
set $menu qs msg -p $noctalia launcher toggle

# Launch noctalia-shell on startup
exec noctalia-shell

# Disable default bar (noctalia provides this)
# bar { }

### Output configuration
# Default wallpaper
output * bg #1e1e2e solid_color

### Input configuration
input type:touchpad {
    tap enabled
    natural_scroll enabled
}

input type:keyboard {
    xkb_layout us
}

### Key bindings

# Launch terminal
bindsym $mod+Return exec $term

# Kill focused window
bindsym $mod+q kill

# Launch app launcher
bindsym $mod+r exec $menu

# Noctalia shortcuts
bindsym $mod+c exec qs msg -p $noctalia controlCenter toggle
bindsym $mod+n exec qs msg -p $noctalia notifications togglePanel
bindsym $mod+p exec qs msg -p $noctalia sessionMenu toggle
bindsym $mod+comma exec qs msg -p $noctalia settings toggle
bindsym $mod+Shift+w exec qs msg -p $noctalia wallpaper togglePanel
bindsym $mod+m exec qs msg -p $noctalia media togglePanel
bindsym $mod+t exec qs msg -p $noctalia calendar toggle

# Reload config
bindsym $mod+Shift+c reload

# Exit sway
bindsym $mod+Shift+e exec swaynag -t warning -m 'Exit sway?' -B 'Yes' 'swaymsg exit'

# Move focus
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
bindsym $mod+l focus right
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# Move windows
bindsym $mod+Shift+h move left
bindsym $mod+Shift+j move down
bindsym $mod+Shift+k move up
bindsym $mod+Shift+l move right
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# Workspaces
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5

# Move to workspace
bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5

# Layout
bindsym $mod+b splith
bindsym $mod+v splitv
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split
bindsym $mod+f fullscreen
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle
bindsym $mod+a focus parent

# Resize mode
mode "resize" {
    bindsym h resize shrink width 10px
    bindsym j resize grow height 10px
    bindsym k resize shrink height 10px
    bindsym l resize grow width 10px
    bindsym Left resize shrink width 10px
    bindsym Down resize grow height 10px
    bindsym Up resize shrink height 10px
    bindsym Right resize grow width 10px
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+Shift+r mode "resize"

# Window decorations
default_border pixel 2
gaps inner 5
gaps outer 5

# Colors (Catppuccin Mocha inspired)
client.focused          #b4befe #1e1e2e #cdd6f4 #f5e0dc #b4befe
client.focused_inactive #45475a #1e1e2e #cdd6f4 #f5e0dc #45475a
client.unfocused        #313244 #1e1e2e #a6adc8 #f5e0dc #313244
client.urgent           #f38ba8 #1e1e2e #cdd6f4 #f5e0dc #f38ba8

include /etc/sway/config.d/*
EOF
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$SWAY_CONFIG_DIR"
else
    log_warn "Sway config already exists. Add this to your config to launch noctalia:"
    echo "    exec noctalia-shell"
fi

# Create noctalia config directory and fix opacity bug
# Qt/Wayland has rendering issues with semi-transparent layer shell surfaces
NOCTALIA_CONFIG_DIR="$ACTUAL_HOME/.config/noctalia"
mkdir -p "$NOCTALIA_CONFIG_DIR"
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$NOCTALIA_CONFIG_DIR"

# If settings.json exists, fix the opacity; otherwise it will be created on first run
if [[ -f "$NOCTALIA_CONFIG_DIR/settings.json" ]]; then
    log_info "Fixing bar opacity in existing noctalia config..."
    python3 -c "
import json
with open('$NOCTALIA_CONFIG_DIR/settings.json', 'r+') as f:
    data = json.load(f)
    if 'bar' in data:
        data['bar']['backgroundOpacity'] = 1.0
    if 'ui' in data:
        data['ui']['panelBackgroundOpacity'] = 0
    f.seek(0)
    json.dump(data, f, indent=4)
    f.truncate()
" 2>/dev/null || true
fi

echo
log_info "Sway installed!"
log_info "Select 'Sway (Noctalia)' from your login screen."
log_info "Config: $SWAY_CONFIG_DIR/config"
