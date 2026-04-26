import Foundation

enum PauseDetector {

    /// Find inter-segment gaps + leading/trailing silence longer than `threshold`.
    /// Threshold is exclusive: a gap exactly equal to threshold does NOT trigger.
    static func detect(in segments: [TranscriptionState.RecognizedSegment],
                       totalDuration: TimeInterval,
                       threshold: TimeInterval) -> [PauseEdit] {
        var pauses: [PauseEdit] = []

        // Leading silence
        if let first = segments.first, first.startTime > threshold {
            pauses.append(PauseEdit(timeRange: 0...first.startTime, isEnabled: true))
        }

        // Inter-segment gaps
        if segments.count >= 2 {
            for i in 0..<(segments.count - 1) {
                let gapStart = segments[i].endTime
                let gapEnd = segments[i + 1].startTime
                if gapEnd - gapStart > threshold {
                    pauses.append(PauseEdit(timeRange: gapStart...gapEnd, isEnabled: true))
                }
            }
        }

        // Trailing silence
        if let last = segments.last, totalDuration - last.endTime > threshold {
            pauses.append(PauseEdit(timeRange: last.endTime...totalDuration, isEnabled: true))
        }

        return pauses
    }
}
