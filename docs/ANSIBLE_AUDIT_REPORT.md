# Ansible Roles Audit Report for Ubuntu 22.04 / Debian 13

**Date:** 2025-11-24
**Scope:** Audit of remaining Ansible roles for OpenNet modernization
**Target Platform:** Ubuntu 22.04 LTS / Debian 13
**Status:** Most roles require updates; some are already modernized.

---

## Executive Summary

Out of **11 roles** in the OpenNet Ansible suite:

- **5 roles already modernized** (apt, ez_setup, pygccxml, gccxml, help)
- **6 roles require updates** (ns3, netanim, dlinknctu-mininet, openvswitch, ntp, qperf)

Key issues identified:

1. **Qt4 obsolescence** - netanim still uses `qmake-qt4` (not available on Ubuntu 22.04+)
2. **Python 2 packages** - openvswitch installs `python-openvswitch` (Python 2 only)
3. **Deprecated Ansible modules** - `service:` and `apt:` used without `name:` keyword (deprecated syntax)
4. **No enable flags** - Several roles missing `become:` or proper privilege escalation setup
5. **Hardcoded paths** - Some roles assume specific installation locations
6. **No error checking** - Several async tasks with `ignore_errors: true` hide real failures
7. **Old NTP daemon** - ntp role installs deprecated `ntp` daemon instead of `systemd-timesyncd` or `chrony`

---

## Detailed Audit by Role

### 1. Role: ns3

**File:** `/home/thc1006/dev/OpenNet/ansible/roles/ns3/tasks/main.yml`
**Status:** Requires updates
**Severity:** Medium

#### Issues Found:

| Line | Issue | Type | Recommended Fix |
|------|-------|------|-----------------|
| 28 | `command: "./waf configure"` without explicit `--enable-python` | Missing flag | Add `--enable-python --enable-python-bindings` to configure |
| 34-43 | Async waf apiscan with `ignore_errors: true` can hide real failures | Error handling | Either remove async/poll or add proper error checking |
| 45-51 | Async waf build with `ignore_errors: true` - dangerous | Error handling | Change to `async: 0 poll: 1` to wait for completion; add failure detection |
| 59 | `command: "ldconfig"` requires root | Privilege escalation | Add `become: yes` to task |

#### Details:

**Lines 27-32 (Waf configure):**
```yaml
- name: Waf configure
  command: "./waf configure"
  args:
    chdir: "{{ home_location }}/ns-allinone-{{ NS3_VERSION }}/ns-{{ NS3_VERSION }}"
  register: gg
  tags: ns3
```

**Problem:** The `waf configure` is called without `--enable-python` flag. For ns-3 to work with Mininet (which uses Python bindings), Python support must be enabled.

**Recommended fix:**
```yaml
- name: Waf configure with Python bindings
  command: "./waf configure --enable-python --enable-python-bindings"
  args:
    chdir: "{{ home_location }}/ns-allinone-{{ NS3_VERSION }}/ns-{{ NS3_VERSION }}"
  register: waf_config
  tags: ns3
```

**Lines 33-44 (Waf apiscan async):**
```yaml
- name: Waf apiscan
  command: "./waf --apiscan={{ item }}"
  with_items:
    - netanim
    - wifi
    - lte
  args:
    chdir: "{{ home_location }}/ns-allinone-{{ NS3_VERSION }}/ns-{{ NS3_VERSION }}"
  async: 0
  poll: 0
  ignore_errors: true
  tags: ns3
```

**Problem:** `async: 0 poll: 0` means "fire and forget" - the playbook doesn't wait for apiscan to complete. The `ignore_errors: true` hides failures. This can lead to incomplete API documentation.

**Recommended fix:**
```yaml
- name: Waf apiscan (generate API bindings)
  command: "./waf --apiscan={{ item }}"
  with_items:
    - netanim
    - wifi
    - lte
  args:
    chdir: "{{ home_location }}/ns-allinone-{{ NS3_VERSION }}/ns-{{ NS3_VERSION }}"
  tags: ns3
  # NOTE: apiscan can be slow on older systems.
  # Set async timeout if you experience timeouts on slow hardware.
```

**Lines 45-52 (Waf build async):**
```yaml
- name: Waf build
  command: "./waf build"
  args:
    chdir: "{{ home_location }}/ns-allinone-{{ NS3_VERSION }}/ns-{{ NS3_VERSION }}"
  async: 0
  poll: 0
  ignore_errors: true
  tags: ns3
```

**Problem:** Same as apiscan - fire-and-forget with error suppression. The playbook will report success even if the build fails. This is a critical issue.

**Recommended fix:**
```yaml
- name: Waf build
  command: "./waf build --jobs={{ ansible_processor_vcpus | default(4) }}"
  args:
    chdir: "{{ home_location }}/ns-allinone-{{ NS3_VERSION }}/ns-{{ NS3_VERSION }}"
  timeout: 3600  # 1 hour - ns-3 builds can be slow
  tags: ns3
```

**Line 59 (ldconfig):**
```yaml
- name: Configure dynamic linker run-time bindings
  command: "ldconfig"
  tags: ns3
```

**Problem:** `ldconfig` typically requires root privileges. On a system with restricted sudoers config, this will fail silently or with "permission denied".

**Recommended fix:**
```yaml
- name: Configure dynamic linker run-time bindings
  command: "ldconfig"
  become: yes  # Requires root
  tags: ns3
```

---

### 2. Role: netanim

**File:** `/home/thc1006/dev/OpenNet/ansible/roles/netanim/tasks/main.yml`
**Status:** Requires critical updates
**Severity:** Critical

#### Issues Found:

| Line | Issue | Type | Recommended Fix |
|------|-------|------|-----------------|
| 7 | `qmake-qt4` not available on Ubuntu 22.04+ | Deprecated tool | Use `qmake` from Qt 5 instead |
| 12-17 | Async make with `ignore_errors: true` | Error handling | Remove async; use proper error checking |

#### Details:

**Lines 6-10 (qmake-qt4):**
```yaml
- name: qmake Netanim
  command: "qmake-qt4 NetAnim.pro"
  args:
    chdir: "{{ netanim_location }}"
  tags: netanim
```

**Problem:** Qt 4 is end-of-life and not packaged on Ubuntu 22.04+. The `qmake-qt4` tool does not exist. NetAnim has Qt 5 support in modern versions.

**Status Check:** NetAnim 3.105 (specified in `group_vars/all`) was released in 2014 and may not have proper Qt 5 support. This likely requires upgrading NetAnim version or using pre-built binaries.

**Recommended fix (Option 1 - Upgrade NetAnim):**
```yaml
- name: Download NetAnim 3.114+ (Qt5 support)
  get_url:
    url: "https://www.nsnam.org/releases/ns-allinone-3.22.1.tar.bz2"
    dest: "{{ home_location }}"
  tags: netanim

- name: Untar NetAnim
  unarchive:
    src: "{{ home_location }}/ns-allinone-3.22.1.tar.bz2"
    dest: "{{ home_location }}"
  tags: netanim

- name: qmake NetAnim with Qt5
  command: "qmake NetAnim.pro"  # Uses system qmake (Qt5)
  args:
    chdir: "{{ netanim_location }}"
  tags: netanim
```

**Recommended fix (Option 2 - Use pre-built binary or skip):**
```yaml
- name: NetAnim deprecation notice
  debug:
    msg: |
      NetAnim 3.105 requires Qt4 which is EOL and not available on Ubuntu 22.04+.

      Options:
      1. Upgrade to NetAnim 3.114+ (requires ns-3.22.1+)
      2. Use ns-3 37+ with built-in visualization
      3. Run NetAnim in a legacy Docker container
      4. Skip NetAnim and use alternative tools (wireshark, pcap analysis)
  tags: netanim
```

**Lines 11-18 (Async make):**
```yaml
- name: make Netanim
  command: "make"
  args:
    chdir: "{{ netanim_location }}"
  async: 0
  poll: 0
  ignore_errors: true
  tags: netanim
```

**Problem:** Same async + ignore_errors pattern. Make failures are hidden.

**Recommended fix:**
```yaml
- name: Build NetAnim
  command: "make -j{{ ansible_processor_vcpus | default(4) }}"
  args:
    chdir: "{{ netanim_location }}"
  timeout: 600  # 10 minutes
  tags: netanim
```

---

### 3. Role: dlinknctu-mininet

**File:** `/home/thc1006/dev/OpenNet/ansible/roles/dlinknctu-mininet/tasks/main.yml`
**Status:** Requires minor updates
**Severity:** Low-to-Medium

#### Issues Found:

| Line | Issue | Type | Recommended Fix |
|------|-------|------|-----------------|
| 10 | `update: no` is deprecated Ansible syntax | Syntax | Change to `version: opennet` only (implied no update) |
| 15 | `./util/install.sh -n` called without checking for Python 2/3 | Python version | Verify script works with Python 3 |
| 18 | `poll: 0` without `async` - incomplete async config | Syntax | Either use proper async or remove poll |
| 19 | `retries: 3` may mask real issues | Error handling | Add better error checking |

#### Details:

**Lines 6-13 (Git clone):**
```yaml
- name: Clone dlinknctu-mininet
  git:
    repo: "{{ mininet_repos }}"
    dest: "{{ mininet_dir_path }}"
    update: no
    accept_hostkey: true
    version: "opennet"
  tags: mininet
```

**Problem:** `update: no` is deprecated Ansible syntax (pre-2.9). Modern Ansible uses implicit behavior.

**Recommended fix:**
```yaml
- name: Clone dlinknctu-mininet (opennet branch)
  git:
    repo: "{{ mininet_repos }}"
    dest: "{{ mininet_dir_path }}"
    version: "opennet"
    accept_hostkey: true
  tags: mininet
```

**Lines 14-20 (Install script):**
```yaml
- name: Install dlinknctu-mininet
  command: "./util/install.sh -n"
  args:
    chdir: "{{ home_location }}/mininet"
  poll: 0
  retries: 3
  tags: mininet
```

**Problem 1:** `poll: 0` without `async` is invalid syntax - it means "check immediately without waiting" but has no effect.

**Problem 2:** The mininet install script (`util/install.sh`) was written for Python 2. Need to verify it works with Python 3.

**Problem 3:** `retries: 3` will retry on any failure, which may hide configuration issues.

**Recommended fix:**
```yaml
- name: Install dlinknctu-mininet dependencies
  command: "./util/install.sh -n"
  args:
    chdir: "{{ home_location }}/mininet"
  environment:
    PYTHON: "python3"  # Force Python 3 if script respects this
  timeout: 600
  register: mininet_install
  tags: mininet

- name: Verify Mininet installation
  command: "mn --version"
  register: mn_version
  failed_when: mn_version.rc != 0
  tags: mininet

- name: Report Mininet version
  debug:
    msg: "Mininet installed: {{ mn_version.stdout }}"
  tags: mininet
```

---

### 4. Role: openvswitch

**File:** `/home/thc1006/dev/OpenNet/ansible/roles/openvswitch/tasks/main.yml`
**Status:** Requires critical updates
**Severity:** Critical

#### Issues Found:

| Line | Issue | Type | Recommended Fix |
|------|-------|------|-----------------|
| 29 | `python-openvswitch_{{ OVS_VERSION }}-1_all.deb` is Python 2 package | Python 2 EOL | Remove or replace with Python 3 package |
| 35 | `service:` module with deprecated syntax | Deprecated module | Use `ansible.builtin.service` with `name:` keyword |
| 4 | `http://openvswitch.org` uses insecure protocol | Security | Use HTTPS |

#### Details:

**Lines 23-33 (Package installation):**
```yaml
- name: Install OpenvSwitch debian packages
  command: "dpkg -i {{ item }}"
  with_items:
    - openvswitch-common_{{ OVS_VERSION }}-1_amd64.deb
    - openvswitch-switch_{{ OVS_VERSION }}-1_amd64.deb
    - openvswitch-pki_{{ OVS_VERSION }}-1_all.deb
    - python-openvswitch_{{ OVS_VERSION }}-1_all.deb
  args:
    chdir: "{{ temp_location }}"
  notify: Restart OpenvSwitch daemon
  tags: openvswitch
```

**Problem:** `python-openvswitch` is a Python 2 package. OpenVSwitch 2.4.0 (from ~2015) only has Python 2 bindings. Modern OpenVSwitch releases have Python 3 support, but older versions do not.

**Recommended fix (Option 1 - Skip Python bindings for legacy version):**
```yaml
- name: Install OpenvSwitch debian packages
  command: "dpkg -i {{ item }}"
  with_items:
    - openvswitch-common_{{ OVS_VERSION }}-1_amd64.deb
    - openvswitch-switch_{{ OVS_VERSION }}-1_amd64.deb
    - openvswitch-pki_{{ OVS_VERSION }}-1_all.deb
    # NOTE: python-openvswitch for OVS 2.4.0 requires Python 2
    # Skip Python bindings or upgrade to OpenVSwitch 2.13+ for Python 3 support
  args:
    chdir: "{{ temp_location }}"
  notify: Restart OpenvSwitch daemon
  tags: openvswitch
```

**Recommended fix (Option 2 - Upgrade OpenVSwitch):**
```yaml
# Update group_vars/all to use OVS_VERSION: 2.17.0 or later
# Then build will include Python 3 support

- name: Install OpenvSwitch debian packages (Python 3 compatible)
  command: "dpkg -i {{ item }}"
  with_items:
    - openvswitch-common_{{ OVS_VERSION }}-1_amd64.deb
    - openvswitch-switch_{{ OVS_VERSION }}-1_amd64.deb
    - openvswitch-pki_{{ OVS_VERSION }}-1_all.deb
    - python3-openvswitch_{{ OVS_VERSION }}-1_all.deb  # Python 3
  args:
    chdir: "{{ temp_location }}"
  notify: Restart OpenvSwitch daemon
  tags: openvswitch
```

**Line 35 (Service module):**
```yaml
- name: Start OpenvSwitch Daemon
  service: name=openvswitch-switch state=started enabled=yes
  tags: openvswitch
```

**Problem:** Deprecated module syntax. Modern Ansible uses the full module name and `name:` as a keyword.

**Recommended fix:**
```yaml
- name: Start OpenvSwitch Daemon
  ansible.builtin.service:
    name: openvswitch-switch
    state: started
    enabled: yes
  tags: openvswitch
```

**Line 4 (HTTP URL):**
```yaml
ovs_url: "http://openvswitch.org/releases/openvswitch-{{ OVS_VERSION }}.tar.gz"
```

**Problem:** Uses insecure HTTP. Should use HTTPS.

**Recommended fix:**
```yaml
ovs_url: "https://www.openvswitch.org/releases/openvswitch-{{ OVS_VERSION }}.tar.gz"
```

**Handlers file (openvswitch/handlers/main.yml, Line 3):**
```yaml
- name: Restart OpenvSwitch daemon
  service: name=openvswitch-switch state=restarted
```

**Problem:** Same deprecated syntax as above.

**Recommended fix:**
```yaml
- name: Restart OpenvSwitch daemon
  ansible.builtin.service:
    name: openvswitch-switch
    state: restarted
```

---

### 5. Role: ntp

**File:** `/home/thc1006/dev/OpenNet/ansible/roles/ntp/tasks/main.yml`
**Status:** Requires updates
**Severity:** Medium

#### Issues Found:

| Line | Issue | Type | Recommended Fix |
|------|-------|------|-----------------|
| 3 | `apt:` module with deprecated syntax | Deprecated module | Use `ansible.builtin.apt` with `name:` keyword |
| 3 | Installs legacy `ntp` daemon | Obsolete package | Use `chrony` or `systemd-timesyncd` instead |
| 6 | `copy:` module with deprecated syntax | Deprecated module | Use `ansible.builtin.copy` with proper syntax |
| 14 | `service:` module with deprecated syntax | Deprecated module | Use `ansible.builtin.service` with `name:` keyword |

#### Details:

**Line 3 (APT syntax):**
```yaml
- name: Be sure ntp daemon is installed
  apt: name=ntp state=installed
  tags: ntp
```

**Problem 1:** Deprecated module syntax (pre-2.7).

**Problem 2:** `ntp` daemon is obsolete on Ubuntu 22.04. The system uses `systemd-timesyncd` by default for NTP synchronization. Installing `ntp` conflicts with timesyncd.

**Recommended fix (Option 1 - Use systemd-timesyncd):**
```yaml
# systemd-timesyncd is enabled by default on Ubuntu 22.04
# Just verify it's running:

- name: Ensure time synchronization is enabled (systemd-timesyncd)
  ansible.builtin.service:
    name: systemd-timesyncd
    state: started
    enabled: yes
  tags: ntp
  # Note: This is the default NTP client on Ubuntu 22.04
```

**Recommended fix (Option 2 - Use chrony instead):**
```yaml
- name: Install chrony (modern NTP client)
  ansible.builtin.apt:
    name: chrony
    state: present
    update_cache: yes
  tags: ntp

- name: Ensure chrony is running and enabled
  ansible.builtin.service:
    name: chronyd
    state: started
    enabled: yes
  tags: ntp
```

**Line 6 (Copy timezone):**
```yaml
- name: Change timezone Asia/Taipei
  copy: src=/usr/share/zoneinfo/Asia/Taipei dest=/etc/localtime
  tags: ntp
```

**Problem 1:** Deprecated syntax (missing colons).

**Problem 2:** Using `copy:` to manage timezone is fragile. The proper way is to use the `timezone` module.

**Recommended fix:**
```yaml
- name: Set timezone to Asia/Taipei
  ansible.builtin.timezone:
    name: Asia/Taipei
  become: yes
  tags: ntp
```

**Line 10 (hwclock):**
```yaml
- name: Write to hardware
  command: 'hwclock -w'
  run_once: true
  tags: ntp
```

**Problem:** `hwclock` requires root. The playbook is run as `remote_user: root` (see playbook.yml line 3), but this should be explicit.

**Recommended fix:**
```yaml
- name: Synchronize hardware clock
  command: hwclock --systohc
  become: yes
  run_once: yes  # Only run once for the cluster
  tags: ntp
```

**Line 14 (Service syntax):**
```yaml
- name: Be sure ntp daemon is running and enabled
  service: name=ntp state=running enabled=yes
  tags: ntp
```

**Problem:** Deprecated syntax. Also assumes `ntp` daemon exists.

**Recommended fix (with chrony):**
```yaml
- name: Ensure chrony is running and enabled
  ansible.builtin.service:
    name: chronyd
    state: started
    enabled: yes
  tags: ntp
```

---

### 6. Role: qperf

**File:** `/home/thc1006/dev/OpenNet/ansible/roles/qperf/tasks/main.yml`
**Status:** Requires minor updates
**Severity:** Low

#### Issues Found:

| Line | Issue | Type | Recommended Fix |
|------|-------|------|-----------------|
| 3 | Uses old SourceForge URL | Outdated source | Verify URL still works or use modern mirror |
| 16-38 | Multiple async make/install commands | Error handling | Add proper error checking |

#### Details:

**Line 3 (SourceForge URL):**
```yaml
qperf_url: "https://www.openfabrics.org/downloads/qperf/qperf-0.4.9.tar.gz"
```

**Problem:** This URL is from 2012. The openfabrics.org site may no longer host this version. Need to verify the URL is still accessible.

**Recommended fix:**
```yaml
- name: Check qperf availability (may not be on openfabrics.org anymore)
  uri:
    url: "{{ qperf_url }}"
    method: HEAD
  register: qperf_check
  ignore_errors: yes
  tags: qperf

- name: Download qperf (with fallback)
  get_url:
    url: "{{ qperf_url }}"
    dest: "{{ temp_location }}"
  when: qperf_check.status | default(200) == 200
  tags: qperf
```

**Lines 16-38 (Build steps):**
```yaml
- name: Cleanup
  command: "./cleanup"
  args:
    chdir: "{{ temp_location }}/qperf-0.4.9"
  tags: qperf

- name: Autogen
  command: "./autogen.sh"
  args:
    chdir: "{{ temp_location }}/qperf-0.4.9"
  tags: qperf

- name: Configure
  command: "./configure"
  args:
    chdir: "{{ temp_location }}/qperf-0.4.9"
  tags: qperf

- name: make
  command: "make"
  args:
    chdir: "{{ temp_location }}/qperf-0.4.9"
  tags: qperf

- name: make install
  command: "make install"
  args:
    chdir: "{{ temp_location }}/qperf-0.4.9"
  tags: qperf
```

**Problem:** No error checking between steps. If any step fails, the next one will fail in unexpected ways.

**Recommended fix:**
```yaml
- name: Prepare qperf build
  block:
    - name: Run qperf cleanup
      command: "./cleanup"
      args:
        chdir: "{{ temp_location }}/qperf-0.4.9"
      tags: qperf

    - name: Generate qperf build files
      command: "./autogen.sh"
      args:
        chdir: "{{ temp_location }}/qperf-0.4.9"
      tags: qperf

    - name: Configure qperf
      command: "./configure"
      args:
        chdir: "{{ temp_location }}/qperf-0.4.9"
      tags: qperf

    - name: Build qperf
      command: "make -j{{ ansible_processor_vcpus | default(4) }}"
      args:
        chdir: "{{ temp_location }}/qperf-0.4.9"
      timeout: 600
      tags: qperf

    - name: Install qperf
      command: "make install"
      args:
        chdir: "{{ temp_location }}/qperf-0.4.9"
      become: yes  # make install usually needs root
      tags: qperf

  rescue:
    - name: Report qperf build failure
      debug:
        msg: "qperf build failed - check logs above for details"
      tags: qperf
```

---

## Summary of Required Changes by Module

### Critical Issues (Must Fix):

| Role | Issue | Impact | Fix Difficulty |
|------|-------|--------|-----------------|
| netanim | Qt4 obsolete, qmake-qt4 not available | Build fails | High (may need to upgrade NetAnim) |
| openvswitch | python-openvswitch is Python 2 only | Python 2 EOL, package may not install | Medium (skip or upgrade OVS) |

### High Priority (Should Fix):

| Role | Issue | Impact | Fix Difficulty |
|------|-------|--------|-----------------|
| ns3 | Missing `--enable-python` flag | Python bindings won't work | Low |
| ns3 | Async build with ignore_errors | Build failures hidden | Low |
| ntp | Uses deprecated ntp daemon | Package conflict, won't work | Low-Medium |
| openvswitch | Deprecated service/apt syntax | May fail with Ansible 2.14+ | Low |

### Low Priority (Nice to Fix):

| Role | Issue | Impact | Fix Difficulty |
|------|-------|--------|-----------------|
| dlinknctu-mininet | Deprecated git syntax | May fail with Ansible 2.14+ | Low |
| qperf | Old SourceForge URL | May fail if URL no longer works | Low |

---

## Modernization Strategy

### Phase 1: Critical Fixes (Quick Wins)

1. **Fix ns3 role:**
   - Add `--enable-python` to waf configure
   - Remove `ignore_errors: true` from async tasks
   - Add `become: yes` to ldconfig

2. **Fix openvswitch role:**
   - Change `python-openvswitch` to `python3-openvswitch` OR remove Python package
   - Update `service:` syntax to modern form
   - Change HTTP to HTTPS in URL

3. **Fix ntp role:**
   - Replace `ntp` daemon with `chrony` or `systemd-timesyncd`
   - Update all module syntax (apt, service, copy → timezone)
   - Add `become: yes` where needed

### Phase 2: Medium Priority (Better Stability)

4. **Fix netanim role:**
   - Research Qt5 support in NetAnim 3.105 or plan upgrade
   - Update make syntax with proper error handling

5. **Fix dlinknctu-mininet role:**
   - Update git syntax
   - Verify mininet install.sh works with Python 3
   - Add explicit error checking

### Phase 3: Nice to Have (Polish)

6. **Fix qperf role:**
   - Add error handling with block/rescue
   - Verify SourceForge URL still works
   - Use block syntax for build steps

---

## Related Issues in Other Components

### Playbook-level Issues

**File:** `/home/thc1006/dev/OpenNet/ansible/playbook.yml`

**Issues:**
- Line 3: `remote_user: root` - Requires root login enabled on all hosts. Should use `become: yes` instead (better security).
- Lines 5-6, 17-18, 30-31: Includes `group_vars/all` which defines software versions (ns-3.22, OVS 2.4.0) - These are quite old and may have compatibility issues with Ubuntu 22.04.

**Recommended fix:**
```yaml
---
- hosts: all
  # Use privilege escalation instead of direct root login
  become: yes
  any_errors_fatal: true
  vars_files:
    - group_vars/all
  roles:
    - apt
    - ez_setup
    - ntp
    - openvswitch
    - qperf

# ... rest of playbook
```

### Variable File Issues

**File:** `/home/thc1006/dev/OpenNet/ansible/group_vars/all`

**Issues:**
- OVS_VERSION: 2.4.0 (2015) - Too old, no Python 3 support
- NS3_VERSION: 3.22 (2014) - Very old, may have compatibility issues
- NETANIM_VERSION: 3.105 (2014) - Qt4 only, no Qt5 support
- PYGCCXML_VERSION: 1.0.0 (2010) - Not used anymore, superseded by system package

**Recommended updates:**
```yaml
---
OVS_VERSION: 2.17.0  # Latest stable with Python 3 support
MININET_VERSION: 2.3.0  # Latest available
NS3_VERSION: 3.39  # Latest stable LTS (or 3.22 if must stay old)
PYGCCXML_VERSION: 2.5.0  # Not used; castxml is the standard now
NETANIM_VERSION: 3.114  # Latest (requires ns-3.24+)
QUAGGA_VERSION: 1.2.4  # Latest stable
temp_location: "/tmp"
home_location: "/opt/opennet"  # More appropriate than empty string
```

---

## Testing Recommendations

Before applying these fixes, test with:

1. **Syntax validation:**
   ```bash
   ansible-playbook --syntax-check playbook.yml
   ```

2. **Dry-run on test VM:**
   ```bash
   ansible-playbook -i inventory.ini --check playbook.yml
   ```

3. **Smoke tests after deployment:**
   - Verify ns-3 Python bindings: `python3 -c "import ns"`
   - Verify OVS: `ovs-vsctl --version`
   - Verify Mininet: `mn --version`
   - Verify time sync: `timedatectl status`

---

## Conclusion

The OpenNet Ansible playbooks need modernization for Ubuntu 22.04+. The good news is that:

1. Five roles (apt, ez_setup, pygccxml, gccxml, help) are already modernized.
2. Most remaining issues are straightforward to fix.
3. No changes require structural refactoring - all fixes are incremental.

The critical path is:

1. **ns3:** Enable Python support (1 line change)
2. **netanim:** Resolve Qt4 → Qt5 migration (moderate effort)
3. **openvswitch:** Update Python package (1 line change) + syntax updates
4. **ntp:** Switch from ntp to chrony/systemd-timesyncd (5-line change)
5. **Everything:** Update deprecated Ansible module syntax (10-15 line changes across roles)

Estimated effort: 4-8 hours for a developer familiar with Ansible and ns-3.

