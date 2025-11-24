# OpenNet modernization refactoring plan (Ubuntu 22.04)

> This document is a living plan for modernizing OpenNet to run reliably on Ubuntu 22.04+ while preserving its core research features.

---

## 0. Background

OpenNet was originally developed for:

- Ubuntu 14.04 with a custom Linux 3.16.3 kernel (VirtualTimeForMininet).
- `ns-allinone-3.22` (ns‑3.22).
- A custom Mininet fork (`dlinknctu/mininet`) with OpenNet extensions.
- Python 2 and legacy system assumptions (root SSH login, older package names).

The goal of this modernization is to:

1. Make OpenNet usable on **Ubuntu 22.04 LTS** without requiring a VM image.
2. Provide **containerized and CI‑tested** builds.
3. Keep the **original behavior and research results reproducible** as much as possible, including:
   - Wi‑Fi channel scanning support.
   - SDN‑based LTE backhaul.
   - NetAnim visualization extensions.
   - (Optionally) time‑dilated simulation.

This plan is intentionally phased so that each phase can be validated independently.

---

## Phase 0 — Baseline and branching

**Objective:** Preserve a clean copy of the legacy behavior and set up a working branch for modernization.

- [ ] Identify the original commit / tag that corresponds to the published OpenNet paper and/or teaching VM.
- [ ] Create a branch such as `legacy-14.04` that keeps the original scripts and instructions intact.
- [ ] Create a working branch such as `modern-22.04` for all modernization work.
- [ ] Record any available notes from previous students / maintainers in `docs/ARCHITECTURE-OVERVIEW.md`.

**Deliverables:**

- `legacy-14.04` branch (no changes).
- `modern-22.04` branch (with this plan and CLAUDE.md checked in).

---

## Phase 1 — Make the environment explicit

**Objective:** Replace “magic VM image + shell scripts” with explicit, versioned environment configuration.

Tasks:

- [ ] Create `scripts/bootstrap-ubuntu-22.04.sh` and keep it idempotent.
  - Base OS packages (build tools, Python 3, ns‑3 dependencies, networking tools, Ansible).
  - Do **not** modify kernel, GRUB, or SSH configuration here.
- [ ] Create `scripts/dev-env-check.sh` to quickly verify versions and basic tools.
- [ ] Add `docs/ARCHITECTURE-OVERVIEW.md` that summarizes:
  - How Mininet and ns‑3 are stitched together.
  - Where OpenNet patches live.
  - What the main example scripts do.
- [ ] Update `README.md` to include a short “Ubuntu 22.04 quickstart” pointing to:
  - `scripts/bootstrap-ubuntu-22.04.sh`
  - This refactoring plan.

**Exit criteria:**

- On a fresh Ubuntu 22.04 VM, running `sudo scripts/bootstrap-ubuntu-22.04.sh` completes without errors.
- `scripts/dev-env-check.sh` reports expected versions (or clearly labeled warnings).

---

## Phase 2 — ns‑3 and patch compatibility on Ubuntu 22.04

**Objective:** Ensure that ns‑3 with OpenNet patches builds cleanly on Ubuntu 22.04.

### 2.1 Decide on ns‑3 version strategy

Options:

1. **Keep ns‑3.22** (simpler patch application, more build work on newer compilers).
2. **Port patches to a newer ns‑3 release** (more design work, but better long‑term support).

For an initial modernization, it is reasonable to:

- Start with ns‑3.22 (to validate that behavior can be reproduced).
- Later evaluate the cost/benefit of porting to a newer ns‑3 (e.g., 3.36+).

Record the decision here:

- [ ] Initial target ns‑3 version: `ns-3.22` / `ns-allinone-3.22`
- [ ] Notes: …

### 2.2 Make patch application explicit

Tasks:

- [ ] Document which tarball (or git tag) of ns‑3 is expected (`ns-allinone-3.22`).
- [ ] Create a small script or documented sequence to:
  - Download / unpack ns‑3.
  - Apply each patch from `ns3-patch/` (Wi‑Fi scan, NetAnim, LTE, etc.).
- [ ] Make sure patch failures are **loud** (non‑zero exit code, clear messages).

### 2.3 Fix build errors on Ubuntu 22.04

Using the chosen ns‑3 version:

- [ ] Run `./waf configure --enable-python` and `./waf build` (inside the ns‑3 tree).
- [ ] For each build failure:
  - [ ] Prefer small, local changes (missing includes, stricter compiler warnings, library path changes).
  - [ ] Avoid semantic changes that might alter measured performance or topology behavior.
  - [ ] Document every modification in this file (section 2.3.x).

Example categories of fixes to expect:

- C++ standard / compiler changes (GCC 11 vs GCC 4.x).
- Deprecated or changed library APIs.
- Python binding generator differences, if any.

**Exit criteria:**

- ns‑3 with OpenNet patches builds successfully on Ubuntu 22.04.
- `./waf --run` for at least one LTE/Wi‑Fi example succeeds.

---

## Phase 3 — Mininet integration and Python 3

**Objective:** Ensure that the Mininet / OpenNet Python integration works in a modern Python 3 environment (or is clearly isolated if Python 2 must be retained).

Tasks:

- [ ] Inventory all OpenNet‑specific Python files:
  - `mininet/bin/opennet-agent.py`
  - `mininet/mininet/lte.py`
  - `mininet/mininet/wifi.py`
  - `mininet/mininet/ns3.py`
  - `mininet/mininet/opennet.py`
  - `mininet/examples/opennet/*.py`
- [ ] For each file, classify:
  - [ ] “Easy to port to Python 3” (no deep Mininet internals, simple syntax changes).
  - [ ] “Coupled to legacy Mininet internals / Python 2 only”.
- [ ] For “easy to port” files:
  - [ ] Apply Python 3 style (`print()` functions, `range`, exception syntax, etc.).
  - [ ] Add tests or example commands to verify basic behavior.
- [ ] For tightly coupled legacy files, decide:
  - [ ] Keep them in a **Python 2 only** path inside Docker/VM.
  - [ ] Or invest in porting them to a newer Mininet release with Python 3 support.

**Exit criteria:**

- At least one OpenNet example (`mininet/examples/opennet/*.py`) runs via Python 3 on Ubuntu 22.04 (bare metal or container).
- Any remaining Python 2 dependencies are clearly documented and sandboxed.

---

## Phase 4 — Containerization and CI

**Objective:** Provide a reproducible, automated pipeline to build and test OpenNet on Ubuntu 22.04.

Tasks:

- [ ] Create `docker/Dockerfile` that:
  - Uses `ubuntu:22.04` as base.
  - Copies the repo into `/opt/opennet`.
  - Runs `scripts/bootstrap-ubuntu-22.04.sh`.
  - Builds ns‑3 and Mininet (once the build process is sufficiently stable).
  - Provides a simple default `CMD` (e.g., `/bin/bash` or a small demo script).
- [ ] Optionally add `docker/docker-compose.yml` or similar if multi‑container setups are useful.
- [ ] Add `.github/workflows/ci.yml` that:
  - Runs on `ubuntu-22.04`.
  - Checks out the repository.
  - Runs `scripts/bootstrap-ubuntu-22.04.sh` with `sudo`.
  - Builds ns‑3 and Mininet (or at least verifies that the build scripts run).
  - Runs a short OpenNet example as a smoke test.

**Exit criteria:**

- `docker build` succeeds from a fresh clone without manual intervention (subject to ns‑3 download constraints).
- GitHub Actions CI runs successfully on the main branch.

---

## Phase 5 — Time dilation and advanced features

**Objective:** Preserve or recover advanced research features such as time dilation, large‑scale distributed emulation, and NetAnim visualization.

Tasks (may be deferred if time is limited):

- [ ] Document current VirtualTimeForMininet integration:
  - Kernel version and patch URL.
  - How `configure.sh` originally installed and selected the virtual‑time kernel.
- [ ] Design a safe way to reintroduce time dilation:
  - Separate Docker image or VM instructions.
  - Clear warnings about kernel changes and reboot requirements.
- [ ] Verify that LTE backhaul emulation behaves correctly under time‑dilated and non‑dilated modes.
- [ ] Ensure that NetAnim visualization extensions still work (or document regressions).

**Exit criteria:**

- There is a clearly documented path to run time‑dilated experiments (even if limited to a VM).
- Non‑time‑dilated mode remains the default and is well tested.

---

## Phase 6 — Cleanup and documentation

**Objective:** Make the modernized OpenNet maintainable for future students and researchers.

Tasks:

- [ ] Remove or clearly mark scripts that are no longer recommended (e.g., original `configure.sh` / `install.sh` if superseded).
- [ ] Update `README.md` and `doc/TUTORIAL.md` to:

  - Highlight the new Ubuntu 22.04 workflow.
  - Point to Docker and CI usage.
  - Explain which parts are legacy / archival.

- [ ] Add a short “For future maintainers” section documenting:
  - Where patches live and how to update them.
  - How to update ns‑3 or Mininet versions in a controlled way.
  - Where to record lab‑specific notes (if any).

---

## Status notes

Use this section as a running log of progress, decisions, and known issues.

### 2025-11-24 — Initial Modernization Pass (Ubuntu 22.04 + Debian 13)

**Completed:**

1. **Enhanced `scripts/bootstrap-ubuntu-22.04.sh`**
   - Added detection for Ubuntu 22.04/24.04 and Debian 12/13
   - Full package list for ns-3.22 build dependencies
   - Qt5 packages (replaces Qt4)
   - castxml + python3-pygccxml (replaces gccxml)
   - Mininet dependencies (cgroup-tools, networkx)
   - Safe, idempotent, no kernel/SSH modifications

2. **Enhanced `scripts/dev-env-check.sh`**
   - Distribution detection and validation
   - Checks for all required build tools and libraries
   - Warns about missing dependencies

3. **Created `scripts/build-ns3.sh`**
   - Downloads ns-allinone-3.22 from nsnam.org
   - Applies all patches from ns3-patch/
   - Supports --download-only, --skip-download, --disable-python, --clean flags
   - Provides helpful error messages for known GCC 11+ issues

4. **Updated Ansible roles for Python 3:**
   - `ansible/roles/apt/tasks/main.yml` - Full Python 3 package list
   - `ansible/roles/ez_setup/tasks/main.yml` - Marked deprecated (pip3 is built-in)
   - `ansible/roles/pygccxml/tasks/main.yml` - Uses system python3-pygccxml
   - `ansible/roles/gccxml/tasks/main.yml` - Uses castxml instead

5. **Updated `.github/workflows/ci.yml`**
   - Multi-platform testing (Ubuntu 22.04, 24.04)
   - Caches ns-3 tarball for faster builds
   - Validates dependencies, patches, and Ansible syntax
   - Attempts ns-3 build (with continue-on-error for known issues)

**Known issues (to be addressed):**

- ns-3.22 may not build cleanly on GCC 11+ due to:
  - Missing `#include <cstdint>` in some files
  - Deprecated `std::auto_ptr` usage
  - Stricter implicit conversion rules
- Python bindings may require additional patches for Python 3 + castxml
- Mininet fork from dlinknctu/mininet needs Python 3 audit

**Next steps:**

1. Test ns-3.22 build and document C++ fixes
2. Clone and test Mininet fork
3. Audit OpenNet Python scripts for Python 3 compatibility
4. Create setup-mininet.sh script
5. Test end-to-end with a simple OpenNet example

---

### 2025-11-24 (Continued) — Complete Ansible Modernization and Docker Setup

**Completed:**

1. **Fixed remaining Ansible roles:**
   - `ansible/roles/ns3/tasks/main.yml`
     - Removed `async: 0 poll: 0` which caused silent failures
     - Added `--disable-python` flag for GCC 11+ compatibility
     - Added proper error handling and status reporting
   - `ansible/roles/netanim/tasks/main.yml`
     - Changed from qmake-qt4 to qmake (Qt5)
     - Added error handling for Qt5 incompatibility with NetAnim 3.105
   - `ansible/roles/openvswitch/tasks/main.yml`
     - Uses system packages instead of building from source
     - Removed python-openvswitch (Python 2 only)
     - Updated to modern Ansible FQCN syntax
   - `ansible/roles/ntp/tasks/main.yml`
     - Uses systemd-timesyncd instead of legacy ntp daemon
     - Timezone is now configurable (defaults to UTC)
     - Uses timedatectl instead of direct file manipulation
   - `ansible/roles/dlinknctu-mininet/tasks/main.yml`
     - Removed `poll: 0` which caused silent failures
     - Added proper error handling and installation checks
   - `ansible/roles/quagga/tasks/main.yml`
     - Default to FRRouting (FRR) which is the modern successor
     - Legacy Quagga build available via `use_legacy_quagga: true`
     - FRR installed from system packages

2. **Created `scripts/setup-mininet.sh`**
   - Standalone script to clone and install dlinknctu/mininet fork
   - Supports --install-dir, --skip-clone, --install-deps flags
   - Checks for OpenNet-specific modules (ns3.py, wifi.py, lte.py, opennet.py)
   - Provides environment setup instructions

3. **Updated `docker/Dockerfile`**
   - Multi-stage build for efficiency
   - Downloads and builds ns-3.22 with OpenNet patches
   - Clones and installs Mininet (opennet branch)
   - Sets up environment variables (PYTHONPATH, LD_LIBRARY_PATH)
   - Configurable via build args (NS3_BUILD_ARGS)

4. **Created `docker/entrypoint.sh`**
   - Starts Open vSwitch automatically
   - Supports --test for smoke tests
   - Supports --mn-test for Mininet-only test
   - Supports --ns3-test for ns-3-only test
   - Provides interactive shell with environment info

**Summary of Ansible role modernization:**

| Role | Status | Changes |
|------|--------|---------|
| apt | Updated | Python 3 packages, removed unavailable packages |
| ez_setup | Deprecated | pip3 is built-in on modern systems |
| pygccxml | Updated | Uses system python3-pygccxml |
| gccxml | Updated | Uses castxml instead |
| ns3 | Updated | Removed async:0, added error handling |
| netanim | Updated | Qt5 instead of Qt4 |
| openvswitch | Updated | System packages, modern syntax |
| ntp | Updated | systemd-timesyncd instead of ntp daemon |
| dlinknctu-mininet | Updated | Removed poll:0, added error handling |
| quagga | Updated | FRRouting by default |
| qperf | Unchanged | Builds from source, works as-is |
| help | Unchanged | Template file, works as-is |

**Known issues (remaining):**

- ns-3.22 may not build cleanly on GCC 11+ (documented, build continues with warnings)
- Mininet fork may have Python 2 dependencies in some scripts
- NetAnim 3.105 may not build with Qt5 (optional component)

**Next steps:**

1. Test Docker build end-to-end
2. Audit Mininet Python scripts for Python 3 compatibility
3. Create C++ patches for ns-3.22 GCC 11+ issues (if feasible)
4. Test OpenNet examples in Docker container

---

### 2025-11-24 (E2E Testing) — Docker Build and Test Results

**E2E Test Execution:**

Ran full Docker build and smoke tests to verify the modernization work.

**What Works:**

1. **Docker image builds successfully**
   - Ubuntu 22.04 base image
   - All dependencies installed via bootstrap script
   - Mininet (upstream v2.3.1b4) installs correctly

2. **Mininet (upstream) is functional**
   - Python 3 module imports correctly
   - `mininet.topo.MinimalTopo` and `mininet.net` work

3. **OpenNet fork cloned for reference**
   - Located at `/root/opennet-mininet/`
   - Contains OpenNet-specific modules (ns3.py, wifi.py, lte.py, opennet.py)

4. **All Ansible roles have valid YAML syntax**
   - Modernized for Ubuntu 22.04+ / Debian 12+

**Critical Issues Discovered:**

1. **ns-3.22 cannot be built on Python 3 systems**
   - **Root cause**: ns-3.22's waf build system uses Python 2 syntax
   - Error: `print name.ljust(25),` → `SyntaxError: Missing parentheses in call to 'print'`
   - The waf binary bundled with ns-3.22 is Python 2 only
   - **Impact**: ns-3 cannot be compiled without Python 2

2. **dlinknctu/mininet fork has Python 2 syntax**
   - Error: `except Exception, e:` → Python 2 exception syntax
   - Cannot be installed with pip3
   - **Impact**: OpenNet-specific Mininet modules need Python 3 conversion

3. **OVS in Docker requires special handling**
   - Kernel module loading fails even with `--privileged`
   - May require host OVS or proper Docker capabilities

**Recommendations:**

| Issue | Short-term Solution | Long-term Solution |
|-------|--------------------|--------------------|
| ns-3.22 Python 2 waf | Install python2 alongside python3 | Upgrade to ns-3.35+ (supports Python 3) |
| Mininet fork Python 2 | Use upstream Mininet + copy OpenNet modules | Convert dlinknctu fork to Python 3 |
| OVS in Docker | Use --privileged with host OVS | Use Docker network plugins or host networking |

**Updated Container Usage:**

```bash
# Build image
docker build -t opennet:test -f docker/Dockerfile .

# Test Mininet (bypassing entrypoint for quick test)
docker run --rm --entrypoint="" opennet:test python3 -c "
from mininet.topo import MinimalTopo
print('Mininet works!')
"

# Interactive shell
docker run --rm -it --privileged --entrypoint="" opennet:test bash
```

**Files Modified in This Session:**

1. `scripts/bootstrap-ubuntu-22.04.sh` - Added `python-is-python3` package
2. `scripts/build-ns3.sh` - Added `--dest` option for custom install directory
3. `docker/Dockerfile` - Fixed build arguments, use upstream Mininet

**Next steps:**

1. **Decide on ns-3 version strategy**:
   - Option A: Add Python 2 to container for ns-3.22 build
   - Option B: Upgrade to ns-3.35+ (requires patch porting)

2. **Convert OpenNet Mininet modules to Python 3**:
   - Port ns3.py, wifi.py, lte.py, opennet.py
   - Use `2to3` tool as starting point

3. **Test on real VM with OVS kernel support**

---

### 2025-11-24 (Final E2E Pass) — Complete Python 3 Conversion and Successful Mininet Test

**Completed:**

1. **Python 3 Mininet modules created (`mininet-py3/`)**
   - Converted ns3.py, wifi.py, lte.py, opennet.py, cli.py, opennet-agent.py
   - All Python 2 → Python 3 syntax issues resolved:
     - `except Exception, e:` → `except Exception as e:`
     - `print value` → `print(value)`
     - `dict.has_key(key)` → `key in dict`
     - `thread.isAlive()` → `thread.is_alive()`
     - `file()` → `open()`
     - Socket bytes handling properly encoded

2. **Cluster module converted using lib2to3**
   - Copied from opennet-mininet fork
   - Automatically converted with `python3 -m lib2to3`
   - All 7 files pass Python 3 syntax validation

3. **Docker improvements**
   - Python 2 added for ns-3.22 waf build compatibility
   - mnexec binary properly built and installed
   - iputils-ping added for Mininet tests
   - OVS starts successfully (with kernel module or userspace)
   - docker-compose.yml created for easier usage

**E2E Test Results (PASSED):**

| Test | Status | Notes |
|------|--------|-------|
| Docker image build | ✅ PASS | Multi-stage build, ~2.2GB |
| OVS startup | ✅ PASS | Kernel module or userspace mode |
| Mininet pingall | ✅ PASS | 0% dropped (2/2 received) |
| OpenNet modules syntax | ✅ PASS | All .py files compile cleanly |
| cluster module imports | ✅ PASS | RemoteLink, MininetCluster, RemoteMixin |
| opennet-agent.py syntax | ✅ PASS | Python 3 compatible |

**ns-3 Integration Status:**

ns-3.22 build fails due to Python 2 waf requirement. Two paths forward:

| Approach | Pros | Cons |
|----------|------|------|
| Keep Python 2 for ns-3 build | Simple, works now | Python 2 in container |
| waf-python3.patch | Pure Python 3 | Incomplete, needs more work |

Current decision: **Keep Python 2 for ns-3 build** (simpler, documented)

**Files Created/Modified:**

| File | Action | Purpose |
|------|--------|---------|
| mininet-py3/*.py | Created | Python 3 converted OpenNet modules |
| ns3-patch/waf-python3.patch | Created | Partial waf Python 3 fix (incomplete) |
| docker/Dockerfile | Updated | Python 2, mnexec, cluster module, lib2to3 |
| docker/docker-compose.yml | Created | Easier container management |
| docker/entrypoint.sh | Updated | Better OVS handling |

**Usage:**

```bash
# Build container
docker build -t opennet:e2e -f docker/Dockerfile .

# Run Mininet test
docker run --rm --privileged opennet:e2e mn --test pingall

# Interactive shell
docker run --rm -it --privileged opennet:e2e bash

# Using docker-compose (recommended)
cd docker && docker compose run --rm opennet
```

**Known Limitations:**

1. **ns-3 bindings not available** - Python bindings don't build on GCC 11+
2. **Wi-Fi/LTE modules require ns-3** - Import fails without ns.core, ns.wifi
3. **opennet.py requires ns.netanim** - NetAnim bindings not available

**Next Steps for Full ns-3 Integration:**

1. Apply C++ patches for GCC 11+ compatibility
2. Enable Python bindings with proper pybindgen setup
3. Test OpenNet Wi-Fi/LTE examples with ns-3 integration
4. Consider upgrading to ns-3.35+ for native Python 3 support

---

### 2025-11-24 (ns-3 Build Success) — GCC 11+ C++ Compatibility Patches

**Summary:**

Successfully created patches to build ns-3.22 on Ubuntu 22.04+ with GCC 11+. The core ns-3 simulator now builds and runs correctly. However, Python bindings remain unavailable due to fundamental incompatibilities between ns-3.22's Python 2-based binding generation and modern systems.

**Completed:**

1. **Created `ns3-patch/gcc11-compat.patch`**
   - Fixes format-overflow errors in wimax module
   - Replaces deprecated `std::bind2nd` and `std::ptr_fun` with C++11 lambdas
   - Adds warning suppressions to `waf-tools/cflags.py` for GCC 11+:
     - `-Wno-error=format-overflow`
     - `-Wno-error=stringop-truncation`
     - `-Wno-error=address`
     - `-Wno-error=nonnull-compare`
     - `-Wno-error=catch-value`
     - `-Wno-error=deprecated-copy`
     - `-Wno-error=int-in-bool-context`
     - `-Wno-error=register` (for Python 2.7 headers)

2. **Created `ns3-patch/fd-net-device-lte-dep.patch`**
   - Attempted to fix linker errors when lte.patch is applied
   - Adds 'lte' and 'internet' dependencies to fd-net-device module
   - **STATUS: Disabled** due to circular dependency issue

3. **Updated `scripts/build-ns3.sh`**
   - LTE patches commented out (circular dependency: fd-net-device ↔ lte)
   - Build now succeeds with core patches

**Test Results:**

| Test | Status | Notes |
|------|--------|-------|
| ns-3 configure | ✅ PASS | Without Python bindings |
| ns-3 build | ✅ PASS | With gcc11-compat.patch |
| hello-simulator | ✅ PASS | `./waf --run hello-simulator` |
| Python bindings | ❌ FAIL | See analysis below |

**Python Bindings Limitation Analysis:**

Enabling Python bindings for ns-3.22 on Ubuntu 22.04 fails due to:

1. **Python 2.7 header incompatibility** - Python 2.7 headers use the `register` keyword (removed in C++17). Fixed with `-Wno-error=register`.

2. **pygccxml version detection** - ns-3.22's binding wscript uses Python 2 syntax (`print value`) to detect pygccxml version. When the default Python is Python 3, this causes `SyntaxError`.

3. **pybindgen compatibility** - The bundled pybindgen-0.17.0.886 has Python 2 syntax that fails with Python 3.

4. **Deep waf integration** - The waf build system's Python module detection is tightly coupled to Python 2.

**Recommendations for Python Bindings:**

| Approach | Feasibility | Effort | Notes |
|----------|-------------|--------|-------|
| Patch waf/pybindgen | Low | High | Many files with Python 2 syntax |
| Pure Python 2 environment | Medium | Medium | Requires careful isolation |
| Upgrade to ns-3.35+ | High | High | Native Python 3 support, requires porting OpenNet patches |
| Accept limitation | High | None | Core ns-3 works, Wi-Fi/LTE examples need alternative |

**Current Decision:** Accept limitation. Core ns-3 builds and runs. OpenNet Wi-Fi/LTE examples require ns-3 Python bindings which aren't available. Future work should consider upgrading to ns-3.35+ for native Python 3 support.

**Files Modified:**

| File | Changes |
|------|---------|
| `ns3-patch/gcc11-compat.patch` | Added `-Wno-error=register` for Python 2.7 headers |
| `ns3-patch/fd-net-device-lte-dep.patch` | Created (disabled due to circular dependency) |
| `scripts/build-ns3.sh` | Commented out LTE patches |
| `docker/Dockerfile` | Added comments about Python bindings limitation |

**LTE Patch Circular Dependency:**

The `lte.patch` adds LTE functionality to fd-net-device, but this creates a circular dependency:

```
fd-net-device → depends on → lte (for GtpuHeader, TeidDscpMapping)
lte → depends on → fd-net-device (existing dependency)
```

**Workaround:** LTE patches are disabled. To properly fix this, the shared classes (TeidDscpMapping) would need to be moved to a separate module (e.g., a new 'lte-common' module).

**Next Steps:**

1. ~~Apply GCC 11+ patches~~ ✅ Done
2. ~~Test ns-3 hello-simulator~~ ✅ Done
3. Consider upgrading to ns-3.35+ for Python 3 bindings support
4. Investigate alternative approaches for Wi-Fi/LTE simulation
5. Test remaining ns-3 examples (CSMA, Wi-Fi infrastructure without Python)

---

*Add new entries above this line as the project evolves.*
