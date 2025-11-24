#!/usr/bin/env bash
# Bootstrap script for setting up OpenNet build dependencies.
#
# Supported distributions:
#   - Ubuntu 22.04 LTS (Jammy Jellyfish)
#   - Ubuntu 24.04 LTS (Noble Numbat)
#   - Debian 12 (Bookworm)
#   - Debian 13 (Trixie)
#
# Usage:
#   sudo ./scripts/bootstrap-ubuntu-22.04.sh
#
# This script installs packages but does NOT modify your kernel, GRUB, or SSH settings.
#
# What this script installs:
#   - Core build tools (gcc, g++, make, cmake, etc.)
#   - Python 3 and development headers
#   - ns-3 dependencies (libgsl, libboost, Qt5, etc.)
#   - Python bindings tools (castxml, pygccxml - replaces legacy gccxml)
#   - Networking tools (OVS, tcpdump, iproute2)
#   - Mininet dependencies (cgroup-tools, networkx)
#   - Ansible (for optional multi-host deployments)
#
# References:
#   - ns-3 installation: https://www.nsnam.org/wiki/Installation
#   - Debian packages: https://packages.debian.org/stable/source/ns3

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Please run this script with sudo, e.g.:" >&2
  echo "  sudo $0" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# Detect distribution
detect_distro() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_VERSION="${VERSION_ID:-unknown}"
    DISTRO_CODENAME="${VERSION_CODENAME:-unknown}"
  else
    DISTRO_ID="unknown"
    DISTRO_VERSION="unknown"
    DISTRO_CODENAME="unknown"
  fi
}

detect_distro

echo "=============================================="
echo "[OpenNet] Bootstrap Script"
echo "=============================================="
echo "Detected: $DISTRO_ID $DISTRO_VERSION ($DISTRO_CODENAME)"
echo

# Validate supported distribution
case "$DISTRO_ID" in
  ubuntu)
    case "$DISTRO_VERSION" in
      22.04|24.04) echo "  [OK] Ubuntu $DISTRO_VERSION is supported" ;;
      *) echo "  [WARN] Ubuntu $DISTRO_VERSION may work but is not tested" ;;
    esac
    ;;
  debian)
    case "$DISTRO_VERSION" in
      12|13) echo "  [OK] Debian $DISTRO_VERSION is supported" ;;
      *) echo "  [WARN] Debian $DISTRO_VERSION may work but is not tested" ;;
    esac
    ;;
  *)
    echo "  [WARN] Distribution '$DISTRO_ID' is not officially supported"
    echo "         This script may still work on Debian/Ubuntu derivatives"
    ;;
esac
echo

echo "[1/7] Updating package index..."
apt-get update -y

echo "[2/7] Installing core build tools..."
apt-get install -y \
  build-essential \
  gcc \
  g++ \
  make \
  cmake \
  pkg-config \
  gdb \
  git \
  patch \
  autoconf \
  automake \
  libtool \
  debhelper \
  dpkg-dev \
  unzip \
  curl \
  wget \
  bzip2

echo "[3/7] Installing Python 3 and development packages..."
apt-get install -y \
  python3 \
  python3-dev \
  python3-venv \
  python3-pip \
  python3-setuptools \
  python3-wheel \
  python-is-python3

echo "[4/7] Installing ns-3 build dependencies..."
# Core ns-3 libraries
apt-get install -y \
  libboost-all-dev \
  libgsl-dev \
  libsqlite3-dev \
  libxml2-dev \
  libssl-dev \
  libpcap-dev \
  libcurl4-openssl-dev \
  libreadline-dev \
  libncurses5-dev \
  libpcre3-dev \
  gawk \
  texinfo

# Qt5 for NetAnim (replaces legacy Qt4)
apt-get install -y \
  qtbase5-dev \
  qt5-qmake \
  qtchooser \
  libgtk-3-dev

# Python bindings generation (castxml replaces deprecated gccxml)
apt-get install -y \
  castxml \
  python3-pygccxml

echo "[5/7] Installing networking and SDN-related tools..."
apt-get install -y \
  openvswitch-switch \
  openvswitch-common \
  tcpdump \
  iproute2 \
  ethtool \
  bridge-utils \
  net-tools \
  ssh \
  sshpass \
  iperf3

echo "[6/7] Installing Mininet dependencies..."
apt-get install -y \
  python3-networkx \
  cgroup-tools \
  uuid-runtime

# Install Python packages that may not be in apt
# Note: Use --break-system-packages for PEP 668 compliance on Ubuntu 22.04+/Debian 12+
pip3 install --quiet --break-system-packages --upgrade pip 2>/dev/null || pip3 install --quiet --upgrade pip
pip3 install --quiet --break-system-packages pyelftools 2>/dev/null || pip3 install --quiet pyelftools

echo "[7/7] Installing Ansible (optional, for multi-host setups)..."
apt-get install -y \
  ansible \
  python3-paramiko || true

echo
echo "=============================================="
echo "[OpenNet] Bootstrap complete!"
echo "=============================================="
echo
echo "Installed versions:"
echo "  - Python: $(python3 --version 2>&1)"
echo "  - GCC: $(gcc --version | head -n1)"
echo "  - CMake: $(cmake --version | head -n1)"
echo "  - castxml: $(castxml --version 2>&1 | head -n1 || echo 'not found')"
echo "  - OVS: $(ovs-vsctl --version 2>&1 | head -n1 || echo 'not found')"
echo
echo "Next steps:"
echo "  1. Run: bash scripts/dev-env-check.sh"
echo "  2. Run: bash scripts/build-ns3.sh (once created)"
echo "  3. Clone Mininet fork and install"
echo
