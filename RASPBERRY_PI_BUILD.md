# Building for Raspberry Pi 5 - Quick Guide

This document provides a quick reference for building and running the we_plan2 app on Raspberry Pi 5.

## What Was Changed

The app has been configured to support Linux desktop, specifically for Raspberry Pi 5:

1. **Linux Platform Support**: Added `lib/platform/platform_linux.dart` for Linux-specific device identification
2. **Platform Detection**: Updated `lib/platform/platform.dart` to detect and use Linux platform
3. **Mobile-Only Features**: Made mobile-only features conditional:
   - Home widgets (Android/iOS only)
   - QR code scanner (hidden on Linux, manual code entry available)
   - Android-specific permissions (not required on Linux)
4. **Linux Build Configuration**: Enabled Flutter Linux desktop support

## Quick Start on Raspberry Pi 5

### Step 1: Install Flutter on Raspberry Pi

```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install dependencies
sudo apt-get install -y \
    clang \
    cmake \
    curl \
    file \
    git \
    libglu1-mesa-dev \
    libgtk-3-dev \
    libx11-dev \
    libxrandr-dev \
    libxi-dev \
    libxcursor-dev \
    libxinerama-dev \
    pkg-config \
    unzip \
    xz-utils \
    zip

# Install Flutter
cd ~
git clone https://github.com/flutter/flutter.git -b stable
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
source ~/.bashrc

# Enable Linux desktop
flutter config --enable-linux-desktop

# Verify installation
flutter doctor
```

### Step 2: Build the App

```bash
# Clone or transfer the project to Raspberry Pi
cd ~
git clone <your-repo-url> we_plan2
cd we_plan2

# Install dependencies
flutter pub get

# Build for release (ARM64)
flutter build linux --release --target-platform linux-arm64
```

### Step 3: Run the App

**Development mode:**
```bash
flutter run -d linux
```

**Release mode:**
```bash
# The built app is in build/linux/arm64/release/bundle/
cd build/linux/arm64/release/bundle
./we_plan2
```

## Architecture Notes

Raspberry Pi 5 uses **ARM64** architecture. Make sure to:
- Build on the Raspberry Pi itself (recommended), or
- Use proper cross-compilation tools if building from another machine

## Limitations on Linux

The following mobile-specific features are **not available** on Linux:

1. **Home Widgets**: Calendar widgets for home screen (Android/iOS only)
2. **QR Code Scanner**: Cannot scan QR codes (but you can manually enter share codes)
3. **Mobile Permissions**: No runtime permission requests (not needed on Linux)

All core calendar functionality works:
- ✅ View calendar and events
- ✅ Create, edit, delete events
- ✅ Share calendars with share codes
- ✅ Join calendars with share codes (manual entry)
- ✅ Offline caching
- ✅ Multi-device synchronization via Firebase

## Troubleshooting

### Build Fails with Architecture Error
```bash
# Make sure you're building for ARM64
flutter build linux --release --target-platform linux-arm64
```

### Missing Dependencies
```bash
# Install all required system packages
sudo apt-get install -y \
    libglu1-mesa-dev \
    libgtk-3-dev \
    libx11-dev \
    libxrandr-dev \
    libxi-dev \
    libxcursor-dev \
    libxinerama-dev
```

### Flutter Doctor Shows Issues
```bash
# Run flutter doctor and install any missing components
flutter doctor
flutter doctor --android-licenses  # If Android SDK is installed
```

### App Doesn't Start
```bash
# Check if all dependencies are installed
ldd build/linux/arm64/release/bundle/lib/libflutter_linux_gtk.so
```

## Building on Windows for Raspberry Pi

If you want to build on Windows and transfer to Raspberry Pi, see **[BUILD_FROM_WINDOWS.md](BUILD_FROM_WINDOWS.md)** for detailed instructions.

**Quick options:**
- ✅ **Easiest**: Transfer source code to Pi and build there
- ✅ **WSL2**: Build Linux ARM64 binary in Windows Subsystem for Linux
- ✅ **Git**: Sync code via Git, build on Pi

**Better approach**: Build directly on the Raspberry Pi for the most reliable results.

## Next Steps

1. Test the app on Raspberry Pi 5
2. Create a desktop launcher icon (optional)
3. Set up auto-start on boot (optional)
4. Configure display settings for your use case

