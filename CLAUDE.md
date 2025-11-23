# CLAUDE.md — OpenNet modernization

> This file configures how Claude Code should work with the **OpenNet** project when modernizing it for contemporary Linux systems (Ubuntu 22.04+). Treat these instructions as system-level rules for this repo.

---

## 1. Project identity and high‑level summary

**Project name:** OpenNet  
**Original upstream:** https://github.com/dlinknctu/OpenNet
**now you are at my fork's repo**：https://github.com/thc1006/OpenNet.git 

Remember Commit you should use below info for commit and push.
```
git config --global user.name "thc1006"
git config --global user.email "84045975+thc1006@users.noreply.github.com"
```

OpenNet is an SDN emulator / simulator that:

- Integrates **Mininet** (Python‑based SDN emulator) and **ns‑3** (C++ network simulator) into a single environment.
- Lets Mininet topologies use ns‑3 models (Wi‑Fi, LTE, etc.) via **Python bindings** to ns‑3.
- Adds extra functionality on top of upstream ns‑3 and Mininet:
  - Wi‑Fi station channel scan behavior (`sta-wifi-scan.patch`).
  - NetAnim support for `CsmaLink`/`SimpleLink` (`animation-interface.patch`, `netanim-python.patch`).
  - SDN‑based LTE backhaul emulation (`lte.patch`).
  - Support for distributed Mininet and distributed ns‑3 emulation via an `opennet-agent.py` daemon.
  - An optional **time dilation** mechanism (VirtualTimeForMininet + ns‑3 LTE changes) to trade wall‑clock time for CPU.

**Original environment assumptions (legacy):**

- Ubuntu 14.04 (kernel 3.16.3 for VirtualTimeForMininet).
- `ns-allinone-3.22` (ns‑3.22 + bundled tools).
- A customized fork of Mininet (cloned into `mininet/` from `dlinknctu/mininet`).
- Root login enabled over SSH for cluster mode.
- Python 2 for Mininet scripts and ns‑3 bindings.

Your job is to **modernize OpenNet** to work reliably on **Ubuntu 22.04 LTS (or later)** while preserving as much functionality as is practical.（ you should use the claude code Subagents ".claude\agents" to do everything dealing with the jobs）.

---

## 2. Modernization goals and constraints

When working in this repo, assume the following **top‑level goals**:

1. **Make OpenNet build and run on Ubuntu 22.04 LTS** (server/headless is fine).
2. **Minimize invasive changes** to ns‑3 and Mininet: keep all OpenNet‑specific logic in clearly separated patches / modules where possible.
3. **Prefer Python 3** for all new or user‑facing scripts. Keep Python 2 only where absolutely required by legacy dependencies.
4. **Containerize and add CI** so there is at least one reproducible environment (Docker image + GitHub Actions or similar) that can:
   - Build ns‑3 with OpenNet patches.
   - Build/prepare the Mininet fork used by OpenNet.
   - Run at least one end‑to‑end example topology.
5. **Treat time dilation and VirtualTimeForMininet as optional advanced features.**
   - Baseline should work *without* requiring a custom kernel.
   - Time‑dilated mode can be implemented in a separate profile or container.

### Non‑goals / safety rails

Claude **must not**:

- Rewrite large portions of upstream ns‑3 or Mininet from scratch.
- Silently drop major OpenNet features (Wi‑Fi scan, NetAnim link visualization, LTE backhaul, distributed emulation) without clearly documenting trade‑offs.
- Perform destructive operations on a developer’s host (e.g., editing `/etc/default/grub` or installing custom kernels) without being explicitly asked and clearly warning the user.
- Hard‑code professor‑ or lab‑specific paths, usernames, or IPs into shared scripts.

If a change might be risky (kernel patches, SSH root login, systemd changes), Claude should:
1. Propose the change in a **plan**.
2. Ask the user to confirm, and 
3. Prefer containing the change in a VM or Docker image.

---

## 3. Expected repository layout

This project is assumed to be a fork/clone of the original OpenNet repo, with the following key elements:

- `ansible/` – Ansible roles/playbooks for multi‑host deployment of OpenNet.
- `doc/`
  - `TUTORIAL.md` – Main design and usage tutorial for OpenNet.
- `ns3-patch/`
  - `lte.patch` – Adds SDN‑based LTE backhaul and time‑dilation hooks to ns‑3 LTE.
  - `sta-wifi-scan.patch` – Adds Wi‑Fi channel scanning behavior.
  - `animation-interface.patch` – Displays `CsmaLink`/`SimpleLink` in NetAnim.
  - `netanim-python.patch` – Python bindings / integration improvements for NetAnim.
- `configure.sh` – Legacy system‑level configuration script for original environment.
- `install.sh` – Legacy installer script that downloads ns‑3, Mininet, applies patches, etc.
- `mininet/` – Customized Mininet fork (cloned from `dlinknctu/mininet`) containing:
  - `mininet/examples/opennet/` – OpenNet example scripts.
  - `mininet/bin/opennet-agent.py` – TCP daemon for distributed ns‑3 emulation.
  - `mininet/mininet/lte.py` – LTE emulation interface.
  - `mininet/mininet/wifi.py` – Distributed Wi‑Fi emulation interface.
  - `mininet/mininet/ns3.py` – Wi‑Fi emulation interface from Mininet to ns‑3.
  - `mininet/mininet/opennet.py` – Utilities for NetAnim and pcap.
- `ns-allinone-3.xx/` – ns‑3 all‑in‑one tree (legacy; likely `ns-allinone-3.22/`).

**Modernization additions (to be created or maintained by Claude):**

- `scripts/bootstrap-ubuntu-22.04.sh` – Idempotent host‑level dependency installer.
- `scripts/dev-env-check.sh` – Quick sanity checks (versions, paths, environment).
- `docker/Dockerfile` – Modern development/runtime container.
- `docker/docker-compose.yml` (optional) – For multi‑container topologies or CI.
- `.github/workflows/ci.yml` – Minimal CI that builds ns‑3 + Mininet and runs a smoke test.
- `docs/REFACTORING_PLAN.md` – Detailed human‑readable migration plan (kept up to date).
- `docs/ARCHITECTURE-OVERVIEW.md` – System overview derived from `doc/TUTORIAL.md` and the OpenNet paper.

---

## 4. Environments and tooling

### 4.1 Target host environment

Assume:

- OS: **Ubuntu 22.04 LTS** (server or desktop).
- Shell: `bash`.
- Package manager: `apt`.

**Baseline host dependencies to install (via `scripts/bootstrap-ubuntu-22.04.sh`):**

Claude should ensure the bootstrap script installs at least:

- Core build tools:
  - `build-essential`, `cmake`, `gcc`, `g++`, `pkg-config`, `gdb`, `git`.
- Python and tooling:
  - `python3`, `python3-venv`, `python3-dev`, `python3-pip`.
- ns‑3 dependencies (approximate; adjust based on actual errors):
  - `libboost-all-dev`, `libgtk-3-dev`, `qtbase5-dev`, `qtchooser`, `qt5-qmake`,
  - `libsqlite3-dev`, `libxml2-dev`, `libgsl-dev`.
- Mininet / OpenFlow / OVS / networking:
  - `openvswitch-switch`, `openvswitch-common`, `tcpdump`, `iproute2`, `ethtool`, `bridge-utils`,
  - `net-tools` (for legacy scripts), `ssh`, `sshpass`.
- Ansible (if using `ansible/`):
  - `ansible`, `python3-paramiko` (or equivalent).

Claude may extend or trim this list based on build errors and 22.04‑specific best practices, but changes should be documented in `scripts/bootstrap-ubuntu-22.04.sh` and `docs/REFACTORING_PLAN.md`.

### 4.2 Containerization

Claude should maintain a `docker/Dockerfile` that:

1. Starts from a recent `ubuntu:22.04` base image.
2. Installs all build dependencies via `scripts/bootstrap-ubuntu-22.04.sh`.
3. Copies the repo into `/opt/opennet` (or similar) as a non‑root user.
4. Builds ns‑3 + patches and Mininet fork in a non‑interactive way (once that flow is defined).
5. Provides an entrypoint that can run a small example (e.g., an OpenNet Wi‑Fi test script) for smoke testing.

The container is the **source of truth** for reproducible builds. Host installation can be slightly more flexible but should conceptually match the container steps.

### 4.3 Time‑dilation / VirtualTimeForMininet

Treat time dilation as **optional**:

- Provide configuration flags or environment variables such as `OPENNET_ENABLE_VT=true`.
- If enabled, limit the installation to controlled environments (e.g., separate Docker image or VM that can safely run a custom kernel).
- Document the kernel version, patch repo, and exact commands in `docs/REFACTORING_PLAN.md`.

---

## 5. How Claude should work on this project

### 5.1 General behavior

When Claude Code is invoked in this repository:

1. **Start in Plan Mode** for any substantial change (refactors, new containerization, shell script rewrites).  
   - Create a step‑by‑step plan.
   - Get confirmation from the user before editing files.
2. Prefer **small, incremental commits** with clear messages:
   - Example: `chore: add ubuntu 22.04 bootstrap script`, `feat: dockerfile for ns-3.22 + opennet`.
3. Keep a strong separation between:
   - **Core logic** (ns‑3 patches, Mininet OpenNet integrations).
   - **Environment scripts and tooling** (installers, Ansible, Docker, CI).
4. **Never assume sudo on behalf of the user.** If a command needs `sudo`, say so explicitly and comment it in the relevant script rather than executing it yourself.

### 5.2 Default workflows

#### Workflow A — Understand current state

When asked to understand or summarize the project:

1. Read:
   - `README.md`
   - `doc/TUTORIAL.md`
   - Any top‑level `doc/*.md` files.
2. List the existing top‑level files and directories.
3. Summarize:
   - How OpenNet integrates Mininet and ns‑3 (Python bindings, opennet-agent).
   - How Wi‑Fi, LTE, and NetAnim patches are wired in.
   - The roles of `configure.sh` and `install.sh`.
4. Write or update `docs/ARCHITECTURE-OVERVIEW.md` if it is missing or outdated.

#### Workflow B — Modernize install pipeline for Ubuntu 22.04

1. Analyze **but do not immediately run** `configure.sh` and `install.sh`.
   - Identify: OS assumptions, kernel changes, package installations, file system layout.
2. Create `scripts/bootstrap-ubuntu-22.04.sh` that:
   - Installs OS packages required by ns‑3.22 and Mininet on 22.04.
   - Is idempotent and safe to re‑run.
   - Avoids dangerous changes (kernel update, GRUB edits) by default.
3. Update documentation:
   - Add a section to `README.md` for Ubuntu 22.04 usage.
   - Expand `docs/REFACTORING_PLAN.md` to describe legacy vs new pipelines.
4. Add a minimal `docker/Dockerfile` that uses the bootstrap script and runs a smoke test.

#### Workflow C — Port ns‑3 patches and build ns‑3 on 22.04

1. Inspect files under `ns3-patch/`.
2. Attempt to apply them cleanly to the target ns‑3 source inside the all‑in‑one tree (e.g., `ns-allinone-3.22/ns-3.22`).
3. Run the usual ns‑3 build sequence:
   - `./waf configure --enable-python`
   - `./waf build`
   - `./waf install`
4. If build errors occur due to compiler or library changes on Ubuntu 22.04:
   - Prefer local, minimal fixes (e.g., add `#include <cstdint>` instead of risky work‑arounds).
   - Avoid changing the intended behavior of the OpenNet patches.
5. Document any compromises or behavior changes in `docs/REFACTORING_PLAN.md`.

#### Workflow D — Python 3 and Mininet integration

1. Identify all Python scripts that are part of OpenNet (especially under `mininet/`).
2. Detect Python 2‑only constructs (e.g., `print` statements without parentheses, `xrange`, old exception syntax).
3. Propose a migration plan:
   - For scripts that can be easily ported, apply `2to3`‑style changes and manually review.
   - For scripts tightly coupled to Mininet versions that expect Python 2, consider:
     - Running them inside a Python 2 environment in Docker, or
     - Pinning to a Mininet release with Python 3 support and re‑porting OpenNet logic.
4. Update shebangs and documentation to favor Python 3 virtual environments.

#### Workflow E — CI and smoke tests

1. Add `.github/workflows/ci.yml` that:
   - Runs on Ubuntu 22.04.
   - Checks out the repo.
   - Runs `scripts/bootstrap-ubuntu-22.04.sh`.
   - Builds ns‑3 and Mininet.
   - Executes at least one simple OpenNet example (Wi‑Fi or LTE) as a smoke test.
2. Keep CI fast and robust:
   - Prefer small topologies and short simulation times.
   - Make long‑running examples opt‑in.

---

## 6. Specific instructions about key components

### 6.1 Ansible (`ansible/`)

- Treat Ansible playbooks as **optional tooling** for multi‑host setups.
- Keep roles and playbooks compatible with Ansible on Ubuntu 22.04:
  - Update deprecated modules or syntax where needed.
  - Avoid hard‑coding hostnames/IPs.
- Document typical inventory patterns (e.g., `[opennet_master]`, `[opennet_workers]`) in comments.

### 6.2 Distributed Mininet and NS‑3

- **Mininet cluster:**
  - When documenting instructions, prefer SSH key authentication instead of password‑based root login.
  - If modifying existing scripts that edit `/etc/ssh/sshd_config`, keep changes behind explicit user confirmation and clearly comment them.
- **OpenNet agent (`opennet-agent.py`):**
  - If modernizing this script, keep the TCP protocol backward‑compatible where possible.
  - Ensure it works with Python 3 or clearly document if Python 2 is still required and why.

### 6.3 Time dilation

- Keep any VirtualTimeForMininet integration **opt‑in**.
- Provide clear instructions (ideally in `docs/REFACTORING_PLAN.md`) for:
  - Installing the virtual‑time kernel in an isolated environment.
  - Booting into that kernel.
  - Running OpenNet examples that rely on time dilation.
- If time dilation cannot be ported in a reasonable timeframe, it is acceptable to:
  - Temporarily disable time‑dilation‑dependent examples.
  - Mark them clearly as “legacy / needs virtual‑time kernel”.

---

## 7. Coding style and refactor guidelines

When editing code or scripts in this repo:

- Prefer **small, isolated diffs** and explain them in commit messages.
- Add **comments near tricky parts**, especially where:
  - Behavior depends on specific ns‑3 or Mininet versions.
  - Time dilation or virtualization assumptions are in play.
- For shell scripts:
  - Use `set -euo pipefail` where safe.
  - Avoid interactive prompts; either:
    - Default to safe behavior, or
    - Require explicit flags for dangerous actions (e.g., `--enable-kernel-patch`).
- For Python:
  - Target Python 3.10+.
  - Use `venv` instead of system‑wide installs when possible.
- For new documentation:
  - Keep it in `docs/*.md` rather than long comments inside scripts.

---

## 8. Suggested prompts and workflows for the human user

These are **suggested ways** to talk to Claude Code when working on this repo:

- “Give me a high‑level overview of this repo and how OpenNet integrates Mininet and ns‑3.”
- “Read configure.sh and install.sh in plan mode, then propose a modern replacement for Ubuntu 22.04 that is non‑destructive.”
- “Create or update `scripts/bootstrap-ubuntu-22.04.sh` so that it installs all dependencies to build ns‑3.22 and Mininet on Ubuntu 22.04.”
- “Add a Dockerfile that reproduces the OpenNet environment on Ubuntu 22.04, then update `docs/REFACTORING_PLAN.md` to describe how to use it.”
- “Try to build ns‑3 with the patches in `ns3-patch/` and fix compile errors without changing intended behavior. Document everything you had to change.”
- “Audit Python scripts under `mininet/` and propose a migration plan to Python 3, including any trade‑offs and testing strategy.”
- “Design a minimal GitHub Actions workflow that builds OpenNet on Ubuntu 22.04 and runs one short OpenNet example as a smoke test.”

---

## 9. Keep this file up to date

Whenever Claude or a human makes structural changes to the project (new scripts, new Dockerfile, major refactors), they should:

1. Update:
   - This `CLAUDE.md`;
   - `docs/REFACTORING_PLAN.md`; and
   - Any relevant README sections.
2. Briefly summarize:
   - What changed,
   - Why it changed, and
   - How to reproduce or test the new behavior.

This keeps Claude Code “in sync” with the real state of the project and makes it much easier for future contributors (and future versions of Claude) to understand and extend OpenNet safely.

## AI Patch Guardrails (for Claude Code)

You are Claude Code working on this repository.  
Your main responsibilities are:
- Help implement small, well-scoped changes.
- Respect existing architecture, tests, and maintainer feedback.
- Avoid over-engineering and premature abstraction.

**IMPORTANT: You MUST follow all rules in this section whenever you propose patches or edit files.**

---

### 0. General workflow

1. **Explore & understand before coding**
   - ALWAYS read the relevant files and existing tests first.
   - Summarize your understanding and planned changes before editing.
   - If anything is ambiguous, ask for clarification instead of guessing.

2. **Plan → Implement → Verify**
   - Make a short plan (“think hard”) before you start editing.
   - Keep changes minimal and focused on the requested task.
   - Always run the relevant tests or at least explain precisely how to run them.

3. **Respect project-local rules**
   - The rules below (imports, logging, Dockerfile, tests, etc.) come from real code review feedback.
   - Treat them as authoritative for this repository.

---

### 1. Function abstraction & structure

**IMPORTANT: DO NOT introduce premature abstractions.**

1. **No trivial wrapper functions**
   - If a function only:
     - has 1–2 lines, AND
     - just calls another function (e.g., `return compose_text_message(...)`),
     - and is used only 1–2 times,
   - THEN: DO NOT create a separate helper function for it.
   - Example: DO NOT create `create_error_message(lang_code: str)` that only wraps `compose_text_message(get_response(...))`.

2. **Rule of Three (YAGNI)**
   - 1st occurrence: write the code inline.
   - 2nd occurrence: copy-paste is acceptable.
   - 3rd occurrence: you MAY propose a helper.
   - 4th occurrence: you SHOULD refactor into a shared abstraction.
   - Any refactor MUST clearly improve readability and reduce real duplication, not just “cosmetic” wrapping.

3. **Handler vs implementation**
   - For public handlers, follow this pattern:
     - `handler()`:
       - Handles `try/except`.
       - Logs exceptions with `logger.exception(...)`.
       - Returns a standard error message.
     - `_handler_impl()`:
       - Contains business logic only.
   - DO NOT move complex business logic into the handler.

---

### 2. Python imports

**IMPORTANT: All imports MUST follow PEP 8 and be at module top-level.**

1. **Placement**
   - Place imports at the top of the file, after module comments/docstring.
   - DO NOT add imports inside functions or methods unless explicitly documented as an exception.

2. **Order**
   - Group imports as:
     1. Standard library
     2. Third-party libraries
     3. Local modules
   - Separate each group with a blank line.

3. **Example**

```python
# 1. Standard library
from typing import Dict, Optional

# 2. Third-party
from linebot.v3.messaging import TextMessage

# 3. Local modules
from src.modules.qna.constants import RESPONSE_DATA_PATH
from src.modules.utils import compose_text_message, get_response
```

---

### 3. Logging & error handling

1. **Use `logger.exception` in `except` blocks**
   - When catching unexpected errors in handlers, prefer:
     ```python
     except Exception as e:
         logger.exception(f"Error in qna_handler: {e}")
         return compose_text_message(
             get_response(RESPONSE_DATA_PATH, "error_message", lang_code)
         )
     ```
   - This captures the full stack trace at ERROR level.

2. **Separation of concerns**
   - Handlers:
     - Validate input.
     - Call `_impl`.
     - Catch and log unexpected errors.
   - `_impl` functions:
     - Contain business logic and can be unit-tested directly.

---

### 4. Dockerfile changes

**IMPORTANT: Keep runtime images slim and focused on runtime dependencies.**

1. **Base image**
   - Prefer minimal base images similar to:
     ```Dockerfile
     FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim
     ```

2. **Dependency installation**
   - Copy only `pyproject.toml` and lockfiles before running the install command.
   - Install ONLY runtime dependencies inside the final image.
   - DO NOT install tools that are only required for:
     - type checking (e.g. pyright),
     - linters,
     - local development.
   - If such tools are needed, suggest:
     - a dev-only image, or
     - a separate `dev` target in the Dockerfile,
     - but DO NOT add them silently.

---

### 5. Code smell & refactoring

When you notice repetition:

1. **Do NOT refactor automatically just because you see repetition.**
   - First, check:
     - Is this “incidental” repetition (similar text but different semantics)?
     - Or “essential” repetition (same logic, same semantics)?

2. **Avoid shotgun surgery**
   - If a change requires modifying many different files and call sites for a small benefit, you are probably introducing a bad abstraction.
   - In that case:
     - Explain the tradeoffs.
     - Ask the user before proceeding with a large refactor.

---

### 6. Tests & TDD

**IMPORTANT: Tests must be meaningful, not just “green”.**

1. **Correct TDD order**
   - DO NOT follow:
     - “write tests → accept whatever output you get”.
   - Instead:
     - Read the existing implementation first.
     - Understand whether the feature is implemented or still TODO.
     - Design tests that match the intended behavior.
     - Then update implementation to satisfy those tests.

2. **Detect unimplemented features**
   - If you see any of the following:
     - `// TODO: implement this`
     - returning an **empty struct** (e.g., `Tracing: &SomeType{}`)
     - variables assigned but only used as `_ = variable`
     - golden files containing empty objects like `tracing: {}`
   - THEN:
     - Treat the feature as “NOT YET IMPLEMENTED”.
     - DO NOT write tests that pretend the feature is fully working.
     - Instead, you may:
       - Add clearly labeled placeholder tests, OR
       - Create a GitHub issue describing the missing implementation.

3. **Test naming**
   - Use precise names:
     - `valid-X` → tests the successful path.
     - `invalid-X` → tests error handling and validation failures.
     - `placeholder-X` → feature not yet fully implemented, placeholder coverage only.
   - DO NOT name a test `invalid-tracing` if it does not actually test invalid behavior.

4. **No skipped tests in new code**
   - DO NOT add tests with `t.Skip()` unless explicitly requested and clearly documented as a temporary measure.
   - All new tests you add SHOULD run and pass on CI.

5. **Avoid redundant tests**
   - Before adding a new test file:
     - Check existing E2E / integration tests.
     - If existing tests already cover the behavior, DO NOT add redundant tests.
   - Example: For minimal RBAC changes, prefer relying on existing E2E tests rather than adding new tests that just verify Kubernetes basics.

6. **Use standard library & project helpers**
   - In Go tests:
     - Prefer `strings.Contains` over custom substring checks.
     - Use existing helper packages (e.g. `ktesting/setup.go`) instead of building ad-hoc loggers or setups.

---

### 7. File selection & change scope

**IMPORTANT: Keep diffs minimal and focused.**

1. **Verify file usage before editing**
   - Before modifying a file:
     - Check if it is still used in the build/runtime.
     - For suspicious files (e.g., old generators like `kubebuilder-gen.go`):
       - Use `git grep` or build commands to confirm usage.
   - If a maintainer comment says “this file is not used anymore, better to delete it”:
     - DO NOT update the file.
     - Suggest deleting it instead, if appropriate for this PR.

2. **Minimal patch principle**
   - For tasks like “minimal RBAC fix”:
     - Focus only on the specific RBAC manifests mentioned by the issue or reviewer.
     - Avoid:
       - editing unrelated manifests,
       - adding new test suites,
       - touching generator files unless required.

3. **Respect project conventions**
   - Follow existing patterns in the codebase:
     - Same logging style.
     - Same error handling style.
     - Same file layout and naming conventions.

---

### 8. Human review & maintainer feedback

1. **Maintainer comments are authoritative**
   - When a reviewer (e.g. project maintainer) gives feedback like:
     - “These tests are unnecessary.”
     - “This file is unused; delete it instead of updating it.”
   - You MUST:
     - Treat this feedback as the source of truth for future edits.
     - Reflect these rules in your subsequent patches.

2. **Document learnings**
   - When you discover a new project-specific rule through review:
     - Propose an update to `CLAUDE.md` (or ask the user to add it).
     - Follow the updated rule consistently in future changes.

---

### 9. How to work with tests & golden files in this repo

1. **Golden files**
   - When adding or updating golden files (YAML, JSON, etc.):
     - Ensure they contain meaningful, non-empty configuration.
     - If the implementation is a placeholder, clearly mark the golden file as such with comments.
     - Question suspicious emptiness (e.g., `tracing: {}`) and check whether the feature is really implemented.

2. **Creating follow-up issues**
   - If you identify missing behavior (e.g., tracing translation not fully implemented):
     - Propose creating a GitHub issue with:
       - Title, e.g.: `"Implement tracing translation in AgentgatewayPolicy frontend"`.
       - Links to the relevant PR / tests / files.
       - A plan for implementation and test updates.

---

### 10. Claude Code behavior summary (TL;DR)

When generating patches in this repo, you MUST:

- **Understand before coding**: read implementation & tests first.
- **Keep changes minimal**: avoid editing unused files or adding redundant tests.
- **Avoid premature abstraction**: no one-line wrappers unless used ≥3 times AND more readable.
- **Follow local style**: imports at top, logging via `logger.exception`, handler + `_impl` split, slim Dockerfiles.
- **Design meaningful tests**: no fake “invalid” tests, no `t.Skip()` tests, no empty golden files unless clearly marked as placeholders.
- **Respect maintainers**: treat review comments as project rules and adjust your behavior accordingly.

If you are unsure which rule applies, you MUST stop, summarize the options, and ask the user for guidance before making large-scale or irreversible changes.


# CLAUDE.md

## AI Patch Guardrails (for Claude Code)

You are Claude Code working on this repository.  
Your main responsibilities are:
- Help implement small, well-scoped changes.
- Respect existing architecture, tests, and maintainer feedback.
- Avoid over-engineering and premature abstraction.

**IMPORTANT: You MUST follow all rules in this section whenever you propose patches or edit files.**

---

### 0. General workflow

1. **Explore & understand before coding**
   - ALWAYS read the relevant files and existing tests first.
   - Summarize your understanding and planned changes before editing.
   - If anything is ambiguous, ask for clarification instead of guessing.

2. **Plan → Implement → Verify**
   - Make a short plan (“think hard”) before you start editing.
   - Keep changes minimal and focused on the requested task.
   - Always run the relevant tests or at least explain precisely how to run them.

3. **Respect project-local rules**
   - The rules below (imports, logging, Dockerfile, tests, etc.) come from real code review feedback.
   - Treat them as authoritative for this repository.

---

### 1. Function abstraction & structure

**IMPORTANT: DO NOT introduce premature abstractions.**

1. **No trivial wrapper functions**
   - If a function only:
     - has 1–2 lines, AND
     - just calls another function (e.g., `return compose_text_message(...)`),
     - and is used only 1–2 times,
   - THEN: DO NOT create a separate helper function for it.
   - Example: DO NOT create `create_error_message(lang_code: str)` that only wraps `compose_text_message(get_response(...))`.

2. **Rule of Three (YAGNI)**
   - 1st occurrence: write the code inline.
   - 2nd occurrence: copy-paste is acceptable.
   - 3rd occurrence: you MAY propose a helper.
   - 4th occurrence: you SHOULD refactor into a shared abstraction.
   - Any refactor MUST clearly improve readability and reduce real duplication, not just “cosmetic” wrapping.

3. **Handler vs implementation**
   - For public handlers, follow this pattern:
     - `handler()`:
       - Handles `try/except`.
       - Logs exceptions with `logger.exception(...)`.
       - Returns a standard error message.
     - `_handler_impl()`:
       - Contains business logic only.
   - DO NOT move complex business logic into the handler.

---

### 2. Python imports

**IMPORTANT: All imports MUST follow PEP 8 and be at module top-level.**

1. **Placement**
   - Place imports at the top of the file, after module comments/docstring.
   - DO NOT add imports inside functions or methods unless explicitly documented as an exception.

2. **Order**
   - Group imports as:
     1. Standard library
     2. Third-party libraries
     3. Local modules
   - Separate each group with a blank line.

3. **Example**

```python
# 1. Standard library
from typing import Dict, Optional

# 2. Third-party
from linebot.v3.messaging import TextMessage

# 3. Local modules
from src.modules.qna.constants import RESPONSE_DATA_PATH
from src.modules.utils import compose_text_message, get_response
```

---

### 3. Logging & error handling

1. **Use `logger.exception` in `except` blocks**
   - When catching unexpected errors in handlers, prefer:
     ```python
     except Exception as e:
         logger.exception(f"Error in qna_handler: {e}")
         return compose_text_message(
             get_response(RESPONSE_DATA_PATH, "error_message", lang_code)
         )
     ```
   - This captures the full stack trace at ERROR level.

2. **Separation of concerns**
   - Handlers:
     - Validate input.
     - Call `_impl`.
     - Catch and log unexpected errors.
   - `_impl` functions:
     - Contain business logic and can be unit-tested directly.

---

### 4. Dockerfile changes

**IMPORTANT: Keep runtime images slim and focused on runtime dependencies.**

1. **Base image**
   - Prefer minimal base images similar to:
     ```Dockerfile
     FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim
     ```

2. **Dependency installation**
   - Copy only `pyproject.toml` and lockfiles before running the install command.
   - Install ONLY runtime dependencies inside the final image.
   - DO NOT install tools that are only required for:
     - type checking (e.g. pyright),
     - linters,
     - local development.
   - If such tools are needed, suggest:
     - a dev-only image, or
     - a separate `dev` target in the Dockerfile,
     - but DO NOT add them silently.

---

### 5. Code smell & refactoring

When you notice repetition:

1. **Do NOT refactor automatically just because you see repetition.**
   - First, check:
     - Is this “incidental” repetition (similar text but different semantics)?
     - Or “essential” repetition (same logic, same semantics)?

2. **Avoid shotgun surgery**
   - If a change requires modifying many different files and call sites for a small benefit, you are probably introducing a bad abstraction.
   - In that case:
     - Explain the tradeoffs.
     - Ask the user before proceeding with a large refactor.

---

### 6. Tests & TDD

**IMPORTANT: Tests must be meaningful, not just “green”.**

1. **Correct TDD order**
   - DO NOT follow:
     - “write tests → accept whatever output you get”.
   - Instead:
     - Read the existing implementation first.
     - Understand whether the feature is implemented or still TODO.
     - Design tests that match the intended behavior.
     - Then update implementation to satisfy those tests.

2. **Detect unimplemented features**
   - If you see any of the following:
     - `// TODO: implement this`
     - returning an **empty struct** (e.g., `Tracing: &SomeType{}`)
     - variables assigned but only used as `_ = variable`
     - golden files containing empty objects like `tracing: {}`
   - THEN:
     - Treat the feature as “NOT YET IMPLEMENTED”.
     - DO NOT write tests that pretend the feature is fully working.
     - Instead, you may:
       - Add clearly labeled placeholder tests, OR
       - Create a GitHub issue describing the missing implementation.

3. **Test naming**
   - Use precise names:
     - `valid-X` → tests the successful path.
     - `invalid-X` → tests error handling and validation failures.
     - `placeholder-X` → feature not yet fully implemented, placeholder coverage only.
   - DO NOT name a test `invalid-tracing` if it does not actually test invalid behavior.

4. **No skipped tests in new code**
   - DO NOT add tests with `t.Skip()` unless explicitly requested and clearly documented as a temporary measure.
   - All new tests you add SHOULD run and pass on CI.

5. **Avoid redundant tests**
   - Before adding a new test file:
     - Check existing E2E / integration tests.
     - If existing tests already cover the behavior, DO NOT add redundant tests.
   - Example: For minimal RBAC changes, prefer relying on existing E2E tests rather than adding new tests that just verify Kubernetes basics.

6. **Use standard library & project helpers**
   - In Go tests:
     - Prefer `strings.Contains` over custom substring checks.
     - Use existing helper packages (e.g. `ktesting/setup.go`) instead of building ad-hoc loggers or setups.

---

### 7. File selection & change scope

**IMPORTANT: Keep diffs minimal and focused.**

1. **Verify file usage before editing**
   - Before modifying a file:
     - Check if it is still used in the build/runtime.
     - For suspicious files (e.g., old generators like `kubebuilder-gen.go`):
       - Use `git grep` or build commands to confirm usage.
   - If a maintainer comment says “this file is not used anymore, better to delete it”:
     - DO NOT update the file.
     - Suggest deleting it instead, if appropriate for this PR.

2. **Minimal patch principle**
   - For tasks like “minimal RBAC fix”:
     - Focus only on the specific RBAC manifests mentioned by the issue or reviewer.
     - Avoid:
       - editing unrelated manifests,
       - adding new test suites,
       - touching generator files unless required.

3. **Respect project conventions**
   - Follow existing patterns in the codebase:
     - Same logging style.
     - Same error handling style.
     - Same file layout and naming conventions.

---

### 8. Human review & maintainer feedback

1. **Maintainer comments are authoritative**
   - When a reviewer (e.g. project maintainer) gives feedback like:
     - “These tests are unnecessary.”
     - “This file is unused; delete it instead of updating it.”
   - You MUST:
     - Treat this feedback as the source of truth for future edits.
     - Reflect these rules in your subsequent patches.

2. **Document learnings**
   - When you discover a new project-specific rule through review:
     - Propose an update to `CLAUDE.md` (or ask the user to add it).
     - Follow the updated rule consistently in future changes.

---

### 9. How to work with tests & golden files in this repo

1. **Golden files**
   - When adding or updating golden files (YAML, JSON, etc.):
     - Ensure they contain meaningful, non-empty configuration.
     - If the implementation is a placeholder, clearly mark the golden file as such with comments.
     - Question suspicious emptiness (e.g., `tracing: {}`) and check whether the feature is really implemented.

2. **Creating follow-up issues**
   - If you identify missing behavior (e.g., tracing translation not fully implemented):
     - Propose creating a GitHub issue with:
       - Title, e.g.: `"Implement tracing translation in AgentgatewayPolicy frontend"`.
       - Links to the relevant PR / tests / files.
       - A plan for implementation and test updates.

---

### 10. Claude Code behavior summary (TL;DR)

When generating patches in this repo, you MUST:

- **Understand before coding**: read implementation & tests first.
- **Keep changes minimal**: avoid editing unused files or adding redundant tests.
- **Avoid premature abstraction**: no one-line wrappers unless used ≥3 times AND more readable.
- **Follow local style**: imports at top, logging via `logger.exception`, handler + `_impl` split, slim Dockerfiles.
- **Design meaningful tests**: no fake “invalid” tests, no `t.Skip()` tests, no empty golden files unless clearly marked as placeholders.
- **Respect maintainers**: treat review comments as project rules and adjust your behavior accordingly.

If you are unsure which rule applies, you MUST stop, summarize the options, and ask the user for guidance before making large-scale or irreversible changes.
