#!/usr/bin/env bash
# Cloud Agent environment bootstrap for OdbDesign.
# Idempotent: safe to re-run. Prepares the C++/CMake/vcpkg toolchain, fetches
# test data, and produces the canonical linux-dynamic-release build.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export VCPKG_ROOT="${VCPKG_ROOT:-$HOME/vcpkg}"
TESTDATA_DIR="$HOME/OdbDesignTestData"

echo "==> Installing system build dependencies"
sudo apt-get update -qq
sudo apt-get install -y -q --no-install-recommends \
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    curl \
    zip \
    unzip \
    tar \
    git

# The default image points cc/c++ at Clang, which selects a GCC-14 toolchain
# dir that has no libstdc++-14-dev and fails to link (-lstdc++ missing). The
# CMake presets reference cc/c++ directly, and CI builds with GCC, so pin the
# alternatives to GCC 13 for a working, CI-matching compiler.
echo "==> Pinning cc/c++ alternatives to GCC"
sudo update-alternatives --set cc /usr/bin/gcc
sudo update-alternatives --set c++ /usr/bin/g++

echo "==> Ensuring vcpkg is bootstrapped at $VCPKG_ROOT"
if [ ! -x "$VCPKG_ROOT/vcpkg" ]; then
    rm -rf "$VCPKG_ROOT"
    git clone https://github.com/microsoft/vcpkg.git "$VCPKG_ROOT"
    "$VCPKG_ROOT/bootstrap-vcpkg.sh" -disableMetrics
fi

echo "==> Fetching OdbDesign test data (design .tgz archives)"
if [ ! -d "$TESTDATA_DIR/TEST_DATA" ]; then
    git clone --depth 1 https://github.com/nam20485/OdbDesignTestData.git "$TESTDATA_DIR"
fi

echo "==> Persisting environment variables in ~/.bashrc"
BASHRC="$HOME/.bashrc"
touch "$BASHRC"
grep -q 'VCPKG_ROOT=' "$BASHRC" || echo "export VCPKG_ROOT=\"$HOME/vcpkg\"" >> "$BASHRC"
grep -q 'ODB_TEST_DATA_DIR=' "$BASHRC" || echo "export ODB_TEST_DATA_DIR=\"$HOME/OdbDesignTestData/TEST_DATA\"" >> "$BASHRC"
grep -q 'ODB_TEST_ENVIRONMENT_VARIABLE=' "$BASHRC" || echo "export ODB_TEST_ENVIRONMENT_VARIABLE=ODB_TEST_ENVIRONMENT_VARIABLE_EXISTS" >> "$BASHRC"

echo "==> Configuring and building (linux-dynamic-release)"
cd "$REPO_ROOT"
cmake --preset linux-dynamic-release
cmake --build --preset linux-dynamic-release

echo "==> OdbDesign environment bootstrap complete"
