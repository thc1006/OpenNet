"""
ns_compat.wifi - Compatibility shim for ns.wifi module

Re-exports all attributes from ns-3.41 Cppyy bindings' wifi namespace.
"""

from ns import ns as _ns

# Get the wifi namespace from Cppyy bindings
_wifi = _ns.wifi

# Re-export commonly used classes
WifiHelper = _wifi.WifiHelper
WifiMacHelper = _wifi.WifiMacHelper
YansWifiChannelHelper = _wifi.YansWifiChannelHelper
YansWifiPhyHelper = _wifi.YansWifiPhyHelper
Ssid = _wifi.Ssid
SsidValue = _wifi.SsidValue
WifiNetDevice = _wifi.WifiNetDevice
WifiPhy = _wifi.WifiPhy
WifiMac = _wifi.WifiMac
StaWifiMac = _wifi.StaWifiMac
ApWifiMac = _wifi.ApWifiMac
AdhocWifiMac = _wifi.AdhocWifiMac

# Allow dynamic attribute access for anything not explicitly listed
def __getattr__(name):
    return getattr(_wifi, name)
