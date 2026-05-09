import Foundation
import SwiftData

/// A persisted Smart Cut session: a single source audio file plus the user's
/// in-progress edit list and transcript cache reference. Sessions live under
/// `<AppGroup>/smart-cut/<id>/` on disk and are listed in `SmartCutHomeView`.
///
/// `sourceHashHex` is the SHA-256 of the source file's bytes (no mode suffix);
/// it lets `RootTabView` resolve background-transcription notifications back
/// to the originating session via a single-column FetchDescriptor.
@Model
final class SmartCutSession {
    @Attribute(.unique) var id: UUID
    var name: String
    var sourceFilename: String
    var sourceHashHex: String
    var durationSeconds: Double
    var createdAt: Date
    var lastOpenedAt: Date
    var editListJSON: Data?
    /// BCP-47 locale identifier for Smart Cut analysis (e.g. "en-US", "es-ES").
    /// `nil` (the default for fresh sessions and pre-migration sessions) resolves
    /// to the device's preferred language at analyze time, falling back to "en-US".
    var localeIdentifier: String?
    var transcriptCacheRef: String?

    init(
        id: UUID = UUID(),
        name: String,
        sourceFilename: String,
        sourceHashHex: String,
        durationSeconds: Double,
        localeIdentifier: String? = nil
    ) {
        self.id = id
        self.name = name
        self.sourceFilename = sourceFilename
        self.sourceHashHex = sourceHashHex
        self.durationSeconds = durationSeconds
        self.createdAt = .now
        self.lastOpenedAt = .now
        self.localeIdentifier = localeIdentifier
    }
}
