import SwiftUI

struct PlayerBarView: View {
    @EnvironmentObject private var player: AudioPlayerService
    @Binding var showNowPlaying: Bool

    var body: some View {
        if let track = player.currentTrack {
            HStack(spacing: 12) {
                Button {
                    showNowPlaying = true
                } label: {
                    HStack(spacing: 12) {
                        ArtworkView(data: track.artworkData, size: 44, cornerRadius: 6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.displayTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.caption)
                                .foregroundStyle(Color.pulseSecondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                }

                Button {
                    player.playNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 36)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                // Thin progress line at top of bar
                GeometryReader { geo in
                    let progress = player.duration > 0 ? player.currentTime / player.duration : 0
                    Rectangle()
                        .fill(Color.pulseAccent)
                        .frame(width: geo.size.width * progress, height: 2)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                showNowPlaying = true
            }
        }
    }
}
