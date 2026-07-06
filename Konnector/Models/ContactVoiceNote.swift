import Foundation
import SwiftData

@Model
final class ContactVoiceNote {
    var id: UUID
    var createdAt: Date
    var duration: TimeInterval
    var fileName: String
    var contact: ContactSnapshot?

    init(fileName: String, duration: TimeInterval, createdAt: Date = Date()) {
        id = UUID()
        self.fileName = fileName
        self.duration = duration
        self.createdAt = createdAt
    }

    var formattedDuration: String {
        Self.formatDuration(duration)
    }

    static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
