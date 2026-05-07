import Foundation

/// Pure helper that converts `TranscriptionState.RecognizedSegment` arrays
/// into shareable text formats (.txt / .srt / .vtt) plus simple paragraph
/// rendering for SwiftUI views.
///
/// Stateless. All methods are static. No async. No service dependencies.
enum TranscriptExporter {

    /// Gap (seconds) between two consecutive segments that triggers a paragraph break.
    static let paragraphBreakThreshold: TimeInterval = 1.5

    // MARK: - Plain text

    static func plainText(from segments: [TranscriptionState.RecognizedSegment]) -> String {
        guard !segments.isEmpty else { return "" }
        var output = ""
        for (index, seg) in segments.enumerated() {
            let text = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { continue }
            if index > 0 {
                let prev = segments[index - 1]
                let gap = seg.startTime - prev.endTime
                if gap >= paragraphBreakThreshold {
                    output += "\n\n"
                } else if let lastChar = output.last, !lastChar.isWhitespace {
                    output += " "
                }
            }
            output += text
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - SRT (SubRip)

    static func srt(from segments: [TranscriptionState.RecognizedSegment]) -> String {
        guard !segments.isEmpty else { return "" }
        var output = ""
        var cueNumber = 0
        for seg in segments {
            let text = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { continue }
            cueNumber += 1
            output += "\(cueNumber)\n"
            output += "\(srtTimestamp(seg.startTime)) --> \(srtTimestamp(seg.endTime))\n"
            output += "\(text)\n\n"
        }
        return output
    }

    private static func srtTimestamp(_ seconds: TimeInterval) -> String {
        let total = max(0, seconds)
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        let secs = Int(total) % 60
        let millis = Int((total - floor(total)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, secs, millis)
    }

    // MARK: - VTT (WebVTT)

    static func vtt(from segments: [TranscriptionState.RecognizedSegment]) -> String {
        guard !segments.isEmpty else { return "WEBVTT\n\n" }
        var output = "WEBVTT\n\n"
        for seg in segments {
            let text = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { continue }
            output += "\(vttTimestamp(seg.startTime)) --> \(vttTimestamp(seg.endTime))\n"
            output += "\(text)\n\n"
        }
        return output
    }

    private static func vttTimestamp(_ seconds: TimeInterval) -> String {
        let total = max(0, seconds)
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        let secs = Int(total) % 60
        let millis = Int((total - floor(total)) * 1000)
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, secs, millis)
    }

    // MARK: - File writing helper

    static func writeTempFile(content: String, ext: String, basename: String = "transcript") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(basename).\(ext)")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
