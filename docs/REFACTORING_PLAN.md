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

- *Example:*  
  `2025‑11‑23 — Bootstrapped Ubuntu 22.04 packages with scripts/bootstrap-ubuntu-22.04.sh. ns‑3.22 builds with minor header fixes; LTE patch still needs investigation.`

Add new entries above this line as the project evolves.
