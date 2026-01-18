# ki7mt-ai-lab-devel

Development environment bootstrap for KI7MT AI Lab sovereign AI stack.

## Overview

This package provides a bootstrap script that configures all required repositories
and installs dependencies for developing and running the KI7MT AI Lab WSPR/Solar
data processing and model training infrastructure.

**Why a bootstrap script instead of an RPM?** External repositories (NVIDIA CUDA,
ClickHouse) must be configured before their packages can be installed. A bootstrap
script handles this dependency ordering automatically.

## Target Environment

- **OS**: Rocky Linux 9.x or 10.x (RHEL/AlmaLinux compatible)
- **GPU**: NVIDIA RTX 5090 (sm_120 Blackwell) or compatible
- **CUDA**: 12.8+ (required for sm_120)
- **Driver**: 570+ (Blackwell support)

## Quick Start

```bash
# Download and run the bootstrap script
curl -fsSL https://raw.githubusercontent.com/KI7MT/ki7mt-ai-lab-devel/main/ki7mt-ai-lab-bootstrap.sh -o ki7mt-ai-lab-bootstrap.sh
chmod +x ki7mt-ai-lab-bootstrap.sh

# Full installation (requires root)
sudo ./ki7mt-ai-lab-bootstrap.sh --full

# Or minimal (skip CUDA/ML packages)
sudo ./ki7mt-ai-lab-bootstrap.sh --minimal

# Verify installation (no root required)
./ki7mt-ai-lab-bootstrap.sh --verify
```

## Installation Modes

| Mode | Description |
|------|-------------|
| `--full` | Install everything: repos, build tools, CUDA, ClickHouse, Python ML (default) |
| `--minimal` | Skip CUDA and ML packages (for non-GPU nodes) |
| `--cuda-only` | Install only NVIDIA CUDA toolchain |
| `--tune` | Apply system tuning only (sysctl, ulimits, ClickHouse config) |
| `--verify` | Check installation status (no changes made) |

## What Gets Installed

### Repositories Configured
- **EPEL**: Extra Packages for Enterprise Linux
- **NVIDIA CUDA**: Direct from NVIDIA (not distro packages)
- **ClickHouse**: Official ClickHouse LTS repository
- **KI7MT COPR**: ki7mt-ai-lab-apps and ki7mt-ai-lab-core

### Build Tools
- make, gcc, gcc-c++, cmake
- autoconf, automake, libtool
- git, rpm-build, mock

### Go Development
- golang 1.22+ (for ch-go, application builds)

### NVIDIA CUDA Toolchain (--full or --cuda-only)
- cuda-toolkit-12-8
- cuda-nvcc-12-8 (compiler)
- cuda-cudart-devel-12-8 (runtime)
- cuda-libraries-devel-12-8
- nvidia-driver 570+

### ClickHouse Database
- clickhouse-server
- clickhouse-client

### Python Development
- python3 3.9+
- python3-pip, python3-devel
- python3-numpy, python3-pandas

### Python ML Packages (via pip, --full only)
- jupyter, jupyterlab
- torch, transformers, datasets

### Utilities
- pigz (parallel gzip)
- pv (pipe viewer)
- zstd, lz4 (compression)
- curl, wget, rsync

### KI7MT AI Lab Packages
- ki7mt-ai-lab-core (DDL schemas)
- ki7mt-ai-lab-apps (wspr-shredder, wspr-turbo, solar-ingest, etc.)

## System Tuning

The `--tune` mode (also included in `--full`) applies optimizations for high-throughput
data processing:

### Network/Memory Tuning (sysctl)
- `net.core.rmem_max=134217728` (128MB receive buffer)
- `net.core.wmem_max=134217728` (128MB send buffer)
- `vm.dirty_background_ratio=5`
- `vm.dirty_ratio=10`
- `vm.swappiness=10`

### User Limits
- `nofile` soft/hard: 1048576
- `nproc` soft/hard: 65535
- `memlock` unlimited

### ClickHouse Configuration
- `max_threads`: CPU count
- `max_memory_usage`: 75% of RAM
- `max_insert_threads`: CPU count / 2

## Post-Installation

### Verify Everything

```bash
./ki7mt-ai-lab-bootstrap.sh --verify
```

### Check CUDA

```bash
nvidia-smi
nvcc --version
```

### Check ClickHouse

```bash
clickhouse-client --query "SELECT version()"
```

### Initialize Database Schema

```bash
ki7mt-lab-db-init --stamp-version
```

## NVIDIA Notes

**IMPORTANT**: The bootstrap script uses NVIDIA's official CUDA repository, not
distro-provided packages. Distro packages often lag behind and may not support
the latest GPUs (e.g., Blackwell sm_120).

As of January 2026:
- **Rocky/RHEL 9.x**: Fully supported by NVIDIA
- **Rocky/RHEL 10.x**: Check NVIDIA for availability; may need 9.x repo with compatibility

## Version History

- **2.0.0** - Bootstrap script approach, aligned with ki7mt-ai-lab-apps/core v2.0.0
