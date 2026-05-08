// SonicMergeTests/Services/VideoAudioExtractorTests.swift
import Testing
import Foundation
import AVFoundation
@testable import SonicMerge

struct VideoAudioExtractorTests {

    /// Generate a tiny MP4 file with the given audio configuration in a temp
    /// location. Returns the URL. Caller cleans up via try? remove.
    @MainActor
    private func makeFixture(includeAudio: Bool, durationSeconds: Double) async throws -> URL {
        let outURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("fixture-\(UUID().uuidString).mp4")

        let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)

        // Video track — 64x64 black frames at 30 fps (smallest that AVAssetWriter
        // accepts cleanly).
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 64,
            AVVideoHeightKey: 64
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        let pixelAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 64,
                kCVPixelBufferHeightKey as String: 64
            ]
        )
        writer.add(videoInput)

        // Optional audio track — 16 kHz mono PCM.
        var audioInput: AVAssetWriterInput?
        if includeAudio {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 32_000
            ]
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            input.expectsMediaDataInRealTime = false
            writer.add(input)
            audioInput = input
        }

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        // Write video frames.
        let frameRate: Int32 = 30
        let totalFrames = Int(durationSeconds * Double(frameRate))
        for frameIndex in 0..<totalFrames {
            while !videoInput.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(2))
            }
            var pixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelAdaptor.pixelBufferPool!, &pixelBuffer)
            guard status == kCVReturnSuccess, let pb = pixelBuffer else {
                videoInput.markAsFinished()
                throw NSError(domain: "FixtureGen", code: -1)
            }
            CVPixelBufferLockBaseAddress(pb, [])
            // Leave bytes as default (zeros) — pure black frame is fine.
            CVPixelBufferUnlockBaseAddress(pb, [])
            let pts = CMTime(value: CMTimeValue(frameIndex), timescale: frameRate)
            pixelAdaptor.append(pb, withPresentationTime: pts)
        }
        videoInput.markAsFinished()

        // Write audio (silence) if included.
        if let audioInput {
            let sampleRate: Int = 16_000
            let totalSamples = Int(durationSeconds * Double(sampleRate))
            let chunkSamples = 1024
            var samplesWritten = 0
            let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                       sampleRate: Double(sampleRate),
                                       channels: 1,
                                       interleaved: true)!
            while samplesWritten < totalSamples {
                while !audioInput.isReadyForMoreMediaData {
                    try await Task.sleep(for: .milliseconds(2))
                }
                let thisChunk = min(chunkSamples, totalSamples - samplesWritten)
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                                    frameCapacity: AVAudioFrameCount(thisChunk)) else {
                    audioInput.markAsFinished()
                    throw NSError(domain: "FixtureGen", code: -2)
                }
                buffer.frameLength = AVAudioFrameCount(thisChunk)
                // Buffer is zeroed — silence. That's fine for the noAudioTrack
                // test (we only check track presence, not signal content).
                if let sb = sampleBuffer(from: buffer,
                                          presentationTime: CMTime(value: CMTimeValue(samplesWritten),
                                                                    timescale: CMTimeScale(sampleRate))) {
                    audioInput.append(sb)
                }
                samplesWritten += thisChunk
            }
            audioInput.markAsFinished()
        }

        await writer.finishWriting()
        if writer.status != .completed {
            throw writer.error ?? NSError(domain: "FixtureGen", code: -3)
        }
        return outURL
    }

    /// Convert AVAudioPCMBuffer to CMSampleBuffer for AVAssetWriterInput.
    private func sampleBuffer(from buffer: AVAudioPCMBuffer,
                              presentationTime: CMTime) -> CMSampleBuffer? {
        var asbdCopy = buffer.format.streamDescription.pointee
        var formatDesc: CMFormatDescription?
        guard CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault,
                                              asbd: &asbdCopy,
                                              layoutSize: 0, layout: nil,
                                              magicCookieSize: 0, magicCookie: nil,
                                              extensions: nil,
                                              formatDescriptionOut: &formatDesc) == noErr,
              let format = formatDesc else { return nil }

        var sampleBuffer: CMSampleBuffer?
        let frameCount = CMItemCount(buffer.frameLength)
        let timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(asbdCopy.mSampleRate)),
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )
        guard CMSampleBufferCreate(allocator: kCFAllocatorDefault,
                                   dataBuffer: nil,
                                   dataReady: false,
                                   makeDataReadyCallback: nil,
                                   refcon: nil,
                                   formatDescription: format,
                                   sampleCount: frameCount,
                                   sampleTimingEntryCount: 1,
                                   sampleTimingArray: [timing],
                                   sampleSizeEntryCount: 0,
                                   sampleSizeArray: nil,
                                   sampleBufferOut: &sampleBuffer) == noErr,
              let sb = sampleBuffer else { return nil }

        guard CMSampleBufferSetDataBufferFromAudioBufferList(
            sb,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: buffer.audioBufferList) == noErr else { return nil }
        return sb
    }

    @Test func extractFromAudibleVideoReturnsM4A() async throws {
        let src = try await makeFixture(includeAudio: true, durationSeconds: 1.0)
        defer { try? FileManager.default.removeItem(at: src) }

        let out = try await VideoAudioExtractor.extractAudio(from: src)
        defer { try? FileManager.default.removeItem(at: out) }

        #expect(out.pathExtension == "m4a")
        #expect(FileManager.default.fileExists(atPath: out.path))

        let asset = AVURLAsset(url: out)
        let dur = try await asset.load(.duration).seconds
        // Audio duration should be in the same ballpark as the source —
        // allow generous slack (encoders sometimes drop a few samples).
        #expect(dur > 0.5 && dur < 1.5)
    }

    @Test func extractFromSilentVideoThrowsNoAudioTrack() async throws {
        let src = try await makeFixture(includeAudio: false, durationSeconds: 0.5)
        defer { try? FileManager.default.removeItem(at: src) }

        await #expect(throws: VideoAudioExtractor.ExtractError.noAudioTrack) {
            _ = try await VideoAudioExtractor.extractAudio(from: src)
        }
    }
}
