import SwiftUI

@main
struct PulseApp: App {
    @StateObject private var library = LibraryStore()
    @StateObject private var player = AudioPlayerService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .environmentObject(player)
                .preferredColorScheme(.dark)
                .onAppear {
                    player.bind(to: library)
                    Task { await library.load() }
                }
        }
    }
}
