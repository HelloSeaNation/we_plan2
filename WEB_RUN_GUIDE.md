# Running the App on Web

Your app is already configured for web! Here's how to run it.

## Quick Start

### Development Mode (Hot Reload)

**Option 1: Run in Chrome (Recommended)**
```bash
flutter run -d chrome
```

**Option 2: Run in Edge**
```bash
flutter run -d edge
```

**Option 3: Run in any browser**
```bash
flutter run -d web-server --web-port 8080
```
Then open `http://localhost:8080` in any browser.

### Production Build

**Build for web:**
```bash
flutter build web --release
```

The built files will be in `build/web/` directory.

**To serve the built app locally:**
```bash
# Using Python (if installed)
cd build/web
python -m http.server 8000

# Or using Node.js http-server
npx http-server build/web -p 8000

# Or using any static file server
```

Then open `http://localhost:8000` in your browser.

## Deploying to Web

### Option 1: Firebase Hosting (Recommended)

Since you're already using Firebase:

```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase Hosting (if not already done)
firebase init hosting

# Build the app
flutter build web --release

# Deploy
firebase deploy --only hosting
```

### Option 2: GitHub Pages

1. Build the app:
   ```bash
   flutter build web --release --base-href "/your-repo-name/"
   ```

2. Copy `build/web/*` to your GitHub Pages branch

3. Push to GitHub

### Option 3: Netlify / Vercel

1. Build the app:
   ```bash
   flutter build web --release
   ```

2. Deploy the `build/web` folder to Netlify or Vercel

### Option 4: Any Static Hosting

Just upload the contents of `build/web/` to any static hosting service:
- AWS S3 + CloudFront
- Google Cloud Storage
- Azure Static Web Apps
- Your own web server

## Web-Specific Features

✅ **What works on web:**
- Full calendar functionality
- Create, edit, delete events
- Share calendars with share codes
- Join calendars (manual code entry)
- Offline caching (using browser storage)
- Firebase Firestore sync
- Responsive design for desktop/tablet/mobile browsers

❌ **What doesn't work on web:**
- Home widgets (mobile-only feature)
- QR code scanner (mobile-only, but you can manually enter codes)
- Native device permissions (not needed on web)

## Troubleshooting

### App doesn't load
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build web --release
```

### Firebase errors on web
- Make sure `firebase_options.dart` has valid web configuration
- Check Firebase console that web app is enabled
- Verify API keys are correct

### CORS errors
- If accessing Firestore from a custom domain, configure CORS in Firebase
- Make sure your Firebase project allows your domain

### Performance issues
- Use release build for production: `flutter build web --release`
- Enable tree-shaking and minification (enabled by default in release builds)

## Browser Compatibility

The app works on:
- ✅ Chrome/Edge (Chromium) - Recommended
- ✅ Firefox
- ✅ Safari
- ✅ Opera

**Minimum requirements:**
- Modern browser with ES6 support
- JavaScript enabled
- Local storage enabled (for offline caching)

## Development Tips

### Hot Reload
When running `flutter run -d chrome`, you can:
- Press `r` in terminal to hot reload
- Press `R` to hot restart
- Press `q` to quit

### Debugging
- Open Chrome DevTools (F12) for debugging
- Use Flutter DevTools for advanced debugging
- Check browser console for errors

### Testing Different Screen Sizes
Use Chrome DevTools device emulation to test:
- Mobile (320px - 768px)
- Tablet (768px - 1024px)
- Desktop (1024px+)

## Configuration

### Change Web Port
```bash
flutter run -d web-server --web-port 3000
```

### Build with Custom Base Href
```bash
flutter build web --release --base-href "/app/"
```

### Build for Specific Browser
```bash
# Chrome
flutter run -d chrome

# Edge
flutter run -d edge

# Firefox (if available)
flutter run -d web-server
```

## Next Steps

1. **Test locally**: `flutter run -d chrome`
2. **Build for production**: `flutter build web --release`
3. **Deploy**: Choose your hosting platform and deploy
4. **Share**: Share your web app URL with users!




