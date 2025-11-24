# Detailed Ansible Fixes for Ubuntu 22.04 / Debian 13

This document provides exact code replacements for each role that needs updating.

---

## 1. ns3 Role - `/ansible/roles/ns3/tasks/main.yml`

### Change 1: Add Python bindings support to waf configure

**Current (Lines 27-32):**
```yaml
- name: Waf configure
  command: "./waf configure"
  args:
    chdir: "{{ home_location }}/ns-allinone-{{ NS3_VERSION }}/ns-{{ NS3_VERSION }}"
  register: gg
  tags: ns3
```

**Recommended:**
```yaml
- name: Waf configure with Python 3 bindings
  command: "./waf configure --enable-python --enable-python-bindings"
  args:
    chdir: "{{ home_location }}/ns-allinone-{{ NS3_VERSION }}/ns-{{ NS3_VERSION }}"
  register: waf_configure_result
  timeout: 300
  tags: ns3
```

### Change 2: Fix waf apiscan async task

**Current (Lines 33-44):**
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

**Recommended:**
```yaml
- name: Waf apiscan (generate API bindings documentation)
  command: "./waf --apiscan={{ item }}"
  with_items:
    - netanim
    - wifi
    - lte
  args:
    chdir: "{{ home_location }}/ns-allinone-{{ NS3_VERSION }}/ns-{{ NS3_VERSION }}"
  timeout: 600  # Apiscan can be slow
  # Note: Removed async: 0 poll: 0 to ensure task completes before continuing
  tags: ns3
```

### Change 3: Fix waf build async task

**Current (Lines 45-52):**
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

**Recommended:**
```yaml
- name: Waf build (compile ns-3 with patches)
  command: "./waf build --jobs={{ ansible_processor_vcpus | default(4) }}"
  args:
    chdir: "{{ home_location }}/ns-allinone-{{ NS3_VERSION }}/ns-{{ NS3_VERSION }}"
  timeout: 3600  # Allow up to 1 hour for compilation
  register: waf_build_result
  tags: ns3

- name: Verify waf build succeeded
  fail:
    msg: "ns-3 build failed. Check logs above for details."
  when: waf_build_result.rc != 0
  tags: ns3
```

### Change 4: Add privilege escalation to ldconfig

**Current (Lines 58-60):**
```yaml
- name: Configure dynamic linker run-time bindings
  command: "ldconfig"
  tags: ns3
```

**Recommended:**
```yaml
- name: Configure dynamic linker run-time bindings
  command: "ldconfig"
  become: yes  # ldconfig requires root privileges
  tags: ns3
```

### Change 5: Fix waf install (add privilege escalation)

**Current (Lines 53-57):**
```yaml
- name: Waf install
  command: "./waf install"
  args:
    chdir: "{{ home_location }}/ns-allinone-{{ NS3_VERSION }}/ns-{{ NS3_VERSION }}"
  tags: ns3
```

**Recommended:**
```yaml
- name: Waf install (install ns-3 to system paths)
  command: "./waf install"
  args:
    chdir: "{{ home_location }}/ns-allinone-{{ NS3_VERSION }}/ns-{{ NS3_VERSION }}"
  become: yes  # Installation to /usr/local requires root
  register: waf_install_result
  tags: ns3
```

---

## 2. netanim Role - `/ansible/roles/netanim/tasks/main.yml`

### Issue: Qt4 is end-of-life and not available on Ubuntu 22.04+

**Current (entire file):**
```yaml
---
- name: Set Netanim
  set_fact:
    netanim_location: "{{ home_location }}/ns-allinone-{{ NS3_VERSION }}/netanim-{{ NETANIM_VERSION }}"
  tags: netanim
- name: qmake Netanim
  command: "qmake-qt4 NetAnim.pro"
  args:
    chdir: "{{ netanim_location }}"
  tags: netanim
- name: make Netanim
  command: "make"
  args:
    chdir: "{{ netanim_location }}"
  async: 0
  poll: 0
  ignore_errors: true
  tags: netanim
```

### Option 1: Skip NetAnim (Recommended for ns-3.22)

```yaml
---
# NetAnim 3.105 requires Qt4, which is end-of-life and not available on Ubuntu 22.04+.
#
# Alternatives:
# 1. Upgrade to ns-3.39+ with NetAnim 3.114+, which uses Qt5
# 2. Use ns-3 built-in visualization (if supported)
# 3. Skip NetAnim and use Wireshark/pcap analysis instead
# 4. Run NetAnim in a legacy Docker container with Qt4

- name: NetAnim deprecation notice
  debug:
    msg: |
      [INFO] NetAnim 3.105 requires Qt4, which is EOL and not available on Ubuntu 22.04+.

      Your options:
      1. SKIP NetAnim (current configuration)
         - ns-3 and Mininet will work fine without NetAnim
         - Use Wireshark or pcap analysis for packet visualization

      2. UPGRADE ns-3 to 3.39+ and NetAnim to 3.114+
         - Requires updating NS3_VERSION and NETANIM_VERSION in group_vars/all
         - NetAnim 3.114+ uses Qt5 which is available on Ubuntu 22.04+
         - May require code changes to OpenNet patches

      3. RUN NetAnim in separate legacy container
         - Build a separate Docker image with Qt4 and old libraries
         - Use that container for visualization only

      Current approach: Skipping NetAnim
  tags: netanim

- name: Verify Qt5 is available for future upgrades
  command: "qmake --version"
  register: qt_version
  changed_when: false
  tags: netanim

- name: Show Qt version
  debug:
    msg: "Qt5 available: {{ qt_version.stdout_lines[0] }}"
  tags: netanim
```

### Option 2: Build with Qt5 (if NetAnim 3.114+ is used)

```yaml
---
# This assumes:
# - NS3_VERSION is 3.24 or later
# - NETANIM_VERSION is 3.114 or later
# - You have updated group_vars/all accordingly

- name: Set Netanim location
  set_fact:
    netanim_location: "{{ home_location }}/ns-allinone-{{ NS3_VERSION }}/netanim-{{ NETANIM_VERSION }}"
  tags: netanim

- name: Build NetAnim with Qt5
  command: "qmake NetAnim.pro"  # Uses system qmake (Qt5)
  args:
    chdir: "{{ netanim_location }}"
  tags: netanim

- name: Compile NetAnim
  command: "make -j{{ ansible_processor_vcpus | default(4) }}"
  args:
    chdir: "{{ netanim_location }}"
  timeout: 600  # Allow up to 10 minutes
  register: netanim_build
  tags: netanim

- name: Verify NetAnim build succeeded
  fail:
    msg: "NetAnim build failed. Ensure Qt5 is installed (qtbase5-dev)."
  when: netanim_build.rc != 0
  tags: netanim
```

---

## 3. openvswitch Role - Multiple files

### File: `/ansible/roles/openvswitch/tasks/main.yml`

### Change 1: Use HTTPS instead of HTTP

**Current (Line 4):**
```yaml
ovs_url: "http://openvswitch.org/releases/openvswitch-{{ OVS_VERSION }}.tar.gz"
```

**Recommended:**
```yaml
ovs_url: "https://www.openvswitch.org/releases/openvswitch-{{ OVS_VERSION }}.tar.gz"
```

### Change 2: Fix Python package name (Python 3 support)

**Current (Lines 24-29):**
```yaml
- name: Install OpenvSwitch debian packages
  command: "dpkg -i {{ item }}"
  with_items:
    - openvswitch-common_{{ OVS_VERSION }}-1_amd64.deb
    - openvswitch-switch_{{ OVS_VERSION }}-1_amd64.deb
    - openvswitch-pki_{{ OVS_VERSION }}-1_all.deb
    - python-openvswitch_{{ OVS_VERSION }}-1_all.deb
```

**Recommended (if upgrading to OVS 2.17+):**
```yaml
- name: Install OpenvSwitch debian packages
  command: "dpkg -i {{ item }}"
  with_items:
    - openvswitch-common_{{ OVS_VERSION }}-1_amd64.deb
    - openvswitch-switch_{{ OVS_VERSION }}-1_amd64.deb
    - openvswitch-pki_{{ OVS_VERSION }}-1_all.deb
    - python3-openvswitch_{{ OVS_VERSION }}-1_all.deb  # Changed from python-openvswitch
```

**Recommended (if staying with OVS 2.4.0 - skip Python package):**
```yaml
- name: Install OpenvSwitch debian packages
  command: "dpkg -i {{ item }}"
  with_items:
    - openvswitch-common_{{ OVS_VERSION }}-1_amd64.deb
    - openvswitch-switch_{{ OVS_VERSION }}-1_amd64.deb
    - openvswitch-pki_{{ OVS_VERSION }}-1_all.deb
    # NOTE: Skipped python-openvswitch_{{ OVS_VERSION }}-1_all.deb
    # OVS 2.4.0 only provides Python 2 bindings which is incompatible with Ubuntu 22.04+
    # For Python 3 support, upgrade to OpenvSwitch 2.17+
```

### Change 3: Fix service module syntax

**Current (Line 35):**
```yaml
- name: Start OpenvSwitch Daemon
  service: name=openvswitch-switch state=started enabled=yes
  tags: openvswitch
```

**Recommended:**
```yaml
- name: Start OpenvSwitch Daemon
  ansible.builtin.service:
    name: openvswitch-switch
    state: started
    enabled: yes
  become: yes  # May require root on some systems
  tags: openvswitch
```

### File: `/ansible/roles/openvswitch/handlers/main.yml`

**Current (Line 3):**
```yaml
- name: Restart OpenvSwitch daemon
  service: name=openvswitch-switch state=restarted
```

**Recommended:**
```yaml
- name: Restart OpenvSwitch daemon
  ansible.builtin.service:
    name: openvswitch-switch
    state: restarted
  become: yes
```

---

## 4. ntp Role - `/ansible/roles/ntp/tasks/main.yml`

### Complete rewrite (using chrony instead of ntp):

**Current (entire file):**
```yaml
---
- name: Be sure ntp daemon is installed
  apt: name=ntp state=installed
  tags: ntp
- name: Change timezone Asia/Taipei
  copy: src=/usr/share/zoneinfo/Asia/Taipei dest=/etc/localtime
  tags: ntp
# XXX: run_once is useless
- name: Write to hardware
  command: 'hwclock -w'
  run_once: true
  tags: ntp
- name: Be sure ntp daemon is running and enabled
  service: name=ntp state=running enabled=yes
  tags: ntp
- name: Check System Time
  command: 'date'
  register: time_result
  tags: ntp
- debug: msg="System time {{ time_result.stdout }}}"
  tags: ntp
```

**Recommended (using chrony):**
```yaml
---
# NTP configuration for Ubuntu 22.04+
# Uses chrony as the NTP client (better than legacy ntp daemon)
# systemd-timesyncd is also available as a lightweight alternative

- name: Ensure chrony is installed (modern NTP client)
  ansible.builtin.apt:
    name: chrony
    state: present
    update_cache: yes
  tags: ntp

- name: Set timezone to Asia/Taipei
  ansible.builtin.timezone:
    name: Asia/Taipei
  become: yes
  tags: ntp

- name: Ensure chronyd is running and enabled
  ansible.builtin.service:
    name: chronyd
    state: started
    enabled: yes
  become: yes
  tags: ntp

- name: Synchronize hardware clock with system time
  ansible.builtin.command: "hwclock --systohc"
  become: yes
  run_once: yes  # Only run once per cluster to avoid race conditions
  changed_when: false
  tags: ntp

- name: Check system time
  ansible.builtin.command: "date"
  register: time_result
  changed_when: false
  tags: ntp

- name: Show current system time and NTP status
  ansible.builtin.debug:
    msg: |
      System time: {{ time_result.stdout }}
      Timezone: {{ ansible_date_time.tz }}
      NTP service: chronyd
  tags: ntp
```

**Alternative (using lightweight systemd-timesyncd):**
```yaml
---
# Lightweight alternative using systemd-timesyncd (no separate daemon needed)
# This is the default time sync service on Ubuntu 22.04

- name: Set timezone to Asia/Taipei
  ansible.builtin.timezone:
    name: Asia/Taipei
  become: yes
  tags: ntp

- name: Ensure systemd-timesyncd is running (lightweight NTP)
  ansible.builtin.service:
    name: systemd-timesyncd
    state: started
    enabled: yes
  become: yes
  tags: ntp

- name: Check time synchronization status
  ansible.builtin.shell: timedatectl status
  register: timedatectl_result
  changed_when: false
  tags: ntp

- name: Show time sync status
  ansible.builtin.debug:
    msg: "{{ timedatectl_result.stdout_lines }}"
  tags: ntp
```

---

## 5. dlinknctu-mininet Role - `/ansible/roles/dlinknctu-mininet/tasks/main.yml`

### Change 1: Update git syntax

**Current (Lines 6-13):**
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

**Recommended:**
```yaml
- name: Clone dlinknctu-mininet (opennet branch)
  ansible.builtin.git:
    repo: "{{ mininet_repos }}"
    dest: "{{ mininet_dir_path }}"
    version: "opennet"
    accept_hostkey: true
    # Note: Removed deprecated 'update: no' - version specification implies no update
  tags: mininet
```

### Change 2: Improve install error handling

**Current (Lines 14-20):**
```yaml
- name: Install dlinknctu-mininet
  command: "./util/install.sh -n"
  args:
    chdir: "{{ home_location }}/mininet"
  poll: 0
  retries: 3
  tags: mininet
```

**Recommended:**
```yaml
- name: Install dlinknctu-mininet dependencies
  block:
    - name: Run mininet install script
      command: "./util/install.sh -n"
      args:
        chdir: "{{ home_location }}/mininet"
      environment:
        # Force Python 3 if script respects this variable
        PYTHON: "python3"
      timeout: 600  # Allow up to 10 minutes
      register: mininet_install_result
      tags: mininet

    - name: Check Mininet installation
      command: "mn --version"
      register: mn_version_check
      changed_when: false
      tags: mininet

    - name: Report Mininet version
      debug:
        msg: "Mininet installed: {{ mn_version_check.stdout }}"
      tags: mininet

  rescue:
    - name: Mininet installation failed
      debug:
        msg: |
          Mininet installation failed!
          Check the output above for details.
          The mininet/util/install.sh script may need updates for Python 3.
      tags: mininet
      failed_when: true
```

### Change 3: Remove duplicate version check

**Current (Lines 21-26):**
```yaml
- name: Check mininet version
  command: "mn --version"
  register: mn_version
  tags: mininet
- debug: msg="Mininet Version {{ mn_version.stdout }}"
  tags: mininet
```

**Recommended:**
```yaml
# Version check is now in the block above, no need to duplicate
```

---

## 6. qperf Role - `/ansible/roles/qperf/tasks/main.yml`

### Rewrite with better error handling:

**Current (entire file):**
```yaml
- name: Set qperf
  set_fact:
    qperf_url: "https://www.openfabrics.org/downloads/qperf/qperf-0.4.9.tar.gz"
  tags: qperf
- name: Download qperf
  get_url:
    url: "{{ qperf_url }}"
    dest: "{{ temp_location }}"
  tags: qperf
- name: Untar qperf
  unarchive:
    src: "{{ temp_location }}/qperf-0.4.9.tar.gz"
    dest: "{{ temp_location }}"
  tags: qperf
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
- name: Remove qperf source code
  file:
    path: "{{ temp_location }}/qperf-0.4.9.tar.gz"
    state: absent
  tags: qperf
```

**Recommended:**
```yaml
---
- name: Set qperf download URL
  set_fact:
    qperf_version: "0.4.9"
    qperf_url: "https://www.openfabrics.org/downloads/qperf/qperf-0.4.9.tar.gz"
  tags: qperf

- name: Download qperf
  ansible.builtin.get_url:
    url: "{{ qperf_url }}"
    dest: "{{ temp_location }}"
    timeout: 300
  tags: qperf

- name: Extract qperf source
  ansible.builtin.unarchive:
    src: "{{ temp_location }}/qperf-{{ qperf_version }}.tar.gz"
    dest: "{{ temp_location }}"
  tags: qperf

- name: Build and install qperf
  block:
    - name: Run qperf cleanup
      command: "./cleanup"
      args:
        chdir: "{{ temp_location }}/qperf-{{ qperf_version }}"
      tags: qperf

    - name: Generate build configuration (autogen)
      command: "./autogen.sh"
      args:
        chdir: "{{ temp_location }}/qperf-{{ qperf_version }}"
      timeout: 300
      tags: qperf

    - name: Configure qperf build
      command: "./configure"
      args:
        chdir: "{{ temp_location }}/qperf-{{ qperf_version }}"
      timeout: 300
      tags: qperf

    - name: Compile qperf
      command: "make -j{{ ansible_processor_vcpus | default(4) }}"
      args:
        chdir: "{{ temp_location }}/qperf-{{ qperf_version }}"
      timeout: 600
      tags: qperf

    - name: Install qperf
      command: "make install"
      args:
        chdir: "{{ temp_location }}/qperf-{{ qperf_version }}"
      become: yes  # Installation to /usr/local typically needs root
      tags: qperf

  rescue:
    - name: Report qperf build failure
      debug:
        msg: |
          ERROR: qperf build failed!
          Check output above for details.

          Common issues:
          - Missing build tools (gcc, make, autoconf)
          - Missing dependencies
          - qperf source URL no longer available
      tags: qperf
      failed_when: true

- name: Remove qperf source archive
  ansible.builtin.file:
    path: "{{ temp_location }}/qperf-{{ qperf_version }}.tar.gz"
    state: absent
  tags: qperf

- name: Verify qperf installation
  command: "qperf --version"
  register: qperf_version_check
  changed_when: false
  tags: qperf

- name: Report qperf version
  debug:
    msg: "qperf installed: {{ qperf_version_check.stdout }}"
  tags: qperf
```

---

## 7. APT and Module Syntax Updates

### General Ansible module syntax fixes across all roles

**Deprecated Ansible syntax pattern (pre-2.7):**
```yaml
service: name=foo state=started
apt: name=foo state=installed
copy: src=bar dest=baz
```

**Modern Ansible syntax (2.7+):**
```yaml
ansible.builtin.service:
  name: foo
  state: started

ansible.builtin.apt:
  name: foo
  state: present  # 'installed' is deprecated in favor of 'present'

ansible.builtin.copy:
  src: bar
  dest: baz
```

**Key changes:**
1. Use full module names: `ansible.builtin.service`, `ansible.builtin.apt`, etc.
2. Use keyword arguments instead of `key=value` pairs
3. Proper indentation with colons
4. Use `become: yes` for privilege escalation instead of relying on `remote_user: root`

---

## Summary of Changes

| Role | Critical | High | Medium | Low | Files Changed |
|------|----------|------|--------|-----|----------------|
| ns3 | - | 1 | 2 | - | 1 |
| netanim | 1 | - | - | - | 1 |
| openvswitch | 1 | 1 | 1 | - | 2 |
| ntp | - | 2 | - | - | 1 |
| dlinknctu-mininet | - | - | 2 | - | 1 |
| qperf | - | - | - | 2 | 1 |
| **TOTAL** | **3** | **4** | **5** | **2** | **7** |

---

## Testing the Changes

After applying these fixes, test with:

```bash
# 1. Validate YAML syntax
ansible-playbook --syntax-check ansible/playbook.yml

# 2. Dry-run (check mode)
ansible-playbook -i your_inventory.ini --check ansible/playbook.yml

# 3. Run on a single test host first
ansible-playbook -i your_inventory.ini -l test-host ansible/playbook.yml

# 4. Verify installations after deployment
ansible all -i your_inventory.ini -m command -a "ns-3 --version"
ansible all -i your_inventory.ini -m command -a "ovs-vsctl --version"
ansible all -i your_inventory.ini -m command -a "mn --version"
ansible all -i your_inventory.ini -m command -a "timedatectl status"
```

