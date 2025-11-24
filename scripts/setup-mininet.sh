#!/bin/bash
# setup-mininet.sh - Install OpenNet's customized Mininet fork
#
# This script clones and installs the dlinknctu/mininet fork with OpenNet extensions.
# Designed for Ubuntu 22.04+ and Debian 12+.
#
# Usage:
#   ./scripts/setup-mininet.sh [OPTIONS]
#
# Options:
#   --install-dir DIR    Install Mininet to DIR (default: ~/mininet)
#   --skip-clone         Skip cloning if directory exists
#   --install-deps       Install system dependencies first
#   --help               Show this help message
#
# Note: This script requires sudo for some operations.

set -euo pipefail

# Default configuration
MININET_REPO="https://github.com/dlinknctu/mininet.git"
MININET_BRANCH="opennet"
INSTALL_DIR="${HOME}/mininet"
SKIP_CLONE=false
INSTALL_DEPS=false

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

show_help() {
    head -25 "$0" | tail -17
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --skip-clone)
            SKIP_CLONE=true
            shift
            ;;
        --install-deps)
            INSTALL_DEPS=true
            shift
            ;;
        --help|-h)
            show_help
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

info "OpenNet Mininet Setup Script"
info "============================"
info "Repository: ${MININET_REPO}"
info "Branch: ${MININET_BRANCH}"
info "Install directory: ${INSTALL_DIR}"

# Install dependencies if requested
if [[ "${INSTALL_DEPS}" == "true" ]]; then
    info "Installing Mininet dependencies..."

    sudo apt-get update
    sudo apt-get install -y \
        git \
        python3 \
        python3-pip \
        python3-setuptools \
        cgroup-tools \
        ethtool \
        help2man \
        pyflakes3 \
        pylint \
        pep8 \
        psmisc \
        xterm \
        ssh \
        iperf \
        iperf3 \
        net-tools \
        socat \
        telnet \
        tcpdump \
        openvswitch-switch \
        openvswitch-common

    info "Dependencies installed successfully"
fi

# Clone Mininet if not already present
if [[ -d "${INSTALL_DIR}" ]]; then
    if [[ "${SKIP_CLONE}" == "true" ]]; then
        info "Mininet directory exists, skipping clone (--skip-clone)"
    else
        warn "Mininet directory already exists at ${INSTALL_DIR}"
        warn "Use --skip-clone to use existing directory, or remove it first"
        read -p "Remove existing directory and re-clone? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "Removing existing Mininet directory..."
            rm -rf "${INSTALL_DIR}"
        else
            info "Using existing directory..."
            SKIP_CLONE=true
        fi
    fi
fi

if [[ ! -d "${INSTALL_DIR}" ]]; then
    info "Cloning Mininet repository..."
    git clone --branch "${MININET_BRANCH}" "${MININET_REPO}" "${INSTALL_DIR}"

    if [[ $? -ne 0 ]]; then
        error "Failed to clone Mininet repository"
    fi
    info "Repository cloned successfully"
fi

# Check Python version
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
info "Python version: ${PYTHON_VERSION}"

# Check for Python 2 dependencies in install script
if [[ -f "${INSTALL_DIR}/util/install.sh" ]]; then
    if grep -q "python-" "${INSTALL_DIR}/util/install.sh" 2>/dev/null; then
        warn "Mininet install.sh may contain Python 2 package references"
        warn "Some packages may need manual adjustment for Python 3"
    fi
fi

# Run Mininet installation
info "Installing Mininet (core only, -n flag)..."
cd "${INSTALL_DIR}"

# Try to run the install script
if [[ -x "./util/install.sh" ]]; then
    # The -n flag installs Mininet core only (no extras like POX, NOX, etc.)
    sudo ./util/install.sh -n || {
        warn "Mininet install.sh had some issues (may be expected on modern systems)"
        warn "Trying alternative installation method..."

        # Alternative: direct pip install
        if [[ -f "setup.py" ]]; then
            info "Attempting pip install..."
            sudo pip3 install -e . || warn "pip install failed"
        fi
    }
else
    error "Mininet install.sh not found or not executable"
fi

# Verify installation
info "Verifying Mininet installation..."

if command -v mn &> /dev/null; then
    MN_VERSION=$(mn --version 2>&1 || echo "unknown")
    info "Mininet installed successfully!"
    info "Version: ${MN_VERSION}"
else
    warn "Mininet 'mn' command not found in PATH"
    warn "You may need to add ${INSTALL_DIR}/bin to your PATH"
fi

# Check for OpenNet-specific modules
info "Checking for OpenNet modules..."

OPENNET_MODULES=(
    "mininet/ns3.py"
    "mininet/wifi.py"
    "mininet/lte.py"
    "mininet/opennet.py"
    "examples/opennet"
)

for module in "${OPENNET_MODULES[@]}"; do
    if [[ -e "${INSTALL_DIR}/${module}" ]]; then
        info "  Found: ${module}"
    else
        warn "  Missing: ${module}"
    fi
done

# Check OVS status
info "Checking Open vSwitch status..."
if systemctl is-active --quiet openvswitch-switch; then
    info "  Open vSwitch service is running"
else
    warn "  Open vSwitch service is not running"
    warn "  Run: sudo systemctl start openvswitch-switch"
fi

# Summary
echo ""
info "============================"
info "Mininet Setup Complete"
info "============================"
info "Install location: ${INSTALL_DIR}"
info ""
info "Next steps:"
info "  1. Ensure ns-3 is built (run scripts/build-ns3.sh)"
info "  2. Set up environment variables:"
info "     export PYTHONPATH=\${PYTHONPATH}:${INSTALL_DIR}"
info "  3. Test with: sudo mn --test pingall"
info ""
info "For OpenNet examples:"
info "  cd ${INSTALL_DIR}/examples/opennet"
info "  sudo python3 wifiroaming.py"
