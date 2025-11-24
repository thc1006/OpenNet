"""
ns_compat.internet - Compatibility shim for ns.internet module

Re-exports all attributes from ns-3.41 Cppyy bindings' internet namespace.
"""

from ns import ns as _ns

# Get the internet namespace from Cppyy bindings
_internet = _ns.internet

# Re-export commonly used classes
InternetStackHelper = _internet.InternetStackHelper
Ipv4AddressHelper = _internet.Ipv4AddressHelper
Ipv4InterfaceContainer = _internet.Ipv4InterfaceContainer
Ipv4GlobalRoutingHelper = _internet.Ipv4GlobalRoutingHelper
Ipv4StaticRoutingHelper = _internet.Ipv4StaticRoutingHelper

# Allow dynamic attribute access for anything not explicitly listed
def __getattr__(name):
    return getattr(_internet, name)
