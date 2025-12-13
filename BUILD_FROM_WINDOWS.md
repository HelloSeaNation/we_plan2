# Building from Windows and Transferring to Raspberry Pi 5

Yes, you can build on Windows and send it to Raspberry Pi 5! Here are your options:

## ⚠️ Important: Architecture Difference

- **Your Windows PC**: x64/x86 architecture
- **Raspberry Pi 5**: ARM64 architecture

You **cannot** build a Windows executable and run it on Raspberry Pi. However, there are several ways to work around this:

---

## Option 1: Build in WSL2 (Recommended for Windows) ✅

**Windows Subsystem for Linux 2** allows you to build Linux ARM64 binaries on Windows.

### Step 1: Install WSL2

```powershell
# Open PowerShell as Administrator
wsl --install
# Restart your computer when prompted
```

### Step 2: Install Flutter in WSL2

After WSL2 is installed, open Ubuntu (or your Linux distribution) from Start Menu:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies for ARM64 cross-compilation
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
    zip \
    qemu-user-static \
    binfmt-support

# Install Flutter
cd ~
git clone https://github.com/flutter/flutter.git -b stable
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
source ~/.bashrc

# Enable Linux desktop
flutter config --enable-linux-desktop
flutter doctor
```

### Step 3: Access Your Project in WSL2

Your Windows files are accessible in WSL2 at `/mnt/c/`:

```bash
# Navigate to your project (adjust path as needed)
cd /mnt/c/Users/YourUsername/path/to/we_plan2

# Or if it's on G: drive
cd /mnt/g/Flutter\ project/we_plan2

# Install dependencies
flutter pub get
```

### Step 4: Build for ARM64

```bash
# Build for Raspberry Pi 5 (ARM64)
flutter build linux --release --target-platform linux-arm64
```

The built app will be in: `build/linux/arm64/release/bundle/`

### Step 5: Transfer to Raspberry Pi

**Option A: Using SCP (if Raspberry Pi is on your network):**

```bash
# From WSL2
scp -r build/linux/arm64/release/bundle pi@raspberry-pi-ip:/home/pi/we_plan2/
```

**Option B: Copy to Windows and transfer manually:**

```bash
# Copy from WSL2 to Windows (for easy access)
cp -r build/linux/arm64/release/bundle /mnt/c/Users/YourUsername/Desktop/we_plan2-arm64
```

Then transfer the folder to Raspberry Pi using:
- USB drive
- Network share
- SCP/WinSCP from Windows
- Any file transfer method you prefer

---

## Option 2: Transfer Source Code and Build on Pi (Easiest) ✅

This is the **simplest and most reliable** method:

### Step 1: Prepare Project on Windows

```powershell
# In your project directory
cd "G:\Flutter project\we_plan2"

# Clean build artifacts (optional, but recommended)
flutter clean

# Create a compressed archive
# Using PowerShell
Compress-Archive -Path . -DestinationPath we_plan2.zip -Force
```

### Step 2: Transfer to Raspberry Pi

Transfer `we_plan2.zip` to your Raspberry Pi using:
- USB drive
- Network share (Samba/FTP)
- SCP: `scp we_plan2.zip pi@raspberry-pi-ip:/home/pi/`
- Email/Cloud storage
- Git (if your project is in a repository)

### Step 3: Build on Raspberry Pi

On your Raspberry Pi:

```bash
# Extract the project
unzip we_plan2.zip -d ~/we_plan2
cd ~/we_plan2

# Install dependencies
flutter pub get

# Build (this will build for ARM64 automatically)
flutter build linux --release
```

The built app will be in: `build/linux/arm64/release/bundle/`

---

## Option 3: Use Git (Best for Development) ✅

If your project is in Git:

### On Windows:
```powershell
# Make sure all changes are committed
git add .
git commit -m "Prepare for Raspberry Pi build"
git push
```

### On Raspberry Pi:
```bash
# Clone the repository
git clone <your-repo-url> we_plan2
cd we_plan2

# Install dependencies and build
flutter pub get
flutter build linux --release
```

---

## Option 4: Remote Build via SSH (Advanced)

You can also build directly on the Raspberry Pi from Windows using SSH:

```powershell
# Install OpenSSH Client on Windows (usually pre-installed)
# Then connect and build remotely
ssh pi@raspberry-pi-ip "cd ~/we_plan2 && flutter build linux --release"
```

---

## Running the Built App on Raspberry Pi

After transferring the built app:

```bash
# Make sure it's executable
chmod +x we_plan2

# Run it
./we_plan2

# Or create a desktop launcher
# Create ~/.local/share/applications/we_plan2.desktop
```

Create a desktop launcher file `~/.local/share/applications/we_plan2.desktop`:

```ini
[Desktop Entry]
Version=1.0
Type=Application
Name=WePlan
Comment=Shared Calendar Application
Exec=/home/pi/we_plan2/we_plan2
Icon=/home/pi/we_plan2/data/icon.png
Terminal=false
Categories=Office;Calendar;
```

---

## Quick Comparison

| Method | Difficulty | Speed | Reliability | Recommended |
|--------|-----------|-------|-------------|-------------|
| **WSL2 Build** | Medium | Fast | Good | ✅ If you have WSL2 |
| **Transfer & Build on Pi** | Easy | Medium | Excellent | ✅ **Best option** |
| **Git Sync** | Easy | Medium | Excellent | ✅ For ongoing development |
| **Remote SSH Build** | Medium | Medium | Good | For advanced users |

---

## Troubleshooting

### WSL2 Build Issues

If cross-compilation fails in WSL2:
```bash
# Make sure QEMU is installed for ARM64 emulation
sudo apt-get install qemu-user-static binfmt-support
sudo systemctl restart systemd-binfmt
```

### Missing Dependencies on Pi

After transferring, if the app doesn't run:
```bash
# Install required libraries on Raspberry Pi
sudo apt-get install -y \
    libgtk-3-0 \
    libx11-6 \
    libxrandr2 \
    libxi6 \
    libxcursor1 \
    libxinerama1
```

### Check Architecture

Verify the build architecture:
```bash
# Check binary architecture
file we_plan2
# Should show: ELF 64-bit LSB executable, ARM aarch64
```

---

## My Recommendation

**For a one-time build**: Use **Option 2** (transfer source and build on Pi) - it's the most reliable.

**For ongoing development**: Use **Option 3** (Git) - sync code easily, build on Pi.

**If you're comfortable with WSL2**: Use **Option 1** - build once, transfer executable.


