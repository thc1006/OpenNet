#!/usr/bin/env bash
# Quick environment sanity check for OpenNet on Ubuntu 22.04+.

set -euo pipefail

echo "========================================================"
echo "  OpenNet Development Environment Check"
echo "========================================================"
echo

# Track warnings
WARNINGS=0

check_command() {
  local name="$1"
  local cmd="$2"
  local required="${3:-yes}"

  if command -v "$cmd" >/dev/null 2>&1; then
    echo "  [OK] $name: $($cmd --version 2>&1 | head -n 1)"
  else
    if [[ "$required" == "yes" ]]; then
      echo "  [MISSING] $name: NOT FOUND (required)"
      WARNINGS=$((WARNINGS + 1))
    else
      echo "  [SKIP] $name: not found (optional)"
    fi
  fi
}

check_lib() {
  local name="$1"
  local pkg="$2"

  if dpkg -s "$pkg" >/dev/null 2>&1; then
    local version=$(dpkg -s "$pkg" 2>/dev/null | grep "^Version:" | cut -d' ' -f2)
    echo "  [OK] $name: $version"
  else
    echo "  [MISSING] $name ($pkg): NOT INSTALLED"
    WARNINGS=$((WARNINGS + 1))
  fi
}

echo "[OS Information]"
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  echo "  Distro: ${PRETTY_NAME:-$ID $VERSION_ID}"
  echo "  ID: $ID"
  echo "  Version: ${VERSION_ID:-unknown}"
  echo "  Codename: ${VERSION_CODENAME:-unknown}"

  # Check if supported
  case "$ID" in
    ubuntu)
      case "${VERSION_ID:-}" in
        22.04|24.04) echo "  Status: [SUPPORTED]" ;;
        *) echo "  Status: [UNTESTED - may work]" ;;
      esac
      ;;
    debian)
      case "${VERSION_ID:-}" in
        12|13) echo "  Status: [SUPPORTED]" ;;
        *) echo "  Status: [UNTESTED - may work]" ;;
      esac
      ;;
    *)
      echo "  Status: [UNTESTED - Debian/Ubuntu derivatives may work]"
      ;;
  esac
elif command -v lsb_release >/dev/null 2>&1; then
  echo "  Distro: $(lsb_release -d 2>/dev/null | cut -f2)"
  echo "  Codename: $(lsb_release -c 2>/dev/null | cut -f2)"
else
  echo "  Unable to detect distribution"
fi
echo "  Kernel: $(uname -r)"
echo "  Architecture: $(uname -m)"
echo

echo "[Core Build Tools]"
check_command "GCC" "gcc"
check_command "G++" "g++"
check_command "Make" "make"
check_command "CMake" "cmake"
check_command "Git" "git"
check_command "Patch" "patch"
echo

echo "[Python Environment]"
check_command "Python 3" "python3"
check_command "pip3" "pip3"
if command -v python3 >/dev/null 2>&1; then
  # Check for key Python packages
  if python3 -c "import pygccxml" 2>/dev/null; then
    echo "  [OK] pygccxml: $(python3 -c 'import pygccxml; print(pygccxml.__version__)' 2>/dev/null || echo 'installed')"
  else
    echo "  [MISSING] pygccxml: NOT INSTALLED"
    WARNINGS=$((WARNINGS + 1))
  fi
  if python3 -c "import networkx" 2>/dev/null; then
    echo "  [OK] networkx: $(python3 -c 'import networkx; print(networkx.__version__)')"
  else
    echo "  [MISSING] networkx: NOT INSTALLED"
    WARNINGS=$((WARNINGS + 1))
  fi
fi
echo

echo "[ns-3 Build Dependencies]"
check_command "castxml" "castxml"
check_lib "Boost" "libboost-all-dev"
check_lib "GSL" "libgsl-dev"
check_lib "SQLite3" "libsqlite3-dev"
check_lib "libxml2" "libxml2-dev"
check_lib "libpcap" "libpcap-dev"
echo

echo "[Qt5 (for NetAnim)]"
check_lib "Qt5 Base" "qtbase5-dev"
check_command "qmake" "qmake"
echo

echo "[Networking Tools]"
check_command "Open vSwitch" "ovs-vsctl"
check_command "tcpdump" "tcpdump"
check_command "ip" "ip"
check_command "ethtool" "ethtool"
echo

echo "[Optional Tools]"
check_command "Ansible" "ansible" "no"
check_command "Docker" "docker" "no"
check_command "iperf3" "iperf3" "no"
echo

echo "========================================================"
if [[ $WARNINGS -eq 0 ]]; then
  echo "  All required dependencies found!"
  echo "  You can proceed with building ns-3 and Mininet."
else
  echo "  WARNING: $WARNINGS missing dependencies detected."
  echo "  Run: sudo ./scripts/bootstrap-ubuntu-22.04.sh"
fi
echo "========================================================"
