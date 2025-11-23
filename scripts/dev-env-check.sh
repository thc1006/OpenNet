#!/usr/bin/env bash
# Quick environment sanity check for OpenNet on Ubuntu 22.04+.

set -euo pipefail

echo "=== OpenNet development environment check ==="
echo

echo "[OS] lsb_release:"
if command -v lsb_release >/dev/null 2>&1; then
  lsb_release -a || true
else
  echo "lsb_release not found"
fi
echo

echo "[Python] python3 version:"
if command -v python3 >/dev/null 2>&1; then
  python3 --version
else
  echo "python3 not found"
fi
echo

echo "[Compiler] gcc/g++ versions:"
if command -v gcc >/dev/null 2>&1; then
  gcc --version | head -n 1
else
  echo "gcc not found"
fi
if command -v g++ >/dev/null 2>&1; then
  g++ --version | head -n 1
else
  echo "g++ not found"
fi
echo

echo "[Networking] openvswitch-switch:"
if command -v ovs-vsctl >/dev/null 2>&1; then
  ovs-vsctl --version | head -n 1 || true
else
  echo "Open vSwitch (ovs-vsctl) not found"
fi
echo

echo "[Ansible] ansible:"
if command -v ansible >/dev/null 2>&1; then
  ansible --version | head -n 1
else
  echo "ansible not found (only needed for multi-host automation)"
fi
echo

echo "Environment check complete. Review any warnings above before building OpenNet."
