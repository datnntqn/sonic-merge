import Foundation
import SwiftData

/// A persisted Denoise session. Source audio at <AppGroup>/denoise/<id>/source.<ext>;
/// processed (denoised) audio at <AppGroup>/denoise/<id>/processed.wav once apply
/// completes. `intensity` is the last applied wet/dry blend (0–1).
@Model
final class DenoiseSession {
    @Attribute(.unique) var id: UUID
    var name: String
    var sourceFilename: String
    var processedFilename: String?
    var intensity: Double
    var durationSeconds: Double
    var createdAt: Date
    var lastOpenedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        sourceFilename: String,
        durationSeconds: Double,
        intensity: Double = 0.5
    ) {
        self.id = id
        self.name = name
        self.sourceFilename = sourceFilename
        self.durationSeconds = durationSeconds
        self.intensity = intensity
        self.createdAt = .now
        self.lastOpenedAt = .now
    }
}
