#!/usr/bin/env bash
# Build script for ns-3 with OpenNet patches on Ubuntu 22.04+ / Debian 12+.
#
# Usage:
#   ./scripts/build-ns3.sh [OPTIONS]
#
# Options:
#   --download-only    Only download and extract ns-3, don't build
#   --skip-download    Skip download, assume ns-3 is already extracted
#   --disable-python   Build without Python bindings (faster, fewer deps)
#   --clean            Remove existing ns-3 directory before starting
#   --dest DIR         Install to DIR instead of project directory
#   --help             Show this help message
#
# This script will:
#   1. Download ns-allinone-3.22.tar.bz2 from nsnam.org
#   2. Extract it to the OpenNet root directory
#   3. Apply all patches from ns3-patch/
#   4. Configure and build ns-3 with waf
#
# Note: This script does NOT require root privileges for building.
#       Run bootstrap-ubuntu-22.04.sh first to install dependencies.

set -euo pipefail

# Configuration
NS3_VERSION="3.22"
NS3_TARBALL="ns-allinone-${NS3_VERSION}.tar.bz2"
NS3_URL="https://www.nsnam.org/release/${NS3_TARBALL}"
NS3_SHA256="f44609dd52a6a9e60d8d7ad1553dba99a1e83e18"  # SHA1 checksum (official)

# Determine script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PATCH_DIR="${PROJECT_DIR}/ns3-patch"

# Default options
DOWNLOAD_ONLY=false
SKIP_DOWNLOAD=false
DISABLE_PYTHON=false
CLEAN_BUILD=false
DEST_DIR=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --download-only)
      DOWNLOAD_ONLY=true
      shift
      ;;
    --skip-download)
      SKIP_DOWNLOAD=true
      shift
      ;;
    --disable-python)
      DISABLE_PYTHON=true
      shift
      ;;
    --clean)
      CLEAN_BUILD=true
      shift
      ;;
    --dest)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --dest requires a directory argument" >&2
        exit 1
      fi
      DEST_DIR="$2"
      shift 2
      ;;
    --help|-h)
      head -n 23 "$0" | tail -n 21
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Use --help for usage information" >&2
      exit 1
      ;;
  esac
done

# If --dest was specified, use that instead of PROJECT_DIR
if [[ -n "${DEST_DIR}" ]]; then
  mkdir -p "${DEST_DIR}"
  INSTALL_DIR="$(cd "${DEST_DIR}" && pwd)"
else
  INSTALL_DIR="${PROJECT_DIR}"
fi

NS3_ALLINONE_DIR="${INSTALL_DIR}/ns-allinone-${NS3_VERSION}"
NS3_DIR="${NS3_ALLINONE_DIR}/ns-${NS3_VERSION}"

echo "=============================================="
echo "[OpenNet] ns-3 Build Script"
echo "=============================================="
echo "ns-3 version: ${NS3_VERSION}"
echo "Project directory: ${PROJECT_DIR}"
echo "Install directory: ${INSTALL_DIR}"
echo "Options:"
echo "  Download only: ${DOWNLOAD_ONLY}"
echo "  Skip download: ${SKIP_DOWNLOAD}"
echo "  Disable Python: ${DISABLE_PYTHON}"
echo "  Clean build: ${CLEAN_BUILD}"
echo

# Clean if requested
if [[ "${CLEAN_BUILD}" == "true" && -d "${NS3_ALLINONE_DIR}" ]]; then
  echo "[CLEAN] Removing existing ns-3 directory..."
  rm -rf "${NS3_ALLINONE_DIR}"
  rm -f "${INSTALL_DIR}/${NS3_TARBALL}"
fi

# Step 1: Download ns-3
if [[ "${SKIP_DOWNLOAD}" != "true" ]]; then
  echo "[1/4] Downloading ns-3..."

  if [[ -f "${INSTALL_DIR}/${NS3_TARBALL}" ]]; then
    echo "  Tarball already exists, skipping download"
  else
    echo "  Downloading from ${NS3_URL}..."
    cd "${INSTALL_DIR}"
    if command -v wget >/dev/null 2>&1; then
      wget --progress=bar:force -O "${NS3_TARBALL}" "${NS3_URL}"
    elif command -v curl >/dev/null 2>&1; then
      curl -L -o "${NS3_TARBALL}" "${NS3_URL}"
    else
      echo "ERROR: Neither wget nor curl found. Install one of them." >&2
      exit 1
    fi
  fi

  # Extract
  if [[ -d "${NS3_ALLINONE_DIR}" ]]; then
    echo "  ns-3 directory already exists, skipping extraction"
  else
    echo "  Extracting ${NS3_TARBALL}..."
    cd "${INSTALL_DIR}"
    tar -xjf "${NS3_TARBALL}"
  fi
else
  echo "[1/4] Skipping download (--skip-download)"
fi

# Verify ns-3 directory exists
if [[ ! -d "${NS3_DIR}" ]]; then
  echo "ERROR: ns-3 directory not found at ${NS3_DIR}" >&2
  echo "       Run without --skip-download to download ns-3" >&2
  exit 1
fi

if [[ "${DOWNLOAD_ONLY}" == "true" ]]; then
  echo
  echo "[DONE] Download complete. ns-3 extracted to: ${NS3_ALLINONE_DIR}"
  echo "       Run again without --download-only to build."
  exit 0
fi

# Step 2: Apply patches
echo "[2/4] Applying OpenNet patches..."

# LTE patches commented out due to circular dependency issue
# fd-net-device <-> lte creates a dependency cycle in waf
# TODO: Fix by moving TeidDscpMapping to a shared module
PATCHES=(
  "gcc11-compat.patch"
  "animation-interface.patch"
  "netanim-python.patch"
  "sta-wifi-scan.patch"
  # "lte.patch"
  # "fd-net-device-lte-dep.patch"
)

cd "${NS3_DIR}"
for patch_file in "${PATCHES[@]}"; do
  patch_path="${PATCH_DIR}/${patch_file}"
  if [[ ! -f "${patch_path}" ]]; then
    echo "  WARNING: Patch file not found: ${patch_path}"
    continue
  fi

  # Check if patch is already applied
  if patch -p1 --dry-run --reverse --force < "${patch_path}" >/dev/null 2>&1; then
    echo "  [SKIP] ${patch_file} (already applied)"
  else
    echo "  [APPLY] ${patch_file}..."
    if ! patch -p1 --forward < "${patch_path}"; then
      echo "  WARNING: Patch ${patch_file} failed to apply cleanly"
      echo "           This may be expected if patches overlap"
    fi
  fi
done

# Step 3: Configure ns-3
echo "[3/4] Configuring ns-3..."

cd "${NS3_DIR}"

# Build waf configure command
WAF_OPTS=()
WAF_OPTS+=("--enable-examples")
WAF_OPTS+=("--enable-tests")

if [[ "${DISABLE_PYTHON}" == "true" ]]; then
  WAF_OPTS+=("--disable-python")
  echo "  Python bindings: DISABLED"
else
  # Try to enable Python bindings
  # Note: ns-3.22 may have issues with Python 3 bindings on modern systems
  if command -v python3 >/dev/null 2>&1; then
    WAF_OPTS+=("--with-python=/usr/bin/python3")
    echo "  Python bindings: ENABLED (Python 3)"
  else
    WAF_OPTS+=("--disable-python")
    echo "  Python bindings: DISABLED (Python 3 not found)"
  fi
fi

# Use python2 for waf if available (ns-3.22's waf requires Python 2)
PYTHON_CMD="${PYTHON:-python2}"
if ! command -v "$PYTHON_CMD" >/dev/null 2>&1; then
  PYTHON_CMD="python"
fi

echo "  Using Python: $PYTHON_CMD"
echo "  Running: $PYTHON_CMD ./waf configure ${WAF_OPTS[*]}"
$PYTHON_CMD ./waf configure "${WAF_OPTS[@]}" || {
  echo
  echo "WARNING: waf configure failed."
  echo "         This is expected for ns-3.22 on modern systems."
  echo "         Common issues:"
  echo "           - Python bindings may not work (try --disable-python)"
  echo "           - Some modules may be disabled"
  echo
  echo "         Attempting to continue with build..."
}

# Step 4: Build ns-3
echo "[4/4] Building ns-3..."

cd "${NS3_DIR}"
NPROC=$(nproc 2>/dev/null || echo 4)
echo "  Using ${NPROC} parallel jobs"

# Build with error tolerance for ns-3.22 on modern compilers
# GCC 11+ is stricter and may produce warnings-as-errors
echo "  Running: $PYTHON_CMD ./waf build -j${NPROC}"
if ! $PYTHON_CMD ./waf build -j"${NPROC}"; then
  echo
  echo "=============================================="
  echo "BUILD FAILED"
  echo "=============================================="
  echo
  echo "ns-3.22 was designed for older compilers (GCC 4.x-5.x)."
  echo "Modern GCC (11+) is stricter and may fail on:"
  echo "  - Missing #include <cstdint>"
  echo "  - Deprecated std::auto_ptr usage"
  echo "  - Implicit type conversions"
  echo
  echo "Options to resolve:"
  echo "  1. Check docs/REFACTORING_PLAN.md for known fixes"
  echo "  2. Try building without Python bindings: --disable-python"
  echo "  3. Apply C++ compatibility patches (to be documented)"
  echo
  exit 1
fi

# Install to system (optional, requires sudo)
echo
echo "=============================================="
echo "BUILD SUCCESSFUL"
echo "=============================================="
echo
echo "ns-3 has been built in: ${NS3_DIR}"
echo
echo "Optional: Install to system (requires sudo):"
echo "  cd ${NS3_DIR} && sudo ./waf install && sudo ldconfig"
echo
echo "To test, run:"
echo "  cd ${NS3_DIR}"
echo "  ./waf --run hello-simulator"
echo
echo "Next steps:"
echo "  1. Clone and install the Mininet fork"
echo "  2. Run an OpenNet example"
echo
