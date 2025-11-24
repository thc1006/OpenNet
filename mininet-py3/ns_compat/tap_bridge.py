"""
ns_compat.tap_bridge - Compatibility shim for ns.tap_bridge module

Re-exports all attributes from ns-3.41 Cppyy bindings' tap-bridge namespace.
"""

from ns import ns as _ns

# Get the tap_bridge namespace from Cppyy bindings
_tap_bridge = _ns.tap_bridge

# Re-export commonly used classes
TapBridgeHelper = _tap_bridge.TapBridgeHelper
TapBridge = _tap_bridge.TapBridge

# Allow dynamic attribute access for anything not explicitly listed
def __getattr__(name):
    return getattr(_tap_bridge, name)
