import AVFoundation
import Foundation
import Observation

enum VoiceNoteFiles {
    static func ensureDirectoryExists() throws {
        let fileManager = FileManager.default
        let voiceNotesDirectory = directory
        if !fileManager.fileExists(atPath: voiceNotesDirectory.path()) {
            try fileManager.createDirectory(at: voiceNotesDirectory, withIntermediateDirectories: true)
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var mutableDirectory = voiceNotesDirectory
            try mutableDirectory.setResourceValues(resourceValues)
        }
    }

    static var directory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "KonnectorContacts/VoiceNotes", directoryHint: .isDirectory)
    }

    static func makeFileName() -> String {
        "\(UUID().uuidString).m4a"
    }

    static func fileURL(for fileName: String) -> URL {
        directory.appending(path: fileName)
    }

    static func deleteFile(named fileName: String) {
        let url = fileURL(for: fileName)
        try? FileManager.default.removeItem(at: url)
    }

    static func deleteFiles(for notes: [ContactVoiceNote]) {
        for note in notes {
            deleteFile(named: note.fileName)
        }
    }
}

@MainActor
@Observable
final class VoiceNoteRecorder {
    enum State: Equatable {
        case idle
        case recording
        case playing(noteID: UUID)
    }

    private(set) var state: State = .idle
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var permissionDenied = false

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingURL: URL?
    private var recordingStartedAt: Date?
    private var progressTimer: Timer?
    private var playingNoteID: UUID?

    func requestPermissionIfNeeded() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            permissionDenied = false
            return true
        case .denied:
            permissionDenied = true
            return false
        case .undetermined:
            let granted = await AVAudioApplication.requestRecordPermission()
            permissionDenied = !granted
            return granted
        @unknown default:
            permissionDenied = true
            return false
        }
    }

    func startRecording() throws {
        guard state == .idle else { return }

        try VoiceNoteFiles.ensureDirectoryExists()
        try configureSession(for: .record)

        let fileName = VoiceNoteFiles.makeFileName()
        let url = VoiceNoteFiles.fileURL(for: fileName)
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()

        recordingStartedAt = Date()
        state = .recording
        elapsedTime = 0
        startProgressTimer()
    }

    func stopRecording() -> (fileName: String, duration: TimeInterval)? {
        guard state == .recording else { return nil }

        stopProgressTimer()
        audioRecorder?.stop()
        audioRecorder = nil

        let duration = recordingStartedAt.map { Date().timeIntervalSince($0) } ?? elapsedTime
        defer {
            recordingURL = nil
            recordingStartedAt = nil
            state = .idle
            elapsedTime = 0
        }

        guard let url = recordingURL else { return nil }
        let fileName = url.lastPathComponent
        guard duration >= 0.5, FileManager.default.fileExists(atPath: url.path()) else {
            VoiceNoteFiles.deleteFile(named: fileName)
            return nil
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return (fileName, duration)
    }

    func cancelRecording() {
        guard state == .recording else { return }

        stopProgressTimer()
        audioRecorder?.stop()
        audioRecorder = nil

        if let url = recordingURL {
            VoiceNoteFiles.deleteFile(named: url.lastPathComponent)
        }

        recordingURL = nil
        recordingStartedAt = nil
        state = .idle
        elapsedTime = 0

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func play(note: ContactVoiceNote) throws {
        if playingNoteID == note.id {
            stopPlayback()
            return
        }

        stopPlayback()
        try configureSession(for: .playback)

        let url = VoiceNoteFiles.fileURL(for: note.fileName)
        guard FileManager.default.fileExists(atPath: url.path()) else {
            throw VoiceNoteError.missingFile
        }

        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = PlaybackDelegate.shared
        PlaybackDelegate.shared.onFinish = { [weak self] in
            Task { @MainActor in
                self?.stopPlayback()
            }
        }
        audioPlayer?.play()

        playingNoteID = note.id
        state = .playing(noteID: note.id)
        elapsedTime = 0
        startProgressTimer(updateFromPlayer: true)
    }

    func stopPlayback() {
        stopProgressTimer()
        audioPlayer?.stop()
        audioPlayer = nil
        playingNoteID = nil
        state = .idle
        elapsedTime = 0

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func isPlaying(_ note: ContactVoiceNote) -> Bool {
        playingNoteID == note.id
    }

    private enum SessionMode {
        case record
        case playback
    }

    private func configureSession(for mode: SessionMode) throws {
        let session = AVAudioSession.sharedInstance()
        switch mode {
        case .record:
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        case .playback:
            try session.setCategory(.playback, mode: .spokenAudio)
        }
        try session.setActive(true)
    }

    private func startProgressTimer(updateFromPlayer: Bool = false) {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if updateFromPlayer, let player = self.audioPlayer {
                    self.elapsedTime = player.currentTime
                } else if let startedAt = self.recordingStartedAt {
                    self.elapsedTime = Date().timeIntervalSince(startedAt)
                }
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

enum VoiceNoteError: LocalizedError {
    case missingFile
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .missingFile:
            "This voice note file is missing."
        case .permissionDenied:
            "Microphone access is required to record voice notes."
        }
    }
}

@MainActor
private final class PlaybackDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = PlaybackDelegate()
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}
