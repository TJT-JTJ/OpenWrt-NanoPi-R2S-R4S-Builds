# Building OpenWrt for NanoPi R4S Locally on Ubuntu

This guide provides step-by-step instructions to build the exact same OpenWrt firmware for the NanoPi R4S on your own Ubuntu machine (self-hosted) that is produced by the GitHub Actions workflow in this repository.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [System Requirements](#system-requirements)
3. [Environment Setup](#environment-setup)
4. [Build Process](#build-process)
5. [Output Files](#output-files)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Supported Ubuntu Version
- **Ubuntu 22.04 LTS** (recommended and tested)
- Other recent Ubuntu versions may work but are untested

### Hardware Requirements
- **CPU**: Multi-core processor (4+ cores recommended)
- **RAM**: Minimum 8GB, 16GB+ recommended
- **Disk Space**: At least 50GB of free space
- **Internet**: Stable broadband connection for downloading sources and packages

---

## System Requirements

### Install Required Packages

First, update your system and install all required build dependencies:

```bash
# Update package lists
sudo apt-get update -y

# Install all required build dependencies
sudo apt-get install -y build-essential ccache ecj fastjar file g++ gawk \
  gettext git java-propose-classpath libelf-dev libncurses5-dev \
  libncursesw5-dev libssl-dev python3 unzip wget python3-distutils \
  python3-setuptools python3-dev rsync subversion swig time xsltproc \
  zlib1g-dev python3-pyelftools clang llvm

# Configure git (required for the build process)
git config --global user.name 'Your Name'
git config --global user.email 'your.email@example.com'
```

### Free Up Disk Space (Optional)

If you're running on a system with limited disk space, you can optionally remove some unused packages:

```bash
# Remove large unused packages (optional)
sudo apt-get remove -y '^ghc-8.*' '^dotnet-.*' '^llvm-.*' 'php.*' \
  'temurin-.*' 'mono-.*' azure-cli google-cloud-sdk hhvm \
  google-chrome-stable firefox powershell microsoft-edge-stable

sudo apt-get autoremove -y
sudo apt-get clean
```

---

## Environment Setup

### 1. Clone This Repository

Clone the OpenWrt build repository to your local machine:

```bash
cd ~
git clone https://github.com/TJT-JTJ/OpenWrt-NanoPi-R2S-R4S-Builds.git
cd OpenWrt-NanoPi-R2S-R4S-Builds
```

### 2. Set Environment Variables

Set up the build environment variables. Choose the OpenWrt branch you want to build:

```bash
# Set the OpenWrt branch (choose one)
export OPENWRT_BRANCH=24.10    # For latest OpenWrt 24.10.x
# OR
# export OPENWRT_BRANCH=23.05  # For OpenWrt 23.05.x

# Set the model (for R4S)
export NANOPI_MODEL=R4S

# Set build type (full includes LuCI UI, mini is headless)
export BUILD_MINI=false
export BUILD_FULL=true

# Set build date identifier
export BUILD_STRING=$(date +%Y.%m.%d)
export RELTAG=$(date +%Y%m%d)
```

---

## Build Process

Follow these steps in order to build the firmware. Each step corresponds to a script in the repository.

### Step 1: Clone OpenWrt Source

This step downloads the official OpenWrt source code:

```bash
./openwrt-$OPENWRT_BRANCH/steps/01_clone_openwrt.sh
```

**What it does:**
- Creates a `build` directory in the repository root
- Clones the official OpenWrt repository (branch-specific)
- For 24.10: Clones `openwrt-24.10` branch
- For 23.05: Clones `openwrt-23.05` branch

**Expected output:** A `build/openwrt-fresh-<version>` directory is created

### Step 2: Prepare OpenWrt Working Folder

This step creates a working copy of OpenWrt and locks it to a specific version:

```bash
./openwrt-$OPENWRT_BRANCH/steps/02_prepare_openwrt_folder.sh
```

**What it does:**
- Copies the fresh OpenWrt source to a working directory
- Resets to a specific frozen commit for reproducibility:
  - 24.10: Commit `dbd975a3b674c917d2f3b6663864084421944909` (24.10.2)
  - 23.05: Commit `28cf53e6bd9bb68958aae7958e7950d967f02b46` (23.05.5)

**Expected output:** A `build/openwrt` directory is created

### Step 3: Patch OpenWrt Source

This step applies custom patches specific to the NanoPi R4S:

```bash
./openwrt-$OPENWRT_BRANCH/steps/03_patch_openwrt.sh
```

**What it does:**
- Replaces u-boot package with custom version supporting R4S 1GB models
- Updates Rockchip target configuration
- Enables Motorcomm PHY for R2C
- Adds custom USB audio module support
- Applies various ImmortalWRT cherry-picked patches

**Expected output:** OpenWrt source is patched and ready for package preparation

### Step 4: Prepare Packages

This step adds custom packages and updates feeds:

```bash
./openwrt-$OPENWRT_BRANCH/steps/04-prepare_package.sh
```

**What it does:**
- Clones third-party package repositories:
  - stangri's PBR (Policy Based Routing) packages (v1.1.8)
  - kenzok8's packages (OpenClash, Argon theme, etc.)
- Updates OpenWrt feeds
- Replaces/adds custom packages:
  - PBR and luci-app-pbr
  - luci-app-openclash
  - luci-theme-argon and luci-app-argon-config
  - AdGuardHome with prebuilt latest version
- Installs all feeds
- Adds build date to banner and release info

**Expected output:** All feeds installed and custom packages added

### Step 5: Create LuCI ACL

This step generates access control lists for LuCI packages:

```bash
./openwrt-$OPENWRT_BRANCH/steps/05-create_luci_acl.sh
```

**What it does:**
- Runs the ACL creation script for LuCI applications
- Sets up proper permissions for web interface components

### Step 6: Configure Build (Full Build)

Load the configuration for the R4S full build:

```bash
./openwrt-$OPENWRT_BRANCH/steps/06-create_config_from_seed.sh $NANOPI_MODEL full
```

**What it does:**
- Loads the R4S full configuration from seed file
- Runs `make defconfig` to generate complete configuration

**Seed options:**
- `full`: Complete build with LuCI, Docker, and all applications
- `mini`: Minimal build without UI (headless)

### Step 7: Download Packages

Download all required source packages:

```bash
cd build/openwrt
make download -j$(nproc)
find dl -size -1024c -exec ls -l {} \;
find dl -size -1024c -exec rm -f {} \;
cd ../..
```

**What it does:**
- Downloads all package sources to `dl/` directory
- Uses parallel downloads (number of CPU cores)
- Removes failed/incomplete downloads (files smaller than 1KB)

### Step 8: Build Toolchain

Build the cross-compilation toolchain:

```bash
cd build/openwrt
make toolchain/install -j$(nproc) || make toolchain/install -j1 V=s
cd ../..
```

**What it does:**
- Compiles the cross-compilation toolchain for ARM64
- First tries parallel build, falls back to single-threaded verbose on error
- This step can take 30-60 minutes depending on your hardware

### Step 9: Build Kernel Modules (for Full Build)

Build all kernel modules and prepare package repository:

```bash
./openwrt-$OPENWRT_BRANCH/steps/07-all_kmods.sh
```

**What it does:**
- Enables building of all kernel modules
- Compiles toolchain if needed
- Compiles kernel and all kernel modules
- Creates package index and signing keys
- Prepares local package repository in firmware

**Note:** This step is important for ensuring all kernel modules are available after flashing

### Step 10: Final Configuration (Full Build)

Reload the full configuration (this is done again to ensure clean state):

```bash
./openwrt-$OPENWRT_BRANCH/steps/06-create_config_from_seed.sh $NANOPI_MODEL full
```

### Step 11: Compile OpenWrt Firmware

Compile the complete firmware:

```bash
cd build/openwrt
make -j$(nproc) || make -j$(nproc) || make -j1 V=s
cd ../..
```

**What it does:**
- Compiles all packages and creates firmware images
- Tries parallel build twice, then falls back to single-threaded verbose on error
- This step can take 1-3 hours depending on your hardware

**Expected output:** Firmware images in `build/openwrt/bin/targets/rockchip/armv8/`

### Step 12: Organize Output Files

Organize and rename the firmware files:

```bash
./openwrt-$OPENWRT_BRANCH/steps/organize_files.sh $NANOPI_MODEL full $OPENWRT_BRANCH $RELTAG
```

**What it does:**
- Creates `artifact/` directory
- Moves firmware images to artifact directory
- Renames files to standardized naming format:
  - `OpenWrt-AO-NanoPiR4S-full-<version>-<date>-ext4.img.gz`
  - `OpenWrt-AO-NanoPiR4S-full-<version>-<date>-squashfs.img.gz`
- Decompresses and recompresses with best compression

---

## Output Files

After a successful build, you will find the firmware images in the `artifact/` directory:

```
artifact/
├── OpenWrt-AO-NanoPiR4S-full-24.10-<date>-ext4.img.gz
└── OpenWrt-AO-NanoPiR4S-full-24.10-<date>-squashfs.img.gz
```

### File Types

- **squashfs** (recommended): Read-only root filesystem with overlay
  - Smaller size
  - Can reset to factory defaults
  - Recommended for most users

- **ext4**: Fully writable filesystem
  - Larger size
  - No factory reset capability
  - Useful for heavy customization

### Flashing the Firmware

To flash the firmware to your NanoPi R4S:

1. Decompress the `.img.gz` file:
   ```bash
   gunzip artifact/OpenWrt-AO-NanoPiR4S-full-24.10-<date>-squashfs.img.gz
   ```

2. Flash to microSD card or eMMC:
   ```bash
   # Replace /dev/sdX with your actual device (be very careful!)
   sudo dd if=artifact/OpenWrt-AO-NanoPiR4S-full-24.10-<date>-squashfs.img of=/dev/sdX bs=4M status=progress
   sudo sync
   ```

3. Insert the card into your NanoPi R4S and boot

**Default Network Settings:**
- LAN IP: 192.168.1.1
- Default username: root
- Default password: (none - set on first login)

---

## Troubleshooting

### Common Issues

#### Build Fails with "No space left on device"
- Ensure you have at least 50GB free space
- Clean previous builds: `rm -rf build/`
- Run the disk cleanup script mentioned earlier

#### Download failures
- Check your internet connection
- Some download mirrors may be slow or unavailable
- Re-run the download step: `cd build/openwrt && make download -j$(nproc)`

#### Toolchain compilation fails
- Try building with single thread for verbose output: `cd build/openwrt && make toolchain/install -j1 V=s`
- Check the error messages carefully
- Ensure all dependencies are installed

#### Package compilation fails
- Use verbose mode: `cd build/openwrt && make -j1 V=s`
- The error will show which package failed
- Check if you have all required dependencies

#### Out of memory during compilation
- Reduce parallel jobs: Use `-j2` or `-j4` instead of `-j$(nproc)`
- Add swap space if needed
- Upgrade RAM if building regularly

### Clean Build

To start over with a clean build:

```bash
# Remove only the working build directory (keeps downloads)
rm -rf build/openwrt

# Or remove everything (including downloaded sources)
rm -rf build/
```

### Build Time Estimates

On a typical modern system:
- **4-core CPU, 8GB RAM**: 2-4 hours total
- **8-core CPU, 16GB RAM**: 1-2 hours total
- **16-core CPU, 32GB RAM**: 30-60 minutes total

### Getting Help

- Check the [main README](README.md) for general information
- Review the [GitHub Actions workflow](.github/workflows/NanoPi-Build.yml) for the exact automated process
- Open an issue on the repository for build-specific problems

---

## Quick Build Script

For convenience, here's a complete script to build the full R4S firmware:

```bash
#!/bin/bash
set -e

# Configuration
export OPENWRT_BRANCH=24.10
export NANOPI_MODEL=R4S
export BUILD_STRING=$(date +%Y.%m.%d)
export RELTAG=$(date +%Y%m%d)

# Build steps
echo "Step 1: Clone OpenWrt source..."
./openwrt-$OPENWRT_BRANCH/steps/01_clone_openwrt.sh

echo "Step 2: Prepare OpenWrt folder..."
./openwrt-$OPENWRT_BRANCH/steps/02_prepare_openwrt_folder.sh

echo "Step 3: Patch OpenWrt..."
./openwrt-$OPENWRT_BRANCH/steps/03_patch_openwrt.sh

echo "Step 4: Prepare packages..."
./openwrt-$OPENWRT_BRANCH/steps/04-prepare_package.sh

echo "Step 5: Create LuCI ACL..."
./openwrt-$OPENWRT_BRANCH/steps/05-create_luci_acl.sh

echo "Step 6: Configure build (toolchain)..."
./openwrt-$OPENWRT_BRANCH/steps/06-create_config_from_seed.sh $NANOPI_MODEL full

echo "Step 7: Download packages..."
cd build/openwrt
make download -j$(nproc)
find dl -size -1024c -exec rm -f {} \;
cd ../..

echo "Step 8: Build toolchain..."
cd build/openwrt
make toolchain/install -j$(nproc) || make toolchain/install -j1 V=s
cd ../..

echo "Step 9: Build kernel modules..."
./openwrt-$OPENWRT_BRANCH/steps/07-all_kmods.sh

echo "Step 10: Reconfigure for full build..."
./openwrt-$OPENWRT_BRANCH/steps/06-create_config_from_seed.sh $NANOPI_MODEL full

echo "Step 11: Compile firmware..."
cd build/openwrt
make -j$(nproc) || make -j$(nproc) || make -j1 V=s
cd ../..

echo "Step 12: Organize output files..."
./openwrt-$OPENWRT_BRANCH/steps/organize_files.sh $NANOPI_MODEL full $OPENWRT_BRANCH $RELTAG

echo "Build complete! Firmware images are in the artifact/ directory."
```

Save this as `build_r4s_full.sh`, make it executable with `chmod +x build_r4s_full.sh`, and run it with `./build_r4s_full.sh`.

---

## Building for Other Models

### NanoPi R2S

To build for R2S instead of R4S, set:
```bash
export NANOPI_MODEL=R2S
```

The scripts will automatically adjust the configuration for R2S.

### NanoPi R2C

To build for R2C, set:
```bash
export NANOPI_MODEL=R2C
```

### Mini Build (Headless)

To build the minimal version without LuCI UI:
```bash
export BUILD_MINI=true
export BUILD_FULL=false
```

And use `mini` instead of `full` in step 6 and step 10:
```bash
./openwrt-$OPENWRT_BRANCH/steps/06-create_config_from_seed.sh $NANOPI_MODEL mini
```

---

## Additional Information

### What's Included in the Full Build

The full build includes:
- **LuCI Web Interface**: Complete web-based management
- **Docker Support**: Container runtime for running applications
- **Policy Based Routing (PBR)**: Advanced routing capabilities
- **OpenClash**: Clash proxy client
- **AdGuard Home**: Network-wide ad blocking
- **Argon Theme**: Modern LuCI theme
- **Various utilities**: See the seed files for complete package list

### Custom Modifications

To customize the build:

1. After step 6, you can modify the configuration:
   ```bash
   cd build/openwrt
   make menuconfig
   ```

2. Make your changes in the menuconfig interface

3. Continue with the remaining build steps

### Source Code Locations

- OpenWrt official: `build/openwrt-fresh-<version>/`
- Working copy: `build/openwrt/`
- Downloaded packages: `build/openwrt/dl/`
- Build output: `build/openwrt/bin/`

---

**Note**: This build process creates the exact same firmware as the automated GitHub Actions builds. If you encounter any issues, ensure you're following the steps exactly as described and have all prerequisites installed.
