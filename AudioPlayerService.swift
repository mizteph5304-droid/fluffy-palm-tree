import Foundation
import AVFoundation
import MediaPlayer
import Combine

@MainActor
final class AudioPlayerService: ObservableObject {
    // MARK: - Published state
    @Published private(set) var queue: [Track] = []
    @Published private(set) var currentIndex: Int = -1
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var isSeeking = false

    // Lyrics
    @Published private(set) var lyricLines: [LyricLine] = []
    @Published private(set) var activeLyricIndex: Int = -1
    @Published private(set) var lyricsStatus: LyricsStatus = .idle
    @Published var lyricsOffset: Double = 0

    var currentTrack: Track? {
        guard currentIndex >= 0, currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    // MARK: - Private
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var library: LibraryStore?
    private var lyricsTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        configureSession()
        setupRemoteCommands()
        setupInterruptionHandling()
    }

    func bind(to library: LibraryStore) {
        self.library = library
    }

    // MARK: - Session

    private func configureSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Audio session error:", error)
        }
    }

    // MARK: - Queue control

    func play(_ tracks: [Track], startingAt index: Int = 0) {
        guard !tracks.isEmpty else { return }
        queue = tracks
        currentIndex = max(0, min(index, tracks.count - 1))
        loadAndPlay(queue[currentIndex])
    }

    func play(_ track: Track, in context: [Track]? = nil) {
        if let context, let idx = context.firstIndex(where: { $0.id == track.id }) {
            play(context, startingAt: idx)
        } else {
            play([track], startingAt: 0)
        }
    }

    func enqueue(_ tracks: [Track]) {
        queue.append(contentsOf: tracks)
    }

    func playNext() {
        guard !queue.isEmpty else { return }
        let next = currentIndex + 1
        if next < queue.count {
            currentIndex = next
            loadAndPlay(queue[currentIndex])
        } else {
            // End of queue
            pause()
            seek(to: 0)
        }
    }

    func playPrevious() {
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        guard !queue.isEmpty else { return }
        let prev = currentIndex - 1
        if prev >= 0 {
            currentIndex = prev
            loadAndPlay(queue[currentIndex])
        } else {
            seek(to: 0)
        }
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingPlayback()
    }

    func resume() {
        guard player != nil else {
            if let t = currentTrack { loadAndPlay(t) }
            return
        }
        player?.play()
        isPlaying = true
        updateNowPlayingPlayback()
    }

    func seek(to time: TimeInterval) {
        let t = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
        updateActiveLyric()
        updateNowPlayingElapsed()
    }

    func clearQueue() {
        pause()
        queue = []
        currentIndex = -1
        currentTime = 0
        duration = 0
        clearLyrics()
        clearNowPlaying()
    }

    func removeFromQueue(at offsets: IndexSet) {
        let removingCurrent = offsets.contains(currentIndex)
        queue.remove(atOffsets: offsets)
        if queue.isEmpty {
            clearQueue()
            return
        }
        if removingCurrent {
            currentIndex = min(currentIndex, queue.count - 1)
            loadAndPlay(queue[currentIndex])
        } else if let firstRemoved = offsets.first, firstRemoved < currentIndex {
            currentIndex -= offsets.filter { $0 < currentIndex }.count
        }
    }

    // MARK: - Load track

    private func loadAndPlay(_ track: Track) {
        guard let library else { return }
        let url = library.fileURL(for: track)

        tearDownPlayer()

        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        player = p

        duration = track.duration
        currentTime = 0
        isPlaying = true

        // Time observer
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self, !self.isSeeking else { return }
            self.currentTime = time.seconds
            self.updateActiveLyric()
            self.updateNowPlayingElapsed()
        }

        // End of track
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.playNext()
        }

        // Actual duration from asset if missing
        Task {
            if track.duration <= 0 {
                let asset = AVURLAsset(url: url)
                if let d = try? await asset.load(.duration), d.seconds.isFinite {
                    await MainActor.run {
                        self.duration = d.seconds
                        self.updateNowPlayingInfo()
                    }
                }
            }
        }

        p.play()
        updateNowPlayingInfo()
        loadLyrics(for: track)
    }

    private func tearDownPlayer() {
        if let obs = timeObserver, let p = player {
            p.removeTimeObserver(obs)
        }
        timeObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        player?.pause()
        player = nil
    }

    // MARK: - Lyrics

    private func clearLyrics() {
        lyricsTask?.cancel()
        lyricLines = []
        activeLyricIndex = -1
        lyricsStatus = .idle
        lyricsOffset = 0
    }

    private func loadLyrics(for track: Track) {
        clearLyrics()
        lyricsOffset = track.lyricsOffset

        if let text = track.lyrics, !text.isEmpty {
            applyLyricsText(text, source: track.lyricsSource ?? "tags")
            return
        }

        // Online lookup
        lyricsStatus = .loading
        let title = track.title
        let artist = track.artist
        let album = track.album
        let duration = track.duration
        let trackId = track.id

        lyricsTask = Task {
            let (status, text, _) = await LyricsService.shared.find(
                title: title,
                artist: artist,
                album: album,
                duration: duration
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self.currentTrack?.id == trackId else { return }
                self.lyricsStatus = status
                if let text, !text.isEmpty {
                    self.applyLyricsText(text, source: "lrclib")
                    // Persist so we don't re-fetch every time
                    Task {
                        var updated = track
                        updated.lyrics = text
                        updated.lyricsSource = "lrclib"
                        updated.lyricsCheckedAt = Date()
                        await self.library?.updateTrack(updated)
                        // Also update queue copy
                        if let idx = self.queue.firstIndex(where: { $0.id == trackId }) {
                            self.queue[idx] = updated
                        }
                    }
                }
            }
        }
    }

    private func applyLyricsText(_ text: String, source: String) {
        let lines = LyricsService.parseLRC(text)
        if lines.isEmpty {
            // Plain text — show as a single non-timed block
            lyricLines = [LyricLine(time: 0, text: text)]
            lyricsStatus = .found(synced: false)
        } else {
            lyricLines = lines
            lyricsStatus = .found(synced: true)
        }
        updateActiveLyric()
    }

    private func updateActiveLyric() {
        guard !lyricLines.isEmpty else {
            activeLyricIndex = -1
            return
        }
        // Only advance if we have real timed lines (more than one or first time > 0)
        let timed = lyricLines.count > 1 || (lyricLines.first?.time ?? 0) > 0
        if timed {
            activeLyricIndex = LyricsService.activeIndex(in: lyricLines, at: currentTime, offset: lyricsOffset)
        } else {
            activeLyricIndex = 0
        }
    }

    func setLyricsOffset(_ offset: Double) {
        lyricsOffset = offset
        updateActiveLyric()
        if var t = currentTrack {
            t.lyricsOffset = offset
            Task { await library?.updateTrack(t) }
            if let idx = queue.firstIndex(where: { $0.id == t.id }) {
                queue[idx] = t
            }
        }
    }

    // MARK: - Now Playing / Remote

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playNext() }
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playPrevious() }
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            clearNowPlaying()
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.displayTitle,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: duration > 0 ? duration : track.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let data = track.artworkData, let image = UIImage(data: data) {
            let art = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = art
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingElapsed() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingPlayback() {
        updateNowPlayingElapsed()
    }

    private func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Interruptions

    private func setupInterruptionHandling() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            Task { @MainActor in
                switch type {
                case .began:
                    self?.pause()
                case .ended:
                    if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) {
                            self?.resume()
                        }
                    }
                @unknown default:
                    break
                }
            }
        }
    }
}
