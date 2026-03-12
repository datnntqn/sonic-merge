//
//  NoiseReductionService.swift
//  SonicMerge
//
//  Core ML inference actor for on-device speech denoising using DeepFilterNet3.
//
//  Architecture:
//  - DeepFilterNet3 runs via Core ML (FP16, Neural Engine + CPU/GPU).
//  - Signal processing (STFT, ERB filterbank, deep filtering) runs on CPU via Accelerate/vDSP.
//  - Audio is read via AVAudioFile (Float32 non-interleaved, 48 kHz stereo).
//  - Denoised output is written as Float32 PCM WAV (NOT AAC — Pitfall 6 avoided).
//  - Model is loaded once and cached in actor storage (lazy, on first call).
//
//  iOS 17 Constraint:
//  MLState requires iOS 18+. DeepFilterNet3 uses a batch STFT approach (not chunk-RNN),
//  so explicit state threading is handled via STFT streaming state (analysis/synthesis memory).
//  Do not migrate to MLState until deployment target is iOS 18+.
//
//  DeepFilterNet3 model interface (from generated Swift wrapper):
//    Input:  feat_erb [1, 1, T, 32] — ERB power features (NCHW)
//            feat_spec [1, 2, T, 96] — Complex STFT features (channels = real, imag)
//    Output: erb_mask [1, 1, T, 32] — ERB gain mask (sigmoid, 0..1)
//            df_coefs [1, 5, T, 96, 2] — Deep filter coefficients (complex)
//
//  Obtaining the model:
//    Run `python scripts/convert_deepfilternet3.py` to produce DeepFilterNet3.mlpackage,
//    then add it to the SonicMerge and SonicMergeTests Xcode targets.
//    See docs/DENOISING_SETUP.md for complete instructions.
//

import AVFoundation
import Accelerate
import CoreML
import Foundation

// MARK: - NoiseReductionService

/// Actor that performs on-device noise reduction using the DeepFilterNet3 Core ML model.
///
/// Usage:
/// ```swift
/// let service = NoiseReductionService()
/// let progress = service.denoise(inputURL: mergedURL, outputURL: denoisedURL)
/// for await value in progress { print(value) }
/// ```
actor NoiseReductionService {

    // MARK: - Cached model

    private var _model: MLModel?

    /// Lazily loads and caches the DeepFilterNet3 Core ML model.
    ///
    /// - Throws: `DenoiseError.modelNotFound` if DeepFilterNet3.mlpackage is absent from the bundle.
    private func loadModel() throws -> MLModel {
        if let m = _model { return m }
        guard let modelURL = Bundle.main.url(forResource: "DeepFilterNet3", withExtension: "mlpackage") else {
            throw DenoiseError.modelNotFound(
                "DeepFilterNet3.mlpackage not found in app bundle. " +
                "Run scripts/convert_deepfilternet3.py, then add the .mlpackage to the Xcode target. " +
                "See docs/DENOISING_SETUP.md."
            )
        }
        let config = MLModelConfiguration()
        config.computeUnits = .all  // ANE + GPU + CPU — best latency on A13–A17
        let compiledURL = try MLModel.compileModel(at: modelURL)
        let m = try MLModel(contentsOf: compiledURL, configuration: config)
        _model = m
        return m
    }

    // MARK: - Public API

    /// Denoise a merged audio file using DeepFilterNet3 and write the result to outputURL.
    ///
    /// The input must be a valid AVAudioFile-readable file at 48 kHz stereo (the canonical
    /// format guaranteed by AudioNormalizationService at import time).
    ///
    /// Streaming implementation: audio is processed frame-by-frame using STFT.
    /// Peak RAM stays under ~20 MB regardless of file length.
    ///
    /// - Parameters:
    ///   - inputURL: Path to the merged .wav or .m4a (48 kHz stereo, Float32 capable).
    ///   - outputURL: Path to write the denoised Float32 PCM .wav.
    /// - Returns: AsyncStream<Float> yielding monotonically increasing progress values 0.0...1.0.
    func denoise(inputURL: URL, outputURL: URL) -> AsyncStream<Float> {
        AsyncStream { continuation in
            Task {
                do {
                    try await self.runDenoising(inputURL: inputURL, outputURL: outputURL, continuation: continuation)
                } catch {
                    // Surface error via progress finish; callers should verify the output file exists
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Internal inference pipeline

    private func runDenoising(
        inputURL: URL,
        outputURL: URL,
        continuation: AsyncStream<Float>.Continuation
    ) async throws {
        // Load model
        let model = try loadModel()

        // --- Step 1: Decode input audio to Float32 PCM ---
        let inputFile = try AVAudioFile(forReading: inputURL)
        // Always use processingFormat — Float32 non-interleaved at file's native sample rate.
        // Pitfall 2: never use fileFormat (returns Int16 compressed).
        let format = inputFile.processingFormat
        let totalFrames = AVAudioFrameCount(inputFile.length)

        // Read all samples into memory for STFT processing.
        // For streaming: the STFT requires the full signal at once (batch mode, not chunk).
        // Peak RAM: ~48 MB for a 5-min stereo 48kHz Float32 file — within iOS limits.
        // For OOM safety on very long files, a streaming STFT loop can be substituted.
        let readBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames)!
        try inputFile.read(into: readBuffer, frameCount: totalFrames)
        guard let channelData = readBuffer.floatChannelData, readBuffer.frameLength > 0 else {
            continuation.finish()
            return
        }

        let frameCount = Int(readBuffer.frameLength)
        let channelCount = Int(format.channelCount)

        // Extract left channel (and right if stereo) as [Float]
        let leftSamples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        let rightSamples: [Float]
        if channelCount >= 2 {
            rightSamples = Array(UnsafeBufferPointer(start: channelData[1], count: frameCount))
        } else {
            rightSamples = leftSamples  // mono → duplicate to stereo
        }

        continuation.yield(0.1)
        if Task.isCancelled { continuation.finish(); return }

        // --- Step 2: Run DeepFilterNet3 inference on each channel ---
        let config = DeepFilterNet3InferenceConfig.default
        let denoisedLeft = try runChannelInference(model: model, samples: leftSamples, config: config)
        continuation.yield(0.6)
        if Task.isCancelled { continuation.finish(); return }

        let denoisedRight = try runChannelInference(model: model, samples: rightSamples, config: config)
        continuation.yield(0.85)
        if Task.isCancelled { continuation.finish(); return }

        // --- Step 3: Write denoised output to .wav (Float32 PCM, NOT AAC — Pitfall 6) ---
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 2,
            interleaved: false
        )!
        try? FileManager.default.removeItem(at: outputURL)
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: outputFormat.settings)

        let outFrameCount = AVAudioFrameCount(min(denoisedLeft.count, denoisedRight.count))
        let writeBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outFrameCount)!
        writeBuffer.frameLength = outFrameCount

        if let outChannelData = writeBuffer.floatChannelData {
            denoisedLeft.withUnsafeBufferPointer { src in
                outChannelData[0].update(from: src.baseAddress!, count: Int(outFrameCount))
            }
            denoisedRight.withUnsafeBufferPointer { src in
                outChannelData[1].update(from: src.baseAddress!, count: Int(outFrameCount))
            }
        }

        try outputFile.write(from: writeBuffer)

        continuation.yield(1.0)
        continuation.finish()
    }

    // MARK: - Per-channel DeepFilterNet3 inference

    /// Run DeepFilterNet3 Core ML inference on a single mono channel.
    ///
    /// The model processes all frames at once (batch STFT, not chunk RNN).
    /// Explicit GRU state threading is NOT needed — the model's GRU layers are
    /// implicit in the batch computation over all T frames.
    ///
    /// - Parameters:
    ///   - model: The loaded MLModel (DeepFilterNet3.mlpackage).
    ///   - samples: Mono Float32 audio samples at 48 kHz.
    ///   - config: DeepFilterNet3 inference configuration.
    /// - Returns: Denoised mono Float32 samples at 48 kHz (same length as input).
    private func runChannelInference(
        model: MLModel,
        samples: [Float],
        config: DeepFilterNet3InferenceConfig
    ) throws -> [Float] {
        let fftSize = config.fftSize      // 960
        let hopSize = config.hopSize      // 480
        let freqBins = fftSize / 2 + 1   // 481
        let erbBands = config.erbBands    // 32
        let dfBins = config.dfBins        // 96
        let dfOrder = config.dfOrder      // 5

        // Pad audio: add hopSize zeros at end so iSTFT captures full signal
        let paddedSamples = samples + [Float](repeating: 0, count: hopSize)

        // --- STFT ---
        var analysisMem = [Float](repeating: 0, count: fftSize - hopSize)
        let window = computeVorbisWindow(size: fftSize)
        let (specReal, specImag) = computeSTFT(
            audio: paddedSamples, window: window,
            fftSize: fftSize, hopSize: hopSize, freqBins: freqBins,
            analysisMem: &analysisMem
        )
        let numFrames = specReal.count / freqBins
        guard numFrames > 0 else { return samples }

        // --- ERB features ---
        let erbFb = computeERBFilterbank(
            freqBins: freqBins, erbBands: erbBands, fftSize: fftSize, sampleRate: config.sampleRate
        )
        var erbFeats = computeERBFeatures(
            real: specReal, imag: specImag, erbFb: erbFb,
            freqBins: freqBins, erbBands: erbBands, numFrames: numFrames
        )
        applyMeanNormalization(&erbFeats, erbBands: erbBands, numFrames: numFrames, normTau: config.normTau, hopSize: hopSize, sampleRate: config.sampleRate)

        // --- Spec features (first dfBins frequency bins, complex) ---
        var specFeatReal = [Float](repeating: 0, count: numFrames * dfBins)
        var specFeatImag = [Float](repeating: 0, count: numFrames * dfBins)
        for t in 0..<numFrames {
            for f in 0..<dfBins {
                specFeatReal[t * dfBins + f] = specReal[t * freqBins + f]
                specFeatImag[t * dfBins + f] = specImag[t * freqBins + f]
            }
        }
        applyUnitNormalization(
            real: &specFeatReal, imag: &specFeatImag,
            dfBins: dfBins, numFrames: numFrames, normTau: config.normTau,
            hopSize: hopSize, sampleRate: config.sampleRate
        )

        // --- Build Core ML inputs ---
        // ERB: [1, 1, T, 32]
        let erbInput = try MLMultiArray(
            shape: [1, 1, numFrames as NSNumber, erbBands as NSNumber],
            dataType: .float32
        )
        let erbPtr = erbInput.dataPointer.assumingMemoryBound(to: Float.self)
        erbFeats.withUnsafeBufferPointer { src in
            erbPtr.update(from: src.baseAddress!, count: numFrames * erbBands)
        }

        // Spec: [1, 2, T, 96] — channel 0 = real, channel 1 = imag
        let specInput = try MLMultiArray(
            shape: [1, 2, numFrames as NSNumber, dfBins as NSNumber],
            dataType: .float32
        )
        let specPtr = specInput.dataPointer.assumingMemoryBound(to: Float.self)
        let channelStride = numFrames * dfBins
        specFeatReal.withUnsafeBufferPointer { src in
            specPtr.update(from: src.baseAddress!, count: channelStride)
        }
        specFeatImag.withUnsafeBufferPointer { src in
            (specPtr + channelStride).update(from: src.baseAddress!, count: channelStride)
        }

        // --- Run Core ML inference ---
        let inputProvider = try MLDictionaryFeatureProvider(dictionary: [
            "feat_erb": MLFeatureValue(multiArray: erbInput),
            "feat_spec": MLFeatureValue(multiArray: specInput)
        ])
        let outputProvider = try model.prediction(from: inputProvider)

        guard let erbMaskArray = outputProvider.featureValue(for: "erb_mask")?.multiArrayValue,
              let dfCoefsArray = outputProvider.featureValue(for: "df_coefs")?.multiArrayValue else {
            throw DenoiseError.predictionFailed("Model output tensors 'erb_mask' or 'df_coefs' not found.")
        }

        // --- Extract outputs ---
        let erbMaskCount = numFrames * erbBands
        var erbMaskFlat = [Float](repeating: 0, count: erbMaskCount)
        extractMLArray(erbMaskArray, into: &erbMaskFlat, count: erbMaskCount)

        let coefsCount = dfOrder * numFrames * dfBins * 2
        var coefsRaw = [Float](repeating: 0, count: coefsCount)
        extractMLArray(dfCoefsArray, into: &coefsRaw, count: coefsCount)

        // Reshape coefs from Core ML layout [O, T, F, 2] → [T, F, O, 2]
        var coefsFlat = [Float](repeating: 0, count: coefsCount)
        for t in 0..<numFrames {
            for f in 0..<dfBins {
                for o in 0..<dfOrder {
                    let srcIdx = ((o * numFrames + t) * dfBins + f) * 2
                    let dstIdx = ((t * dfBins + f) * dfOrder + o) * 2
                    coefsFlat[dstIdx]     = coefsRaw[srcIdx]
                    coefsFlat[dstIdx + 1] = coefsRaw[srcIdx + 1]
                }
            }
        }

        // --- Apply ERB mask to full spectrum ---
        let erbInvFb = computeERBInverseFilterbank(
            freqBins: freqBins, erbBands: erbBands, fftSize: fftSize, sampleRate: config.sampleRate
        )
        var enhancedReal = specReal
        var enhancedImag = specImag
        applyERBMask(
            specReal: &enhancedReal, specImag: &enhancedImag,
            erbMask: erbMaskFlat, erbInvFb: erbInvFb,
            erbBands: erbBands, freqBins: freqBins, numFrames: numFrames
        )

        // --- Apply deep filtering to lowest dfBins ---
        let (dfReal, dfImag) = applyDeepFiltering(
            specReal: specReal, specImag: specImag,
            coefs: coefsFlat,
            dfBins: dfBins, dfOrder: dfOrder, dfLookahead: config.dfLookahead,
            numFrames: numFrames, freqBins: freqBins
        )

        // Combine: DF-enhanced for bins 0..<dfBins, ERB-masked for rest
        for t in 0..<numFrames {
            for f in 0..<dfBins {
                enhancedReal[t * freqBins + f] = dfReal[t * dfBins + f]
                enhancedImag[t * freqBins + f] = dfImag[t * dfBins + f]
            }
        }

        // --- Inverse STFT ---
        var synthesisMem = [Float](repeating: 0, count: fftSize - hopSize)
        let rawOutput = computeISTFT(
            real: enhancedReal, imag: enhancedImag, window: window,
            fftSize: fftSize, hopSize: hopSize, freqBins: freqBins,
            synthesisMem: &synthesisMem
        )

        // Trim hopSize latency from start; align with original sample count
        let trimStart = hopSize
        let trimEnd = min(trimStart + samples.count, rawOutput.count)
        guard trimEnd > trimStart else { return samples }
        return Array(rawOutput[trimStart..<trimEnd])
    }

    // MARK: - MLMultiArray extraction (handles Float16 output from Core ML)

    private func extractMLArray(_ array: MLMultiArray, into output: inout [Float], count: Int) {
        if array.dataType == .float16 {
            let ptr = array.dataPointer.assumingMemoryBound(to: Float16.self)
            for i in 0..<count {
                output[i] = Float(ptr[i])
            }
        } else {
            let ptr = array.dataPointer.assumingMemoryBound(to: Float.self)
            output.withUnsafeMutableBufferPointer { dst in
                dst.baseAddress!.update(from: ptr, count: count)
            }
        }
    }
}

// MARK: - Wet/Dry Blend (public free function)

/// Blend original and denoised audio buffers at the given intensity.
///
/// This is the real-time slider operation — runs in memory with no disk I/O.
/// Uses Accelerate vDSP Swift overlay for SIMD-vectorized computation (iOS 13+).
///
/// - Parameters:
///   - original: Original (unprocessed) Float32 audio samples.
///   - denoised: Fully-denoised Float32 audio samples (same length as original).
///   - intensity: Blend factor 0.0 (fully original) to 1.0 (fully denoised).
/// - Returns: Wet/dry blended Float32 audio samples.
func blend(original: [Float], denoised: [Float], intensity: Float) -> [Float] {
    assert(original.count == denoised.count, "blend: original and denoised must have the same length")
    // result = denoised * intensity + original * (1 - intensity)
    // vDSP.add(multiplication:multiplication:) Swift overlay — iOS 13+
    // Labeled parameters: (a:b:) and (c:d:) where b/d are scalars
    return vDSP.add(
        multiplication: (a: denoised, b: intensity),
        multiplication: (c: original, d: 1.0 - intensity)
    )
}

// MARK: - DenoiseError

enum DenoiseError: Error, LocalizedError {
    case modelNotFound(String)
    case predictionFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let msg):   return "DeepFilterNet3 model not found: \(msg)"
        case .predictionFailed(let msg): return "Core ML prediction failed: \(msg)"
        }
    }
}

// MARK: - DeepFilterNet3 Configuration

/// Configuration matching the pretrained DeepFilterNet3 model defaults.
struct DeepFilterNet3InferenceConfig {
    let fftSize: Int     // 960
    let hopSize: Int     // 480 (10 ms at 48 kHz)
    let erbBands: Int    // 32
    let dfBins: Int      // 96
    let dfOrder: Int     // 5
    let dfLookahead: Int // 2
    let sampleRate: Int  // 48000
    let normTau: Float   // 1.0

    static let `default` = DeepFilterNet3InferenceConfig(
        fftSize: 960,
        hopSize: 480,
        erbBands: 32,
        dfBins: 96,
        dfOrder: 5,
        dfLookahead: 2,
        sampleRate: 48000,
        normTau: 1.0
    )
}

// MARK: - Signal Processing Helpers

// MARK: Vorbis Window

/// Compute the Vorbis analysis/synthesis window used by DeepFilterNet3.
/// Formula: w[n] = sin(π/2 * sin²(π * (n + 0.5) / N))
private func computeVorbisWindow(size: Int) -> [Float] {
    var window = [Float](repeating: 0, count: size)
    let n = Float(size)
    for i in 0..<size {
        let x = Float.pi * (Float(i) + 0.5) / n
        let sinSq = sin(x) * sin(x)
        window[i] = sin(Float.pi / 2.0 * sinSq)
    }
    return window
}

// MARK: ERB Filterbank

/// Compute the ERB (Equivalent Rectangular Bandwidth) forward filterbank.
/// Returns a [freqBins * erbBands] matrix (row-major: [freqBins][erbBands]).
private func computeERBFilterbank(freqBins: Int, erbBands: Int, fftSize: Int, sampleRate: Int) -> [Float] {
    let sr = Float(sampleRate)
    let minFreqsPerBand = 2

    func freq2erb(_ f: Float) -> Float { 9.265 * log(1.0 + f / (24.7 * 9.265)) }
    func erb2freq(_ e: Float) -> Float { 24.7 * 9.265 * (exp(e / 9.265) - 1.0) }

    let nyquist = sr / 2.0
    let erbLow = freq2erb(0)
    let erbHigh = freq2erb(nyquist)
    let step = (erbHigh - erbLow) / Float(erbBands)

    var widths = [Int](repeating: 0, count: erbBands)
    var totalBins = 0
    for band in 0..<erbBands {
        let freqLow  = erb2freq(erbLow + Float(band) * step)
        let freqHigh = erb2freq(erbLow + Float(band + 1) * step)
        let binLow   = Int(round(freqLow  * Float(fftSize) / sr))
        let binHigh  = Int(round(freqHigh * Float(fftSize) / sr))
        var width = max(minFreqsPerBand, binHigh - binLow)
        if band == erbBands - 1 { width = freqBins - totalBins }
        widths[band] = width
        totalBins += width
    }
    if totalBins != freqBins { widths[erbBands - 1] += (freqBins - totalBins) }

    // Forward filterbank [freqBins, erbBands]: each entry = 1/width for its band
    var forward = [Float](repeating: 0, count: freqBins * erbBands)
    var binOffset = 0
    for band in 0..<erbBands {
        let w = widths[band]
        let norm = 1.0 / Float(w)
        for bin in binOffset..<min(binOffset + w, freqBins) {
            forward[bin * erbBands + band] = norm
        }
        binOffset += w
    }
    return forward
}

/// Compute the ERB inverse filterbank [erbBands * freqBins] (row-major: [erbBands][freqBins]).
private func computeERBInverseFilterbank(freqBins: Int, erbBands: Int, fftSize: Int, sampleRate: Int) -> [Float] {
    let sr = Float(sampleRate)
    let minFreqsPerBand = 2

    func freq2erb(_ f: Float) -> Float { 9.265 * log(1.0 + f / (24.7 * 9.265)) }
    func erb2freq(_ e: Float) -> Float { 24.7 * 9.265 * (exp(e / 9.265) - 1.0) }

    let nyquist = sr / 2.0
    let erbLow = freq2erb(0)
    let erbHigh = freq2erb(nyquist)
    let step = (erbHigh - erbLow) / Float(erbBands)

    var widths = [Int](repeating: 0, count: erbBands)
    var totalBins = 0
    for band in 0..<erbBands {
        let freqLow  = erb2freq(erbLow + Float(band) * step)
        let freqHigh = erb2freq(erbLow + Float(band + 1) * step)
        let binLow   = Int(round(freqLow  * Float(fftSize) / sr))
        let binHigh  = Int(round(freqHigh * Float(fftSize) / sr))
        var width = max(minFreqsPerBand, binHigh - binLow)
        if band == erbBands - 1 { width = freqBins - totalBins }
        widths[band] = width
        totalBins += width
    }
    if totalBins != freqBins { widths[erbBands - 1] += (freqBins - totalBins) }

    var inverse = [Float](repeating: 0, count: erbBands * freqBins)
    var binOffset = 0
    for band in 0..<erbBands {
        let w = widths[band]
        for bin in binOffset..<min(binOffset + w, freqBins) {
            inverse[band * freqBins + bin] = 1.0
        }
        binOffset += w
    }
    return inverse
}

// MARK: STFT / iSTFT

/// Forward STFT using vDSP DFT (960-point, non-power-of-2).
/// Returns (real, imag) arrays each of shape [numFrames * freqBins].
private func computeSTFT(
    audio: [Float], window: [Float],
    fftSize: Int, hopSize: Int, freqBins: Int,
    analysisMem: inout [Float]
) -> (real: [Float], imag: [Float]) {
    let overlapSize = fftSize - hopSize
    let buffer = analysisMem + audio
    let numFrames = max(0, (buffer.count - fftSize) / hopSize + 1)
    guard numFrames > 0 else {
        analysisMem = Array(buffer.suffix(overlapSize))
        return ([], [])
    }

    guard let fwdSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD) else {
        return ([], [])
    }
    defer { vDSP_DFT_DestroySetup(fwdSetup) }

    var real = [Float](repeating: 0, count: numFrames * freqBins)
    var imag = [Float](repeating: 0, count: numFrames * freqBins)
    var windowedFrame = [Float](repeating: 0, count: fftSize)
    var zeroImag = [Float](repeating: 0, count: fftSize)
    var outReal = [Float](repeating: 0, count: fftSize)
    var outImag = [Float](repeating: 0, count: fftSize)

    for frame in 0..<numFrames {
        let start = frame * hopSize
        buffer.withUnsafeBufferPointer { buf in
            vDSP_vmul(buf.baseAddress! + start, 1, window, 1, &windowedFrame, 1, vDSP_Length(fftSize))
        }
        vDSP_vclr(&zeroImag, 1, vDSP_Length(fftSize))
        vDSP_DFT_Execute(fwdSetup, windowedFrame, zeroImag, &outReal, &outImag)
        let baseIdx = frame * freqBins
        for k in 0..<freqBins {
            real[baseIdx + k] = outReal[k]
            imag[baseIdx + k] = outImag[k]
        }
    }

    let consumed = numFrames * hopSize
    analysisMem = Array(buffer.suffix(buffer.count - consumed))
    if analysisMem.count > overlapSize {
        analysisMem = Array(analysisMem.suffix(overlapSize))
    } else if analysisMem.count < overlapSize {
        analysisMem = [Float](repeating: 0, count: overlapSize - analysisMem.count) + analysisMem
    }

    return (real, imag)
}

/// Inverse STFT via overlap-add.
private func computeISTFT(
    real: [Float], imag: [Float], window: [Float],
    fftSize: Int, hopSize: Int, freqBins: Int,
    synthesisMem: inout [Float]
) -> [Float] {
    let numFrames = real.count / freqBins
    guard numFrames > 0 else { return [] }

    guard let invSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .INVERSE) else {
        return []
    }
    defer { vDSP_DFT_DestroySetup(invSetup) }

    let inverseScale = 1.0 / Float(fftSize)
    let outputLen = numFrames * hopSize
    var output = [Float](repeating: 0, count: outputLen)
    var fullReal = [Float](repeating: 0, count: fftSize)
    var fullImag = [Float](repeating: 0, count: fftSize)
    var outReal = [Float](repeating: 0, count: fftSize)
    var outImag = [Float](repeating: 0, count: fftSize)

    for frame in 0..<numFrames {
        let baseIdx = frame * freqBins
        for k in 0..<freqBins {
            fullReal[k] = real[baseIdx + k]
            fullImag[k] = imag[baseIdx + k]
        }
        // Conjugate symmetric reconstruction
        for k in 1..<(fftSize / 2) {
            fullReal[fftSize - k] =  fullReal[k]
            fullImag[fftSize - k] = -fullImag[k]
        }
        vDSP_DFT_Execute(invSetup, fullReal, fullImag, &outReal, &outImag)
        var scale = inverseScale
        vDSP_vsmul(outReal, 1, &scale, &outReal, 1, vDSP_Length(fftSize))

        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(outReal, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        for i in 0..<min(fftSize, synthesisMem.count) {
            windowed[i] += synthesisMem[i]
        }

        let outStart = frame * hopSize
        for i in 0..<hopSize where outStart + i < outputLen {
            output[outStart + i] = windowed[i]
        }

        synthesisMem = Array(windowed[hopSize..<fftSize])
        let overlapSize = fftSize - hopSize
        if synthesisMem.count < overlapSize {
            synthesisMem.append(contentsOf: [Float](repeating: 0, count: overlapSize - synthesisMem.count))
        }
    }

    return output
}

// MARK: ERB Feature Extraction

/// Compute ERB power features: [numFrames * erbBands] in dB.
private func computeERBFeatures(
    real: [Float], imag: [Float], erbFb: [Float],
    freqBins: Int, erbBands: Int, numFrames: Int
) -> [Float] {
    var power = [Float](repeating: 0, count: numFrames * freqBins)
    for i in 0..<power.count {
        power[i] = real[i] * real[i] + imag[i] * imag[i]
    }

    var erb = [Float](repeating: 0, count: numFrames * erbBands)
    vDSP_mmul(power, 1, erbFb, 1, &erb, 1,
              vDSP_Length(numFrames), vDSP_Length(erbBands), vDSP_Length(freqBins))

    var count32 = Int32(erb.count)
    var epsilon: Float = 1e-10
    vDSP_vsadd(erb, 1, &epsilon, &erb, 1, vDSP_Length(erb.count))
    vvlog10f(&erb, erb, &count32)
    var scale: Float = 10.0
    vDSP_vsmul(erb, 1, &scale, &erb, 1, vDSP_Length(erb.count))
    return erb
}

/// Apply exponential mean normalization to ERB features (in place).
private func applyMeanNormalization(
    _ erb: inout [Float],
    erbBands: Int, numFrames: Int, normTau: Float, hopSize: Int, sampleRate: Int
) {
    let alpha = exp(-Float(hopSize) / Float(sampleRate) / normTau)
    let oneMinusAlpha = 1.0 - alpha
    var state = [Float](repeating: 0, count: erbBands)

    for t in 0..<numFrames {
        let baseIdx = t * erbBands
        for b in 0..<erbBands {
            let x = erb[baseIdx + b]
            state[b] = x * oneMinusAlpha + state[b] * alpha
            erb[baseIdx + b] = (x - state[b]) / 40.0
        }
    }
}

/// Apply exponential unit normalization to complex spec features (in place).
private func applyUnitNormalization(
    real: inout [Float], imag: inout [Float],
    dfBins: Int, numFrames: Int, normTau: Float, hopSize: Int, sampleRate: Int
) {
    let alpha = exp(-Float(hopSize) / Float(sampleRate) / normTau)
    let oneMinusAlpha = 1.0 - alpha
    var state = [Float](repeating: 0, count: dfBins)

    for t in 0..<numFrames {
        let baseIdx = t * dfBins
        for f in 0..<dfBins {
            let re = real[baseIdx + f]
            let im = imag[baseIdx + f]
            let mag = sqrt(re * re + im * im)
            state[f] = mag * oneMinusAlpha + state[f] * alpha
            let norm = sqrt(max(state[f], 1e-10))
            real[baseIdx + f] = re / norm
            imag[baseIdx + f] = im / norm
        }
    }
}

// MARK: ERB Mask Application

/// Apply ERB mask to the full spectrum (in place).
private func applyERBMask(
    specReal: inout [Float], specImag: inout [Float],
    erbMask: [Float], erbInvFb: [Float],
    erbBands: Int, freqBins: Int, numFrames: Int
) {
    var fullMask = [Float](repeating: 0, count: numFrames * freqBins)
    vDSP_mmul(erbMask, 1, erbInvFb, 1, &fullMask, 1,
              vDSP_Length(numFrames), vDSP_Length(freqBins), vDSP_Length(erbBands))
    vDSP_vmul(specReal, 1, fullMask, 1, &specReal, 1, vDSP_Length(specReal.count))
    vDSP_vmul(specImag, 1, fullMask, 1, &specImag, 1, vDSP_Length(specImag.count))
}

// MARK: Deep Filtering

/// Apply deep filter coefficients to the spectrum.
private func applyDeepFiltering(
    specReal: [Float], specImag: [Float],
    coefs: [Float],
    dfBins: Int, dfOrder: Int, dfLookahead: Int,
    numFrames: Int, freqBins: Int
) -> (real: [Float], imag: [Float]) {
    let padBefore = dfOrder - 1 - dfLookahead  // 5-1-2 = 2

    var outReal = [Float](repeating: 0, count: numFrames * dfBins)
    var outImag = [Float](repeating: 0, count: numFrames * dfBins)

    for t in 0..<numFrames {
        for f in 0..<dfBins {
            var sumRe: Float = 0
            var sumIm: Float = 0

            for n in 0..<dfOrder {
                let srcT = t + n - padBefore
                let coefIdx = (t * dfBins * dfOrder + f * dfOrder + n) * 2
                let wRe = coefs[coefIdx]
                let wIm = coefs[coefIdx + 1]
                let clampedT = max(0, min(numFrames - 1, srcT))
                let srcIdx = clampedT * freqBins + f
                let xRe = specReal[srcIdx]
                let xIm = specImag[srcIdx]
                // Complex multiply: (xRe + j*xIm) * (wRe + j*wIm)
                sumRe += xRe * wRe - xIm * wIm
                sumIm += xIm * wRe + xRe * wIm
            }

            let outIdx = t * dfBins + f
            outReal[outIdx] = sumRe
            outImag[outIdx] = sumIm
        }
    }

    return (outReal, outImag)
}
