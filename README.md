# we_plan2

weplan version 2 - A shared calendar application built with Flutter and Firebase.

## Getting Started

### Prerequisites

Before running this app, make sure you have:

1. **Flutter SDK** installed (version 3.8.1 or higher)
   - Download from: https://docs.flutter.dev/get-started/install
   - Verify installation: `flutter doctor`

2. **Firebase Project** configured
   - The app uses Firebase Firestore for data storage
   - Firebase configuration files are already included in the project

3. **Development Environment**:
   - For Android: Android Studio with Android SDK
   - For iOS: Xcode (macOS only)
   - For Web: Chrome or any modern browser
   - For Linux/Raspberry Pi: Flutter Linux desktop support enabled

### Installation Steps

1. **Clone or navigate to the project directory**
   ```bash
   cd "G:\Flutter project\we_plan2"
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Verify Flutter setup**
   ```bash
   flutter doctor
   ```
   Make sure all necessary components are installed and configured.

### Running the App

#### On Android Device/Emulator

1. **Check available devices**
   ```bash
   flutter devices
   ```

2. **Run the app**
   ```bash
   flutter run
   ```
   Or specify a device:
   ```bash
   flutter run -d <device-id>
   ```

#### On iOS Simulator/Device (macOS only)

1. **Open iOS Simulator** or connect an iOS device

2. **Run the app**
   ```bash
   flutter run
   ```

#### On Web Browser

1. **Run in Chrome** (recommended)
   ```bash
   flutter run -d chrome
   ```

2. **Or run in any web browser**
   ```bash
   flutter run -d web-server --web-port 8080
   ```

#### On Linux Desktop / Raspberry Pi 5

**Prerequisites for Raspberry Pi 5:**

1. **Install Flutter on Raspberry Pi OS**
   ```bash
   # Install dependencies
   sudo apt-get update
   sudo apt-get install -y \
       clang \
       cmake \
       curl \
       file \
       git \
       libgtk-3-dev \
       pkg-config \
       unzip \
       xz-utils \
       zip

   # Download and install Flutter SDK
   cd ~
   git clone https://github.com/flutter/flutter.git -b stable
   export PATH="$PATH:`pwd`/flutter/bin"
   flutter doctor
   ```

2. **Enable Linux desktop support** (if not already enabled)
   ```bash
   flutter config --enable-linux-desktop
   ```

3. **Install required system dependencies**
   ```bash
   # For Raspberry Pi OS / Debian-based systems
   sudo apt-get install -y \
       libglu1-mesa-dev \
       libx11-dev \
       libxrandr-dev \
       libxi-dev \
       libxcursor-dev \
       libxinerama-dev
   ```

4. **Run the app**
   ```bash
   # Navigate to project directory
   cd /path/to/we_plan2
   
   # Get dependencies
   flutter pub get
   
   # Run the app
   flutter run -d linux
   ```

**Note:** The app has been configured to work on Linux, but some mobile-specific features will be disabled:
- Home widget functionality (mobile-only)
- QR code scanner (mobile-only, can manually enter share codes)
- Some Android-specific permissions

### Building for Release

#### Android APK
```bash
flutter build apk --release
```

#### Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
```

#### iOS (macOS only)
```bash
flutter build ios --release
```

#### Web
```bash
flutter build web --release
```

**Deploying to GitHub Pages:**
See **[GITHUB_PAGES_DEPLOY.md](GITHUB_PAGES_DEPLOY.md)** for detailed instructions on deploying to GitHub Pages.

Quick steps:
1. Build with correct base-href: `flutter build web --release --base-href "/your-repo-name/"`
2. Use the provided GitHub Actions workflow (automatic) or deploy manually
3. Enable GitHub Pages in repository settings

#### Linux Desktop / Raspberry Pi 5
```bash
flutter build linux --release
```

The built application will be in `build/linux/x64/release/bundle/` (or `arm64` for ARM-based systems like Raspberry Pi 5).

**For Raspberry Pi 5 (ARM64):**

Raspberry Pi 5 uses ARM64 architecture. To build specifically for ARM64:

```bash
# Build for ARM64 architecture
flutter build linux --release --target-platform linux-arm64
```

**Note:** If you encounter architecture issues, you may need to:
1. Build on the Raspberry Pi itself (recommended)
2. Or use cross-compilation tools

### Important Notes

- **Firebase Setup**: The app requires Firebase to be properly configured. Make sure your `firebase_options.dart` file has valid Firebase project credentials.

- **Permissions**: The app may request device permissions on Android (e.g., phone permission for device identification). On Linux, no runtime permissions are required.

- **Internet Connection**: The app requires internet connectivity to sync events with Firestore, but it can work offline with local caching.

- **Platform-Specific Features**:
  - **Mobile (Android/iOS)**: Full feature set including home widgets and QR code scanning
  - **Linux Desktop**: Core calendar functionality works, but home widgets and QR scanning are disabled
  - **Web**: Core functionality available through browser

### Troubleshooting

1. **If dependencies fail to install**:
   ```bash
   flutter clean
   flutter pub get
   ```

2. **If Firebase errors occur**:
   - Verify your Firebase project is active
   - Check that `google-services.json` (Android) is properly configured
   - Ensure Firestore is enabled in your Firebase console

3. **If build fails**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

### Project Structure

- `lib/main.dart` - Main application entry point
- `lib/firestore_service.dart` - Firebase Firestore service
- `lib/services/` - Additional services (widget, calendar)
- `lib/screens/` - Application screens
- `lib/widgets/` - Reusable widgets

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
