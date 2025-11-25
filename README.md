OpenNet
=======

An emulator for Software-Defined Wireless Local Area Network and Software-Defined LTE Backhaul Network.

**Modernized fork**: This fork has been updated to work on **Ubuntu 22.04+** with Docker support.

> **Last Updated**: 2025-11-26

## Quick Start (Docker - Recommended)

The fastest way to get started with OpenNet:

```bash
# Clone the repository
git clone https://github.com/thc1006/OpenNet.git
cd OpenNet

# Build the Docker image
docker build -t opennet:latest -f docker/Dockerfile .

# Run smoke tests
docker run --rm --privileged opennet:latest --test

# Interactive shell
docker run --rm -it --privileged opennet:latest --shell

# Run Mininet pingall test
docker run --rm --privileged opennet:latest bash -c "mn --test pingall"
```

## Features

* Built on top of Mininet and ns-3
* Complement ns-3 by supporting channel scan behavior on Wi-Fi station (`sta-wifi-scan.patch`)
* Show CsmaLink and SimpleLink in NetAnim (`animation-interface.patch`)
* Support SDN-based LTE backhaul emulation (`lte.patch`)
* **NEW**: Docker support for Ubuntu 22.04+
* **NEW**: Python 3 compatible modules
* **NEW**: GCC 11+ compatibility patches for ns-3.22

## What Works

| Feature | Status | Notes |
|---------|--------|-------|
| Mininet core | Working | All topologies (tree, linear, single, torus) |
| OVS switches | Working | OVS 2.17.9 |
| ns-3 C++ examples | Working | hello-simulator, etc. |
| ns-3.22 Python bindings | Not available | Legacy ns-3.22 requires Python 2 |
| ns-3.41 Python bindings | Working | Use `opennet:ns3-modern` image |
| OpenNet module imports | Working | ns3.py, wifi.py, lte.py, opennet.py load in ns3-modern |
| OpenNet Wi-Fi examples | Experimental | Use ns3-modern image |
| OpenNet LTE examples | Experimental | Use ns3-modern image |

## Docker Images

### Standard Image (ns-3.22, legacy)
```bash
docker build -t opennet:latest -f docker/Dockerfile .
docker run --rm -it --privileged opennet:latest --shell
```
- Mininet + OVS fully working
- ns-3 C++ examples working
- Python bindings NOT available (ns-3.22 limitation)

### Modern Image (ns-3.41, Python 3 bindings) - Recommended for OpenNet
```bash
docker build -t opennet:ns3-modern -f docker/Dockerfile.ns3-modern .
docker run --rm -it --privileged opennet:ns3-modern bash

# Test ns-3 Python bindings
docker run --rm opennet:ns3-modern python3 -c "from ns import ns; print(ns.wifi)"

# Test OpenNet module imports
docker run --rm opennet:ns3-modern python3 -c "
import sys
sys.path.insert(0, '/opt/opennet/mininet-py3')
from ns3 import *
print('OpenNet ns3.py loaded successfully')
"
```
- Full Python 3 bindings via Cppyy
- WiFi, LTE, Mesh modules accessible from Python
- OpenNet modules (ns3.py, wifi.py, lte.py, opennet.py) import successfully
- Includes cluster module for distributed emulation
- Updated for ns-3.41 Cppyy API (`from ns import ns` import style)

## Requirements

### Docker (Recommended)
- Docker 20.10+
- Linux host with kernel modules for OVS

### Native Installation (Ubuntu 22.04)
```bash
sudo ./scripts/bootstrap-ubuntu-22.04.sh
./scripts/build-ns3.sh
```

## Documentation

- [Tutorial](doc/TUTORIAL.md) - Original OpenNet tutorial
- [Architecture Overview](docs/ARCHITECTURE-OVERVIEW.md) - System design
- [Refactoring Plan](docs/REFACTORING_PLAN.md) - Modernization status
- [Python 3 Migration](docs/PYTHON3-MIGRATION-PLAN.md) - Migration details

## Reading Material

- [Mininet Walkthrough](http://mininet.org/walkthrough/)
- [Introduction to Mininet](https://github.com/mininet/mininet/wiki/Introduction-to-Mininet)
- [Link modeling using ns-3](https://github.com/mininet/mininet/wiki/Link-modeling-using-ns-3)

## Legacy Installation (Ubuntu 14.04)

For the original Ubuntu 14.04 installation, see the [original repository](https://github.com/dlinknctu/OpenNet).

```bash
sudo su -
apt-get install git ssh
git clone https://github.com/dlinknctu/OpenNet.git
cd OpenNet
./configure.sh
./install.sh master
```

## Run OpenNet Example Script

```bash
# Using Docker
docker run --rm -it --privileged opennet:latest bash
cd /root/opennet-mininet/examples/opennet/wifi
python3 two-ap-one-sw.py  # Note: Requires ns-3 Python bindings

# Native (legacy)
sudo su -
cd OpenNet
python mininet/examples/opennet/wifi/two-ap-one-sw.py
```

## Run NetAnim

Use NetAnim to open the XML file in the directory `/tmp/xml`.

```bash
# Inside Docker container
cd /root/ns-allinone-3.22/netanim-3.105
./NetAnim
```

## Known Limitations

1. **ns-3.22 Python bindings**: The legacy ns-3.22 container cannot generate Python bindings (requires Python 2). Use the `opennet:ns3-modern` image with ns-3.41 for full Python 3 support.

2. **ns-3.41 API differences**: OpenNet modules have been updated for ns-3.41's Cppyy bindings, which use `from ns import ns` import style instead of `import ns.core`. The `BooleanValue` API now requires Python bool (`True`/`False`) instead of strings (`"true"`/`"false"`).

3. **LTE patches (ns-3.22)**: Temporarily disabled due to circular dependency between `fd-net-device` and `lte` modules. Not yet ported to ns-3.41.

4. **Time dilation**: VirtualTimeForMininet requires a custom kernel and is not included in Docker images.

## Contributing

Issues and pull requests welcome at https://github.com/thc1006/OpenNet

## License

Same as original OpenNet - see LICENSE file.
