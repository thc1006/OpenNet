"""
ns_compat.lte - Compatibility shim for ns.lte module

Re-exports all attributes from ns-3.41 Cppyy bindings' lte namespace.
"""

from ns import ns as _ns

# Get the lte namespace from Cppyy bindings
_lte = _ns.lte

# Re-export commonly used classes
LteHelper = _lte.LteHelper
EpcHelper = _lte.EpcHelper
PointToPointEpcHelper = _lte.PointToPointEpcHelper
NoBackhaulEpcHelper = _lte.NoBackhaulEpcHelper
LteEnbNetDevice = _lte.LteEnbNetDevice
LteUeNetDevice = _lte.LteUeNetDevice
LteEnbRrc = _lte.LteEnbRrc
LteUeRrc = _lte.LteUeRrc
EpsBearer = _lte.EpsBearer

# Allow dynamic attribute access for anything not explicitly listed
def __getattr__(name):
    return getattr(_lte, name)
