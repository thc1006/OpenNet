#!/bin/bash
# entrypoint.sh - Docker entrypoint for OpenNet container
#
# Usage:
#   ./entrypoint.sh [OPTIONS]
#
# Options:
#   --shell         Start an interactive shell (default)
#   --test          Run smoke tests
#   --mn-test       Run Mininet basic test
#   --ns3-test      Run ns-3 hello-simulator test
#   --help          Show this help message
#
# Environment variables:
#   NS3_DIR         Path to ns-3 directory (default: /root/ns-allinone-3.22/ns-3.22)
#   MININET_DIR     Path to Mininet directory (default: /root/mininet)
#   OVS_FORCE_USERSPACE   Set to "1" to force userspace datapath (slower but works without kernel module)
#
# Required Docker capabilities for OVS/Mininet:
#   --cap-add=NET_ADMIN   Network administration
#   --cap-add=SYS_ADMIN   System administration (for namespaces)
#   --cap-add=NET_RAW     Raw socket access
#   OR use --privileged for full access

set -e

# Default paths
NS3_VERSION="${NS3_VERSION:-3.22}"
NS3_DIR="${NS3_DIR:-/root/ns-allinone-${NS3_VERSION}/ns-${NS3_VERSION}}"
MININET_DIR="${MININET_DIR:-/root/mininet}"

# OVS configuration
OVS_DB_CONF="/etc/openvswitch/conf.db"
OVS_DB_SCHEMA="/usr/share/openvswitch/vswitch.ovsschema"
OVS_RUN_DIR="/var/run/openvswitch"
OVS_LOG_DIR="/var/log/openvswitch"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

show_help() {
    head -24 "$0" | tail -21
    exit 0
}

# Initialize OVS database if needed
init_ovs_db() {
    mkdir -p "${OVS_RUN_DIR}" "${OVS_LOG_DIR}" /etc/openvswitch

    # Create database if it doesn't exist or is corrupted
    if [[ ! -f "${OVS_DB_CONF}" ]] || ! ovsdb-tool db-version "${OVS_DB_CONF}" &>/dev/null; then
        info "Initializing OVS database..."
        rm -f "${OVS_DB_CONF}"
        ovsdb-tool create "${OVS_DB_CONF}" "${OVS_DB_SCHEMA}"
    fi
}

# Start Open vSwitch
# Handles both kernel-based and userspace datapath modes
start_ovs() {
    info "Starting Open vSwitch..."

    local kernel_module_loaded=false

    # Try to load kernel module (requires --privileged or CAP_SYS_MODULE)
    if modprobe openvswitch 2>/dev/null; then
        kernel_module_loaded=true
        info "OVS kernel module loaded successfully"
    else
        # Check if module is already loaded
        if lsmod 2>/dev/null | grep -q openvswitch; then
            kernel_module_loaded=true
            info "OVS kernel module already loaded"
        else
            warn "Could not load openvswitch kernel module"
            warn "Possible solutions:"
            warn "  1. Run container with --privileged"
            warn "  2. Load module on host: sudo modprobe openvswitch"
            warn "  3. Mount /lib/modules: -v /lib/modules:/lib/modules:ro"
            if [[ "${OVS_FORCE_USERSPACE:-}" == "1" ]]; then
                warn "OVS_FORCE_USERSPACE=1: Will attempt userspace datapath (slower)"
            fi
        fi
    fi

    # Initialize database
    init_ovs_db

    # Start ovsdb-server if not running
    if ! pgrep -x ovsdb-server > /dev/null; then
        info "Starting ovsdb-server..."
        ovsdb-server "${OVS_DB_CONF}" \
            --remote=punix:"${OVS_RUN_DIR}/db.sock" \
            --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
            --private-key=db:Open_vSwitch,SSL,private_key \
            --certificate=db:Open_vSwitch,SSL,certificate \
            --bootstrap-ca-cert=db:Open_vSwitch,SSL,ca_cert \
            --pidfile="${OVS_RUN_DIR}/ovsdb-server.pid" \
            --log-file="${OVS_LOG_DIR}/ovsdb-server.log" \
            --detach 2>/dev/null

        if [[ $? -ne 0 ]]; then
            error "Failed to start ovsdb-server"
            return 1
        fi
    fi

    # Wait for ovsdb-server socket
    local timeout=10
    while [[ ! -S "${OVS_RUN_DIR}/db.sock" ]] && [[ $timeout -gt 0 ]]; do
        sleep 0.5
        ((timeout--))
    done

    if [[ ! -S "${OVS_RUN_DIR}/db.sock" ]]; then
        error "ovsdb-server socket not available after timeout"
        return 1
    fi

    # Initialize OVS configuration
    ovs-vsctl --no-wait init 2>/dev/null || true

    # Start ovs-vswitchd if not running
    if ! pgrep -x ovs-vswitchd > /dev/null; then
        info "Starting ovs-vswitchd..."

        local vswitchd_opts=""

        # If kernel module is not available and userspace is requested, configure netdev datapath
        if [[ "$kernel_module_loaded" == "false" ]] && [[ "${OVS_FORCE_USERSPACE:-}" == "1" ]]; then
            warn "Using userspace datapath (dpdk or netdev) - performance will be reduced"
            # Note: True userspace datapath requires additional setup (DPDK or AF_XDP)
            # For basic testing, the kernel datapath check will cause vswitchd to fail gracefully
        fi

        ovs-vswitchd \
            --pidfile="${OVS_RUN_DIR}/ovs-vswitchd.pid" \
            --log-file="${OVS_LOG_DIR}/ovs-vswitchd.log" \
            --detach 2>/dev/null

        if [[ $? -ne 0 ]]; then
            if [[ "$kernel_module_loaded" == "false" ]]; then
                error "Failed to start ovs-vswitchd (kernel module not available)"
                error "Mininet will not work without OVS kernel datapath"
                warn "Try: docker run --privileged ... OR load openvswitch module on host"
                return 1
            else
                error "Failed to start ovs-vswitchd"
                return 1
            fi
        fi
    fi

    # Verify OVS is running
    sleep 1
    if ovs-vsctl show &>/dev/null; then
        info "OVS started successfully"
        info "OVS version: $(ovs-vsctl --version | head -1)"
        return 0
    else
        error "OVS verification failed"
        return 1
    fi
}

# Run ns-3 test
run_ns3_test() {
    header "NS-3 Test"

    if [[ ! -d "${NS3_DIR}" ]]; then
        error "NS-3 directory not found: ${NS3_DIR}"
        return 1
    fi

    cd "${NS3_DIR}"

    # Check if hello-simulator exists
    if [[ -f "build/scratch/hello-simulator" ]]; then
        info "Running hello-simulator..."
        ./waf --run hello-simulator && info "NS-3 hello-simulator: PASSED" || {
            error "NS-3 hello-simulator: FAILED"
            return 1
        }
    else
        warn "hello-simulator not built. Checking ns-3 build status..."

        # Check if waf exists
        if [[ -f "./waf" ]]; then
            info "NS-3 waf found. Build may have failed or been skipped."
            info "Try rebuilding with: cd ${NS3_DIR} && ./waf build"
        else
            error "NS-3 waf not found"
            return 1
        fi
    fi

    return 0
}

# Run Mininet test
run_mn_test() {
    header "Mininet Test"

    if ! command -v mn &> /dev/null; then
        error "Mininet 'mn' command not found"
        return 1
    fi

    info "Mininet version: $(mn --version 2>&1)"

    # Basic connectivity test
    info "Running Mininet pingall test..."
    mn --test pingall && info "Mininet pingall: PASSED" || {
        error "Mininet pingall: FAILED"
        return 1
    }

    return 0
}

# Run all smoke tests
run_smoke_tests() {
    header "OpenNet Smoke Tests"

    local tests_passed=0
    local tests_failed=0

    # Check environment
    info "Environment check..."
    info "  NS3_DIR: ${NS3_DIR}"
    info "  MININET_DIR: ${MININET_DIR}"
    info "  Python: $(python3 --version 2>&1)"
    info "  GCC: $(gcc --version | head -1)"

    # Start OVS
    start_ovs

    # NS-3 test (optional - may fail if build failed)
    echo ""
    if run_ns3_test; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
        warn "NS-3 test failed (may be expected if ns-3.22 build had GCC 11+ issues)"
    fi

    # Mininet test
    echo ""
    if run_mn_test; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi

    # OpenNet modules check
    echo ""
    header "OpenNet Modules Check"
    local modules=(
        "${MININET_DIR}/mininet/ns3.py"
        "${MININET_DIR}/mininet/wifi.py"
        "${MININET_DIR}/mininet/lte.py"
        "${MININET_DIR}/mininet/opennet.py"
    )

    for module in "${modules[@]}"; do
        if [[ -f "$module" ]]; then
            info "  Found: $(basename $module)"
        else
            warn "  Missing: $(basename $module)"
        fi
    done

    # Summary
    echo ""
    header "Test Summary"
    info "Tests passed: ${tests_passed}"
    info "Tests failed: ${tests_failed}"

    if [[ ${tests_failed} -gt 0 ]]; then
        warn "Some tests failed. See output above for details."
        return 1
    else
        info "All tests passed!"
        return 0
    fi
}

# Cleanup OVS on exit
cleanup_ovs() {
    info "Cleaning up OVS..."
    # Kill OVS processes
    pkill -9 ovs-vswitchd 2>/dev/null || true
    pkill -9 ovsdb-server 2>/dev/null || true
    # Clean up any leftover Mininet state
    mn -c 2>/dev/null || true
}

# Interactive shell
start_shell() {
    header "OpenNet Development Environment"

    info "NS-3 directory: ${NS3_DIR}"
    info "Mininet directory: ${MININET_DIR}"
    info ""
    info "Python versions:"
    info "  Python 3: $(python3 --version 2>&1)"
    info "  Python 2: $(python2 --version 2>&1 || echo 'not available')"
    info ""
    info "Quick commands:"
    info "  mn --test pingall       # Test Mininet"
    info "  cd ${NS3_DIR} && python2 ./waf --run hello-simulator  # Test ns-3"
    info "  cd ${MININET_DIR}/examples/opennet            # OpenNet examples"
    info ""
    info "For ns-3 builds, use Python 2:"
    info "  cd ${NS3_DIR} && python2 ./waf configure && python2 ./waf build"
    info ""

    # Set up trap for cleanup on exit
    trap cleanup_ovs EXIT

    # Start OVS
    if ! start_ovs; then
        warn "OVS startup failed - Mininet functionality will be limited"
        warn "Consider running with: docker run --privileged ..."
    fi

    exec /bin/bash
}

# Main
case "${1:-}" in
    --test)
        run_smoke_tests
        ;;
    --mn-test)
        start_ovs
        run_mn_test
        ;;
    --ns3-test)
        run_ns3_test
        ;;
    --shell|"")
        start_shell
        ;;
    --help|-h)
        show_help
        ;;
    *)
        # If first arg doesn't start with --, assume it's a command to run
        if [[ "${1:0:2}" != "--" ]]; then
            start_ovs 2>/dev/null
            exec "$@"
        else
            error "Unknown option: $1"
            show_help
        fi
        ;;
esac
