# ki7mt-ai-lab-devel.spec
#
# Meta-package for KI7MT AI Lab development environment
# Installs all required toolchains for WSPR/Solar data processing and model training
#
# Target: Rocky Linux 9.x with NVIDIA RTX 5090 (sm_120 Blackwell)

Name:           ki7mt-ai-lab-devel
Version:        2.0.3
Release:        1%{?dist}
Summary:        Development environment for KI7MT AI Lab
License:        MIT
URL:            https://github.com/KI7MT/ki7mt-ai-lab-devel

BuildArch:      noarch

# =============================================================================
# Core Build Tools
# =============================================================================
Requires:       make
Requires:       gcc
Requires:       gcc-c++
Requires:       git
Requires:       cmake
Requires:       autoconf
Requires:       automake
Requires:       libtool

# =============================================================================
# Go Development (1.22+ required, 1.25+ recommended)
# =============================================================================
Requires:       golang >= 1.22

# =============================================================================
# NVIDIA CUDA Toolchain (sm_120 Blackwell support)
#
# IMPORTANT: Use NVIDIA's direct repository, NOT distro-provided packages.
#
# RTX 5090 requires:
#   - CUDA 12.8+ for sm_120 architecture support
#   - Driver 570+ for Blackwell GPUs
#
# Repository Setup (from NVIDIA directly):
#   https://developer.nvidia.com/cuda-downloads
#
#   Rocky/RHEL 9.x:
#     dnf config-manager --add-repo \
#       https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo
#
#   Rocky/RHEL 10.x (if available, otherwise use 9.x repo with compat):
#     dnf config-manager --add-repo \
#       https://developer.download.nvidia.com/compute/cuda/repos/rhel10/x86_64/cuda-rhel10.repo
#
# Note: As of 2025-01, NVIDIA's latest validated platform is RHEL 9.x.
#       Rocky 10.1 may require RHEL 9 compat repo or waiting for NVIDIA 10.x support.
#       Plan: Standardize on Rocky 9.x for production (EPYC + 9950X3D).
# =============================================================================
Requires:       cuda-toolkit-12-8
Requires:       cuda-cudart-devel-12-8
Requires:       cuda-nvcc-12-8
Requires:       cuda-libraries-devel-12-8
Requires:       nvidia-driver >= 570

# =============================================================================
# ClickHouse Database
#
# Repository setup:
#   curl -fsSL https://packages.clickhouse.com/rpm/lts/repodata/clickhouse.repo | \
#     sudo tee /etc/yum.repos.d/clickhouse.repo
# =============================================================================
Requires:       clickhouse-server
Requires:       clickhouse-client

# =============================================================================
# Python Development (ML/Analysis)
# =============================================================================
Requires:       python3 >= 3.9
Requires:       python3-pip
Requires:       python3-devel
Requires:       python3-numpy
Requires:       python3-pandas

# =============================================================================
# Compression & I/O Utilities
# =============================================================================
Requires:       pigz
Requires:       pv
Requires:       zstd
Requires:       lz4

# =============================================================================
# Networking & Data Transfer
# =============================================================================
Requires:       curl
Requires:       wget
Requires:       rsync

# =============================================================================
# Optional: Jupyter (commented - install via pip for latest)
# =============================================================================
# Requires:     python3-jupyter-core

%description
Meta-package that installs all development dependencies for the KI7MT AI Lab
sovereign AI stack.

Components:
  - CUDA 12.8+ toolchain for RTX 5090 (sm_120 Blackwell)
  - Go development environment
  - ClickHouse database server and client
  - Python ML/analysis tools
  - Compression and I/O utilities

Target Hardware:
  - AMD Ryzen 9 9950X3D / EPYC 7300P
  - NVIDIA RTX 5090 (32GB VRAM, 170 SMs)
  - Rocky Linux 9.x

This package does not install files; it only declares dependencies.

%prep
# Nothing to prepare - meta-package

%build
# Nothing to build - meta-package

%install
# Create marker directory for package verification
mkdir -p %{buildroot}%{_datadir}/%{name}
echo "KI7MT AI Lab Development Environment v%{version}" > %{buildroot}%{_datadir}/%{name}/README
echo "" >> %{buildroot}%{_datadir}/%{name}/README
echo "Installed components:" >> %{buildroot}%{_datadir}/%{name}/README
echo "  - CUDA 12.8+ (sm_120 Blackwell)" >> %{buildroot}%{_datadir}/%{name}/README
echo "  - Go 1.22+" >> %{buildroot}%{_datadir}/%{name}/README
echo "  - ClickHouse server/client" >> %{buildroot}%{_datadir}/%{name}/README
echo "  - Python 3.9+ with ML packages" >> %{buildroot}%{_datadir}/%{name}/README
echo "  - Compression utilities (pigz, zstd, lz4)" >> %{buildroot}%{_datadir}/%{name}/README

%files
%{_datadir}/%{name}/README

%changelog
* Mon Jan 20 2025 Greg Beam <ki7mt@yahoo.com> - 2.0.3-1
- Sync version across all lab packages
- Fix maintainer email in changelog

* Sun Jan 18 2025 KI7MT <ki7mt@ki7mt.com> - 2.0.0-1
- Initial release
- CUDA 12.8+ for RTX 5090 (sm_120 Blackwell) support
- Go, ClickHouse, Python toolchains
- Aligned with ki7mt-ai-lab-apps/core/cuda v2.0.0
