# Release 0.0.1a - Remote Access Alpha

## 🎉 First Alpha Release with Remote Access Support

This is an **alpha testing release** of Ensemble with the new **Remote Access ID** feature, allowing you to connect to your Music Assistant server from anywhere without port forwarding or VPN.

### ⚠️ Alpha Status

This is a development build for testing purposes. The Remote Access feature is functional but has not been extensively tested. Please report any issues you encounter.

### ✨ What's New

#### Remote Access ID Feature
- **WebRTC Connectivity**: Connect via Music Assistant's signaling server
- **QR Code Scanner**: Scan QR code from Music Assistant for instant setup
- **Manual Entry**: Enter Remote ID manually as fallback
- **No Port Forwarding**: Works through NAT without network configuration
- **Secure**: End-to-end encrypted connection via WebRTC

### 📦 How to Use Remote Access

1. **In Music Assistant**: Go to Settings → Remote Access → Generate QR Code
2. **In Ensemble**: Tap "Connect via Remote Access" on the login screen
3. **Scan or Enter**: Use your camera to scan the QR code, or enter the ID manually
4. **Connect**: WebRTC connection establishes in 2-5 seconds
5. **Authenticate**: Use your normal Music Assistant credentials
6. **Enjoy**: All features work the same as local connection

### 🔧 Building from Source

If you need to build the APK yourself:

```bash
# Clone the repository
git clone https://github.com/R00S/Ensemble---remote-access-testing.git
cd Ensemble---remote-access-testing

# Checkout the release tag
git checkout 0.0.1a

# Install dependencies
flutter pub get

# Build the APK (release mode)
flutter build apk --release

# The APK will be at: build/app/outputs/flutter-apk/app-release.apk
```

### 📋 Requirements

- Android 5.0 (API 21) or higher
- Music Assistant server with Remote Access enabled
- Camera permission (for QR code scanning)
- Internet connection

### 🐛 Known Issues

- Remote Access feature requires testing with real-world servers
- Performance profiling not yet complete
- Limited error message localization

### 📚 Documentation

- [Remote Access User Guide](https://github.com/R00S/Ensemble---remote-access-testing/blob/copilot/add-remote-access-id-login/docs/REMOTE_ACCESS.md)
- [Integration Guide](https://github.com/R00S/Ensemble---remote-access-testing/blob/copilot/add-remote-access-id-login/docs/REMOTE_ACCESS_INTEGRATION.md)
- [License Attribution](https://github.com/R00S/Ensemble---remote-access-testing/blob/copilot/add-remote-access-id-login/docs/LICENSE_ATTRIBUTION.md)

### 🔐 License & Attribution

This build includes code adapted from [music-assistant/desktop-companion](https://github.com/music-assistant/desktop-companion) (Apache License 2.0), properly attributed in compliance with both licenses.

- Ensemble: MIT License
- desktop-companion (adapted code): Apache License 2.0
- See [LICENSE_ATTRIBUTION.md](https://github.com/R00S/Ensemble---remote-access-testing/blob/copilot/add-remote-access-id-login/docs/LICENSE_ATTRIBUTION.md) for details

### 🤝 Contributing

This is a feature branch for testing Remote Access. Feedback and bug reports are welcome! Please open an issue if you encounter any problems.

### ⬇️ Download

**APK File**: `app-release.apk` (attached to this release)

To build the APK and attach it to this release:
1. Follow the build instructions above
2. Upload the APK file from `build/app/outputs/flutter-apk/app-release.apk` to this GitHub release

---

**Full Changelog**: https://github.com/R00S/Ensemble---remote-access-testing/compare/7f871f0...0.0.1a
