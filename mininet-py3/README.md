# OpenNet Mininet Python 3 Conversion

This directory contains Python 3 converted versions of the critical OpenNet-specific Mininet files from the dlinknctu/mininet fork (opennet branch).

## Files Included

1. **ns3.py** - NS-3 integration for Mininet (Wi-Fi, CSMA, etc.)
2. **wifi.py** - Distributed Wi-Fi emulation interface
3. **lte.py** - LTE emulation interface with EPC support
4. **opennet.py** - NetAnim and PCAP utilities
5. **cli.py** - Mininet CLI with Python 3 fixes
6. **opennet-agent.py** - TCP daemon for distributed ns-3 emulation
7. **CONVERSION_SUMMARY.md** - Detailed conversion documentation

## What Was Changed

### Python 2 → Python 3 Syntax

1. **Exception Handling**
   - `except Exception, e:` → `except Exception as e:`
   - Applied to all exception handlers

2. **Dictionary Operations**
   - `dict.has_key(key)` → `key in dict`
   - Removed deprecated has_key() method

3. **Print Statements**
   - `print value` → `print(value)`
   - All print statements now use function syntax

4. **Bytes vs Strings (Socket Operations)**
   - All `socket.sendall()` calls use bytes: `b'string'`
   - Dynamic content uses `.encode()`: `'text {0}'.format(x).encode()`
   - Socket `recv()` output properly decoded from bytes

5. **Deprecated Methods**
   - `thread.isAlive()` → `thread.is_alive()`

6. **Builtin Changes**
   - `file(path, mode)` → `open(path, mode)`

7. **Script Shebangs**
   - `#!/usr/bin/python` → `#!/usr/bin/env python3`

## Installation

To use these converted files in your OpenNet installation:

```bash
# Copy to your mininet fork
cp ns3.py wifi.py lte.py opennet.py /path/to/mininet/mininet/
cp cli.py /path/to/mininet/mininet/
cp opennet-agent.py /path/to/mininet/bin/

# Make agent executable
chmod +x /path/to/mininet/bin/opennet-agent.py
```

## Compatibility Notes

### Requirements
- Python 3.6 or later
- ns-3 with Python 3 bindings enabled
- Mininet compatible with Python 3

### Important Considerations

1. **ns-3 Bindings**: The ns3.py module requires ns-3 Python bindings compiled for Python 3:
   ```bash
   ./waf configure --enable-python
   ./waf build
   ```

2. **Socket Protocol**: The socket communication between Mininet and opennet-agent.py remains unchanged. The conversion only handles Python-side bytes/string operations.

3. **Backward Compatibility**: These files are NOT compatible with Python 2. Original Python 2 versions remain in the upstream dlinknctu/mininet repository.

## Known Syntax Warnings

The Python 3 compiler raises these non-fatal warnings (inherited from original Mininet code):

- **cli.py line 143, 442**: String comparison using `is` instead of `==`
  - Not converted as these are from base Mininet
  - Functionally correct but not best practice

- **lte.py line 197, 304**: Unescaped escape sequences in regex patterns
  - Use raw strings: `r'[0-9]*\.[0-9]*\.[0-9]*\.'`
  - Not converted to avoid changing regex logic

These warnings do not affect functionality.

## Testing

To verify the files work:

```bash
# Check for syntax errors
python3 -m py_compile *.py

# Test imports (requires ns-3 bindings)
python3 -c "import sys; sys.path.insert(0, '.'); import ns3; from ns3 import core"

# Test individual modules
python3 -c "from ns3 import core, network, wifi; print('ns-3 imports OK')"
```

## Issues and Troubleshooting

### ImportError: No module named 'ns'
- Ensure ns-3 Python bindings are installed
- Check PYTHONPATH includes ns-3 installation
- Verify ns-3 built with `--enable-python`

### UnicodeDecodeError in socket operations
- Check that socket data is properly encoded as UTF-8
- Inspect opennet-agent.py for protocol-specific issues
- May need custom encoding for binary data

### File descriptor issues in opennet-agent.py
- Python 3 uses different default buffering
- May need to explicitly set `buffering=0` in open() calls
- Check `/tmp/opennet-agent.out` and `.err` for daemon output

## Contributing

When making changes to these files:

1. Maintain Python 3.6+ compatibility
2. Use bytes for socket operations
3. Keep exception handling with `as` syntax
4. Use function-style print()
5. Add comments explaining Python 2 → 3 changes
6. Update CONVERSION_SUMMARY.md with modifications

## References

- Original Repository: https://github.com/dlinknctu/mininet (branch: opennet)
- OpenNet Paper: https://github.com/dlinknctu/OpenNet (documentation)
- ns-3 Python Bindings: https://www.nsnam.org/docs/models/html/

## License

These files inherit the license from the original dlinknctu/mininet repository.

---

**Last Updated:** 2025-11-24
**Python Version:** 3.6+
**Status:** Ready for integration testing
