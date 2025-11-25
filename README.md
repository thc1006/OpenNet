# OpenNet

An emulator for Software-Defined Wireless Local Area Network and Software-Defined LTE Backhaul Network.

> **This is a modernized fork** updated for **Ubuntu 22.04+** with Docker support and Python 3 compatibility.
> Original project: [dlinknctu/OpenNet](https://github.com/dlinknctu/OpenNet)

---

## Modernization Status

| Component | Status | Notes |
|-----------|--------|-------|
| Mininet core | Working | All topologies, pingall, iperf |
| OVS switches | Working | v2.17.9 |
| ns-3 C++ examples | Working | hello-simulator, etc. |
| ns-3.22 Python bindings | Not available | Use ns3-modern image instead |
| **ns-3.41 Python bindings** | **Working** | Full Cppyy support |
| **OpenNet modules** | **Working** | ns3.py, wifi.py, lte.py, opennet.py |
| Docker builds | Working | ~4GB images |
| GitHub Actions CI | Working | Smoke tests pass |

### Known Limitations

- **LTE patches**: Circular dependency issue (fix patches available, not yet integrated)
- **Time dilation**: Requires custom kernel, not supported in Docker

---

## Quick Start (Docker)

```bash
# Clone the repository
git clone https://github.com/thc1006/OpenNet.git
cd OpenNet

# Build and run (standard image)
docker build -t opennet:latest -f docker/Dockerfile .
docker run --rm --privileged opennet:latest --test

# Interactive shell
docker run --rm -it --privileged opennet:latest --shell

# Run Mininet pingall test
docker run --rm --privileged opennet:latest bash -c "mn --test pingall"
```

### Modern Image (Recommended for WiFi/LTE)

For full Python 3 bindings with ns-3.41:

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

---

## Features

* Built on top of Mininet and ns-3
* Wi-Fi station channel scan behavior (`sta-wifi-scan.patch`)
* CsmaLink and SimpleLink visualization in NetAnim (`animation-interface.patch`)
* SDN-based LTE backhaul emulation (`lte.patch`)
* **Docker support** for Ubuntu 22.04+
* **Python 3 compatible** modules
* **GCC 11+ compatibility** patches for ns-3.22

---

## Python 3 Compatibility (ns-3.22)

If building ns-3.22 natively and encountering Python 2 syntax errors:

```
File "wscript", line 109
    print name.ljust(25),
SyntaxError: Missing parentheses in call to 'print'
```

**Solution**: Apply the WAF Python 3 patch:

```bash
cd ns-allinone-3.22/ns-3.22
patch -p1 < /path/to/OpenNet/ns3-patch/waf-python3.patch
```

| Conversion | Count |
|------------|-------|
| `print x` → `print(x)` | 40 |
| `print x,` → `print(x, end=" ")` | 8 |
| `print >> f, x` → `print(x, file=f)` | 8 |
| `except X, e:` → `except X as e:` | 6 |

For detailed analysis, see [docs/NS3-PYTHON3-ANALYSIS-REPORT.md](docs/NS3-PYTHON3-ANALYSIS-REPORT.md).

---

## Documentation

| Document | Description |
|----------|-------------|
| [Tutorial](doc/TUTORIAL.md) | Original OpenNet tutorial |
| [Architecture Overview](docs/ARCHITECTURE-OVERVIEW.md) | System design |
| [Refactoring Plan](docs/REFACTORING_PLAN.md) | Full modernization details |
| [Python 3 Migration](docs/PYTHON3-MIGRATION-PLAN.md) | Migration plan |
| [NS3 Python 3 Analysis](docs/NS3-PYTHON3-ANALYSIS-REPORT.md) | Compatibility analysis |

---

## Native Installation (Ubuntu 22.04)

```bash
# Install dependencies
sudo ./scripts/bootstrap-ubuntu-22.04.sh

# Build ns-3.22 with patches
./scripts/build-ns3.sh

# Optional: Enable LTE patches
./scripts/build-ns3.sh --enable-lte
```

---

## Run OpenNet Examples

```bash
# Using Docker (recommended)
docker run --rm -it --privileged opennet:ns3-modern bash
cd /opt/opennet/mininet-py3
python3 -c "from ns3 import *; print('Ready')"

# Run NetAnim (inside container)
cd /root/ns-allinone-3.22/netanim-3.105
./NetAnim
# Open XML files from /tmp/xml
```

---

## Reading Material

- [Mininet Walkthrough](http://mininet.org/walkthrough/)
- [Introduction to Mininet](https://github.com/mininet/mininet/wiki/Introduction-to-Mininet)
- [Link modeling using ns-3](https://github.com/mininet/mininet/wiki/Link-modeling-using-ns-3)

---

## Legacy Installation (Ubuntu 14.04)

For the original Ubuntu 14.04 installation, see the [original repository](https://github.com/dlinknctu/OpenNet).

---

## Contributing

Issues and pull requests welcome at https://github.com/thc1006/OpenNet

## License

Same as original OpenNet - see LICENSE file.
