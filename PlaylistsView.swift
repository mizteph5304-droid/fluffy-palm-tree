import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: AudioPlayerService

    @State private var showCreate = false
    @State private var newName = ""
    @State private var renameTarget: Playlist?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            Group {
                if library.playlists.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(Color.pulseSecondary)
                        Text("No playlists")
                            .font(.title3.weight(.semibold))
                        Text("Create a playlist, then add tracks from the Library.")
                            .font(.subheadline)
                            .foregroundStyle(Color.pulseSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button {
                            showCreate = true
                        } label: {
                            Label("New Playlist", systemImage: "plus")
                                .font(.headline)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.pulseAccent)
                                .foregroundStyle(.black)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(library.playlists) { pl in
                            NavigationLink {
                                PlaylistDetailView(playlist: pl)
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.pulseCard)
                                            .frame(width: 48, height: 48)
                                        Image(systemName: "music.note.list")
                                            .foregroundStyle(Color.pulseAccent)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(pl.name)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.white)
                                        Text("\(pl.trackIds.count) track\(pl.trackIds.count == 1 ? "" : "s")")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.pulseSecondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.pulseBackground)
                            .listRowSeparatorTint(Color.white.opacity(0.06))
                            .contextMenu {
                                Button {
                                    renameTarget = pl
                                    renameText = pl.name
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    Task { await library.deletePlaylist(id: pl.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { indexSet in
                            let ids = indexSet.map { library.playlists[$0].id }
                            Task {
                                for id in ids { await library.deletePlaylist(id: id) }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.pulseBackground.ignoresSafeArea())
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Playlist", isPresented: $showCreate) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) { newName = "" }
                Button("Create") {
                    let name = newName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    Task {
                        _ = await library.createPlaylist(name: name)
                        newName = ""
                    }
                }
            }
            .alert("Rename Playlist", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) { renameTarget = nil }
                Button("Save") {
                    guard let pl = renameTarget else { return }
                    let name = renameText.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        Task { await library.renamePlaylist(id: pl.id, name: name) }
                    }
                    renameTarget = nil
                }
            }
        }
    }
}

struct PlaylistDetailView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: AudioPlayerService
    let playlist: Playlist

    private var tracks: [Track] {
        // Re-resolve so it stays live after edits
        library.tracks(for: library.playlists.first(where: { $0.id == playlist.id }) ?? playlist)
    }

    var body: some View {
        Group {
            if tracks.isEmpty {
                ContentUnavailableView(
                    "Empty playlist",
                    systemImage: "music.note.list",
                    description: Text("Add tracks from the Library using the context menu.")
                )
            } else {
                List {
                    ForEach(tracks) { track in
                        TrackRow(
                            track: track,
                            isPlaying: player.currentTrack?.id == track.id && player.isPlaying
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            player.play(track, in: tracks)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await library.removeTrack(track.id, fromPlaylist: playlist.id) }
                            } label: {
                                Label("Remove", systemImage: "minus.circle")
                            }
                        }
                        .listRowBackground(Color.pulseBackground)
                        .listRowSeparatorTint(Color.white.opacity(0.06))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.pulseBackground.ignoresSafeArea())
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    player.play(tracks, startingAt: 0)
                } label: {
                    Image(systemName: "play.fill")
                }
                .disabled(tracks.isEmpty)
            }
        }
    }
}
