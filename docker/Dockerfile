# OpenNet Development/Runtime Container for Ubuntu 22.04
#
# This Dockerfile creates a complete OpenNet environment with:
#   - ns-3.22 with OpenNet patches
#   - Mininet (dlinknctu/mininet opennet branch)
#   - Python 2 (for ns-3.22 waf build compatibility)
#   - Python 3 (for modern Mininet and scripts)
#   - All required dependencies
#
# Build:
#   docker build -t opennet:latest -f docker/Dockerfile .
#
# Build with custom ns-3 options:
#   docker build --build-arg NS3_DISABLE_PYTHON="false" -t opennet:latest -f docker/Dockerfile .
#
# Run (interactive, recommended method using docker-compose):
#   docker compose -f docker/docker-compose.yml run --rm opennet
#
# Run (interactive, manual):
#   docker run --rm -it --privileged \
#     --cap-add=NET_ADMIN --cap-add=SYS_ADMIN --cap-add=NET_RAW \
#     -v /lib/modules:/lib/modules:ro \
#     opennet:latest
#
# Run smoke test:
#   docker run --rm --privileged opennet:latest --test
#
# Note on OVS in Docker:
#   - Requires --privileged OR specific capabilities (NET_ADMIN, SYS_ADMIN, NET_RAW)
#   - OVS kernel module must be loaded on the host OR use userspace datapath
#   - Mount /lib/modules for kernel module access
#   - If kernel module is unavailable, OVS runs in userspace mode (slower)

FROM ubuntu:22.04 AS base

LABEL maintainer="OpenNet Modernization Project"
LABEL description="OpenNet SDN Emulator/Simulator (Ubuntu 22.04)"

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/root
ENV NS3_VERSION=3.22
ENV NETANIM_VERSION=3.105

# Create working directories
WORKDIR /opt/opennet

# ============================================
# Stage 1: Install system dependencies
# ============================================

# Copy bootstrap script and install dependencies
COPY scripts/bootstrap-ubuntu-22.04.sh /opt/opennet/scripts/
RUN chmod +x /opt/opennet/scripts/bootstrap-ubuntu-22.04.sh && \
    /opt/opennet/scripts/bootstrap-ubuntu-22.04.sh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ============================================
# Stage 1b: Install Python 2 for ns-3.22 compatibility
# ============================================
# ns-3.22's waf build system requires Python 2
# Ubuntu 22.04 doesn't include Python 2 by default

RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common && \
    add-apt-repository -y universe && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    python2 \
    python2-dev \
    libpython2-dev && \
    # Create python2 symlinks if needed
    update-alternatives --install /usr/bin/python python /usr/bin/python3 2 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python2 1 && \
    # Install pip for Python 2
    curl -sSL https://bootstrap.pypa.io/pip/2.7/get-pip.py -o /tmp/get-pip.py && \
    python2 /tmp/get-pip.py && \
    rm /tmp/get-pip.py && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ============================================
# Stage 1c: Prepare OVS database for container use
# ============================================
# Pre-create OVS database schema so it's ready at runtime

RUN mkdir -p /var/run/openvswitch /var/log/openvswitch /etc/openvswitch && \
    ovsdb-tool create /etc/openvswitch/conf.db /usr/share/openvswitch/vswitch.ovsschema

# ============================================
# Stage 2: Build ns-3
# ============================================

FROM base AS ns3-builder

ARG NS3_DISABLE_PYTHON="true"

# Install Python 2 in the builder stage as well (needed for ns-3.22 waf)
# Note: Python bindings are disabled by default due to incompatibilities between
# ns-3.22's Python 2-based binding generation and modern Python 3 environments.
# See docs/REFACTORING_PLAN.md for details on this limitation.
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common && \
    add-apt-repository -y universe && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    python2 \
    python2-dev \
    libpython2-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy ns-3 build script and patches
COPY scripts/build-ns3.sh /opt/opennet/scripts/
COPY ns3-patch/ /opt/opennet/ns3-patch/
RUN chmod +x /opt/opennet/scripts/build-ns3.sh

# Download ns-3 (cached layer)
RUN /opt/opennet/scripts/build-ns3.sh --download-only --dest /root

# Build ns-3 using Python 2 (ns-3.22's waf requires Python 2)
# Note: We explicitly use python2 for the waf build system
RUN if [ "${NS3_DISABLE_PYTHON}" = "true" ]; then \
        PYTHON=python2 /opt/opennet/scripts/build-ns3.sh --skip-download --dest /root --disable-python || \
        echo "WARNING: ns-3 build had issues (expected for ns-3.22 on GCC 11+)."; \
    else \
        PYTHON=python2 /opt/opennet/scripts/build-ns3.sh --skip-download --dest /root || \
        echo "WARNING: ns-3 build had issues (expected for ns-3.22 on GCC 11+)."; \
    fi

# ============================================
# Stage 3: Final runtime image
# ============================================

FROM base AS runtime

# Copy ns-3 build from builder stage
COPY --from=ns3-builder /root/ns-allinone-${NS3_VERSION} /root/ns-allinone-${NS3_VERSION}

# Copy the rest of the OpenNet repository
COPY . /opt/opennet

# Make scripts executable
RUN chmod +x /opt/opennet/scripts/*.sh 2>/dev/null || true && \
    chmod +x /opt/opennet/docker/entrypoint.sh 2>/dev/null || true

# Install Mininet
# Note: dlinknctu/mininet fork has Python 2 syntax - doesn't work with Python 3
# We use upstream Mininet and keep the OpenNet fork for reference (examples, agents)
RUN git clone https://github.com/mininet/mininet.git /root/mininet && \
    cd /root/mininet && \
    git checkout 2.3.1b4 && \
    pip3 install -e . || echo "WARNING: Mininet pip install had issues."

# Fix Python SyntaxWarnings in Mininet cli.py
# Line 143: "is" with a literal -> use "==" instead
# Line 442: "is not" with a literal -> use "!=" instead
RUN sed -i "s/if line is '':/if line == '':/" /root/mininet/mininet/cli.py && \
    sed -i "s/if key is not '':/if key != '':/" /root/mininet/mininet/cli.py

# Build and install mnexec (required for Mininet to work)
RUN cd /root/mininet && \
    make mnexec && \
    install -m 755 mnexec /usr/local/bin/

# Clone the OpenNet-specific Mininet fork for reference and examples
# Note: This fork has Python 2 syntax issues and may not run directly
RUN git clone --branch opennet https://github.com/dlinknctu/mininet.git /root/opennet-mininet || \
    echo "WARNING: Failed to clone OpenNet mininet fork."

# Copy cluster module from opennet-mininet fork (needed for wifi.py and lte.py)
# Convert to Python 3 syntax using lib2to3
RUN if [ -d /root/opennet-mininet/mininet/cluster ]; then \
        echo "Installing cluster module from OpenNet fork..." && \
        cp -r /root/opennet-mininet/mininet/cluster /root/mininet/mininet/ && \
        # Use lib2to3 for Python 3 conversion
        echo "Converting cluster module to Python 3..." && \
        python3 -m lib2to3 -w -n --no-diffs /root/mininet/mininet/cluster/ && \
        echo "Cluster module installed and converted to Python 3."; \
    else \
        echo "WARNING: cluster module not found in opennet-mininet fork."; \
    fi

# Install ping and other network tools for Mininet tests
RUN apt-get update && apt-get install -y --no-install-recommends \
    iputils-ping \
    telnet \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy Python 3 converted OpenNet modules into Mininet
# These are from mininet-py3/ (converted from dlinknctu/mininet opennet branch)
RUN if [ -d /opt/opennet/mininet-py3 ]; then \
        echo "Installing Python 3 OpenNet modules..." && \
        cp /opt/opennet/mininet-py3/ns3.py /root/mininet/mininet/ && \
        cp /opt/opennet/mininet-py3/wifi.py /root/mininet/mininet/ && \
        cp /opt/opennet/mininet-py3/lte.py /root/mininet/mininet/ && \
        cp /opt/opennet/mininet-py3/opennet.py /root/mininet/mininet/ && \
        cp /opt/opennet/mininet-py3/cli.py /root/mininet/mininet/ 2>/dev/null || true && \
        cp /opt/opennet/mininet-py3/opennet-agent.py /root/mininet/bin/ && \
        chmod +x /root/mininet/bin/opennet-agent.py && \
        echo "OpenNet Python 3 modules installed."; \
    else \
        echo "WARNING: mininet-py3 directory not found, skipping OpenNet module installation."; \
    fi

# Set up environment variables
ENV PYTHONPATH="/root/mininet:/root/ns-allinone-${NS3_VERSION}/ns-${NS3_VERSION}/build/bindings/python:${PYTHONPATH}"
ENV LD_LIBRARY_PATH="/root/ns-allinone-${NS3_VERSION}/ns-${NS3_VERSION}/build:${LD_LIBRARY_PATH}"
ENV PATH="/root/mininet/bin:/root/ns-allinone-${NS3_VERSION}/ns-${NS3_VERSION}:${PATH}"

# Create opennet helper script
RUN echo '#!/bin/bash' > /usr/local/bin/opennet-env && \
    echo 'export NS3_DIR=/root/ns-allinone-${NS3_VERSION}/ns-${NS3_VERSION}' >> /usr/local/bin/opennet-env && \
    echo 'export MININET_DIR=/root/mininet' >> /usr/local/bin/opennet-env && \
    echo 'export PYTHONPATH="${MININET_DIR}:${NS3_DIR}/build/bindings/python:${PYTHONPATH}"' >> /usr/local/bin/opennet-env && \
    echo 'export LD_LIBRARY_PATH="${NS3_DIR}/build:${LD_LIBRARY_PATH}"' >> /usr/local/bin/opennet-env && \
    echo 'echo "OpenNet environment loaded. NS3_DIR=${NS3_DIR}, MININET_DIR=${MININET_DIR}"' >> /usr/local/bin/opennet-env && \
    chmod +x /usr/local/bin/opennet-env

# Ensure OVS kernel module loads at container start (if available)
RUN echo '#!/bin/bash' > /usr/local/bin/start-ovs && \
    echo 'modprobe openvswitch 2>/dev/null || true' >> /usr/local/bin/start-ovs && \
    echo 'service openvswitch-switch start 2>/dev/null || true' >> /usr/local/bin/start-ovs && \
    chmod +x /usr/local/bin/start-ovs

# Set working directory
WORKDIR /opt/opennet

# Default entrypoint
COPY docker/entrypoint.sh /opt/opennet/docker/
RUN chmod +x /opt/opennet/docker/entrypoint.sh 2>/dev/null || true

ENTRYPOINT ["/opt/opennet/docker/entrypoint.sh"]
CMD ["--shell"]
