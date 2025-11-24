# Ansible Modernization Action Plan for Ubuntu 22.04

## Quick Reference: Issues by Priority

### Priority 1: Blocking Issues (Fix ASAP)

These will cause deployment failures or broken functionality.

1. **netanim: Qt4 obsolete** ⚠️ CRITICAL
   - Status: qmake-qt4 not available on Ubuntu 22.04+
   - Impact: NetAnim build will fail completely
   - Effort: Medium (requires decision on Qt5 upgrade or skip)
   - Fix: See ANSIBLE_FIXES_DETAILED.md Section 2

2. **openvswitch: Python 2 package** ⚠️ CRITICAL
   - Status: python-openvswitch package doesn't exist for Python 2
   - Impact: Installation fails or works but without Python bindings
   - Effort: Low (1 line change)
   - Fix: See ANSIBLE_FIXES_DETAILED.md Section 3, Change 2

3. **ntp: Daemon conflict** ⚠️ CRITICAL
   - Status: ntp daemon conflicts with systemd-timesyncd on Ubuntu 22.04
   - Impact: Time synchronization fails or causes package conflicts
   - Effort: Low (rewrite with chrony)
   - Fix: See ANSIBLE_FIXES_DETAILED.md Section 4

### Priority 2: High-Impact Issues (Fix Within 1-2 Days)

These reduce functionality or cause silent failures.

4. **ns3: Missing Python flag** ⚠️ HIGH
   - Status: waf configure doesn't enable Python bindings
   - Impact: ns3 Python bindings won't work, Mininet/OpenNet will fail
   - Effort: Very Low (1 line change)
   - Fix: See ANSIBLE_FIXES_DETAILED.md Section 1, Change 1

5. **ns3: Async build with ignore_errors** ⚠️ HIGH
   - Status: Build failures are hidden by ignore_errors: true
   - Impact: Failed builds reported as successful
   - Effort: Low (remove async, add error checking)
   - Fix: See ANSIBLE_FIXES_DETAILED.md Section 1, Changes 2-3

6. **openvswitch: Deprecated module syntax** ⚠️ HIGH
   - Status: Uses deprecated service: and apt: syntax
   - Impact: May fail with Ansible 2.14+
   - Effort: Low (syntax update)
   - Fix: See ANSIBLE_FIXES_DETAILED.md Section 3, Changes 1 & 3

### Priority 3: Medium-Impact Issues (Fix Within 1 Week)

These improve compatibility and reliability.

7. **dlinknctu-mininet: Python 3 compatibility** - MEDIUM
   - Status: install.sh may not work with Python 3
   - Impact: Mininet installation may fail silently
   - Effort: Low-Medium (test and verify)
   - Fix: See ANSIBLE_FIXES_DETAILED.md Section 5

8. **qperf: Build reliability** - MEDIUM
   - Status: Multiple sequential commands with no error checking
   - Impact: Build failures hidden
   - Effort: Low (add block/rescue)
   - Fix: See ANSIBLE_FIXES_DETAILED.md Section 6

---

## Phased Implementation Plan

### Phase 1: Critical Path (Day 1-2)

**Goal:** Make deployment work on Ubuntu 22.04

**Tasks:**

1. **Task 1A: Update ns3 role** (30 min)
   - Add `--enable-python` flag to waf configure
   - Fix async build tasks
   - Add error checking
   - File: `/home/thc1006/dev/OpenNet/ansible/roles/ns3/tasks/main.yml`

2. **Task 1B: Update openvswitch role** (20 min)
   - Change `python-openvswitch` to `python3-openvswitch` (or remove)
   - Change HTTP to HTTPS
   - Update service module syntax
   - Files:
     - `/home/thc1006/dev/OpenNet/ansible/roles/openvswitch/tasks/main.yml`
     - `/home/thc1006/dev/OpenNet/ansible/roles/openvswitch/handlers/main.yml`

3. **Task 1C: Rewrite ntp role** (20 min)
   - Replace `ntp` daemon with `chrony` or `systemd-timesyncd`
   - Use modern module syntax
   - File: `/home/thc1006/dev/OpenNet/ansible/roles/ntp/tasks/main.yml`

4. **Task 1D: Address netanim issue** (30 min)
   - Decision: Skip NetAnim (quick) OR upgrade ns-3/NetAnim (moderate effort)
   - If skipping: Replace with informational tasks
   - File: `/home/thc1006/dev/OpenNet/ansible/roles/netanim/tasks/main.yml`

**Time estimate:** 2 hours total
**Testing:** Run full playbook on test VM, verify key services start

---

### Phase 2: Reliability Improvements (Day 2-3)

**Goal:** Make deployments more robust and easier to debug

**Tasks:**

5. **Task 2A: Update dlinknctu-mininet role** (30 min)
   - Update git syntax
   - Add Python 3 environment variable
   - Improve error handling
   - File: `/home/thc1006/dev/OpenNet/ansible/roles/dlinknctu-mininet/tasks/main.yml`

6. **Task 2B: Improve qperf role** (20 min)
   - Add block/rescue error handling
   - Use proper timeout values
   - File: `/home/thc1006/dev/OpenNet/ansible/roles/qperf/tasks/main.yml`

7. **Task 2C: Update playbook-level config** (15 min)
   - Consider removing `remote_user: root` in favor of `become: yes`
   - Update group_vars/all with more recent package versions
   - Files:
     - `/home/thc1006/dev/OpenNet/ansible/playbook.yml`
     - `/home/thc1006/dev/OpenNet/ansible/group_vars/all`

**Time estimate:** 1.5 hours total
**Testing:** Run playbook again, verify all services functional

---

### Phase 3: Version Upgrades (Optional, Week 2)

**Goal:** Modernize software versions for better performance and security

**Tasks (optional based on project needs):**

8. **Optional: Upgrade OpenVSwitch** (1-2 hours)
   - From OVS 2.4.0 (2015) to OVS 2.17.0 (2023)
   - Enables Python 3 bindings, better performance
   - Update: `OVS_VERSION: 2.17.0` in group_vars/all
   - Note: May require ns-3 patch adjustments

9. **Optional: Upgrade ns-3** (2-4 hours)
   - From ns-3.22 (2014) to ns-3.39 (2023)
   - Requires updating patches, may require code changes
   - Update: `NS3_VERSION: 3.39` in group_vars/all
   - Check: Which OpenNet patches apply to newer ns-3

10. **Optional: Upgrade NetAnim** (2-3 hours)
    - From NetAnim 3.105 (Qt4) to NetAnim 3.114+ (Qt5)
    - Requires ns-3 23.10+ and Qt5 support
    - Update: `NETANIM_VERSION: 3.114` in group_vars/all

**Time estimate:** 8-12 hours (only do if needed for new features)

---

## Detailed Work Instructions

### Phase 1, Task 1A: Update ns3 Role

**File to edit:** `/home/thc1006/dev/OpenNet/ansible/roles/ns3/tasks/main.yml`

**Step 1:** Replace lines 28 with Python support flag

Old:
```yaml
- name: Waf configure
  command: "./waf configure"
```

New:
```yaml
- name: Waf configure with Python 3 bindings
  command: "./waf configure --enable-python --enable-python-bindings"
```

**Step 2:** Replace lines 33-44 with proper async handling

Old:
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

New:
```yaml
- name: Waf apiscan (generate API bindings documentation)
  command: "./waf --apiscan={{ item }}"
  with_items:
    - netanim
    - wifi
    - lte
  args:
    chdir: "{{ home_location }}/ns-allinone-{{ NS3_VERSION }}/ns-{{ NS3_VERSION }}"
  timeout: 600
  tags: ns3
```

**Step 3:** Replace lines 45-52 with proper async handling

Old:
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

New:
```yaml
- name: Waf build (compile ns-3 with patches)
  command: "./waf build --jobs={{ ansible_processor_vcpus | default(4) }}"
  args:
    chdir: "{{ home_location }}/ns-allinone-{{ NS3_VERSION }}/ns-{{ NS3_VERSION }}"
  timeout: 3600
  register: waf_build_result
  tags: ns3

- name: Verify waf build succeeded
  fail:
    msg: "ns-3 build failed. Check logs above for details."
  when: waf_build_result.rc != 0
  tags: ns3
```

**Step 4:** Add become: yes to ldconfig

Old:
```yaml
- name: Configure dynamic linker run-time bindings
  command: "ldconfig"
  tags: ns3
```

New:
```yaml
- name: Configure dynamic linker run-time bindings
  command: "ldconfig"
  become: yes
  tags: ns3
```

---

### Phase 1, Task 1B: Update openvswitch Role

**File 1 to edit:** `/home/thc1006/dev/OpenNet/ansible/roles/openvswitch/tasks/main.yml`

**Step 1:** Change HTTP to HTTPS (line 4)

Old:
```yaml
ovs_url: "http://openvswitch.org/releases/openvswitch-{{ OVS_VERSION }}.tar.gz"
```

New:
```yaml
ovs_url: "https://www.openvswitch.org/releases/openvswitch-{{ OVS_VERSION }}.tar.gz"
```

**Step 2:** Update Python package (line 29) - CHOOSE ONE OPTION

Option A (Remove Python package for OVS 2.4.0):
```yaml
- name: Install OpenvSwitch debian packages
  command: "dpkg -i {{ item }}"
  with_items:
    - openvswitch-common_{{ OVS_VERSION }}-1_amd64.deb
    - openvswitch-switch_{{ OVS_VERSION }}-1_amd64.deb
    - openvswitch-pki_{{ OVS_VERSION }}-1_all.deb
  args:
    chdir: "{{ temp_location }}"
  notify: Restart OpenvSwitch daemon
  tags: openvswitch
```

Option B (Update for OVS 2.17+):
```yaml
- name: Install OpenvSwitch debian packages
  command: "dpkg -i {{ item }}"
  with_items:
    - openvswitch-common_{{ OVS_VERSION }}-1_amd64.deb
    - openvswitch-switch_{{ OVS_VERSION }}-1_amd64.deb
    - openvswitch-pki_{{ OVS_VERSION }}-1_all.deb
    - python3-openvswitch_{{ OVS_VERSION }}-1_all.deb
  args:
    chdir: "{{ temp_location }}"
  notify: Restart OpenvSwitch daemon
  tags: openvswitch
```

**Step 3:** Update service module syntax (line 35)

Old:
```yaml
- name: Start OpenvSwitch Daemon
  service: name=openvswitch-switch state=started enabled=yes
  tags: openvswitch
```

New:
```yaml
- name: Start OpenvSwitch Daemon
  ansible.builtin.service:
    name: openvswitch-switch
    state: started
    enabled: yes
  become: yes
  tags: openvswitch
```

**File 2 to edit:** `/home/thc1006/dev/OpenNet/ansible/roles/openvswitch/handlers/main.yml`

**Step 4:** Update handler module syntax (line 3)

Old:
```yaml
- name: Restart OpenvSwitch daemon
  service: name=openvswitch-switch state=restarted
```

New:
```yaml
- name: Restart OpenvSwitch daemon
  ansible.builtin.service:
    name: openvswitch-switch
    state: restarted
  become: yes
```

---

### Phase 1, Task 1C: Rewrite ntp Role

**File to replace:** `/home/thc1006/dev/OpenNet/ansible/roles/ntp/tasks/main.yml`

**Complete replacement** - See ANSIBLE_FIXES_DETAILED.md Section 4 for full file content.

Key changes:
- Remove `apt: name=ntp` (installs deprecated daemon)
- Add `apt: name=chrony` (modern NTP client) OR use systemd-timesyncd
- Replace `copy:` with `timezone:` module
- Update `service:` syntax
- Update debug module syntax

---

### Phase 1, Task 1D: Address NetAnim Issue

**File to edit:** `/home/thc1006/dev/OpenNet/ansible/roles/netanim/tasks/main.yml`

**Decision Point:** Choose one approach:

**Option A: Skip NetAnim (QUICK FIX - 5 minutes)**
- Replace entire file with informational tasks
- ns-3 and Mininet will work fine without NetAnim
- Use Wireshark for packet visualization instead
- See ANSIBLE_FIXES_DETAILED.md Section 2, Option 1

**Option B: Upgrade to Qt5 NetAnim (MODERATE - 1-2 hours)**
- Requires updating NS3_VERSION and NETANIM_VERSION in group_vars/all
- NetAnim 3.114+ uses Qt5
- May require testing/verification that OpenNet patches work with newer ns-3
- See ANSIBLE_FIXES_DETAILED.md Section 2, Option 2

**Recommendation:** Use Option A for now (skip NetAnim), plan Option B as Phase 3 work.

---

## Testing Checklist

After each phase, verify:

### Phase 1 Testing (After Day 2):

- [ ] Ansible syntax check passes: `ansible-playbook --syntax-check ansible/playbook.yml`
- [ ] Playbook runs without fatal errors on test VM
- [ ] ns-3 build completes successfully (check logs for "BUILD SUCCESS")
- [ ] OVS daemon is running: `ovs-vsctl --version` shows version
- [ ] Time sync is working: `timedatectl status` shows synchronized
- [ ] Mininet is installed: `mn --version` returns version

### Phase 2 Testing (After Day 3):

- [ ] All Phase 1 tests still pass
- [ ] Mininet install script completes without errors
- [ ] qperf builds and installs without warnings
- [ ] No deprecation warnings in Ansible output
- [ ] Key services restart cleanly: `systemctl restart openvswitch-switch`

### Phase 3 Testing (Optional, Week 2):

- [ ] Upgraded software versions work with OpenNet patches
- [ ] All Phase 1 & 2 tests still pass
- [ ] NetAnim builds with Qt5 (if attempted)
- [ ] Performance improvements verified

---

## Rollback Plan

If something goes wrong, you can revert individual roles:

```bash
# Revert specific role to original state
git checkout ansible/roles/ns3/tasks/main.yml

# Or revert entire Phase 1 changes
git checkout ansible/roles/{ns3,openvswitch,ntp}/tasks/main.yml
git checkout ansible/roles/openvswitch/handlers/main.yml

# Verify no uncommitted changes
git status
```

---

## Estimated Timeline

| Phase | Tasks | Estimated Time | Status |
|-------|-------|-----------------|--------|
| 1 | Critical fixes (ns3, OVS, ntp, netanim) | 2-3 hours | Ready to implement |
| 2 | Reliability improvements (mininet, qperf) | 1.5-2 hours | Can start after Phase 1 |
| 3 | Version upgrades (optional) | 8-12 hours | Optional, Plan for later |
| **TOTAL** (Phases 1-2) | Core modernization | **3.5-5 hours** | **Ready NOW** |

---

## Success Criteria

After Phase 1 & 2, the OpenNet Ansible playbooks will:

✅ Work on Ubuntu 22.04 LTS and Debian 13
✅ Use Python 3 exclusively
✅ Use modern Ansible module syntax (2.10+)
✅ Have proper error handling and timeout values
✅ Install current versions of dependencies
✅ Pass Ansible 2.14+ compatibility checks
✅ Have clear deprecation messages for future work (NetAnim)

---

## Questions and Decisions Needed

Before starting Phase 1, confirm:

1. **NetAnim approach:**
   - Skip it (faster, works now)
   - Upgrade to Qt5 version (more complex, better long-term)

2. **Root access:**
   - Keep `remote_user: root` in playbook (simpler)
   - Switch to `become: yes` (better security)

3. **Software versions:**
   - Stay with ns-3.22 OVS 2.4.0 (legacy, minimal changes)
   - Upgrade to modern versions (better performance, more work)

---

## Next Steps

1. **Review and approve** this action plan
2. **Make decision** on NetAnim approach (skip vs upgrade)
3. **Start Phase 1** with Task 1A (ns3 role - simplest)
4. **Test** after each task before moving to next
5. **Commit changes** with clear git messages
6. **Document** any issues found and how they were resolved

