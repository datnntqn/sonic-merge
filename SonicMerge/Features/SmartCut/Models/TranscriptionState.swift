import Foundation

/// Snapshot of in-progress (or completed) transcription, persisted between chunks
/// so foreground/background work can resume exactly where it stopped.
struct TranscriptionState: Hashable, Codable {

    /// SHA256 of the source audio file's bytes (see SourceHasher).
    let sourceHash: String

    /// Total duration of the source audio, seconds.
    let sourceDuration: TimeInterval

    /// Chunk size used for processing, seconds. Constant within a single state.
    let chunkDurationSeconds: TimeInterval

    /// Number of chunks already processed and merged into recognizedSegments.
    var completedChunkCount: Int

    /// Cumulative recognized segments across all completed chunks.
    var recognizedSegments: [RecognizedSegment]

    /// True after all chunks are processed.
    var isComplete: Bool

    var progressFraction: Double {
        guard sourceDuration > 0 else { return 0 }
        return min(1.0, Double(completedChunkCount) * chunkDurationSeconds / sourceDuration)
    }

    var nextChunkStartTime: TimeInterval {
        TimeInterval(completedChunkCount) * chunkDurationSeconds
    }

    /// One word/phrase recognized by SFSpeechRecognizer with timestamps.
    struct RecognizedSegment: Hashable, Codable {
        let text: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        let confidence: Float
    }
}
