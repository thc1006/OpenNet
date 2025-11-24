"""
ns_compat.core - Compatibility shim for ns.core module

Re-exports all attributes from ns-3.41 Cppyy bindings' core namespace.
"""

from ns import ns as _ns

# Get the core namespace from Cppyy bindings
_core = _ns.core

# Re-export commonly used classes and functions
GlobalValue = _core.GlobalValue
StringValue = _core.StringValue
BooleanValue = _core.BooleanValue
IntegerValue = _core.IntegerValue
UintegerValue = _core.UintegerValue
DoubleValue = _core.DoubleValue
TimeValue = _core.TimeValue
Seconds = _core.Seconds
MilliSeconds = _core.MilliSeconds
MicroSeconds = _core.MicroSeconds
NanoSeconds = _core.NanoSeconds
Time = _core.Time
Simulator = _core.Simulator
Config = _core.Config
ObjectFactory = _core.ObjectFactory
TypeId = _core.TypeId
Ptr = _core.Ptr
Create = _core.Create
MakeCallback = _core.MakeCallback
Callback = _core.Callback
CommandLine = _core.CommandLine
LogComponentEnable = _core.LogComponentEnable
LogComponentEnableAll = _core.LogComponentEnableAll
LOG_LEVEL_ALL = _core.LOG_LEVEL_ALL
LOG_LEVEL_DEBUG = _core.LOG_LEVEL_DEBUG
LOG_LEVEL_INFO = _core.LOG_LEVEL_INFO
LOG_LEVEL_WARN = _core.LOG_LEVEL_WARN
LOG_LEVEL_ERROR = _core.LOG_LEVEL_ERROR
LOG_LEVEL_FUNCTION = _core.LOG_LEVEL_FUNCTION

# Allow dynamic attribute access for anything not explicitly listed
def __getattr__(name):
    return getattr(_core, name)
