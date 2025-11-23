# Development/runtime container for OpenNet on Ubuntu 22.04
#
# This Dockerfile is intentionally minimal. It installs the base dependencies
# via scripts/bootstrap-ubuntu-22.04.sh and drops you into a shell where you
# can run ns-3 and Mininet build commands.
#
# Build:
#   docker build -t opennet-dev -f docker/Dockerfile .
#
# Run:
#   docker run --rm -it --privileged opennet-dev
#
# Note: --privileged may be needed for Mininet/OVS networking inside Docker.
#       Consider creating a more restrictive profile once the build flow is stable.

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /opt/opennet

# Copy only the bootstrap script first so Docker can cache package installs
COPY scripts/bootstrap-ubuntu-22.04.sh /opt/opennet/scripts/bootstrap-ubuntu-22.04.sh

RUN chmod +x /opt/opennet/scripts/bootstrap-ubuntu-22.04.sh && \
    /opt/opennet/scripts/bootstrap-ubuntu-22.04.sh

# Now copy the rest of the repository (in the real project this will include
# the ns-3 tree, Mininet fork, docs, etc.).
COPY . /opt/opennet

# Default entrypoint: interactive shell.
CMD ["/bin/bash"]
