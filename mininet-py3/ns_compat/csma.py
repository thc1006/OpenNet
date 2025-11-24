"""
ns_compat.csma - Compatibility shim for ns.csma module

Re-exports all attributes from ns-3.41 Cppyy bindings' csma namespace.
"""

from ns import ns as _ns

# Get the csma namespace from Cppyy bindings
_csma = _ns.csma

# Re-export commonly used classes
CsmaHelper = _csma.CsmaHelper
CsmaChannel = _csma.CsmaChannel
CsmaNetDevice = _csma.CsmaNetDevice

# Allow dynamic attribute access for anything not explicitly listed
def __getattr__(name):
    return getattr(_csma, name)
