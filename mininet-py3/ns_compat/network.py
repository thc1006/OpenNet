"""
ns_compat.network - Compatibility shim for ns.network module

Re-exports all attributes from ns-3.41 Cppyy bindings' network namespace.
"""

from ns import ns as _ns

# Get the network namespace from Cppyy bindings
_network = _ns.network

# Re-export commonly used classes
Node = _network.Node
NodeContainer = _network.NodeContainer
NetDevice = _network.NetDevice
NetDeviceContainer = _network.NetDeviceContainer
Channel = _network.Channel
Packet = _network.Packet
Socket = _network.Socket
Address = _network.Address
Ipv4Address = _network.Ipv4Address
Ipv6Address = _network.Ipv6Address
Mac48Address = _network.Mac48Address
PacketSocketHelper = _network.PacketSocketHelper
SimpleChannel = _network.SimpleChannel
SimpleNetDevice = _network.SimpleNetDevice

# Allow dynamic attribute access for anything not explicitly listed
def __getattr__(name):
    return getattr(_network, name)
