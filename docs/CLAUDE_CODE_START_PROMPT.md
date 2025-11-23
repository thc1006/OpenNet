# Suggested start prompt for Claude Code (web)

You can paste the following as your **first message** to Claude Code when working on this repo:

---

You are an expert in ns-3, Mininet, and legacy SDN research tooling. You are helping me **modernize the OpenNet project** (Mininet + ns-3 based SD-WLAN / LTE backhaul emulator) so that it runs reliably on Ubuntu 22.04+.

I am a student who has inherited this old research code. The project has not been maintained for several years, but my professor wants me to:

- Make it build and run on Ubuntu 22.04 (server/headless is fine).
- Preserve the original research behavior as much as reasonably possible (Wi-Fi scan, LTE backhaul, NetAnim integration, distributed mode, optional time dilation).
- Clean up and modernize the environment setup (Ansible, SSH, ns-3 build, Mininet integration).
- Add at least one containerized environment and basic CI for reproducibility.

IMPORTANT: Before you do anything else, please:

1. Read the following files carefully:
   - `CLAUDE.md` (this is your system-level instruction file for this repo)
   - `docs/ARCHITECTURE-OVERVIEW.md`
   - `docs/REFACTORING_PLAN.md`
   - `configure.sh`
   - `install.sh`
   - `ansible/hosts`
   - `ansible/playbook.yml`
2. Build a mental model of:
   - How OpenNet was originally installed and configured (single-node vs. multi-node).
   - What `configure.sh` and `install.sh` are doing, including all assumptions and risks (e.g., editing /etc/hosts, editing /etc/ssh/sshd_config, cloning old Ansible).
   - How Ansible is being used to deploy OpenNet.

Then, following the Explore → Plan → Execute pattern that Anthropic recommends for Claude Code:

### Step 1 — Explore & summarize

- Summarize, in your own words, how the current installation pipeline works, end to end.
- Explicitly list:
  - All system-level changes (`/etc/hosts`, `/etc/ssh/sshd_config`, SSH keys).
  - All external dependencies (ns-3 version, Mininet fork, Ansible version, Python version).
- Highlight anything that is obviously outdated or unsafe on Ubuntu 22.04 (e.g., `easy_install`, old Ansible clone, risky SSH configuration).

### Step 2 — Propose a modernization plan (focused on what we can do in 1–2 days)

Given that I have limited time, propose a **concrete, prioritized plan** for a “minimum viable modernization” that we can realistically achieve soon, for example:

1. Make host dependencies explicit and safe on Ubuntu 22.04:
   - Refine `scripts/bootstrap-ubuntu-22.04.sh` (if needed).
   - Add or adjust `scripts/dev-env-check.sh`.
2. Design a modern replacement for `install.sh`:
   - Use system Ansible (`apt-get install ansible`) or a simple pip install instead of cloning Ansible v2.3.2.
   - Avoid editing `/etc/ssh/sshd_config` automatically; instead, document recommended settings and/or move them into explicit Ansible roles that I can review.
   - Keep SSH key distribution, but make it safe and transparent.
3. Define and document a clear workflow for:
   - Downloading and patching ns-3 (initially ns-3.22).
   - Building ns-3 with Python bindings on Ubuntu 22.04.
   - Building/running the Mininet fork with OpenNet glue.
4. (If time allows) Wire up:
   - A minimal Dockerfile that reproduces the 22.04 environment.
   - A GitHub Actions CI job that builds and runs a tiny OpenNet example.

In your plan, please:

- Be very explicit about which parts you want to change and which parts should stay as close to the original as possible.
- Assume I want to keep the research semantics intact (e.g., how Wi-Fi scanning and LTE backhaul behave) and only modernize the “plumbing” around them.

### Step 3 — Execute in small, reviewable steps

Once I confirm your plan:

- Work on ONE logical step at a time (for example: “modernize Ansible installation”, or “create ns-3 install script”), and for each step:
  - Show me a short plan for that step.
  - Then edit/create the relevant files.
  - Explain what changed and why.
  - Suggest concrete commands I should run on an Ubuntu 22.04 host to test that step (e.g., a sequence of `bash scripts/…` and `./waf …` commands).
- Update `docs/REFACTORING_PLAN.md` at the end of each major step with a brief status note.

Important guard rails:

- Do NOT run or suggest commands that silently edit `/etc/ssh/sshd_config` or `/etc/hosts` without clearly labeling them as potentially dangerous and asking for confirmation.
- Prefer scripts that I can run manually over scripts that try to do everything automatically in one shot.
- When in doubt, err on the side of being explicit and conservative.

If you understand, please:

1. Confirm that you have read and parsed all the files listed above.
2. Give me your summarized understanding of the current installation + configuration flow.
3. Present your proposed modernization plan as a numbered checklist that we can tackle step by step today.
