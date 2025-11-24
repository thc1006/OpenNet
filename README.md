OpenNet
=======

An emulator for Software-Defined Wireless Local Area Network and Software-Defined LTE Backhaul Network.

**Modernized fork**: This fork has been updated to work on **Ubuntu 22.04+** with Docker support.

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
| ns-3 Python bindings | Not available | ns-3.22 requires Python 2 for bindings |
| OpenNet Wi-Fi examples | Requires ns-3 bindings | |
| OpenNet LTE examples | Requires ns-3 bindings | |

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

1. **ns-3 Python bindings**: ns-3.22's binding generation requires Python 2, which is incompatible with modern systems. OpenNet examples that use `from mininet.ns3 import *` will not work until ns-3 is upgraded to 3.35+.

2. **LTE patches**: Temporarily disabled due to circular dependency between `fd-net-device` and `lte` modules in ns-3.

3. **Time dilation**: VirtualTimeForMininet requires a custom kernel and is not included in the Docker image.

## Contributing

Issues and pull requests welcome at https://github.com/thc1006/OpenNet

## License

Same as original OpenNet - see LICENSE file.
