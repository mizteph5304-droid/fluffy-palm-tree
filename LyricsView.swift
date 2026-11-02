import SwiftUI

struct LyricsView: View {
    @EnvironmentObject private var player: AudioPlayerService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Lyrics")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.pulseSecondary)
                Spacer()
                statusBadge
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            Group {
                switch player.lyricsStatus {
                case .idle:
                    placeholder("Lyrics will appear here")
                case .loading:
                    HStack {
                        ProgressView()
                            .tint(Color.pulseAccent)
                        Text("Looking up lyrics…")
                            .foregroundStyle(Color.pulseSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .instrumental:
                    placeholder("Instrumental")
                case .notFound:
                    placeholder("No lyrics found")
                case .offline:
                    placeholder("Offline — couldn’t reach lyrics server")
                case .found:
                    if player.lyricLines.isEmpty {
                        placeholder("No lyrics")
                    } else {
                        lyricsScroll
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch player.lyricsStatus {
        case .found(let synced):
            Text(synced ? "Synced" : "Text")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.pulseAccent.opacity(0.2))
                .foregroundStyle(Color.pulseAccent)
                .clipShape(Capsule())
        default:
            EmptyView()
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Color.pulseSecondary.opacity(0.7))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var lyricsScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(player.lyricLines.enumerated()), id: \.element.id) { index, line in
                        Text(line.text)
                            .font(.title3.weight(index == player.activeLyricIndex ? .bold : .regular))
                            .foregroundStyle(index == player.activeLyricIndex ? Color.white : Color.pulseSecondary.opacity(0.55))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(index)
                            .animation(.easeInOut(duration: 0.2), value: player.activeLyricIndex)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .padding(.bottom, 40)
            }
            .onChange(of: player.activeLyricIndex) { _, newIndex in
                guard newIndex >= 0 else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
}
