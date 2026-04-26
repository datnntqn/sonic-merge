import Testing
import Foundation
import AVFoundation
@testable import SonicMerge

struct AudioCutterTests {

    /// Creates a WAV at /tmp containing tones at given frequency-per-second.
    /// E.g. tones = [(0, 1000), (3, 2000)] = 1kHz from 0-3s, 2kHz from 3s onwards.
    private func makeToneWAV(toneSchedule: [(start: TimeInterval, hz: Double)],
                             durationSeconds: TimeInterval) throws -> URL {
        let sampleRate: Double = 44100
        let frameCount = AVAudioFrameCount(durationSeconds * sampleRate)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: sampleRate,
                                   channels: 1,
                                   interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let channel = buffer.floatChannelData![0]
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let segment = toneSchedule.last(where: { $0.start <= t }) ?? toneSchedule[0]
            let sample = sin(2.0 * .pi * segment.hz * t)
            channel[frame] = Float(sample) * 0.5
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cutter-fixture-\(UUID().uuidString).wav")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    /// Compute RMS for each second of a WAV file. Returns array of length floor(duration).
    private func rmsBySecond(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let total = AVAudioFrameCount(file.length)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: total)!
        try file.read(into: buffer)

        let sampleRate = Int(format.sampleRate)
        let channel = buffer.floatChannelData![0]
        var rms: [Float] = []
        var frame = 0
        while frame + sampleRate <= Int(total) {
            var sum: Float = 0
            for j in 0..<sampleRate {
                let s = channel[frame + j]
                sum += s * s
            }
            rms.append(sqrt(sum / Float(sampleRate)))
            frame += sampleRate
        }
        return rms
    }

    private func duration(of url: URL) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.processingFormat.sampleRate
    }

    @Test func testEmptyEditListProducesCopyOfInput() async throws {
        let input = try makeToneWAV(
            toneSchedule: [(0, 1000)],
            durationSeconds: 2.0
        )
        defer { try? FileManager.default.removeItem(at: input) }

        let cutter = AudioCutter()
        let output = try await cutter.apply(input: input, editList: EditList())
        defer { try? FileManager.default.removeItem(at: output) }

        let inDur = try duration(of: input)
        let outDur = try duration(of: output)
        #expect(abs(outDur - inDur) < 0.05)
    }

    @Test func testSingleCutShortensDuration() async throws {
        let input = try makeToneWAV(
            toneSchedule: [(0, 1000)],
            durationSeconds: 5.0
        )
        defer { try? FileManager.default.removeItem(at: input) }

        var list = EditList()
        list.pauses = [PauseEdit(timeRange: 2.0...2.2, isEnabled: true)]

        let cutter = AudioCutter()
        let output = try await cutter.apply(input: input, editList: list)
        defer { try? FileManager.default.removeItem(at: output) }

        let outDur = try duration(of: output)
        #expect(abs(outDur - 4.8) < 0.05)
    }

    @Test func testContentPositioningRMSPattern() async throws {
        // 1kHz from 0-2s, silence 2-3s, 2kHz from 3-5s. Cut the silence (2-3s).
        // Expected RMS pattern: [tone, tone, tone, tone] (silence removed).
        let input = try makeToneWAV(
            toneSchedule: [(0, 1000), (2, 0), (3, 2000)],
            durationSeconds: 5.0
        )
        defer { try? FileManager.default.removeItem(at: input) }

        var list = EditList()
        list.pauses = [PauseEdit(timeRange: 2.0...3.0, isEnabled: true)]

        let cutter = AudioCutter()
        let output = try await cutter.apply(input: input, editList: list)
        defer { try? FileManager.default.removeItem(at: output) }

        let rms = try rmsBySecond(output)
        // 4 seconds of output. Each second should have non-trivial RMS (no silent second).
        #expect(rms.count == 4)
        for value in rms {
            #expect(value > 0.1, "second-by-second RMS should be > 0.1; got \(value)")
        }
    }

    @Test func testAllDisabledEqualsEmptyList() async throws {
        let input = try makeToneWAV(
            toneSchedule: [(0, 1000)],
            durationSeconds: 2.0
        )
        defer { try? FileManager.default.removeItem(at: input) }

        var list = EditList()
        list.pauses = [PauseEdit(timeRange: 0.5...1.0, isEnabled: false)]

        let cutter = AudioCutter()
        let output = try await cutter.apply(input: input, editList: list)
        defer { try? FileManager.default.removeItem(at: output) }

        let outDur = try duration(of: output)
        let inDur = try duration(of: input)
        #expect(abs(outDur - inDur) < 0.05)
    }
}
