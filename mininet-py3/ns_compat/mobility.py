"""
ns_compat.mobility - Compatibility shim for ns.mobility module

Re-exports all attributes from ns-3.41 Cppyy bindings' mobility namespace.
"""

from ns import ns as _ns

# Get the mobility namespace from Cppyy bindings
_mobility = _ns.mobility

# Re-export commonly used classes
MobilityHelper = _mobility.MobilityHelper
MobilityModel = _mobility.MobilityModel
ConstantPositionMobilityModel = _mobility.ConstantPositionMobilityModel
ConstantVelocityMobilityModel = _mobility.ConstantVelocityMobilityModel
RandomWaypointMobilityModel = _mobility.RandomWaypointMobilityModel
ListPositionAllocator = _mobility.ListPositionAllocator
GridPositionAllocator = _mobility.GridPositionAllocator
Vector = _mobility.Vector

# Allow dynamic attribute access for anything not explicitly listed
def __getattr__(name):
    return getattr(_mobility, name)
