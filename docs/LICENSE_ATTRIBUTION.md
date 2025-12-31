# License and Attribution

## Ensemble License

Ensemble is licensed under the MIT License.

## Remote Access Implementation

The Remote Access feature in this repository includes code adapted from the [Music Assistant Desktop Companion](https://github.com/music-assistant/desktop-companion) project, which is licensed under the Apache License 2.0.

### Original Source

- **Project**: music-assistant/desktop-companion
- **License**: Apache License 2.0
- **Files Adapted**:
  - `src/plugins/remote/signaling.ts` → `lib/services/remote/signaling.dart`
  - `src/plugins/remote/webrtc-transport.ts` → `lib/services/remote/webrtc_transport.dart`
  - `src/plugins/remote/websocket-transport.ts` → `lib/services/remote/websocket_bridge_transport.dart`
  - `src/plugins/remote/connection-manager.ts` → `lib/services/remote/remote_access_manager.dart`

### License Compatibility

The Apache License 2.0 is compatible with the MIT License. Code adapted from Apache 2.0 licensed projects can be included in MIT licensed projects, with proper attribution.

### Attribution

Portions of the Remote Access implementation are:
```
Copyright 2024 Music Assistant
Licensed under the Apache License, Version 2.0

Adapted for Flutter/Dart by Ensemble contributors
```

### Changes Made

The TypeScript implementation from desktop-companion has been adapted to Dart/Flutter with the following platform-specific changes:

1. **Language**: TypeScript → Dart
2. **WebRTC Library**: Browser WebRTC API → flutter_webrtc package
3. **WebSocket**: Browser WebSocket API → web_socket_channel package
4. **Storage**: localStorage → SharedPreferences
5. **UI**: Vue.js → Flutter widgets
6. **Platform**: Desktop (Electron) → Mobile (Android/iOS)

The core protocol, message formats, and connection logic remain identical to ensure compatibility with the Music Assistant signaling server.

### Full License Texts

#### Apache License 2.0 (Original Code)

The full Apache License 2.0 text is available at:
https://www.apache.org/licenses/LICENSE-2.0

Key points:
- Permits use, reproduction, and distribution
- Requires preservation of copyright notices
- Provides patent grant
- Requires stating significant changes

#### MIT License (Ensemble)

The full MIT License text is available in the repository root.

Key points:
- Very permissive
- Allows commercial use
- Requires copyright notice
- No warranty

## Third-Party Dependencies

The Remote Access feature also depends on:

- **flutter_webrtc** (MIT License)
- **mobile_scanner** (BSD-3-Clause License)
- **web_socket_channel** (BSD-3-Clause License)

All dependencies are compatible with the MIT License.

## Contributing

When contributing to the Remote Access feature:

1. Maintain attribution to the original desktop-companion project
2. Significant changes from the original implementation should be documented
3. New code should follow the Ensemble MIT License
4. Keep protocol compatibility with desktop-companion for interoperability

## Questions

For licensing questions, please refer to:
- [Apache License 2.0 FAQ](https://www.apache.org/foundation/license-faq.html)
- [MIT License](https://opensource.org/licenses/MIT)
