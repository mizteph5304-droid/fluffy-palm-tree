import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var player: AudioPlayerService
    @Environment(\.dismiss) private var dismiss

    @State private var dragOffset: CGFloat = 0
    @State private var isScrubbing = false
    @State private var scrubTime: TimeInterval = 0

    var body: some View {
        ZStack {
            Color.pulseBackground.ignoresSafeArea()

            if let track = player.currentTrack {
                VStack(spacing: 0) {
                    // Grabber / close
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, 8)

                    // Artwork
                    ArtworkView(data: track.artworkData, size: 280, cornerRadius: 16)
                        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                        .padding(.top, 12)
                        .padding(.bottom, 28)

                    // Title / artist
                    VStack(spacing: 6) {
                        Text(track.displayTitle)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(track.artist)
                            .font(.title3)
                            .foregroundStyle(Color.pulseSecondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 24)

                    // Progress
                    VStack(spacing: 6) {
                        Slider(
                            value: Binding(
                                get: { isScrubbing ? scrubTime : player.currentTime },
                                set: { scrubTime = $0 }
                            ),
                            in: 0...max(player.duration, 1),
                            onEditingChanged: { editing in
                                isScrubbing = editing
                                player.isSeeking = editing
                                if !editing {
                                    player.seek(to: scrubTime)
                                }
                            }
                        )
                        .tint(Color.pulseAccent)

                        HStack {
                            Text(Formatters.time(isScrubbing ? scrubTime : player.currentTime))
                            Spacer()
                            Text(Formatters.time(player.duration))
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.pulseSecondary)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 20)

                    // Transport
                    HStack(spacing: 48) {
                        Button { player.playPrevious() } label: {
                            Image(systemName: "backward.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                        Button { player.togglePlayPause() } label: {
                            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(.white)
                        }
                        Button { player.playNext() } label: {
                            Image(systemName: "forward.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    // Lyrics section
                    LyricsView()
                        .frame(maxHeight: .infinity)
                }
            } else {
                VStack {
                    Text("Nothing playing")
                        .foregroundStyle(Color.pulseSecondary)
                    Button("Close") { dismiss() }
                        .padding(.top)
                }
            }
        }
    }
}
