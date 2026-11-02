import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: AudioPlayerService

    @State private var search = ""
    @State private var sort: LibraryStore.Sort = .recent
    @State private var showImporter = false
    @State private var showClearConfirm = false
    @State private var selection = Set<String>()
    @State private var isSelecting = false

    private var filtered: [Track] {
        library.filtered(search: search, sort: sort)
    }

    var body: some View {
        NavigationStack {
            Group {
                if library.tracks.isEmpty && !library.isImporting {
                    emptyState
                } else {
                    trackList
                }
            }
            .background(Color.pulseBackground.ignoresSafeArea())
            .navigationTitle("Library")
            .searchable(text: $search, prompt: "Search title, artist, album")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isSelecting {
                        Button("Cancel") {
                            isSelecting = false
                            selection.removeAll()
                        }
                    } else {
                        Menu {
                            Picker("Sort", selection: $sort) {
                                ForEach(LibraryStore.Sort.allCases, id: \.self) { s in
                                    Text(s.label).tag(s)
                                }
                            }
                            Divider()
                            Button("Select…") { isSelecting = true }
                            Button("Clear Library", role: .destructive) {
                                showClearConfirm = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelecting {
                        Button("Delete", role: .destructive) {
                            Task {
                                await library.removeTracks(ids: selection)
                                selection.removeAll()
                                isSelecting = false
                            }
                        }
                        .disabled(selection.isEmpty)
                    } else {
                        Button {
                            showImporter = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [
                    .audio, .mp3, .mpeg4Audio, .wav,
                    UTType(filenameExtension: "flac") ?? .audio,
                    UTType(filenameExtension: "m4a") ?? .mpeg4Audio,
                    UTType(filenameExtension: "aac") ?? .audio,
                    UTType(filenameExtension: "ogg") ?? .audio
                ],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    Task { await library.importFiles(urls: urls) }
                case .failure(let err):
                    print("Import error:", err)
                }
            }
            .overlay {
                if library.isImporting {
                    ZStack {
                        Color.black.opacity(0.5).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text(library.importProgress ?? "Importing…")
                                .foregroundStyle(.white)
                        }
                        .padding(28)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .confirmationDialog("Clear entire library?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear Library", role: .destructive) {
                    Task { await library.clearLibrary() }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.pulseSecondary)
            Text("No music yet")
                .font(.title2.weight(.semibold))
            Text("Import tracks from the Files app.\nThey stay on your device.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.pulseSecondary)
                .font(.subheadline)
            Button {
                showImporter = true
            } label: {
                Label("Add Music", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.pulseAccent)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var trackList: some View {
        List {
            ForEach(filtered) { track in
                TrackRow(
                    track: track,
                    isPlaying: player.currentTrack?.id == track.id && player.isPlaying,
                    isSelected: selection.contains(track.id),
                    isSelecting: isSelecting
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    if isSelecting {
                        if selection.contains(track.id) {
                            selection.remove(track.id)
                        } else {
                            selection.insert(track.id)
                        }
                    } else {
                        player.play(track, in: filtered)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await library.removeTracks(ids: [track.id]) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button {
                        player.play(track, in: filtered)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                    Button {
                        player.enqueue([track])
                    } label: {
                        Label("Add to Queue", systemImage: "text.append")
                    }
                    Menu("Add to Playlist") {
                        ForEach(library.playlists) { pl in
                            Button(pl.name) {
                                Task { await library.addTracks([track.id], toPlaylist: pl.id) }
                            }
                        }
                        if library.playlists.isEmpty {
                            Text("No playlists yet")
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        Task { await library.removeTracks(ids: [track.id]) }
                    } label: {
                        Label("Delete", systemImage: "trash")
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

struct TrackRow: View {
    let track: Track
    var isPlaying: Bool = false
    var isSelected: Bool = false
    var isSelecting: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.pulseAccent : Color.pulseSecondary)
                    .font(.title3)
            }

            ArtworkView(data: track.artworkData, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.displayTitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isPlaying ? Color.pulseAccent : .white)
                    .lineLimit(1)
                Text(track.displaySubtitle.isEmpty ? track.artist : track.displaySubtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.pulseSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isPlaying {
                Image(systemName: "waveform")
                    .foregroundStyle(Color.pulseAccent)
                    .font(.caption)
            }

            Text(Formatters.time(track.duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.pulseSecondary)
        }
        .padding(.vertical, 4)
    }
}

struct ArtworkView: View {
    let data: Data?
    var size: CGFloat = 48
    var cornerRadius: CGFloat = 8

    var body: some View {
        Group {
            if let data, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.pulseCard
                    Image(systemName: "music.note")
                        .foregroundStyle(Color.pulseSecondary.opacity(0.6))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
