import Foundation
import AVFoundation
import AppKit

/// Verwaltet die Wiedergabe des TTS-Audios für Live-Briefings.
@MainActor
final class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var progress: Double = 0     // 0.0 – 1.0
    @Published var duration: TimeInterval = 0
    @Published var errorMessage: String? = nil

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    private var tempFileURL: URL?

    // MARK: - News-Sounds (System-Sounds, kein Audio-File nötig)

    static let availableNewsSounds: [String] = [
        "Ping", "Pop", "Glass", "Hero", "Funk", "Submarine",
        "Basso", "Frog", "Morse", "Purr", "Sosumi", "Tink"
    ]

    /// Spielt einen kurzen Beep wenn eine neue relevante News erscheint.
    nonisolated static func playNewsBeep() {
        playNamedSound("Ping")
    }

    /// Spielt den konfigurierten News-Sound.
    nonisolated static func playNewsAlert(impactScore: Double, normalSoundName: String, highImpactSoundName: String) {
        let name = impactScore >= 8 ? highImpactSoundName : normalSoundName
        playNamedSound(name)
    }

    nonisolated static func playNamedSound(_ name: String) {
        DispatchQueue.main.async {
            let sound = NSSound(named: NSSound.Name(name)) ?? NSSound(named: NSSound.Name("Ping"))
            sound?.play()
        }
    }

    // MARK: - Öffentliche API

    func loadAndPlay(data: Data) {
        stop()
        errorMessage = nil

        guard !data.isEmpty else {
            errorMessage = "Keine Audio-Daten empfangen (TTS fehlgeschlagen)"
            print("[AudioPlayer] loadAndPlay: data ist leer")
            return
        }

        do {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("bzm_briefing_\(Int(Date().timeIntervalSince1970)).mp3")
            try data.write(to: url)
            tempFileURL = url
            print("[AudioPlayer] Temp-Datei: \(url.path) (\(data.count) Bytes)")

            let p = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
            p.delegate = self
            p.prepareToPlay()
            let started = p.play()
            player = p
            duration = p.duration
            isPlaying = started
            print("[AudioPlayer] Wiedergabe gestartet=\(started), Dauer=\(p.duration)s")
            if started { startProgressTimer() } else {
                errorMessage = "Wiedergabe konnte nicht gestartet werden"
            }
        } catch {
            errorMessage = "Audio-Fehler: \(error.localizedDescription)"
            print("[AudioPlayer] Fehler: \(error)")
        }
    }

    func togglePlay() {
        guard let p = player else { return }
        if p.isPlaying {
            p.pause()
            isPlaying = false
            stopProgressTimer()
        } else {
            p.play()
            isPlaying = true
            startProgressTimer()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        progress = 0
        duration = 0
        stopProgressTimer()
        cleanupTemp()
    }

    func seek(to fraction: Double) {
        guard let p = player else { return }
        p.currentTime = fraction * p.duration
        progress = fraction
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 1.0
            self.stopProgressTimer()
        }
    }

    // MARK: - Private

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let p = self.player, p.duration > 0 else { return }
                self.progress = p.currentTime / p.duration
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func cleanupTemp() {
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
            tempFileURL = nil
        }
    }

    var currentTimeFormatted: String { format(player?.currentTime ?? 0) }
    var durationFormatted:    String { format(duration) }

    private func format(_ t: TimeInterval) -> String {
        let s = max(0, Int(t)); return String(format: "%d:%02d", s / 60, s % 60)
    }
}
