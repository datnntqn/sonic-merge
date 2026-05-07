import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct TranscriptExporterTests {

    private func segment(text: String, start: TimeInterval, end: TimeInterval) -> TranscriptionState.RecognizedSegment {
        TranscriptionState.RecognizedSegment(text: text, startTime: start, endTime: end, confidence: 1.0)
    }

    // MARK: - Plain text

    @Test func plainTextEmpty() {
        #expect(TranscriptExporter.plainText(from: []) == "")
    }

    @Test func plainTextConcatenatesWithSpaces() {
        let segs = [
            segment(text: "Hello", start: 0, end: 0.5),
            segment(text: "world", start: 0.6, end: 1.0)
        ]
        #expect(TranscriptExporter.plainText(from: segs) == "Hello world")
    }

    @Test func plainTextInsertsParagraphOnLongPause() {
        let segs = [
            segment(text: "First sentence.", start: 0, end: 1.0),
            segment(text: "Second sentence.", start: 3.0, end: 4.0)
        ]
        let out = TranscriptExporter.plainText(from: segs)
        #expect(out.contains("\n\n"))
    }

    @Test func plainTextDoesNotInsertParagraphOnShortPause() {
        let segs = [
            segment(text: "First", start: 0, end: 1.0),
            segment(text: "second", start: 1.2, end: 2.0)
        ]
        let out = TranscriptExporter.plainText(from: segs)
        #expect(!out.contains("\n\n"))
    }

    @Test func plainTextStripsWhitespace() {
        let segs = [segment(text: "  padded  ", start: 0, end: 1)]
        #expect(TranscriptExporter.plainText(from: segs) == "padded")
    }

    @Test func plainTextSkipsEmptySegments() {
        let segs = [
            segment(text: "Hello", start: 0, end: 0.5),
            segment(text: "", start: 0.6, end: 0.7),
            segment(text: "world", start: 0.8, end: 1.0)
        ]
        #expect(TranscriptExporter.plainText(from: segs) == "Hello world")
    }

    // MARK: - SRT

    @Test func srtEmptyReturnsEmptyString() {
        #expect(TranscriptExporter.srt(from: []) == "")
    }

    @Test func srtFormatsCueWithCommaMillis() {
        let segs = [segment(text: "Hello", start: 0, end: 1.5)]
        let out = TranscriptExporter.srt(from: segs)
        #expect(out.contains("00:00:00,000 --> 00:00:01,500"))
        #expect(out.contains("Hello"))
        #expect(out.hasPrefix("1\n"))
    }

    @Test func srtNumbersCuesSequentially() {
        let segs = [
            segment(text: "One", start: 0, end: 1),
            segment(text: "Two", start: 1, end: 2),
            segment(text: "Three", start: 2, end: 3)
        ]
        let out = TranscriptExporter.srt(from: segs)
        #expect(out.contains("1\n"))
        #expect(out.contains("2\n"))
        #expect(out.contains("3\n"))
    }

    @Test func srtHandlesMultiHourTimestamp() {
        let segs = [segment(text: "Late", start: 3725.5, end: 3726.0)]
        let out = TranscriptExporter.srt(from: segs)
        #expect(out.contains("01:02:05,500"))
    }

    // MARK: - VTT

    @Test func vttEmptyReturnsHeaderOnly() {
        #expect(TranscriptExporter.vtt(from: []) == "WEBVTT\n\n")
    }

    @Test func vttFormatsCueWithDotMillis() {
        let segs = [segment(text: "Hello", start: 0, end: 1.5)]
        let out = TranscriptExporter.vtt(from: segs)
        #expect(out.hasPrefix("WEBVTT\n\n"))
        #expect(out.contains("00:00:00.000 --> 00:00:01.500"))
        #expect(out.contains("Hello"))
    }

    @Test func vttHandlesMultiHourTimestamp() {
        let segs = [segment(text: "Late", start: 3725.5, end: 3726.0)]
        let out = TranscriptExporter.vtt(from: segs)
        #expect(out.contains("01:02:05.500"))
    }

    // MARK: - File writing

    @Test func writeTempFileCreatesReadableFile() throws {
        let url = try TranscriptExporter.writeTempFile(content: "test content", ext: "txt", basename: "exporter-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)
        #expect(String(data: data, encoding: .utf8) == "test content")
    }
}
