"""
ns_compat - Compatibility shim for ns-3.41 Cppyy bindings

This package provides backward compatibility with the old-style ns-3 imports
(import ns.core, import ns.network, etc.) used by OpenNet's integration modules.

ns-3.37+ uses Cppyy bindings which require:
    from ns import ns
    # then access as ns.core, ns.network, etc.

OpenNet's original code uses:
    import ns.core
    import ns.network

This shim bridges the gap by re-exporting Cppyy namespace objects as modules.

Usage:
    # Instead of modifying OpenNet code, add this to Python path first:
    import sys
    sys.path.insert(0, '/path/to/ns_compat')

    # Then old-style imports will work:
    import ns.core  # Will actually import from ns_compat.core
"""

from ns import ns as _ns

# Re-export the main ns namespace
# This allows `from ns_compat import ns` to work like `from ns import ns`
ns = _ns
