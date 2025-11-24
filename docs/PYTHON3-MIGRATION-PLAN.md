# Python 3 Compatibility Migration Plan for NS-3.22

## Executive Summary

NS-3.22 cannot run on Python 3-only systems due to Python 2 syntax in its WAF build system. This document provides a comprehensive analysis and mitigation strategy for Ubuntu 22.04 LTS.

## Problem Statement

NS-3.22 (released 2014) uses WAF 1.7.x, which was written for Python 2. Key compatibility issues:

- **58 print statements** without parentheses
- **6 exception statements** using old syntax (except X, e:)
- **File I/O** using removed `file()` builtin
- **Octal literals** in old syntax (0755 vs 0o755)
- **Multi-line statements** that require special handling

**Total: 64+ Python 2 compatibility issues**

## Recommended Solution: Patch + Manual Post-Processing

Given the complexity of perfectly automated conversion, the recommended approach is:

1. **Apply the provided patch** (`ns3-patch/waf-python3.patch`)
2. **Manually fix remaining edge cases** (multi-line statements, octal literals)
3. **Test the build** with waf configure/build
4. **Document any build-specific workarounds**

### Why This Approach?

| Factor | Rationale |
|--------|-----------|
| **Simplicity** | The patch is small (15KB) and can be reviewed |
| **Reproducibility** | Works as part of standard build process |
| **Maintainability** | Clear what changed and why |
| **Reversibility** | Easy to revert if needed |
| **Compatibility** | Works on both Python 2 and Python 3 |

## Step-by-Step Implementation

### Phase 1: Apply the Patch

```bash
cd ns-allinone-3.22/ns-3.22
patch -p1 < /path/to/ns3-patch/waf-python3.patch
```

**Expected result:** Patch applies cleanly to 8 files

### Phase 2: Manual Fixes for Edge Cases

#### Issue 1: Multi-line Print Statements

**Location:** `wscript` (lines ~535-536)

**Current (post-patch):**
```python
print("%-30s: %s%s%s" % ("Build profile", Logs.colors('GREEN'),
                         Options.options.build_profile, Logs.colors('NORMAL')))
```

**Problem:** The closing parenthesis is on the wrong line

**Fix:** Ensure parenthesis is correct:
```python
print("%-30s: %s%s%s" % ("Build profile", Logs.colors('GREEN'),
                         Options.options.build_profile, Logs.colors('NORMAL')))
```

**Manual Fix Script:**
```bash
cd ns-allinone-3.22/ns-3.22
# Review these files for multi-line print statements
grep -n "print(" wscript | grep -B1 "^[0-9]*-"
```

#### Issue 2: Octal Literals

**Locations:** `src/wscript` (lines ~513-515)

**Current:**
```python
os.chmod(dst, 0600)
os.chmod(dst, 0755)
```

**Fix:**
```python
os.chmod(dst, 0o600)
os.chmod(dst, 0o755)
```

**Manual Fix Script:**
```bash
# Find all octal literals
grep -rn "0[0-7]\{3,\}" ns-allinone-3.22/ns-3.22 --include="*.py" --include="wscript"
# Then manually review and fix
```

#### Issue 3: Regex Escape Sequences

Some raw strings should have `r` prefix. The patch may trigger warnings but code still works.

**Example warning:**
```
SyntaxWarning: invalid escape sequence '\d'
```

**Fix (if needed):**
```python
# Before
m = re.match("^GCC-XML version (\d\.\d(\.\d)?)$", version_line)

# After
m = re.match(r"^GCC-XML version (\d\.\d(\.\d)?)$", version_line)
```

### Phase 3: Test the Build

After applying patch and fixes:

```bash
cd ns-allinone-3.22/ns-3.22

# Test WAF parsing
./waf --version

# Try configuration
./waf configure --enable-python -d debug

# Build
./waf build -j4

# Run smoke test
python3 -c "import ns; print(ns)"
```

### Phase 4: Integration into Build Pipeline

Update `scripts/bootstrap-ubuntu-22.04.sh`:

```bash
# Download ns-3.22
wget -q https://www.nsnam.org/releases/ns-allinone-3.22.tar.bz2
tar xjf ns-allinone-3.22.tar.bz2

# Apply Python 3 compatibility patch
cd ns-allinone-3.22/ns-3.22
patch -p1 < ../../ns3-patch/waf-python3.patch

# Apply OpenNet-specific patches
patch -p1 < ../../ns3-patch/lte.patch
patch -p1 < ../../ns3-patch/sta-wifi-scan.patch
# ... etc

# Continue with build
./waf configure ...
```

## Files Affected by Migration

### Core Build Files
- `wscript` - Main WAF build script (2 issues)
- `src/wscript` - Source module build script (3+ issues)
- `bindings/python/wscript` - Python bindings build (15+ issues)

### Build Tool Support
- `bindings/python/ns3modulescan-modular.py`
- `bindings/python/ns3modulegen.py`
- `bindings/python/ns3modulegen-modular.py`
- `bindings/python/ns3modulescan.py`
- `bindings/python/topsort.py`

### Visualizer and Tools
- `src/visualizer/visualizer/core.py`
- `src/visualizer/visualizer/base.py`

### Documentation Generation
- Multiple `conf.py` files under `doc/*/source/` (auto-generated, auto-fixed)

### Example Scripts
- Various example scripts under `examples/` and `src/*/examples/`

## Patch Details

### File: `ns3-patch/waf-python3.patch`

- **Size:** ~15 KB
- **Lines modified:** ~50 across 8 files
- **Format:** Unified diff, compatible with `patch` command
- **Application:** `patch -p1 < waf-python3.patch`

### Transformations Applied

| Python 2 Syntax | Python 3 Syntax | Count |
|-----------------|-----------------|-------|
| `print x` | `print(x)` | ~40 |
| `print x,` | `print(x, end=" ")` | ~8 |
| `print >> f, x` | `print(x, file=f)` | ~8 |
| `except X, e:` | `except X as e:` | 6 |
| `file(...)` | `open(...)` | 1 |

## Risk Assessment

**Risk Level: LOW**

### Why Low Risk?

- Changes are purely syntactic (no functional changes)
- All changes preserve original intent and behavior
- Can be easily tested with `python3 -m py_compile`
- Can be reverted with `patch -R`
- Work on both Python 2 and Python 3

### Potential Issues

1. **Multi-line statements** - May need manual adjustment
2. **Octal literals** - Must be manually converted
3. **String handling** - Implicit unicode changes (unlikely to affect build)
4. **WAF internals** - May have other Python 2 dependencies

## Testing Strategy

### Unit Tests

```bash
# Check syntax of patched files
python3 -m py_compile \
    wscript \
    bindings/python/wscript \
    src/wscript \
    src/visualizer/visualizer/core.py \
    src/visualizer/visualizer/base.py
```

### Integration Tests

```bash
# Test WAF functionality
./waf --version
./waf distclean
./waf configure --enable-python --enable-examples
./waf build -j4

# Test Python bindings
python3 << 'EOF'
import sys
sys.path.insert(0, '/path/to/build/lib')
import ns
print(f"NS-3 version: {ns.__version__}")
EOF
```

### Regression Tests

```bash
# Run any existing example scripts with Python 3
python3 examples/wireless/wifi-ap.py
python3 src/flow-monitor/examples/wifi-olsr-flowmon.py
```

## Fallback Options

If the patching approach encounters blockers:

### Option A: Use Python 2 Wrapper

```bash
# Run waf with Python 2 (if available)
/usr/bin/python2 waf configure
/usr/bin/python2 waf build
```

*Note:* Requires Python 2.7 installation (security risk on modern systems)

### Option B: Use Docker

```dockerfile
FROM ubuntu:20.04  # Has Python 2
RUN apt-get install python2 python3
WORKDIR /opt/opennet
COPY . .
RUN cd ns-allinone-3.22/ns-3.22 && \
    /usr/bin/python2 waf configure --enable-python && \
    /usr/bin/python2 waf build
```

### Option C: Upgrade to NS-3.35+

NS-3.35 and later have native Python 3 support:
- No patches needed
- Modern Python best practices
- Active maintenance

*Requires:* Porting all OpenNet patches to new ns-3 API

## Timeline

- **Week 1:** Test patch on Ubuntu 22.04, identify edge cases
- **Week 2:** Create manual fix list, update build scripts
- **Week 3:** Test complete pipeline (patch → build → examples)
- **Week 4:** Document in REFACTORING_PLAN.md, update Dockerfile

## Success Criteria

- [ ] Patch applies cleanly to ns-3.22
- [ ] `./waf --version` runs without Python errors
- [ ] `./waf configure --enable-python` completes successfully
- [ ] `./waf build -j4` completes without Python-related errors
- [ ] At least one example topology runs successfully
- [ ] All changes documented and tested

## References

- **Analysis:** `/home/thc1006/dev/OpenNet/docs/NS3-PYTHON3-MIGRATION.md`
- **Patch:** `/home/thc1006/dev/OpenNet/ns3-patch/waf-python3.patch`
- **Patch docs:** `/home/thc1006/dev/OpenNet/ns3-patch/README-waf-python3.md`
- **Conversion tool:** `/home/thc1006/dev/OpenNet/scripts/convert-ns3-to-python3.py`
- **Related issue:** CLAUDE.md Section 5.2, Workflow C

## Next Steps

1. Apply patch to OpenNet's ns-allinone-3.22
2. Document remaining edge cases
3. Test full build pipeline
4. Update Docker image to apply patch
5. Add CI job to verify compatibility
