import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: AudioPlayerService
    @State private var selectedTab = 0
    @State private var showNowPlaying = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "music.note.house.fill")
                    }
                    .tag(0)

                PlaylistsView()
                    .tabItem {
                        Label("Playlists", systemImage: "music.note.list")
                    }
                    .tag(1)

                QueueView()
                    .tabItem {
                        Label("Queue", systemImage: "list.bullet")
                    }
                    .tag(2)
            }
            .tint(Color.pulseAccent)

            // Mini player bar
            if player.currentTrack != nil {
                VStack(spacing: 0) {
                    Divider().overlay(Color.white.opacity(0.08))
                    PlayerBarView(showNowPlaying: $showNowPlaying)
                }
                .background(.ultraThinMaterial)
                .padding(.bottom, 49) // sit above tab bar
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
        .accentColor(Color.pulseAccent)
    }
}

extension Color {
    static let pulseAccent = Color(red: 0.114, green: 0.725, blue: 0.329) // #1DB954
    static let pulseBackground = Color(red: 0.04, green: 0.04, blue: 0.04)
    static let pulseCard = Color(red: 0.10, green: 0.10, blue: 0.10)
    static let pulseSecondary = Color(white: 0.65)
}
