import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var player: AudioPlayerService

    var body: some View {
        NavigationStack {
            Group {
                if player.queue.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(Color.pulseSecondary)
                        Text("Queue is empty")
                            .font(.title3.weight(.semibold))
                        Text("Play a track from your library to build a queue.")
                            .font(.subheadline)
                            .foregroundStyle(Color.pulseSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, track in
                            HStack(spacing: 14) {
                                Text("\(index + 1)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Color.pulseSecondary)
                                    .frame(width: 22, alignment: .trailing)

                                TrackRow(
                                    track: track,
                                    isPlaying: index == player.currentIndex && player.isPlaying
                                )
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                player.play(player.queue, startingAt: index)
                            }
                            .listRowBackground(
                                index == player.currentIndex
                                    ? Color.pulseAccent.opacity(0.12)
                                    : Color.pulseBackground
                            )
                            .listRowSeparatorTint(Color.white.opacity(0.06))
                        }
                        .onDelete { offsets in
                            player.removeFromQueue(at: offsets)
                        }
                        .onMove { source, dest in
                            // Simple reordering of the queue array
                            var q = player.queue
                            let currentId = player.currentTrack?.id
                            q.move(fromOffsets: source, toOffset: dest)
                            // Rebuild via play to keep index consistent
                            let newIndex = currentId.flatMap { id in q.firstIndex(where: { $0.id == id }) } ?? 0
                            player.play(q, startingAt: newIndex)
                            if !player.isPlaying {
                                // play() starts playback; if user was paused we accept restart for simplicity
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.pulseBackground.ignoresSafeArea())
            .navigationTitle("Queue")
            .toolbar {
                if !player.queue.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") {
                            player.clearQueue()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
    }
}
