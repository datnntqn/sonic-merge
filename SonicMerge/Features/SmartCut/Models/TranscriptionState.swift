import Foundation

/// Snapshot of in-progress (or completed) transcription, persisted between chunks
/// so foreground/background work can resume exactly where it stopped.
struct TranscriptionState: Hashable, Codable {

    /// Which transcription engine produced this state. Persisted so
    /// `BackgroundTranscriptionTask` can resume on the same engine that wrote
    /// the snapshot, regardless of what `localeIdentifier` is.
    enum Engine: String, Codable, Hashable {
        case sfSpeechRecognizer
        case speechAnalyzer
    }

    /// SHA256 of the source audio file's bytes (see SourceHasher).
    let sourceHash: String

    /// BCP-47 locale identifier the recognizer used for this state. Persisted
    /// so background-resume (BackgroundTranscriptionTask) can construct the
    /// recognizer with the same locale, avoiding a SwiftData lookup. `nil`
    /// for pre-migration cached state JSON — read sites fall back to "en-US".
    let localeIdentifier: String?

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

    /// Engine that produced this state. Defaults to `.sfSpeechRecognizer` for
    /// pre-migration JSON (decoded via `init(from:)`).
    let engine: Engine

    /// SpeechAnalyzer-only resume cursor: how many seconds of source audio
    /// have been recognized so far. SF chunked engine leaves this at 0 and
    /// uses `completedChunkCount * chunkDurationSeconds` instead.
    var completedRecognizedDuration: TimeInterval

    /// SpeechAnalyzer-only live transcript text (single space-joined). SF
    /// chunked engine leaves this empty.
    var liveTranscriptText: String

    init(sourceHash: String,
         sourceDuration: TimeInterval,
         chunkDurationSeconds: TimeInterval,
         completedChunkCount: Int,
         recognizedSegments: [RecognizedSegment],
         isComplete: Bool,
         localeIdentifier: String? = nil,
         engine: Engine = .sfSpeechRecognizer,
         completedRecognizedDuration: TimeInterval = 0,
         liveTranscriptText: String = "") {
        self.sourceHash = sourceHash
        self.sourceDuration = sourceDuration
        self.chunkDurationSeconds = chunkDurationSeconds
        self.completedChunkCount = completedChunkCount
        self.recognizedSegments = recognizedSegments
        self.isComplete = isComplete
        self.localeIdentifier = localeIdentifier
        self.engine = engine
        self.completedRecognizedDuration = completedRecognizedDuration
        self.liveTranscriptText = liveTranscriptText
    }

    private enum CodingKeys: String, CodingKey {
        case sourceHash, localeIdentifier, sourceDuration, chunkDurationSeconds
        case completedChunkCount, recognizedSegments, isComplete
        case engine, completedRecognizedDuration, liveTranscriptText
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.sourceHash = try c.decode(String.self, forKey: .sourceHash)
        self.localeIdentifier = try c.decodeIfPresent(String.self, forKey: .localeIdentifier)
        self.sourceDuration = try c.decode(TimeInterval.self, forKey: .sourceDuration)
        self.chunkDurationSeconds = try c.decode(TimeInterval.self, forKey: .chunkDurationSeconds)
        self.completedChunkCount = try c.decode(Int.self, forKey: .completedChunkCount)
        self.recognizedSegments = try c.decode([RecognizedSegment].self, forKey: .recognizedSegments)
        self.isComplete = try c.decode(Bool.self, forKey: .isComplete)
        self.engine = (try? c.decode(Engine.self, forKey: .engine)) ?? .sfSpeechRecognizer
        self.completedRecognizedDuration = (try? c.decode(TimeInterval.self, forKey: .completedRecognizedDuration)) ?? 0
        self.liveTranscriptText = (try? c.decode(String.self, forKey: .liveTranscriptText)) ?? ""
    }

    var progressFraction: Double {
        guard sourceDuration > 0 else { return 0 }
        switch engine {
        case .sfSpeechRecognizer:
            return min(1.0, Double(completedChunkCount) * chunkDurationSeconds / sourceDuration)
        case .speechAnalyzer:
            return min(1.0, completedRecognizedDuration / sourceDuration)
        }
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
