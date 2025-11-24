# NS-3.22 Python 3 Compatibility Analysis

## Executive Summary

NS-3.22 uses a Python 2-based WAF build system that will not run on Python 3-only systems. The issue is **critical** for Ubuntu 22.04 LTS, which ships with Python 3.10+ and typically does not include Python 2.

**Total Python 2 compatibility issues found: 64**

## Issue Breakdown

### 1. Print Statements Without Parentheses (58 instances)

The most prevalent issue. Python 2 supports `print` as a statement, Python 3 requires it as a function.

**Examples:**
```python
# Python 2 (invalid in Python 3)
print name.ljust(25),           # print with trailing comma
print >> outfile, "text"        # print with output redirection
print >> sys.stderr, "error"    # print to stderr

# Python 3 (required)
print(name.ljust(25), end=' ')
print("text", file=outfile)
print("error", file=sys.stderr)
```

**Affected files:**
- `wscript` (main build file) - 2 instances
- `bindings/python/wscript` - ~15 instances
- `bindings/python/ns3modulescan-modular.py` - ~20 instances
- `bindings/python/ns3modulegen.py` - ~10 instances
- `bindings/python/ns3modulegen-modular.py` - ~5 instances
- Other binding files - ~6 instances

### 2. Old Exception Syntax (6 instances)

Python 2 uses `except Exception, var:`, Python 3 requires `except Exception as var:`.

**Examples:**
```python
# Python 2 (invalid in Python 3)
except OSError, ex:
except ImportError, _import_error:

# Python 3 (required)
except OSError as ex:
except ImportError as _import_error:
```

**Affected files:**
- `src/wscript` - 3 instances
- `src/visualizer/visualizer/core.py` - 1 instance
- `src/visualizer/visualizer/base.py` - 1 instance
- `bindings/python/topsort.py` - 1 instance (docstring example)

### 3. File I/O Issues

Python 2 uses `file()` builtin, Python 3 uses `open()`.

**Examples:**
```python
# Python 2
outfile = file(self.outputs[0].abspath(), "w")

# Python 3
outfile = open(self.outputs[0].abspath(), "w")
```

**Affected files:**
- `bindings/python/wscript` - 1 instance

### 4. Other Potential Issues

- Dictionary methods (`.iterkeys()`, `.itervalues()`, `.iteritems()`) - None found, good sign
- `xrange()` usage - None found, good sign
- Unicode/string handling - May have implicit issues

## Recommended Approach

### Option A: Create a Python 3 Compatibility Patch (RECOMMENDED)

**Pros:**
- Preserves ns-3.22 version (important for reproducibility)
- Minimal, focused changes
- Can be applied cleanly via `git apply` or `patch` command
- Non-invasive to the upstream project
- Works on both Python 2 (if available) and Python 3

**Cons:**
- Requires patch application as part of build process
- 64 changes to maintain across versions

### Option B: Install Python 2 Alongside Python 3

**Pros:**
- No code changes needed
- Python 2 packages may be available

**Cons:**
- Ubuntu 22.04 dropped Python 2 from main repositories
- Requires adding PPA or installing from source
- Python 2 is EOL (January 2020), security risk
- More complex environment setup

### Option C: Upgrade to NS-3.35+ (Future-Proof)

**Pros:**
- NS-3.35+ has native Python 3 support
- No legacy code to maintain
- Better long-term maintainability

**Cons:**
- Requires porting all OpenNet patches to new ns-3 version
- More significant refactoring
- May break API compatibility with existing OpenNet code

## Implementation Plan: Option A (Recommended)

### Phase 1: Create Python 3 Compatibility Patch

Apply the following transformations across all Python files in ns-3.22:

1. **Print statements to print functions:**
   - `print x` → `print(x)`
   - `print x,` → `print(x, end=' ')`
   - `print >> file, x` → `print(x, file=file)`
   - `print >> sys.stderr, x` → `print(x, file=sys.stderr)`
   - Bare `print` → `print()`

2. **Exception syntax:**
   - `except Exception, e:` → `except Exception as e:`

3. **File I/O:**
   - `file(...)` → `open(...)`

4. **Apply to all relevant files:**
   - Main wscript
   - All files under bindings/python/
   - All files under src/

### Phase 2: Create Wrapper Script

Create a `scripts/apply-ns3-python3-patches.sh` that:

1. Downloads/extracts ns-3.22 (if needed)
2. Applies the Python 3 compatibility patch
3. Applies existing OpenNet patches (lte, wifi, netanim, etc.)
4. Verifies patches applied successfully

### Phase 3: Update Build Documentation

- Add notes to `docs/REFACTORING_PLAN.md`
- Update bootstrap script to apply patches
- Update Dockerfile to apply patches

## Testing Strategy

1. **Basic patch application test:**
   ```bash
   patch -p1 < ns3-patch/waf-python3.patch
   ```

2. **WAF parsing test:**
   ```bash
   ./waf --version  # Check if waf can be parsed
   ```

3. **Configuration test:**
   ```bash
   ./waf configure --enable-python
   ```

4. **Build test:**
   ```bash
   ./waf build -j4
   ```

5. **Integration test:**
   - Run a simple OpenNet example (e.g., Wi-Fi topology)
   - Verify ns-3 bindings load correctly

## Risk Assessment

**Risk Level: LOW**

- Changes are purely syntactic (Python 2 → Python 3 equivalents)
- No functional logic changes
- Changes preserve original intent
- Can be tested before applying
- Can be easily reverted

## Backward Compatibility

The patch is **compatible with both Python 2 and Python 3** because:
- `print(x)` works in both Python 2.6+ and Python 3
- `except Exception as e:` works in both Python 2.6+ and Python 3
- `open()` works in both versions

This means environments with Python 2 can still use the patched version.

## Timeline

- **Immediate:** Create patch file
- **Short-term:** Integrate into build pipeline
- **Medium-term:** Test on Ubuntu 22.04
- **Long-term:** Consider ns-3.35+ upgrade path

## Related Files

- `/home/thc1006/dev/OpenNet/ns3-patch/` - Patch storage directory
- `/home/thc1006/dev/OpenNet/scripts/` - Build scripts
- `/home/thc1006/dev/OpenNet/docs/REFACTORING_PLAN.md` - Overall migration plan
- `/home/thc1006/dev/OpenNet/docker/Dockerfile` - Container build definition

## References

- [Python 2 to 3 Migration Guide](https://docs.python.org/3/library/2to3.html)
- [WAF Project](https://waf.io/)
- [NS-3 Build System](https://www.nsnam.org/docs/build/)
