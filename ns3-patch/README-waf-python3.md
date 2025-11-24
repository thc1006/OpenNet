# WAF Python 3 Compatibility Patch for NS-3.22

## Overview

This directory contains patches to make ns-3.22's WAF build system compatible with Python 3.

## Issue: Python 2 Dependencies

NS-3.22 was released in 2014 and uses WAF 1.7.x, which is written in Python 2. The build system includes:

- Print statements without parentheses
- Old exception syntax (`except X, e:`)
- File I/O using `file()` builtin (removed in Python 3)
- Octal literals in old syntax (`0600` instead of `0o600`)
- Multi-line print statements that require special handling

## Current Status

### Patch: `waf-python3.patch`

This patch converts the most common Python 2 syntax issues:
- `print x` → `print(x)`
- `print x,` → `print(x, end=" ")`
- `print >> file, x` → `print(x, file=file)`
- `except X, e:` → `except X as e:`
- `file()` → `open()`

**Known Limitations:**
- Multi-line print statements may require manual fixes
- Octal literals (0600) still need to be converted to 0o600

### Files Modified by Patch

1. `wscript` (main build file)
2. `bindings/python/wscript`
3. `bindings/python/ns3modulescan-modular.py`
4. `bindings/python/ns3modulegen.py`
5. `bindings/python/ns3modulegen-modular.py`
6. `bindings/python/ns3modulescan.py`
7. `bindings/python/topsort.py`
8. `src/wscript`
9. `src/visualizer/visualizer/base.py`
10. `src/visualizer/visualizer/core.py`

## Application Instructions

To apply the patch to ns-3.22:

```bash
cd ns-allinone-3.22/ns-3.22
patch -p1 < /path/to/ns3-patch/waf-python3.patch
```

## Remaining Issues to Fix Manually

After applying the patch, check for the following remaining issues:

### 1. Multi-line print statements

**Location:** `wscript` around line 535

**Problem:**
```python
print "%-30s: %s%s%s" % ("Build profile", Logs.colors('GREEN'),
                         Options.options.build_profile, Logs.colors('NORMAL'))
```

**Fix:**
```python
print("%-30s: %s%s%s" % ("Build profile", Logs.colors('GREEN'),
                         Options.options.build_profile, Logs.colors('NORMAL')))
```

### 2. Octal Literals

**Locations:** `src/wscript` around line 513

**Problem:**
```python
os.chmod(dst, 0600)
os.chmod(dst, 0755)
```

**Fix:**
```python
os.chmod(dst, 0o600)
os.chmod(dst, 0o755)
```

### 3. Escape Sequences

Some raw strings may need `r` prefix (e.g., regex patterns with `\d`).

## Alternative Approaches

### Option 1: Use Python 2to3 Tool (Recommended)

If you have Python 2 installed, you can use the `2to3` tool to automatically convert files:

```bash
# Install 2to3 (usually comes with Python 2)
2to3 -w wscript
2to3 -w bindings/python/wscript
2to3 -w src/wscript
# etc.
```

Then create a unified diff patch from the results.

### Option 2: Install Python 2.7

On Ubuntu 22.04, Python 2 is not in the default repositories, but it can be built from source or installed from a PPA (not recommended for security reasons).

### Option 3: Use Docker

Run ns-3.22 build inside a Docker container with Python 3 compatibility layer installed.

## Testing the Build

After applying patches, test with:

```bash
./waf --version
./waf configure --enable-python -d debug
./waf build -j4
```

## Future Work

Consider upgrading to **NS-3.35 or later**, which has native Python 3 support.

## References

- [Python 2to3 Documentation](https://docs.python.org/3/library/2to3.html)
- [Python 3 Migration Guide](https://docs.python.org/3/howto/pyporting.html)
- [NS-3 Build System](https://www.nsnam.org/docs/build/)
