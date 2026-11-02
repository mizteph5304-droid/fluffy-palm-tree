# Xcode setup checklist

1. **New project**
   - File → New → Project → iOS → App
   - Product Name: `Pulse`
   - Team: your team
   - Organization Identifier: e.g. `com.yourname`
   - Interface: SwiftUI
   - Language: Swift
   - Storage: None (we use our own JSON)

2. **Replace default sources**
   - Delete the generated `PulseApp.swift` and `ContentView.swift`
   - Drag the `Pulse/` folder from this repo into the Xcode project navigator
   - Check “Copy items if needed” and “Add to targets: Pulse”

3. **Background audio**
   - Select the Pulse target → Signing & Capabilities → + Capability → **Background Modes**
   - Enable **Audio, AirPlay, and Picture in Picture**

4. **Deployment**
   - Minimum: iOS 17.0 (recommended)
   - Device orientation: Portrait (or all if you want)

5. **Info keys** (Target → Info)
   - Add `UIBackgroundModes` = `audio` if not already present from the capability
   - Optional: `NSAppleMusicUsageDescription` = “Pulse plays music you import from the Files app.”

6. **App icon**
   - Replace Assets.xcassets/AppIcon with your own (desktop assets/icon.png can be a starting point)

7. **Build & run on a real iPhone**
   - Simulator works for UI, but lock-screen controls and reliable background audio need a device

---

## First-run tips

- Tap **+** in Library → pick audio files from Files / iCloud / On My iPhone
- Files are **copied** into the app sandbox so they stay available
- Play a track → mini player appears → tap it for full Now Playing + lyrics
- Lyrics are fetched automatically from LRCLIB when not embedded
- Create playlists, then long-press a track → Add to Playlist
