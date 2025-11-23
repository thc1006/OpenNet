#!/usr/bin/env bash
# Bootstrap script for setting up OpenNet build dependencies on Ubuntu 22.04+.
# Usage:
#   sudo ./scripts/bootstrap-ubuntu-22.04.sh
#
# This script installs packages but does NOT modify your kernel, GRUB, or SSH settings.

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Please run this script with sudo, e.g.:" >&2
  echo "  sudo $0" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "[OpenNet] Updating package index..."
apt-get update -y

echo "[OpenNet] Installing core build tools and libraries..."
apt-get install -y   build-essential   gcc g++ make cmake pkg-config gdb git   python3 python3-venv python3-dev python3-pip   libboost-all-dev   libgtk-3-dev   qtbase5-dev qtchooser qt5-qmake   libsqlite3-dev libxml2-dev libgsl-dev

echo "[OpenNet] Installing networking and SDN-related tools..."
apt-get install -y   openvswitch-switch openvswitch-common   tcpdump iproute2 ethtool bridge-utils net-tools   ssh sshpass

echo "[OpenNet] Installing Ansible (optional, for multi-host setups)..."
apt-get install -y   ansible   python3-paramiko || true

echo "[OpenNet] Done. You can now proceed to fetch/build ns-3 and the Mininet fork."
