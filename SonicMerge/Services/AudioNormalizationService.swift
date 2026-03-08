//
//  AudioNormalizationService.swift
//  SonicMerge
//
//  Transcodes any AVFoundation-readable audio file to 48 kHz / stereo / AAC .m4a.
//  This is the canonical gate that every imported file must pass before its URL
//  is persisted in SwiftData. Prevents silent AVMutableComposition corruption
//  caused by mismatched sample rates or channel counts downstream.
//

import AVFoundation
import AVFAudio

actor AudioNormalizationService {

    static let canonicalSampleRate: Double = 48_000
    static let canonicalChannels: Int = 2
    static let canonicalBitRate: Int = 128_000

    /// Transcode sourceURL to destinationURL as 48 kHz / stereo / AAC .m4a.
    /// All AVFoundation work is contained within this actor method — no AVFoundation
    /// objects cross actor boundaries (Swift 6 Sendable compliance).
    func normalize(sourceURL: URL, destinationURL: URL) async throws {
        // 1. Load asset and detect source channel count BEFORE setting up reader/writer
        let asset = AVURLAsset(url: sourceURL)
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw NormalizationError.noAudioTrack
        }

        // Detect mono vs stereo from format description
        let formatDescriptions = try await audioTrack.load(.formatDescriptions)
        let sourceChannelCount: UInt32 = formatDescriptions.first.flatMap { desc in
            let cmDesc = desc as! CMAudioFormatDescription
            return CMAudioFormatDescriptionGetStreamBasicDescription(cmDesc)
                .map { UInt32($0.pointee.mChannelsPerFrame) }
        } ?? 1
        let isMono = sourceChannelCount == 1

        // 2. Set up AVAssetReader — decompress to Linear PCM
        let reader = try AVAssetReader(asset: asset)
        let readerOutputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: readerOutputSettings)
        reader.add(readerOutput)

        // 3. Set up mono-to-stereo converter (only if source is mono)
        let monoConverter: AVAudioConverter?
        if isMono {
            // kAudioFormatLinearPCM 16-bit interleaved at canonical sample rate.
            // Reader emits at source sample rate; AVAudioConverter resamples to 48kHz stereo.
            let monoLayout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Mono)!
            let srcFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: AudioNormalizationService.canonicalSampleRate,
                interleaved: true,
                channelLayout: monoLayout
            )
            let stereoLayout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Stereo)!
            let dstFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: AudioNormalizationService.canonicalSampleRate,
                interleaved: true,
                channelLayout: stereoLayout
            )
            guard let conv = AVAudioConverter(from: srcFormat, to: dstFormat) else {
                throw NormalizationError.monoUpmixFailed
            }
            conv.channelMap = [0, 0]  // Route mono channel to both L and R outputs
            monoConverter = conv
        } else {
            monoConverter = nil
        }

        // 4. Set up AVAssetWriter — encode to AAC 48 kHz stereo
        var acl = AudioChannelLayout()
        acl.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
        acl.mChannelBitmap = AudioChannelBitmap(rawValue: 0)
        acl.mNumberChannelDescriptions = 0

        let writerInputSettings: [String: Any] = [
            AVFormatIDKey:          UInt(kAudioFormatMPEG4AAC),
            AVNumberOfChannelsKey:  UInt(AudioNormalizationService.canonicalChannels),
            AVSampleRateKey:        AudioNormalizationService.canonicalSampleRate,
            AVEncoderBitRateKey:    AudioNormalizationService.canonicalBitRate,
            AVChannelLayoutKey:     NSData(bytes: &acl, length: MemoryLayout<AudioChannelLayout>.size)
        ]

        // Remove existing file at destination (AVAssetWriter fails if file already exists)
        try? FileManager.default.removeItem(at: destinationURL)

        let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .m4a)
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: writerInputSettings)
        writerInput.expectsMediaDataInRealTime = false
        writer.add(writerInput)

        // 5. Transcode
        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: .zero)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let queue = DispatchQueue(label: "com.sonicmerge.audio.normalize", qos: .userInitiated)
            writerInput.requestMediaDataWhenReady(on: queue) {
                while writerInput.isReadyForMoreMediaData {
                    if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                        if let converter = monoConverter {
                            // Convert CMSampleBuffer -> AVAudioPCMBuffer -> upmix -> CMSampleBuffer
                            if let converted = Self.upmixMonoBuffer(sampleBuffer, converter: converter) {
                                writerInput.append(converted)
                            }
                        } else {
                            writerInput.append(sampleBuffer)
                        }
                    } else {
                        writerInput.markAsFinished()
                        Task {
                            await writer.finishWriting()
                            continuation.resume()
                        }
                        return
                    }
                }
            }
        }

        if writer.status == .failed {
            throw writer.error ?? NormalizationError.writeFailed
        }
    }

    /// Convert a mono CMSampleBuffer to stereo by duplicating the channel via AVAudioConverter.
    /// Returns nil if conversion fails (caller skips the buffer rather than crashing).
    private static func upmixMonoBuffer(
        _ inputBuffer: CMSampleBuffer,
        converter: AVAudioConverter
    ) -> CMSampleBuffer? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(inputBuffer) else { return nil }
        let numSamples = CMSampleBufferGetNumSamples(inputBuffer)
        guard numSamples > 0 else { return nil }

        // Extract timing from source buffer
        var timingInfo = CMSampleTimingInfo()
        CMSampleBufferGetSampleTimingInfo(inputBuffer, at: 0, timingInfoOut: &timingInfo)

        // Create mono PCM buffer from CMSampleBuffer data
        let monoFormat = converter.inputFormat
        guard let monoPCM = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: AVAudioFrameCount(numSamples)) else { return nil }
        monoPCM.frameLength = AVAudioFrameCount(numSamples)

        // Copy int16 data from CMBlockBuffer
        var dataLength = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &dataLength, dataPointerOut: &dataPointer) == noErr,
              let src = dataPointer,
              let dst = monoPCM.int16ChannelData?[0] else { return nil }
        memcpy(dst, src, min(dataLength, numSamples * 2)) // int16 = 2 bytes per sample

        // Convert mono to stereo
        let stereoFormat = converter.outputFormat
        guard let stereoPCM = AVAudioPCMBuffer(pcmFormat: stereoFormat, frameCapacity: AVAudioFrameCount(numSamples)) else { return nil }

        var conversionError: NSError?
        let status = converter.convert(to: stereoPCM, error: &conversionError) { _, outStatus in
            outStatus.pointee = .haveData
            return monoPCM
        }
        guard status != .error else { return nil }

        // Convert AVAudioPCMBuffer back to CMSampleBuffer
        // Rebuild CMSampleBuffer from stereo PCM buffer with original timing
        guard let stereoData = stereoPCM.int16ChannelData else { return nil }
        let stereoBytes = Int(stereoPCM.frameLength) * 2 * 2 // frames * channels * bytes/sample

        var blockBuf: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(
            allocator: nil,
            memoryBlock: nil,
            blockLength: stereoBytes,
            blockAllocator: nil,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: stereoBytes,
            flags: 0,
            blockBufferOut: &blockBuf
        ) == noErr, let blockBuf else { return nil }

        CMBlockBufferFillDataBytes(
            with: 0,
            blockBuffer: blockBuf,
            offsetIntoDestination: 0,
            dataLength: stereoBytes
        )

        // Interleave L and R channels into block buffer
        if let dst16 = blockBuf.dataPointer?.assumingMemoryBound(to: Int16.self) {
            let l = stereoData[0]
            let r = stereoData[1]
            for i in 0..<Int(stereoPCM.frameLength) {
                dst16[i * 2] = l[i]
                dst16[i * 2 + 1] = r[i]
            }
        }

        // Build output format description for stereo 48kHz int16
        var outputASBD = AudioStreamBasicDescription(
            mSampleRate: 48_000,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
            mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4,
            mChannelsPerFrame: 2, mBitsPerChannel: 16, mReserved: 0
        )
        var fmtDesc: CMAudioFormatDescription?
        guard CMAudioFormatDescriptionCreate(
            allocator: nil,
            asbd: &outputASBD,
            layoutSize: 0, layout: nil,
            magicCookieSize: 0, magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &fmtDesc
        ) == noErr, let fmtDesc else { return nil }

        var outBuffer: CMSampleBuffer?
        CMSampleBufferCreate(
            allocator: nil,
            dataBuffer: blockBuf,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: fmtDesc,
            sampleCount: CMItemCount(stereoPCM.frameLength),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &outBuffer
        )
        return outBuffer
    }
}

enum NormalizationError: Error, LocalizedError {
    case noAudioTrack
    case writeFailed
    case monoUpmixFailed

    var errorDescription: String? {
        switch self {
        case .noAudioTrack: return "Source file contains no audio tracks."
        case .writeFailed: return "AVAssetWriter failed to write output file."
        case .monoUpmixFailed: return "Failed to create AVAudioConverter for mono-to-stereo upmix."
        }
    }
}

// CMBlockBuffer convenience extension for raw data pointer access
private extension CMBlockBuffer {
    var dataPointer: UnsafeMutableRawPointer? {
        var pointer: UnsafeMutablePointer<Int8>?
        var length = 0
        CMBlockBufferGetDataPointer(self, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer)
        return pointer.map { UnsafeMutableRawPointer($0) }
    }
}
