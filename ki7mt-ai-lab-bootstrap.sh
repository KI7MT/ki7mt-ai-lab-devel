#!/bin/bash
# =============================================================================
# ki7mt-ai-lab-bootstrap.sh
#
# Bootstrap script for KI7MT AI Lab development environment
# Sets up all toolchains for WSPR/Solar data processing and model training
#
# Target: Rocky Linux 9.x/10.x with NVIDIA RTX 5090 (sm_120 Blackwell)
#
# Usage:
#   ./ki7mt-ai-lab-bootstrap.sh [OPTIONS]
#
# Options:
#   --full          Install everything (default)
#   --minimal       Skip CUDA and ML packages
#   --cuda-only     Install only CUDA toolchain
#   --tune          Apply sysctl/network tuning only
#   --verify        Verify installation only
#   --help          Show this help
#
# =============================================================================

set -e

VERSION="2.0.0"
SCRIPT_NAME="ki7mt-ai-lab-bootstrap"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

log_success() {
    printf "${GREEN}[OK]${NC} %s\n" "$1"
}

log_warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

log_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

header() {
    printf "\n"
    printf "┌─────────────────────────────────────────────────────────────────┐\n"
    printf "│  KI7MT AI Lab Bootstrap v%s                                  │\n" "$VERSION"
    printf "│  Development Environment Setup                                  │\n"
    printf "└─────────────────────────────────────────────────────────────────┘\n"
    printf "\n"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_VERSION="$VERSION_ID"
        DISTRO_MAJOR="${VERSION_ID%%.*}"
    else
        log_error "Cannot detect distribution"
        exit 1
    fi

    log_info "Detected: $DISTRO_ID $DISTRO_VERSION (major: $DISTRO_MAJOR)"

    # Validate supported distro
    case "$DISTRO_ID" in
        rocky|almalinux|rhel|centos)
            if [[ "$DISTRO_MAJOR" -lt 9 ]]; then
                log_error "Requires Rocky/RHEL 9.x or newer"
                exit 1
            fi
            ;;
        fedora)
            log_info "Fedora detected - using Fedora repos"
            ;;
        *)
            log_warn "Untested distribution: $DISTRO_ID"
            ;;
    esac
}

# =============================================================================
# Repository Setup
# =============================================================================

setup_epel() {
    log_info "Setting up EPEL repository..."
    if rpm -q epel-release &>/dev/null; then
        log_success "EPEL already installed"
    else
        dnf install -y epel-release
        log_success "EPEL installed"
    fi
}

setup_nvidia_repo() {
    log_info "Setting up NVIDIA CUDA repository..."

    local NVIDIA_REPO="/etc/yum.repos.d/cuda-rhel9.repo"

    if [[ -f "$NVIDIA_REPO" ]]; then
        log_success "NVIDIA repo already configured"
        return 0
    fi

    # NVIDIA only officially supports RHEL 9.x as of 2026-01
    # Use rhel9 repo for both Rocky 9 and Rocky 10
    dnf config-manager --add-repo \
        https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo

    log_success "NVIDIA CUDA repo added (rhel9)"
}

setup_clickhouse_repo() {
    log_info "Setting up ClickHouse repository..."

    local CH_REPO="/etc/yum.repos.d/clickhouse.repo"

    if [[ -f "$CH_REPO" ]]; then
        log_success "ClickHouse repo already configured"
        return 0
    fi

    curl -fsSL https://packages.clickhouse.com/rpm/lts/repodata/clickhouse.repo | \
        tee /etc/yum.repos.d/clickhouse.repo > /dev/null

    log_success "ClickHouse LTS repo added"
}

setup_copr_repo() {
    log_info "Setting up KI7MT COPR repository..."

    if dnf copr list 2>/dev/null | grep -q "ki7mt/ki7mt-ai-lab"; then
        log_success "KI7MT COPR already enabled"
        return 0
    fi

    # Determine correct chroot
    if [[ "$DISTRO_MAJOR" -ge 10 ]]; then
        dnf copr enable -y ki7mt/ki7mt-ai-lab epel-10-x86_64 || \
            log_warn "COPR epel-10 not available, trying epel-9"
        dnf copr enable -y ki7mt/ki7mt-ai-lab epel-9-x86_64 2>/dev/null || true
    else
        dnf copr enable -y ki7mt/ki7mt-ai-lab epel-9-x86_64
    fi

    log_success "KI7MT COPR repo enabled"
}

# =============================================================================
# Package Installation
# =============================================================================

install_build_tools() {
    log_info "Installing build tools..."

    dnf install -y \
        make \
        gcc \
        gcc-c++ \
        git \
        cmake \
        autoconf \
        automake \
        libtool \
        pkgconf-pkg-config

    log_success "Build tools installed"
}

install_golang() {
    log_info "Installing Go development environment..."

    dnf install -y golang

    local GO_VERSION
    GO_VERSION=$(go version 2>/dev/null | awk '{print $3}')
    log_success "Go installed: $GO_VERSION"
}

install_cuda() {
    log_info "Installing NVIDIA CUDA toolchain..."

    # Check if NVIDIA driver is loaded
    if ! lsmod | grep -q nvidia; then
        log_warn "NVIDIA driver not loaded - install driver first and reboot"
    fi

    dnf install -y \
        cuda-toolkit-12-8 \
        cuda-cudart-devel-12-8 \
        cuda-nvcc-12-8 \
        cuda-libraries-devel-12-8

    # Add CUDA to PATH
    if ! grep -q "cuda" /etc/profile.d/cuda.sh 2>/dev/null; then
        cat > /etc/profile.d/cuda.sh << 'EOF'
# CUDA Environment
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
EOF
        log_info "Added CUDA to system PATH"
    fi

    log_success "CUDA toolchain installed"
}

install_nvidia_driver() {
    log_info "Installing NVIDIA driver..."

    if lsmod | grep -q nvidia; then
        log_success "NVIDIA driver already loaded"
        nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || true
        return 0
    fi

    dnf install -y nvidia-driver nvidia-driver-cuda

    log_warn "NVIDIA driver installed - REBOOT REQUIRED"
}

install_clickhouse() {
    log_info "Installing ClickHouse..."

    dnf install -y clickhouse-server clickhouse-client

    # Enable but don't start (user may want to configure first)
    systemctl enable clickhouse-server

    log_success "ClickHouse installed (run 'systemctl start clickhouse-server' to start)"
}

install_python_dev() {
    log_info "Installing Python development environment..."

    dnf install -y \
        python3 \
        python3-pip \
        python3-devel \
        python3-numpy \
        python3-pandas

    log_success "Python development packages installed"
}

install_python_ml() {
    log_info "Installing Python ML packages via pip..."

    pip3 install --upgrade pip
    pip3 install \
        jupyter \
        torch \
        transformers \
        datasets \
        scikit-learn \
        matplotlib \
        seaborn

    log_success "Python ML packages installed"
}

install_utilities() {
    log_info "Installing compression and I/O utilities..."

    dnf install -y \
        pigz \
        pv \
        zstd \
        lz4 \
        curl \
        wget \
        rsync \
        htop \
        iotop \
        tmux

    log_success "Utilities installed"
}

install_ki7mt_packages() {
    log_info "Installing KI7MT AI Lab packages..."

    dnf install -y ki7mt-ai-lab-apps

    log_success "KI7MT AI Lab packages installed"
}

# =============================================================================
# System Tuning (EPYC / High-Throughput)
# =============================================================================

apply_sysctl_tuning() {
    log_info "Applying sysctl tuning for high-throughput..."

    local SYSCTL_CONF="/etc/sysctl.d/99-ki7mt-ai-lab.conf"

    cat > "$SYSCTL_CONF" << 'EOF'
# =============================================================================
# KI7MT AI Lab - High-Throughput System Tuning
# Optimized for EPYC / Ryzen with 10GbE+ networking
# =============================================================================

# Network - Increase buffer sizes for 10GbE+
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# Network - Connection handling
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10

# Network - Performance
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3

# Memory - For large datasets
vm.swappiness = 10
vm.dirty_ratio = 40
vm.dirty_background_ratio = 10
vm.vfs_cache_pressure = 50

# File descriptors
fs.file-max = 2097152
fs.nr_open = 2097152

# Shared memory (for ClickHouse / large batch processing)
kernel.shmmax = 68719476736
kernel.shmall = 4294967296

# AIO for ClickHouse
fs.aio-max-nr = 1048576
EOF

    # Apply immediately
    sysctl --system > /dev/null

    log_success "Sysctl tuning applied: $SYSCTL_CONF"
}

apply_limits_tuning() {
    log_info "Applying ulimit tuning..."

    local LIMITS_CONF="/etc/security/limits.d/99-ki7mt-ai-lab.conf"

    cat > "$LIMITS_CONF" << 'EOF'
# KI7MT AI Lab - ulimit tuning
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 65535
* hard nproc 65535
* soft memlock unlimited
* hard memlock unlimited
EOF

    log_success "Ulimit tuning applied: $LIMITS_CONF"
}

apply_clickhouse_tuning() {
    log_info "Applying ClickHouse performance tuning..."

    local CH_TUNING="/etc/clickhouse-server/config.d/ki7mt-tuning.xml"

    mkdir -p /etc/clickhouse-server/config.d

    cat > "$CH_TUNING" << 'EOF'
<?xml version="1.0"?>
<clickhouse>
    <!-- Memory limits -->
    <max_server_memory_usage_to_ram_ratio>0.8</max_server_memory_usage_to_ram_ratio>

    <!-- Parallel processing -->
    <max_threads>32</max_threads>
    <max_insert_threads>16</max_insert_threads>

    <!-- Compression -->
    <compression>
        <case>
            <min_part_size>10000000000</min_part_size>
            <min_part_size_ratio>0.01</min_part_size_ratio>
            <method>lz4</method>
        </case>
    </compression>

    <!-- Mark cache for fast queries -->
    <mark_cache_size>10737418240</mark_cache_size>
</clickhouse>
EOF

    log_success "ClickHouse tuning applied: $CH_TUNING"
}

# =============================================================================
# Verification
# =============================================================================

verify_installation() {
    printf "\n"
    log_info "Verifying installation..."
    printf "\n"

    local FAILED=0

    # Build tools
    printf "Build Tools:\n"
    for cmd in gcc g++ make cmake git; do
        if command -v $cmd &>/dev/null; then
            printf "  ${GREEN}✓${NC} %s: %s\n" "$cmd" "$($cmd --version | head -1)"
        else
            printf "  ${RED}✗${NC} %s: NOT FOUND\n" "$cmd"
            FAILED=1
        fi
    done

    # Go
    printf "\nGo:\n"
    if command -v go &>/dev/null; then
        printf "  ${GREEN}✓${NC} go: %s\n" "$(go version)"
    else
        printf "  ${RED}✗${NC} go: NOT FOUND\n"
        FAILED=1
    fi

    # CUDA
    printf "\nCUDA:\n"
    if command -v nvcc &>/dev/null; then
        printf "  ${GREEN}✓${NC} nvcc: %s\n" "$(nvcc --version | grep release)"
    else
        printf "  ${YELLOW}○${NC} nvcc: NOT FOUND (optional)\n"
    fi

    if command -v nvidia-smi &>/dev/null; then
        printf "  ${GREEN}✓${NC} nvidia-smi:\n"
        nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null | \
            sed 's/^/      /'
    else
        printf "  ${YELLOW}○${NC} nvidia-smi: NOT FOUND (optional)\n"
    fi

    # ClickHouse
    printf "\nClickHouse:\n"
    if command -v clickhouse-client &>/dev/null; then
        printf "  ${GREEN}✓${NC} clickhouse-client: %s\n" "$(clickhouse-client --version 2>/dev/null)"
    else
        printf "  ${RED}✗${NC} clickhouse-client: NOT FOUND\n"
        FAILED=1
    fi

    if systemctl is-active clickhouse-server &>/dev/null; then
        printf "  ${GREEN}✓${NC} clickhouse-server: running\n"
    else
        printf "  ${YELLOW}○${NC} clickhouse-server: not running\n"
    fi

    # Python
    printf "\nPython:\n"
    if command -v python3 &>/dev/null; then
        printf "  ${GREEN}✓${NC} python3: %s\n" "$(python3 --version)"
    else
        printf "  ${RED}✗${NC} python3: NOT FOUND\n"
        FAILED=1
    fi

    # KI7MT packages
    printf "\nKI7MT AI Lab:\n"
    for cmd in wspr-shredder wspr-turbo solar-ingest; do
        if command -v $cmd &>/dev/null; then
            printf "  ${GREEN}✓${NC} %s: %s\n" "$cmd" "$($cmd --help 2>&1 | head -1)"
        else
            printf "  ${YELLOW}○${NC} %s: NOT FOUND\n" "$cmd"
        fi
    done

    printf "\n"
    if [[ $FAILED -eq 0 ]]; then
        log_success "All core components verified"
    else
        log_error "Some components missing - check output above"
    fi

    return $FAILED
}

# =============================================================================
# Main
# =============================================================================

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  --full          Install everything (default)
  --minimal       Skip CUDA and ML packages
  --cuda-only     Install only CUDA toolchain
  --tune          Apply sysctl/network tuning only
  --verify        Verify installation only
  --help          Show this help

Examples:
  sudo ./ki7mt-ai-lab-bootstrap.sh              # Full install
  sudo ./ki7mt-ai-lab-bootstrap.sh --minimal    # Skip CUDA/ML
  sudo ./ki7mt-ai-lab-bootstrap.sh --tune       # Apply tuning only
  ./ki7mt-ai-lab-bootstrap.sh --verify          # Check installation

EOF
}

main() {
    local MODE="full"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --full)
                MODE="full"
                shift
                ;;
            --minimal)
                MODE="minimal"
                shift
                ;;
            --cuda-only)
                MODE="cuda"
                shift
                ;;
            --tune)
                MODE="tune"
                shift
                ;;
            --verify)
                MODE="verify"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    header

    # Verify-only doesn't need root
    if [[ "$MODE" == "verify" ]]; then
        verify_installation
        exit $?
    fi

    check_root
    detect_distro

    case "$MODE" in
        full)
            log_info "Mode: Full installation"
            printf "\n"

            setup_epel
            setup_nvidia_repo
            setup_clickhouse_repo
            setup_copr_repo

            printf "\n"
            dnf makecache
            printf "\n"

            install_build_tools
            install_golang
            install_nvidia_driver
            install_cuda
            install_clickhouse
            install_python_dev
            install_python_ml
            install_utilities
            install_ki7mt_packages

            printf "\n"
            apply_sysctl_tuning
            apply_limits_tuning
            apply_clickhouse_tuning

            printf "\n"
            verify_installation
            ;;

        minimal)
            log_info "Mode: Minimal installation (no CUDA/ML)"
            printf "\n"

            setup_epel
            setup_clickhouse_repo
            setup_copr_repo

            printf "\n"
            dnf makecache
            printf "\n"

            install_build_tools
            install_golang
            install_clickhouse
            install_python_dev
            install_utilities
            install_ki7mt_packages

            printf "\n"
            apply_sysctl_tuning
            apply_limits_tuning
            apply_clickhouse_tuning

            printf "\n"
            verify_installation
            ;;

        cuda)
            log_info "Mode: CUDA-only installation"
            printf "\n"

            setup_nvidia_repo

            printf "\n"
            dnf makecache
            printf "\n"

            install_nvidia_driver
            install_cuda

            printf "\n"
            verify_installation
            ;;

        tune)
            log_info "Mode: Apply tuning only"
            printf "\n"

            apply_sysctl_tuning
            apply_limits_tuning
            apply_clickhouse_tuning

            log_success "Tuning applied. Some settings require logout/reboot to take effect."
            ;;
    esac

    printf "\n"
    printf "┌─────────────────────────────────────────────────────────────────┐\n"
    printf "│  Bootstrap complete!                                            │\n"
    printf "│                                                                 │\n"
    printf "│  Next steps:                                                    │\n"
    printf "│    1. Reboot if NVIDIA driver was installed                    │\n"
    printf "│    2. Run: ki7mt-lab-db-init --stamp-version                   │\n"
    printf "│    3. Start ClickHouse: systemctl start clickhouse-server      │\n"
    printf "└─────────────────────────────────────────────────────────────────┘\n"
    printf "\n"
}

main "$@"
