#!/bin/bash
# install-quickshell.sh - Build and install Quickshell for Debian/Ubuntu/Pop_OS!
# This script installs the Quickshell framework required by noctalia-shell

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

QUICKSHELL_REPO="https://github.com/quickshell-mirror/quickshell.git"
BUILD_DIR="${QUICKSHELL_BUILD_DIR:-/tmp/quickshell-build}"
INSTALL_PREFIX="${QUICKSHELL_PREFIX:-/usr/local}"
QT_VERSION="6.8.3"
QT_INSTALL_DIR="/opt/qt${QT_VERSION}"

# Check if running as root for install step
check_root_for_install() {
    if [[ $EUID -ne 0 ]] && [[ "$INSTALL_PREFIX" == "/usr"* ]]; then
        log_error "Installation to $INSTALL_PREFIX requires root privileges"
        log_info "Run with: sudo $0"
        log_info "Or set QUICKSHELL_PREFIX to a user-writable location"
        exit 1
    fi
}

# Check if Quickshell is already installed
check_existing() {
    if command -v qs &> /dev/null; then
        log_info "Quickshell is already installed at: $(which qs)"
        qs --version 2>/dev/null || true
        read -p "Reinstall anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

# Check system Qt version and install Qt 6.7 if needed
setup_qt() {
    local qt_version
    qt_version=$(pkg-config --modversion Qt6Core 2>/dev/null || echo "0")
    local major minor
    major=$(echo "$qt_version" | cut -d. -f1)
    minor=$(echo "$qt_version" | cut -d. -f2)

    if [[ "$major" -ge 6 ]] && [[ "$minor" -ge 6 ]]; then
        log_info "System Qt version $qt_version is sufficient"
        USE_SYSTEM_QT=true
        return
    fi

    log_warn "System Qt version $qt_version is too old. Quickshell requires Qt 6.6+"

    # Check if we already have a working Qt installed via aqt
    if [[ -f "$QT_INSTALL_DIR/$QT_VERSION/gcc_64/bin/moc" ]]; then
        log_info "Found existing Qt installation at $QT_INSTALL_DIR"
        USE_SYSTEM_QT=false
        return
    fi

    # Remove incomplete Qt installation if exists
    if [[ -d "$QT_INSTALL_DIR" ]]; then
        log_warn "Removing incomplete Qt installation..."
        rm -rf "$QT_INSTALL_DIR"
    fi

    log_info "Installing Qt $QT_VERSION via aqtinstall..."
    install_qt_via_aqt
    USE_SYSTEM_QT=false
}

# Install Qt using aqtinstall
install_qt_via_aqt() {
    # Install aqtinstall
    apt-get install -y python3-pip python3-venv

    # Clean up any leftover aqt files
    rm -rf /tmp/aqt-venv /tmp/aqtinstall.log

    # Create a venv for aqt to avoid pip issues
    python3 -m venv /tmp/aqt-venv
    /tmp/aqt-venv/bin/pip install aqtinstall

    log_info "Downloading Qt $QT_VERSION (this may take a while)..."

    mkdir -p "$QT_INSTALL_DIR"

    # Run aqt from a clean temp directory to avoid log permission issues
    local aqt_workdir
    aqt_workdir=$(mktemp -d)
    cd "$aqt_workdir"

    # Note: Qt 6.8+ uses linux_gcc_64 for aqt, but installs to gcc_64 subdir
    /tmp/aqt-venv/bin/aqt install-qt linux desktop "$QT_VERSION" linux_gcc_64 \
        --outputdir "$QT_INSTALL_DIR" \
        --modules qtshadertools qtwaylandcompositor

    # Cleanup
    rm -rf /tmp/aqt-venv "$aqt_workdir"

    log_info "Qt $QT_VERSION installed to $QT_INSTALL_DIR"
}

# Install build dependencies
install_deps() {
    log_info "Installing build dependencies..."

    apt-get update
    apt-get install -y \
        git \
        cmake \
        ninja-build \
        pkg-config \
        libwayland-dev \
        wayland-protocols \
        libpipewire-0.3-dev \
        libpam0g-dev \
        libdrm-dev \
        libgbm-dev \
        libxcb1-dev \
        libxkbcommon-dev \
        libglib2.0-dev \
        libpolkit-gobject-1-dev \
        spirv-tools \
        libcli11-dev \
        libjemalloc-dev \
        libgl1-mesa-dev \
        libegl1-mesa-dev \
        libvulkan-dev

    log_info "Dependencies installed"
}

# Clone and build Quickshell
build_quickshell() {
    log_info "Cloning Quickshell repository..."

    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    git clone --depth 1 "$QUICKSHELL_REPO" quickshell
    cd quickshell

    local cmake_qt_args=()

    # Set up Qt environment if using aqt-installed Qt
    if [[ "${USE_SYSTEM_QT:-true}" == "false" ]]; then
        QT_PATH="$QT_INSTALL_DIR/$QT_VERSION/gcc_64"
        export PATH="$QT_PATH/bin:$PATH"
        export LD_LIBRARY_PATH="$QT_PATH/lib:${LD_LIBRARY_PATH:-}"
        export QT_PLUGIN_PATH="$QT_PATH/plugins"
        log_info "Using Qt from $QT_PATH"

        # Tell CMake to use our Qt installation exclusively
        cmake_qt_args=(
            "-DCMAKE_PREFIX_PATH=$QT_PATH"
            "-DQT_HOST_PATH=$QT_PATH"
            "-DQt6_DIR=$QT_PATH/lib/cmake/Qt6"
            "-DQt6CoreTools_DIR=$QT_PATH/lib/cmake/Qt6CoreTools"
            "-DQt6GuiTools_DIR=$QT_PATH/lib/cmake/Qt6GuiTools"
            "-DQt6QmlTools_DIR=$QT_PATH/lib/cmake/Qt6QmlTools"
            "-DQt6WidgetsTools_DIR=$QT_PATH/lib/cmake/Qt6WidgetsTools"
        )
    fi

    log_info "Configuring build..."
    cmake -GNinja -B build \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
        -DCRASH_REPORTER=OFF \
        "${cmake_qt_args[@]}"

    log_info "Building Quickshell (this may take a while)..."
    cmake --build build -j"$(nproc)"

    log_info "Build complete"
}

# Install Quickshell
install_quickshell() {
    log_info "Installing Quickshell to $INSTALL_PREFIX..."

    cd "$BUILD_DIR/quickshell"
    cmake --install build

    # Create wrapper script if using custom Qt
    if [[ "${USE_SYSTEM_QT:-true}" == "false" ]]; then
        QT_PATH="$QT_INSTALL_DIR/$QT_VERSION/gcc_64"
        log_info "Creating wrapper script for custom Qt..."

        # Only move if qs.real doesn't exist (idempotent)
        if [[ ! -f "$INSTALL_PREFIX/bin/qs.real" ]]; then
            mv "$INSTALL_PREFIX/bin/qs" "$INSTALL_PREFIX/bin/qs.real"
        fi
        cat > "$INSTALL_PREFIX/bin/qs" << EOF
#!/bin/bash
export LD_LIBRARY_PATH="$QT_PATH/lib:\${LD_LIBRARY_PATH:-}"
export QT_PLUGIN_PATH="$QT_PATH/plugins"
exec "$INSTALL_PREFIX/bin/qs.real" "\$@"
EOF
        chmod +x "$INSTALL_PREFIX/bin/qs"
    fi

    # Update library cache if installing to system path
    if [[ "$INSTALL_PREFIX" == "/usr"* ]]; then
        ldconfig
    fi

    log_info "Quickshell installed successfully!"
}

# Cleanup
cleanup() {
    read -p "Remove build directory ($BUILD_DIR)? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        rm -rf "$BUILD_DIR"
        log_info "Build directory removed"
    fi
}

# Main
main() {
    echo "========================================"
    echo "  Quickshell Installer for Debian/Ubuntu"
    echo "========================================"
    echo

    check_existing
    check_root_for_install
    install_deps
    setup_qt
    build_quickshell
    install_quickshell
    cleanup

    echo
    log_info "Installation complete!"
    log_info "You can now run: noctalia-shell"
    echo

    # Verify installation
    if command -v qs &> /dev/null; then
        log_info "Quickshell version: $(qs --version 2>&1 || echo 'installed')"
    else
        log_warn "qs not in PATH. You may need to add $INSTALL_PREFIX/bin to your PATH"
    fi
}

main "$@"
