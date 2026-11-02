# Pulse — iOS (Native SwiftUI)

Native **SwiftUI** iPhone port of the Pulse local media player.

**First build focus**
- Local music import + persistent library
- Playback, queue, and playlists
- Album artwork + track metadata
- Lyrics lookup (LRCLIB) + synced line display
- Background audio + lock-screen / Control Center controls
- **No** karaoke / vocal separation
- **No** video (music only for this build)

UI: dark theme, Spotify-style green accent (`#1DB954`), bottom player bar → full Now Playing with lyrics.

---

## You are on Windows?

You **cannot** build an IPA on Windows directly. Use a cloud Mac instead:

→ **[CI-SETUP.md](CI-SETUP.md)** — step-by-step for **Codemagic** (easiest) or **GitHub Actions**

That guide covers Apple Developer account, certificates, and downloading the finished `.ipa`.

---

## Project layout

```
Pulse-iOS/
├── project.yml                 # XcodeGen definition (CI generates the .xcodeproj)
├── codemagic.yaml              # Codemagic cloud build
├── .github/workflows/build-ipa.yml
├── ci/                         # ExportOptions plists
├── CI-SETUP.md                 # Cloud build instructions
├── XCODE-SETUP.md              # Local Mac / Xcode instructions
└── Pulse/
    ├── PulseApp.swift
    ├── Info.plist
    ├── Pulse.entitlements
    ├── Models/
    ├── Services/
    ├── Views/
    ├── Utilities/
    └── Assets.xcassets/
```

---

## Architecture

| Piece | Role |
|-------|------|
| `LibraryStore` | Import, library, playlists, JSON persistence |
| `AudioPlayerService` | AVPlayer, queue, Now Playing, remote commands |
| `MetadataService` | Title / artist / album / artwork via AVAsset |
| `LyricsService` | LRCLIB + LRC parser + synced highlighting |

Imported files are **copied** into the app sandbox so they stay available.

---

## Requirements (when building)

- iOS 17+ deployment target
- Background Modes → Audio
- Signing: Automatic (local) or profiles supplied to CI

---

## License

MIT
