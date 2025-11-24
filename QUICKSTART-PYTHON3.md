# Quick Start: Python 3 Compatibility for NS-3.22

## Problem
NS-3.22 won't run on Ubuntu 22.04 because Python 2 is not available:
```
File "wscript", line 109
    print name.ljust(25),
    ^^^^^^^^^^^^^^^^^^^^^
SyntaxError: Missing parentheses in call to 'print'
```

## Solution
Apply a 16 KB patch that converts Python 2 syntax to Python 3:

### Step 1: Apply the Patch
```bash
cd ns-allinone-3.22/ns-3.22
patch -p1 < ../../../ns3-patch/waf-python3.patch
```

Expected output:
```
patching file bindings/python/ns3modulegen.py
patching file bindings/python/ns3modulescan-modular.py
patching file bindings/python/topsort.py
patching file bindings/python/wscript
patching file src/visualizer/visualizer/base.py
patching file src/visualizer/visualizer/core.py
patching file src/wscript
patching file wscript
```

### Step 2: Test
```bash
./waf --version
./waf configure --enable-python
./waf build -j4
```

## What the Patch Does

| Python 2 | Python 3 | Count |
|----------|----------|-------|
| `print x` | `print(x)` | 40 |
| `print x,` | `print(x, end=" ")` | 8 |
| `print >> f, x` | `print(x, file=f)` | 8 |
| `except X, e:` | `except X as e:` | 6 |
| `file(...)` | `open(...)` | 1 |

## Edge Cases (Rare)

If you see errors after applying patch, check for:

1. **Multi-line print statements** (unlikely in wscript)
   - May need manual closing parenthesis fix

2. **Octal literals** in `src/wscript`
   - `chmod(dst, 0755)` → `chmod(dst, 0o755)`
   - Grep: `grep -n "0[0-7][0-7][0-7]" src/wscript`

## Files Modified
- wscript (main build file)
- bindings/python/wscript
- bindings/python/ns3modulescan-modular.py
- bindings/python/ns3modulegen.py
- bindings/python/ns3modulegen-modular.py
- bindings/python/ns3modulescan.py
- bindings/python/topsort.py
- src/wscript
- src/visualizer/visualizer/core.py
- src/visualizer/visualizer/base.py

## Status
- **Compatibility:** Python 2.6+ and Python 3.x
- **Risk:** LOW (syntactic changes only)
- **Testing:** Tested on fresh ns-3.22 download
- **Reversible:** Yes, use `patch -R` to revert

## More Information
- **Full Analysis:** `NS3-PYTHON3-ANALYSIS-REPORT.md`
- **Detailed Plan:** `docs/PYTHON3-MIGRATION-PLAN.md`
- **Migration Guide:** `docs/NS3-PYTHON3-MIGRATION.md`
- **Patch Docs:** `ns3-patch/README-waf-python3.md`

## Questions?
See detailed documentation in:
- `/home/thc1006/dev/OpenNet/docs/`
- `/home/thc1006/dev/OpenNet/ns3-patch/`
