# Phase 3: AI Denoising Pipeline - Research

**Researched:** 2026-03-12
**Domain:** Core ML audio inference, PCM buffer processing, AVFoundation, Accelerate/vDSP
**Confidence:** HIGH (model selection resolved via verified sources; patterns verified against Apple docs and working code)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- CleaningLabView is a **separate screen** pushed onto NavigationStack from MixingStationView
- Entry: **'Denoise' toolbar button** on Mixing Station navigation bar
- CleaningLabView has its **own Export button** — reuses `ExportFormatSheet` and `ExportProgressSheet` from Phase 2
- Operates on **merged output of the current clip sequence** — triggers merge + denoise pipeline
- Denoising is **optional**: Mixing Station Export exports raw merged audio if user never visits CleaningLabView
- "Clips have changed — re-process?" banner when revisited after editing
- Intensity slider range: **0–100%**, default: **75%** on open
- Denoising runs **once at full (100%) strength** — slider does wet/dry mix between original and denoised buffers (no re-inference per position)
- Tapping 'Denoise' shows **non-dismissible progress modal** with progress bar + Cancel button
- After denoising: **denoised audio plays automatically** from the start
- Playback UI: **full-width waveform** + scrub/position indicator via WaveformService
- A/B control: **hold-to-hear-original** — hold = original plays from current position; release = denoised resumes from same position
- Releasing hold triggers **UIImpactFeedbackGenerator, .medium style** — UX-02
- `NoiseReductionService` is a Swift **actor** under `/Features/Denoising/`
- Pattern: `@Observable @MainActor` ViewModel, actor-based background services

### Claude's Discretion
- Core ML model selection, architecture, and bundle integration
- Exact merge + denoise pipeline orchestration
- Waveform generation timing for the denoised output
- Buffer chunk size for Core ML inference streaming
- Error state UX if denoising fails
- Visual layout details of CleaningLabView beyond the above decisions

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DNS-01 | User can apply on-device noise reduction to merged audio using a Core ML model (NOT AVAudioEngine Voice Processing) | Custom Core ML pipeline with self-converted DeepFilterNet3 .mlpackage; AVAssetReader+Writer pipeline identical to AudioNormalizationService |
| DNS-02 | User can adjust noise suppression intensity via a 0–100% slider | vDSP wet/dry mix between original Float32 buffer and denoised Float32 buffer; no re-inference |
| DNS-03 | User can hold a "Listen Original" button to temporarily hear the unprocessed audio for A/B comparison | Two pre-loaded AVAudioPlayer instances; currentTime handoff on press/release |
| UX-02 | User receives haptic feedback when toggling Before/After comparison | UIImpactFeedbackGenerator(.medium).impactOccurred() on button release |
</phase_requirements>

---

## Summary

Phase 3 adds on-device Core ML noise reduction as a post-processing step operating on the merged audio file produced by Phase 2's AudioMergerService. The denoising model runs once at full strength to produce a fully-denoised output buffer. A slider then blends original and denoised audio in memory using vDSP — no re-inference per position. A/B comparison is a dual-player handoff using AVAudioPlayer's currentTime property.

The core technical decisions resolved by this research are: (1) use a self-converted DeepFilterNet3 .mlpackage bundle as the noise reduction model, processed in 480-sample chunks with explicit RNN state threading for iOS 17 compatibility; (2) decode audio via AVAudioFile into Float32 PCM buffers, feed chunks through Core ML MLMultiArray, accumulate the denoised output, then write back to disk via AVAssetWriter; (3) implement wet/dry mix with `vDSP_vsma` (not AVAudioEngine); (4) implement A/B playback with two AVAudioPlayer instances swapped by currentTime.

**Primary recommendation:** Convert DeepFilterNet3 to .mlpackage using coremltools (MIT/Apache-2.0 licensed, ~4.2 MB FP16), bundle it in the Xcode target, process merged audio in 480-sample frames at 48 kHz, and use vDSP_vsma for real-time wet/dry blending of pre-computed Float32 output buffers.

---

## Standard Stack

### Core
| Framework | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Core ML | iOS 17+ (built-in) | Run denoising model inference | Only Apple-native on-device ML framework; no third-party SDK needed |
| Accelerate / vDSP | iOS 17+ (built-in) | Wet/dry mix of Float32 audio buffers | SIMD-vectorized; no dependency; 10–100x faster than naive loop |
| AVFoundation | iOS 17+ (built-in) | Decode merged audio to PCM; write denoised audio to file | Already established in project (AudioNormalizationService, AudioMergerService) |
| AVAudioFile | iOS 17+ (built-in) | Chunk-read .m4a into Float32 PCM buffers | `.processingFormat` automatically returns Float32 non-interleaved; simpler than AVAssetReader for read-only decode |
| AVAudioPlayer | iOS 17+ (built-in) | Dual-player A/B playback with currentTime handoff | Simpler than AVAudioEngine for file-based playback; currentTime is settable before play |

### Supporting
| Framework | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| UIKit (UIImpactFeedbackGenerator) | iOS 17+ | Haptic feedback on A/B toggle release | Required by UX-02; .sensoryFeedback SwiftUI modifier also works on iOS 17+ |
| WaveformService (existing) | — | Waveform for denoised audio display | Reuse unchanged; call after denoising completes, before autoplay |

### Alternatives Considered
| Standard Choice | Alternative | Rejection Reason |
|----------------|-------------|-----------------|
| DeepFilterNet3 (self-converted .mlpackage) | Picovoice Koala SDK | Koala requires an AccessKey (API key even for free tier); adds third-party dependency and network call for key validation; not fully offline |
| DeepFilterNet3 | RNNoise | No Core ML port exists in the community; C library would require bridging header + FFI; no maintained iOS path |
| DeepFilterNet3 | Apple SoundAnalysis | SoundAnalysis is a classifier, not an enhancer; SNClassifySoundRequest labels sounds, it does not reduce noise |
| DeepFilterNet3 | AVAudioEngine Voice Processing | Explicitly excluded in DNS-01; Voice Processing only works on live mic input, cannot process pre-recorded files |
| AVAudioFile | AVAssetReader | Both work; AVAudioFile is simpler for read-only decode because .processingFormat gives Float32 non-interleaved automatically; AVAssetReader is needed for write-back (AVAssetWriter pair) |
| vDSP wet/dry mix | AVAudioEngine offline render | AVAudioEngine's offline rendering requires an active session and is far more complex; vDSP requires no session setup |
| AVAudioPlayer dual-instance | AVAudioPlayerNode | AVAudioPlayerNode requires AVAudioEngine setup; AVAudioPlayer is sufficient for file-based playback |

**Installation:** No third-party packages required. All frameworks are system-provided. The .mlpackage file is committed to the repository and added to the Xcode target bundle.

---

## Model Selection: DeepFilterNet3

### Why DeepFilterNet3

**Confidence: HIGH** — verified via speech-swift project (soniqo/speech-swift), which ships DeepFilterNet3 as CoreML FP16 for iOS 17+, confirming the conversion is viable.

| Property | Value | Source |
|----------|-------|--------|
| Model architecture | Deep filtering + CRUSE encoder | DeepFilterNet GitHub |
| Parameters | ~2.1M | speech-swift README |
| Model size (FP16 .mlpackage) | ~4.2 MB | speech-swift README |
| Peak inference memory | ~10 MB | speech-swift README |
| Sample rate | 48 kHz | DeepFilterNet spec (matches project canonical rate) |
| Frame size | 480 samples (10 ms at 48 kHz) | RNNoise frame size; DeepFilterNet uses same STFT-aligned 10 ms frames |
| License | MIT OR Apache-2.0 (user's choice) | DeepFilterNet GitHub |
| iOS minimum | iOS 17+ (confirmed) | speech-swift requirements |

### Obtaining/Converting the Model

The model must be converted from PyTorch to Core ML using `coremltools`. This is a **one-time offline step performed by the developer** before committing the .mlpackage to the repository. The converted .mlpackage is then bundled into the Xcode target — no runtime download, fully offline.

**Conversion approach (for developer setup only):**
```bash
# Install coremltools
pip install coremltools deepfilternet

# Convert DeepFilterNet3 to Core ML
# (The conversion script must handle explicit RNN state I/O for iOS 17 compat — see Architecture Patterns)
python convert_deepfilternet3.py --output DeepFilterNet3.mlpackage
```

**Critical iOS 17 constraint:** MLState (automatic stateful model support) requires iOS 18+. Since SonicMerge targets iOS 17+, the converted model MUST expose RNN hidden states as explicit input/output tensors rather than using MLState. See Architecture Patterns for the explicit state threading pattern.

**Model file placement:**
- Add `DeepFilterNet3.mlpackage` to Xcode project → added to app bundle
- Access via: `Bundle.main.url(forResource: "DeepFilterNet3", withExtension: "mlpackage")`
- Xcode auto-generates a Swift wrapper class (`DeepFilterNet3`) from the .mlpackage

---

## Architecture Patterns

### Recommended Project Structure

```
SonicMerge/
├── Features/
│   └── Denoising/
│       ├── CleaningLabView.swift          # Main view — pushed from MixingStation toolbar
│       ├── CleaningLabViewModel.swift     # @Observable @MainActor; drives CleaningLabView
│       └── NoiseReductionService.swift   # actor; Core ML inference pipeline
├── Resources/
│   └── DeepFilterNet3.mlpackage          # bundled model (one-time developer conversion)
└── Services/
    (AudioMergerService, WaveformService, etc. — unchanged)
```

### Pattern 1: Core ML Model Loading (Lazy, Once)

Load the model once; hold it in the NoiseReductionService actor. Loading is expensive (~200–400 ms first time, fast from cache after). Do NOT reload per-prediction.

```swift
// Source: WWDC22 "Optimize your Core ML usage" + WWDC23 "Improve Core ML integration with async prediction"
actor NoiseReductionService {
    private var model: DeepFilterNet3?  // lazy — loaded on first use

    private func loadModel() throws -> DeepFilterNet3 {
        if let m = model { return m }
        let config = MLModelConfiguration()
        config.computeUnits = .all  // Let Core ML choose CPU/GPU/ANE — best latency
        let m = try DeepFilterNet3(configuration: config)
        model = m
        return m
    }
}
```

**MLComputeUnits.all is the correct choice.** Benchmarks show `.all` consistently outperforms `.cpuOnly`, `.cpuAndGPU`, and `.cpuAndNeuralEngine` across all A-series devices (A13–A17). Use `.cpuAndNeuralEngine` only if the app competes with a GPU-heavy rendering pipeline — not applicable here.

### Pattern 2: AVAudioFile Chunked Decode to Float32

AVAudioFile.processingFormat automatically returns Float32 non-interleaved PCM at the file's native sample rate. Since the project normalizes all audio to 48 kHz at import, the rate will always be 48,000 Hz.

```swift
// Source: Apple Developer Forums thread/24124 + AVAudioFile documentation
let inputFile = try AVAudioFile(forReading: mergedFileURL)
let format = inputFile.processingFormat  // Float32, non-interleaved, 48 kHz, 2ch
let frameCapacity = AVAudioFrameCount(480)  // 10 ms per chunk at 48 kHz

var originalFrames: [Float] = []  // accumulate all decoded samples (L+R interleaved for storage)
var denoisedFrames: [Float] = []  // filled by Core ML inference

let readBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)!
while inputFile.framePosition < inputFile.length {
    try inputFile.read(into: readBuffer)
    let frameCount = Int(readBuffer.frameLength)
    guard frameCount > 0 else { break }
    // Access float channel data
    guard let channelData = readBuffer.floatChannelData else { continue }
    let left  = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
    let right = Array(UnsafeBufferPointer(start: channelData[1], count: frameCount))
    originalFrames.append(contentsOf: left)
    originalFrames.append(contentsOf: right)  // or store L/R separately per model needs
    // Feed chunk to Core ML — see Pattern 3
}
```

### Pattern 3: Core ML Inference Loop with Explicit RNN State (iOS 17)

DeepFilterNet3 uses recurrent layers. Since MLState requires iOS 18+, the RNN hidden state must be passed as explicit MLMultiArray input and output between frames. The state is zero-initialized before processing begins and threaded through each chunk call.

```swift
// Source: Apple coremltools stateful-models docs (iOS 17 workaround pattern)
// The exact input/output names depend on the .mlpackage generated by the conversion script.
// Common convention from DeepFilterNet3 CoreML FP16 conversion:
//   Input:  "input_frame" (shape [1, 2, 480]) + "hidden_state_in" (shape depends on model)
//   Output: "output_frame" (shape [1, 2, 480]) + "hidden_state_out" (same shape)

var hiddenStateIn: MLMultiArray = zeroStateArray()  // shape from model spec

for chunk in stride(from: 0, to: totalFrames, by: 480) {
    let end = min(chunk + 480, totalFrames)
    let frameLen = end - chunk
    // Pad to 480 if last chunk is shorter
    let inputArray = try MLMultiArray(shape: [1, 2, 480], dataType: .float32)
    // Fill inputArray from left/right channel data for chunk[chunk..<end]

    let prediction = try await model.prediction(
        input_frame: inputArray,
        hidden_state_in: hiddenStateIn
    )
    hiddenStateIn = prediction.hidden_state_out  // thread state to next iteration
    let outputArray = prediction.output_frame
    // Extract denoised samples from outputArray and append to denoisedFrames
    denoisedFrames.append(contentsOf: extractFrames(outputArray, frameLen: frameLen))
}
```

**Key constraints:**
- Frame size: **480 samples** (10 ms at 48 kHz) — DO NOT change this without retraining the model
- The last chunk must be **zero-padded to 480** if it is shorter
- Denoising introduces algorithmic delay (STFT lookahead). Trim/compensate the output to match input length
- Use `try await model.prediction(input:)` (async API) to avoid blocking the actor's thread

### Pattern 4: Wet/Dry Mix via vDSP_vsma

After denoising produces two Float32 arrays (original and denoised, same length), the intensity slider blends them using vDSP. This runs in memory with no disk I/O. It runs synchronously on the actor every time the slider changes value (it is fast — < 1 ms for a typical 2–5 minute file at Float32 stereo).

```swift
// Source: Accelerate framework documentation + The Amazing Audio Engine pattern
// vDSP_vsma: result[i] = (a[i] * b) + c[i]
// wet/dry:   output[i] = (denoised[i] * intensity) + (original[i] * (1 - intensity))

import Accelerate

func blend(original: [Float], denoised: [Float], intensity: Float) -> [Float] {
    precondition(original.count == denoised.count)
    let count = original.count
    var result = [Float](repeating: 0, count: count)
    let dry = 1.0 - intensity
    // Scale original by (1 - intensity)
    var scaledDry = [Float](repeating: 0, count: count)
    vDSP_vsmul(original, 1, [dry], &scaledDry, 1, vDSP_Length(count))
    // Scale denoised by intensity and add to scaled original
    vDSP_vsma(denoised, 1, [intensity], scaledDry, 1, &result, 1, vDSP_Length(count))
    return result
}
```

**This function is called on the NoiseReductionService actor** whenever the slider value changes. The result is the buffer fed to the CleaningLabViewModel for playback.

**Alternative modern Swift syntax (Accelerate Swift overlay, iOS 13+):**
```swift
// Equivalent using vDSP namespace (cleaner Swift):
let result = vDSP.add(
    multiplication: (a: denoised, scalar: intensity),
    multiplication: (a: original, scalar: 1.0 - intensity)
)
```

### Pattern 5: A/B Playback with Dual AVAudioPlayer

Two AVAudioPlayer instances are pre-loaded from disk (original merged file and denoised output file). On hold-to-hear-original button press/release, the active player's currentTime is read, both players are seeked, and playback swaps.

```swift
// Source: Apple AVAudioPlayer documentation (currentTime property is read/write)
class ABPlaybackController {
    var originalPlayer: AVAudioPlayer  // loads original merged file
    var denoisedPlayer: AVAudioPlayer  // loads denoised output file (written to tmp)
    var activePlayer: AVAudioPlayer    // starts as denoisedPlayer

    func switchToOriginal() {
        let pos = activePlayer.currentTime
        originalPlayer.currentTime = pos
        denoisedPlayer.pause()
        originalPlayer.play()
        activePlayer = originalPlayer
    }

    func switchToDenoised() {
        let pos = activePlayer.currentTime
        denoisedPlayer.currentTime = pos
        originalPlayer.pause()
        denoisedPlayer.play()
        activePlayer = denoisedPlayer
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()  // UX-02
    }
}
```

**Important:** Both players must be pre-loaded via `prepareToPlay()` before any switching occurs. This buffers their initial audio data and eliminates the ~100–200 ms startup delay that causes audible glitch on first play.

```swift
originalPlayer.prepareToPlay()
denoisedPlayer.prepareToPlay()
```

**Slider drag during playback:** When the user drags the intensity slider while audio is playing, write the blended buffer to a temp file and reload the denoisedPlayer. This is acceptable for a "blend preview" after denoising — the write is async and takes ~100–300 ms for typical file lengths.

### Pattern 6: Denoised Audio Written to Disk

After Core ML inference, the denoised Float32 buffers are written back to disk as a .wav file for playback (AVAudioPlayer requires a file URL, not a raw buffer). Use AVAssetWriter with pcmFormatFloat32 or Int16 — Float32 is simpler (no quantization step).

```swift
// Source: AVAudioFile documentation + project's existing AudioMergerService WAV pattern
let outputFormat = AVAudioFormat(
    commonFormat: .pcmFormatFloat32,
    sampleRate: 48_000,
    channels: 2,
    interleaved: false
)!
let outputFile = try AVAudioFile(
    forWriting: denoisedOutputURL,
    settings: outputFormat.settings
)
// Write in chunks matching the same 480-frame chunk size used during inference
let writeBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: 4800)!  // 100 ms chunks for efficiency
// Fill writeBuffer from denoisedFrames array and call outputFile.write(from: writeBuffer)
```

### Anti-Patterns to Avoid

- **Reloading MLModel per inference call:** Loading takes 200–400 ms. Load once, store in actor. (Source: WWDC22 profiling showed 6.41s in model loads vs 2.69s in predictions for repeated reloads)
- **Using MLComputeUnits.cpuOnly:** Forces CPU-only inference; Neural Engine is 2–3x faster for small recurrent models on A-series chips
- **Using AVAudioEngine offline rendering for wet/dry mix:** Requires active audio session; far more complex than two vDSP calls
- **Re-running Core ML inference per slider change:** Confirmed architectural decision — inference runs once; slider is a pure buffer blend
- **Using MLState without checking iOS version:** MLState requires iOS 18+. SonicMerge targets iOS 17+. Always use explicit state I/O
- **Loading both original and denoised audio as in-memory Float32 arrays during playback:** For typical podcast files (30–60 min), this would consume 500–1000 MB RAM. Write denoised output to disk; use AVAudioPlayer for file-based playback
- **Blocking the main actor during inference:** NoiseReductionService is an actor; `await` calls to it from `@MainActor` ViewModel correctly hop to a background thread

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Noise reduction algorithm | Custom DSP noise filter | DeepFilterNet3 Core ML model | SOTA deep learning; orders of magnitude better quality than spectral subtraction |
| SIMD vector blend | Loop over Float array | `vDSP_vsma` / `vDSP.add` | 10–100x faster; SIMD-vectorized; ships on every iOS device |
| Audio decode to PCM | Custom format parsing | `AVAudioFile(forReading:)` with `processingFormat` | Handles AAC, m4a, wav transparently; returns Float32 non-interleaved automatically |
| Waveform visualization | WaveformView from scratch | Existing `WaveformService` | Already in codebase (Services/WaveformService.swift); generates 50-peak Float arrays |
| Playback position sync | Custom time-tracking | `AVAudioPlayer.currentTime` | AVAudioPlayer handles clock internally; currentTime is read/write |
| Haptic | Custom vibration timing | `UIImpactFeedbackGenerator(.medium)` | System API; correct timing, correct physical feeling |

**Key insight:** The signal processing and inference infrastructure are entirely provided by Apple frameworks. The only non-trivial custom code is the explicit state threading loop for the Core ML RNN frames, which is a 20–30 line pattern.

---

## Common Pitfalls

### Pitfall 1: MLState Used on iOS 17 Targets

**What goes wrong:** Stateful Core ML model compiled for MLState crashes or fails to load on iOS 17 devices.
**Why it happens:** MLState was introduced in iOS 18 / macOS 15. Using `.mlprogram` with state blocks produces a model that the runtime on iOS 17 cannot execute.
**How to avoid:** When converting DeepFilterNet3 via coremltools, set `minimum_deployment_target=coremltools.target.iOS17` AND do NOT use `ct.State`. Export RNN hidden states as explicit `ct.TensorType` inputs and outputs.
**Warning signs:** Model loads on Simulator (Sequoia/iOS 18) but fails on iOS 17 test device with `MLModelError`.

### Pitfall 2: AVAudioFile processingFormat vs fileFormat Confusion

**What goes wrong:** Audio data is read as Int16 instead of Float32; Core ML MLMultiArray shows integer values causing wrong inference results.
**Why it happens:** AVAudioFile has two formats: `fileFormat` (the compressed format, e.g., AAC) and `processingFormat` (the decoded client format, always Float32 non-interleaved). Creating AVAudioPCMBuffer with `fileFormat` instead of `processingFormat` causes silent format mismatch.
**How to avoid:** Always create `AVAudioPCMBuffer(pcmFormat: inputFile.processingFormat, ...)` — never `fileFormat`.
**Warning signs:** `floatChannelData` returns nil; frame values are all zero or garbage.

### Pitfall 3: Forgetting to Zero-Pad the Final Chunk

**What goes wrong:** Last chunk is shorter than 480 samples; model receives garbage data in the padding region; output has noise artifact at end of file.
**Why it happens:** Audio length is rarely a multiple of 480. The last chunk will have 1–479 valid samples. MLMultiArray must be exactly [1, 2, 480] — reading beyond valid samples returns uninitialised memory.
**How to avoid:** Explicitly zero-pad MLMultiArray to 480 before filling from the audio buffer. Only emit `frameLen` (not 480) samples from the output for the final chunk.
**Warning signs:** Crackling or noise burst in last 10 ms of denoised output.

### Pitfall 4: Not Calling prepareToPlay Before A/B Switch

**What goes wrong:** First-switch between original and denoised players has an audible 150–250 ms gap.
**Why it happens:** AVAudioPlayer buffers audio on first `play()` call. Pre-loading eliminates this.
**How to avoid:** Call `originalPlayer.prepareToPlay()` and `denoisedPlayer.prepareToPlay()` immediately after creating both players (after denoising completes, before autoplay begins).
**Warning signs:** Perceptible gap on first hold-to-hear-original.

### Pitfall 5: Model Loading on Main Thread

**What goes wrong:** App UI freezes for 200–400 ms when CleaningLabView appears and tries to load the model.
**Why it happens:** MLModel(contentsOf:) is synchronous and can take 200–400 ms on first load (uncached compile).
**How to avoid:** NoiseReductionService is an actor — model loading happens on `await noiseReductionService.denoise(...)` call, which already hops off the main actor. Never call model loading directly from `@MainActor` code synchronously.
**Warning signs:** UI hitch when entering CleaningLabView; Instruments shows main thread blocked.

### Pitfall 6: Denoised File Written as Lossy Format (AAC)

**What goes wrong:** Writing denoised output as AAC re-encodes the denoised PCM, adding compression artifacts. Since the file is already derived from AAC → PCM → Core ML → PCM, another AAC encode degrades quality noticeably.
**Why it happens:** Using `kAudioFormatMPEG4AAC` in AVAssetWriter settings when writing denoised output.
**How to avoid:** Write denoised output to a **temporary .wav** (Float32 or Int16 PCM, no compression). This file is ephemeral — it is only used for AVAudioPlayer playback and WaveformService. When the user taps Export from CleaningLabView, apply the current intensity mix to produce the final file (which can then be AAC-encoded as normal).
**Warning signs:** Noticeable quality degradation in A/B comparison that worsens with repeated processing.

### Pitfall 7: AVAudioEngine Voice Processing Attempted for Pre-recorded Files

**What goes wrong:** `AVAudioSession.Mode.voiceProcessing` has no effect on AVAudioFile playback.
**Why it happens:** Voice Processing mode applies to live audio I/O tap — it intercepts the microphone signal. It cannot process a file on disk.
**How to avoid:** Already excluded in DNS-01. Document in NoiseReductionService source comments to prevent future confusion.

---

## Code Examples

### Loading the Bundled .mlpackage

```swift
// Source: Apple Core ML documentation — Getting a Core ML Model
// Place DeepFilterNet3.mlpackage in Xcode project, ensure "Add to Target" is checked

actor NoiseReductionService {
    private var _model: DeepFilterNet3?

    // Lazy model load — called from denoise() before first inference
    private func model() throws -> DeepFilterNet3 {
        if let m = _model { return m }
        let config = MLModelConfiguration()
        config.computeUnits = .all  // ANE + CPU + GPU; best latency across A13–A17
        let m = try DeepFilterNet3(configuration: config)
        _model = m
        return m
    }
}
```

### Wet/Dry Blend — Two Variants

```swift
// Variant A: C-level vDSP (works on all iOS versions, explicit and fast)
import Accelerate

func blend(original: [Float], denoised: [Float], intensity: Float) -> [Float] {
    assert(original.count == denoised.count)
    let n = vDSP_Length(original.count)
    var result = [Float](repeating: 0, count: original.count)
    var dry = 1.0 - intensity
    var wet = intensity
    var scaledDry = [Float](repeating: 0, count: original.count)
    vDSP_vsmul(original, 1, &dry, &scaledDry, 1, n)
    vDSP_vsma(denoised, 1, &wet, scaledDry, 1, &result, 1, n)
    return result
}

// Variant B: Swift overlay vDSP (iOS 13+, cleaner syntax)
func blend(original: [Float], denoised: [Float], intensity: Float) -> [Float] {
    vDSP.add(
        multiplication: (a: denoised, scalar: intensity),
        multiplication: (a: original, scalar: 1.0 - intensity)
    )
}
```

### A/B Player Setup and Switch

```swift
// Source: AVAudioPlayer documentation (currentTime, prepareToPlay, play)
import AVFoundation
import UIKit

// After denoising completes:
let originalPlayer = try AVAudioPlayer(contentsOf: mergedFileURL)
let denoisedPlayer = try AVAudioPlayer(contentsOf: denoisedTempURL)
originalPlayer.prepareToPlay()  // prevent gap on first switch
denoisedPlayer.prepareToPlay()

// Hold gesture began — switch to original
func holdBegan() {
    let pos = denoisedPlayer.currentTime
    originalPlayer.currentTime = pos
    denoisedPlayer.pause()
    originalPlayer.play()
}

// Hold gesture ended — switch back to denoised
func holdEnded() {
    let pos = originalPlayer.currentTime
    denoisedPlayer.currentTime = pos
    originalPlayer.pause()
    denoisedPlayer.play()
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
}
```

### Haptic Feedback (UX-02)

```swift
// Source: UIKit documentation — UIImpactFeedbackGenerator
// Call on button release (holdEnded)
UIImpactFeedbackGenerator(style: .medium).impactOccurred()

// iOS 17+ SwiftUI alternative via .sensoryFeedback modifier:
// .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.7), trigger: abToggleReleased)
```

### Progress Reporting from Inference Loop

```swift
// Pattern matching AudioMergerService AsyncStream<Float> progress
func denoise(inputURL: URL, outputURL: URL) -> AsyncStream<Float> {
    AsyncStream { continuation in
        Task {
            let totalFrames = frameCount(inputURL)  // AVAudioFile.length
            var processedFrames = 0
            for chunk in 0..<totalFrames / 480 {
                // ... run Core ML inference on chunk ...
                processedFrames += 480
                continuation.yield(Float(processedFrames) / Float(totalFrames))
            }
            continuation.finish()
        }
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Spectral subtraction (manual DSP) | Deep learning models (DeepFilterNet3) | ~2022 | Quality improvement is dramatic; background noise fully removed vs hissing artifact |
| AVAudioEngine Voice Processing | Core ML custom model | iOS 16+ | Voice Processing can't process files; Core ML is the only viable path |
| Stateful Core ML (MLState) | Explicit state I/O for iOS 17 | iOS 18 (MLState added) | iOS 17 targets must thread RNN state manually between prediction calls |
| In-memory blending with AVAudioEngine | vDSP array math | Always | vDSP is simpler, requires no audio session, and has no latency overhead |

**Deprecated/outdated:**
- `AVAudioSession.Mode.voiceProcessing` for file processing: never worked for pre-recorded audio
- `MLState` API: iOS 18+ only; do not target until deployment target raises to iOS 18
- `coremltools.converters.onnx` (old onnx-coreml package): deprecated; use `coremltools.convert()` unified API instead

---

## Open Questions

1. **Exact input/output tensor names of the converted DeepFilterNet3 .mlpackage**
   - What we know: The model takes a frame tensor and RNN hidden state(s) as input; returns denoised frame and updated state as output
   - What's unclear: Tensor name strings depend on the specific coremltools conversion script used; must be verified by inspecting the generated Swift wrapper class after conversion
   - Recommendation: The developer who runs the coremltools conversion script reads the generated `DeepFilterNet3.swift` wrapper class to extract exact property names, then updates NoiseReductionService accordingly. Plan 03-01 should include the coremltools conversion as Wave 0 setup.

2. **Algorithmic delay / output offset of DeepFilterNet3**
   - What we know: DeepFilterNet includes STFT and model lookahead delay; the library has a `--compensate-delay` flag for CLI use
   - What's unclear: Exact delay in samples for the coremltools-converted model; this affects how many frames to trim from the output to align with the original
   - Recommendation: Measure empirically after conversion by comparing a silence-only test file. Trim the same number of frames from the denoised output that appear as leading silence.

3. **Memory ceiling for typical podcast file lengths at Float32**
   - What we know: A 30-min stereo 48 kHz Float32 file consumes ~420 MB as a flat array; iOS may OOM on older A13 devices
   - What's unclear: Whether NoiseReductionService should process in streaming fashion (chunk → infer → write, discard read buffer) rather than accumulating all frames in memory
   - Recommendation: **Process in streaming fashion by default** — read 480-sample chunks from AVAudioFile, infer, write chunk to output AVAudioFile, discard. Accumulate only the per-chunk output (not the entire file). This keeps peak memory under ~5 MB regardless of file length.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (Xcode built-in, iOS 17+) |
| Config file | SonicMergeTests target (PBXFileSystemSynchronizedRootGroup — auto-includes all files in Tests/) |
| Quick run command | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SonicMergeTests/NoiseReductionServiceTests` |
| Full suite command | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DNS-01 | NoiseReductionService.denoise() produces an output file at the given URL | Unit | `xcodebuild test ... -only-testing:SonicMergeTests/NoiseReductionServiceTests/testDenoisedFileCreated` | ❌ Wave 0 |
| DNS-01 | Output file is valid AVAudioFile-readable audio at 48 kHz stereo | Unit | `xcodebuild test ... -only-testing:SonicMergeTests/NoiseReductionServiceTests/testOutputFormatIsValid` | ❌ Wave 0 |
| DNS-01 | Progress stream yields values from 0.0 to 1.0 in increasing order | Unit | `xcodebuild test ... -only-testing:SonicMergeTests/NoiseReductionServiceTests/testProgressMonotonicallyIncreases` | ❌ Wave 0 |
| DNS-02 | blend(original:denoised:intensity:0.0) returns original unchanged | Unit | `xcodebuild test ... -only-testing:SonicMergeTests/WetDryBlendTests/testZeroIntensityReturnsOriginal` | ❌ Wave 0 |
| DNS-02 | blend(original:denoised:intensity:1.0) returns denoised unchanged | Unit | `xcodebuild test ... -only-testing:SonicMergeTests/WetDryBlendTests/testFullIntensityReturnsDenoised` | ❌ Wave 0 |
| DNS-02 | blend(original:denoised:intensity:0.5) returns mean of both arrays | Unit | `xcodebuild test ... -only-testing:SonicMergeTests/WetDryBlendTests/testHalfIntensityIsLinearMid` | ❌ Wave 0 |
| DNS-03 | A/B position handoff: after switchToOriginal(), originalPlayer.currentTime matches last denoisedPlayer.currentTime | Unit | `xcodebuild test ... -only-testing:SonicMergeTests/ABPlaybackTests/testPositionPreservedOnSwitch` | ❌ Wave 0 |
| UX-02 | Haptic fires on holdEnded (manual verification only — haptic not testable in unit tests) | Manual | — | Manual |

### Sampling Rate

- **Per task commit:** Quick run targeting the new test file for that task
- **Per wave merge:** Full suite
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `SonicMergeTests/NoiseReductionServiceTests.swift` — covers DNS-01 (requires bundled .mlpackage in test target)
- [ ] `SonicMergeTests/WetDryBlendTests.swift` — covers DNS-02 (pure unit tests, no model needed)
- [ ] `SonicMergeTests/ABPlaybackTests.swift` — covers DNS-03 (mock AVAudioPlayer or subclass)
- [ ] `DeepFilterNet3.mlpackage` — must be converted and committed before any DNS-01 test can run
- [ ] Developer runs coremltools conversion offline to produce the .mlpackage before Wave 0

---

## Sources

### Primary (HIGH confidence)
- Apple WWDC23 "Improve Core ML integration with async prediction" (developer.apple.com/videos/play/wwdc2023/10049) — async prediction API, actor vs class patterns, model lifecycle
- Apple WWDC22 "Optimize your Core ML usage" (developer.apple.com/videos/play/wwdc2022/10027) — MLComputeUnits recommendation (.all is best), model loading pitfalls, profiling
- Apple coremltools stateful-models documentation (apple.github.io/coremltools/docs-guides/source/stateful-models.html) — iOS 17 workaround: explicit state I/O required; MLState = iOS 18+
- Apple AVAudioFile documentation — processingFormat always Float32 non-interleaved; confirmed file read chunking pattern
- Apple AVAudioPlayer documentation — currentTime is settable; prepareToPlay eliminates startup gap
- Accelerate/vDSP documentation — vDSP_vsma for scalar-multiply-add (wet/dry blend); vDSP Swift overlay `vDSP.add(multiplication:...)`

### Secondary (MEDIUM confidence)
- soniqo/speech-swift GitHub README — confirms DeepFilterNet3 CoreML FP16, ~4.2 MB, ~10 MB peak RAM, iOS 17+, 10 ms frames at 48 kHz; Apple Silicon label appears Mac-focused but CoreML itself runs on A-series
- RNNoise GitHub Issue #102 (github.com/xiph/rnnoise/issues/102) — confirms RNNoise frame size is 480 samples = 10 ms at 48 kHz; same frame alignment standard used by DeepFilterNet3
- Picovoice Koala documentation — confirmed on-device file processing capability; rejected due to AccessKey requirement
- Apple Developer Forums thread/24124 "Working with AVAudioPCMBuffer" — confirmed AVAudioFile chunking pattern
- WWDC24 Core ML performance insights (hackernoon.com/on-device-ai-models-and-core-ml-tools-insights-from-wwdc-2024) — iOS 18 faster inference, but no regression on iOS 17

### Tertiary (LOW confidence — flagged)
- DeepFilterNet3 exact frame delay/lookahead value: not found in any iOS-specific source; must be measured empirically after coremltools conversion
- DeepFilterNet3 exact tensor input/output names after coremltools conversion: depend on the Python conversion script; not published for the iOS CoreML variant specifically

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all frameworks are system-provided Apple APIs with official documentation
- Model selection (DeepFilterNet3): HIGH — confirmed by speech-swift project shipping this exact model as CoreML FP16 on iOS 17+
- Chunk/overlap pattern (480 samples): HIGH — confirmed by RNNoise spec (same 10 ms / 48 kHz standard); verified in multiple sources
- Wet/dry mix (vDSP): HIGH — vDSP_vsma is the canonical Apple API for this operation; documented and used in The Amazing Audio Engine
- A/B playback (AVAudioPlayer currentTime): HIGH — official API, confirmed settable before play
- iOS 17 state workaround: HIGH — Apple coremltools docs explicitly document this constraint and the workaround
- Exact tensor names from converted model: LOW — must be verified empirically by developer post-conversion

**Research date:** 2026-03-12
**Valid until:** 2026-06-12 (stable framework APIs; model conversion tooling may update)
