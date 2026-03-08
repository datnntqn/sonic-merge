# Stack Research

**Domain:** iOS audio processing utility (merge + on-device AI denoising)
**Researched:** 2026-03-08
**Confidence:** MEDIUM-HIGH (Apple-native stack well-established; some denoising pipeline decisions require runtime validation)

---

## Recommended Stack

### Core Technologies

| Technology | Version / Requirement | Purpose | Why Recommended |
|---|---|---|---|
| Swift 6 | Xcode 16+ | Language | Strict concurrency enforces correct audio pipeline isolation; Sendable-aware async/await prevents data races in AVFoundation callbacks |
| SwiftUI | iOS 17.0+ | UI layer | Native to the platform; Timeline, drag-and-drop, and gesture APIs are mature enough for the clip-ordering UX |
| AVFoundation / AVMutableComposition | iOS 4.0+ (stable API) | Audio composition and export | The canonical Apple API for non-destructive multi-track audio assembly; no alternative exists at this level that remains first-party |
| AVFAudio / AVAudioEngine | iOS 8.0+ | DSP graph, voice processing | Hosts the denoising pipeline; supports offline manual rendering mode for file-based (non-realtime) processing |
| AVAudioEngine Voice Processing (setVoiceProcessingEnabled) | iOS 13.0+ | On-device noise suppression | Native, zero-model-file approach; Apple tuned for speech; integrates directly into AVAudioEngine graph; no Core ML model to ship or maintain |
| Accelerate / vDSP | iOS 4.0+ | PCM downsampling for waveform | Vectorized math; 50,000%+ faster than naive loops for amplitude downsampling across millions of audio frames |
| UniformTypeIdentifiers | iOS 14.0+ | Audio UTType matching in Share Extension | Modern replacement for string-based UTI; UTType.audio, UTType.wav, UTType.m4a are strongly typed |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---|---|---|---|
| DSWaveformImage | 14.0.0 (SPM) | Waveform rendering from audio file | Use for per-clip waveform thumbnails in the card UI; supports async/await and SwiftUI WaveformView natively. iOS 15.0+ minimum. |
| spfk-loudness | latest (SPM) | EBU R128 / LUFS loudness measurement | Use when computing integrated loudness before normalization gain calculation; wraps libebur128 via Obj-C bridge; gives LUFS, true peak, LRA |

Note: Both libraries are optional. DSWaveformImage can be replaced by a pure native approach (see Stack Patterns). spfk-loudness can be replaced by manual ITU-R BS.1770 implementation using vDSP — but that is significant DSP work.

### Development Tools

| Tool | Purpose | Notes |
|---|---|---|
| Xcode 16+ | Build, instruments, Core ML tools | Required for Swift 6 strict concurrency mode; use Instruments > Time Profiler and Audio Graph Debugger for pipeline validation |
| Swift Package Manager | Dependency management | Only DSWaveformImage and spfk-loudness needed; no CocoaPods or Carthage required |
| Simulator with audio | Local testing | Audio capture limited in Simulator; always test Share Extension and AVAudioEngine voice processing on a physical device |

---

## Decisions by Feature Area

### Audio Composition: AVMutableComposition

**Use:** `AVMutableComposition` + `AVMutableCompositionTrack` + `AVAssetExportSession`

**Rationale:** AVMutableComposition is the only first-party API for constructing a non-destructive, time-indexed multi-track composition from existing audio assets. Alternatives (raw PCM buffer concatenation via AVAudioFile) work but forfeit seeking, time-range precision, and the clean separation between editing model and export.

**Swift 6 note:** `AVAssetExportSession` does not conform to `Sendable` and the native async `.export(to:as:isolation:)` method is iOS 18+ only. For iOS 17 targets, wrap `exportAsynchronously(completionHandler:)` in `withCheckedContinuation`. Keep the export session and its composition off `@MainActor` to avoid isolation crossing errors. (Source: samsonjs Swift 6 AVFoundation gist)

**Silent gaps:** Insert a silent audio file (generated as AVAudioPCMBuffer of zeroed samples, written to a temp file) at the appropriate `CMTime` offset using `insertTimeRange`. Do not attempt gap-by-offset arithmetic alone — use a real silent asset so AVMutableComposition can correctly propagate duration metadata.

**Crossfade:** Apply via `AVMutableAudioMixInputParameters` volume ramps. Set a ramp-down on the ending clip's tail and a ramp-up on the next clip's head over the overlap window. AVMutableComposition handles overlapping time ranges on a single track — insert clip B starting `crossfadeDuration` before clip A ends.

### Noise Reduction: AVAudioEngine Voice Processing

**Use:** `inputNode.setVoiceProcessingEnabled(true)` + `AVAudioSinkNode` to capture processed PCM buffers + `AVAudioFile` to write output.

**Rationale:** Voice Processing IO applies Apple's proprietary speech enhancement DSP (noise suppression, automatic gain control, echo cancellation) without shipping any model file. It is tuned specifically for voice/speech frequencies — exactly what podcasters and voice memo users produce.

**Critical limitation — it is NOT an offline renderer.** `setVoiceProcessingEnabled` requires a live I/O audio session (microphone + speaker). It cannot be used with `enableManualRenderingMode(.offline)`. These two modes are mutually exclusive. Attempting to combine them will result in the engine graph failing silently or refusing to start.

**Working pipeline for file-based denoising:**
```
1. Set AVAudioSession category to .playAndRecord (required for voice processing I/O)
2. Set inputNode.setVoiceProcessingEnabled(true) BEFORE starting engine
3. Observe AVAudioEngineConfigurationChange — restart engine on config change
4. Play the source file through AVAudioPlayerNode → inputNode (via loopback)
5. Tap processed output via AVAudioSinkNode or installTap on mainMixerNode
6. Write captured buffers to AVAudioFile (output)
```

This is an unusual but documented pattern: you drive the engine in real-time even for file input, because voice processing requires the live I/O unit to be active.

**Intensity slider (0–100%):** Voice Processing IO does not expose a continuous intensity parameter. Implement by blending processed and unprocessed buffers: `output = (intensity * denoisedBuffer) + ((1 - intensity) * originalBuffer)` using vDSP.

**Before/After comparison:** Keep the unprocessed AVAudioFile alongside the processed output. Toggle playback source between the two. A/B comparison does not require re-processing.

**Core ML as fallback / alternative:** Only worthwhile if you need stronger suppression for non-speech noise (HVAC, broadband noise). Requires bundling a CoreML model (e.g., a converted RNNoise or Facebook Denoiser model). Adds app size (~5-30 MB), model loading latency, and CoreML conversion maintenance. Not recommended for v1 — the voice processing path is simpler and sufficient for the stated target audience (voice memos, podcasts).

### LUFS Normalization

**Use:** spfk-loudness (EBU R128 / ITU-R BS.1770 measurement) + gain adjustment pass.

**Approach:**
```
1. Analyze exported audio file → measure integrated loudness (LUFS)
2. Compute gain = targetLUFS - measuredLUFS  (e.g., -16 LUFS for Apple Music target)
3. Apply gain: re-export via AVAudioEngine with AVAudioUnitEQ or multiply PCM buffer samples using vDSP.vsmul
```

**Why not AVFoundation alone:** AVFoundation has no LUFS measurement API. `AVAssetExportSession` presets apply Apple's internal normalization for playback only — not a controllable LUFS target. You must measure and adjust manually.

**Apple's target:** -16 LUFS (Apple Music standard per AES TD1008). Podcast target is typically -16 LUFS. Export LUFS target should be user-configurable or default to -16 LUFS.

**spfk-loudness alternative:** If you prefer zero external dependencies, implement ITU-R BS.1770 K-weighting filter using vDSP biquad (`vDSP_biquad` / `vDSP_deq22`) and compute mean square of gated blocks manually. This is ~200 lines of DSP code and well-specified in the ITU standard. Confidence: MEDIUM (correct implementation requires careful testing against reference audio).

### Waveform Visualization

**Two valid approaches — choose based on project scope:**

**Option A — DSWaveformImage (recommended for v1):**
- `WaveformView` (SwiftUI) renders waveform from audio file URL asynchronously
- `WaveformAnalyzer` extracts `[Float]` amplitude array for custom drawing
- iOS 15.0+ minimum (within iOS 17+ target)
- No AVFoundation tap needed; reads PCM samples directly from the file
- Use for per-clip thumbnail in AudioCardComponent

**Option B — Native (pure Apple, no dependency):**
- Read audio PCM samples via `AVAssetReader` + `AVAssetReaderTrackOutput`
- Downsample using `vDSP.maximum` across windows (logarithmic bucketing)
- Draw in SwiftUI `Canvas` or `TimelineView` using `Path` operations
- More control over visual style, zero dependency overhead
- Estimated: ~100-150 lines; feasible in Phase 1

**Recommendation:** Use DSWaveformImage for the first implementation to ship faster. If visual customization requirements grow (animated playhead, color gradients matching theme), migrate to the native Canvas approach in a later phase.

**Do NOT use Metal/Accelerate FFT for this use case.** FFT gives frequency-domain representation (spectrum analyzer), not time-domain amplitude (waveform). The waveform preview needed here is amplitude over time — use downsampled PCM samples, not FFT output.

### Share Extension

**Use:** App Extension target (Share Extension), `UIViewController` subclass hosting a SwiftUI view, `NSItemProvider` with `UTType.audio` conformance, App Groups for file handoff.

**Key implementation decisions:**

1. **SLComposeServiceViewController is deprecated-in-practice.** It doesn't support SwiftUI well. Use a plain `UIViewController` + `UIHostingController` wrapping a SwiftUI view instead.

2. **File copy, not reference.** Audio files imported from the Share Extension must be copied to the App Group shared container (`FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`). The host app's file access sandbox is temporary and revoked after the extension completes.

3. **Audio UTType matching:**
```swift
let audioTypes: [UTType] = [.audio, .wav, .mp3, .aiff, .mpeg4Audio]
// .mpeg4Audio covers both .m4a and .aac
```
Use `NSItemProvider.hasItemConforming(toTypeIdentifier:)` to check, then `loadFileRepresentation(forTypeIdentifier:)` (async-compatible on iOS 16+) to copy to shared container.

4. **App Group is mandatory.** Both the main app target and the Share Extension target must enable the same App Group capability in Xcode. Without this, the copied audio file cannot be read by the main app.

5. **Processing in extension = wrong.** Do not run AVAudioEngine or AVMutableComposition inside the Share Extension. Its memory limit (~120 MB) is low, and it has no background execution. The extension's only job is to copy the file to shared container and notify the main app (via UserDefaults in App Group or a queued file list).

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|---|---|---|
| AVMutableComposition | Raw PCM buffer concatenation (AVAudioPCMBuffer) | Only if you need sample-accurate frame-level editing with custom DSP at each splice point; adds significant complexity with no benefit for a clip-merging use case |
| AVAudioEngine Voice Processing | Core ML + custom denoising model | If you need to suppress non-speech noise types (keyboards, fans, wind) where voice processing performs poorly; requires model selection, conversion, and ongoing maintenance |
| AVAudioEngine Voice Processing | AudioKit | AudioKit is a powerful abstraction but adds ~10 MB binary size, and its I/O node conflicts with setVoiceProcessingEnabled (confirmed bug in AudioKit GitHub issues); avoid for this use case |
| spfk-loudness | Manual BS.1770 with vDSP | If you want zero external dependencies and have ~1 sprint to implement and validate the K-weighting filter correctly |
| DSWaveformImage | SwiftUI Canvas + AVAssetReader | When you need full visual control (animated playhead, per-sample coloring, gradient matching brand theme); total ~120 lines of code |
| AVAssetExportSession | NextLevelSessionExporter | If you need custom encoder settings (bitrate, sample rate control) beyond AVAssetExportSession presets; adds SPM dependency |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|---|---|---|
| Core Audio (AudioUnit C API directly) | Unnecessary complexity for this feature set; AVAudioEngine covers all required functionality with a Swift-friendly API | AVAudioEngine |
| AudioKit | Known incompatibility between AudioKit's engine I/O nodes and `setVoiceProcessingEnabled`; binary size overhead; no benefit over direct AVAudioEngine for this use case | AVAudioEngine directly |
| EZAudio / FDWaveformView | Both are unmaintained (last commits 2019-2021); UIKit-only; no SwiftUI support | DSWaveformImage or native Canvas approach |
| AVAudioEngine offline rendering + voice processing together | Mutually exclusive modes; attempting to combine crashes or silently fails the graph | Use live I/O pipeline for voice processing; use offline rendering only for non-voice-processing DSP passes |
| SLComposeServiceViewController | Not compatible with SwiftUI; Apple has not updated it since iOS 10 era | UIViewController + UIHostingController |
| Metal / GPU-based audio rendering | Overkill for static waveform thumbnails; adds significant complexity | vDSP downsampling + SwiftUI Canvas |
| Cloud APIs for noise reduction (e.g., Dolby.io, Auphonic) | Violates the explicit on-device, privacy-first constraint in PROJECT.md | AVAudioEngine voice processing |

---

## Stack Patterns by Variant

**If the merge-only path is exercised (no denoising):**
- Use AVMutableComposition → AVAssetExportSession only
- No AVAudioSession category change needed
- No AVAudioEngine needed; simpler, faster

**If denoising is applied after merge:**
- Run AVAssetExportSession first (merged file to temp)
- Then run the AVAudioEngine voice processing pipeline on the merged file
- Then run LUFS normalization pass on the denoised file
- Three sequential async operations; show progress per step

**If denoising is applied before merge:**
- Run voice processing on each clip individually (multiple passes)
- Then compose denoised clips via AVMutableComposition
- Slower but allows per-clip intensity settings
- Recommended architecture: make the denoising step injectable so order is configurable

---

## Version Compatibility

| Component | iOS Minimum | Notes |
|---|---|---|
| Swift 6 strict concurrency | Xcode 16 | Language version, not runtime version |
| SwiftUI (full feature set used) | iOS 17.0 | PROJECT.md sets iOS 17.0+ minimum |
| AVMutableComposition | iOS 4.0+ | Stable; no breaking changes in iOS 17 |
| setVoiceProcessingEnabled | iOS 13.0+ | Well within iOS 17+ target |
| AVAudioEngine offline rendering | iOS 11.0+ | Well within iOS 17+ target |
| AVAssetExportSession async/await | iOS 18.0+ | Native async only on iOS 18+; use `withCheckedContinuation` wrapper for iOS 17 |
| DSWaveformImage 14.0 | iOS 15.0+ | Well within iOS 17+ target |
| UniformTypeIdentifiers | iOS 14.0+ | Well within iOS 17+ target |
| spfk-loudness | iOS 13+ (estimated) | Verify in Package.swift before integrating |

---

## Installation

```swift
// In Xcode: File → Add Package Dependencies

// DSWaveformImage — waveform visualization
// URL: https://github.com/dmrschmidt/DSWaveformImage
// Version: "Up to Next Major" from 14.0.0

// spfk-loudness — EBU R128 LUFS measurement (optional, can defer to Phase 2)
// URL: https://github.com/ryanfrancesconi/spfk-loudness
// Version: latest
```

No other external dependencies. All other technologies are Apple system frameworks.

---

## Sources

- Apple Developer Documentation — AVMutableComposition: https://developer.apple.com/documentation/avfoundation/avmutablecomposition
- Apple Developer Documentation — setVoiceProcessingEnabled: https://developer.apple.com/documentation/avfaudio/avaudioionode/setvoiceprocessingenabled(_:)
- Apple Developer Documentation — Performing Offline Audio Processing: https://developer.apple.com/documentation/avfaudio/audio_engine/performing_offline_audio_processing
- Apple Developer Documentation — Using Voice Processing: https://developer.apple.com/documentation/avfaudio/audio_engine/audio_units/using_voice_processing
- WWDC23 — What's New in Voice Processing: https://developer.apple.com/videos/play/wwdc2023/10235/ (confirmed real-time focus, tvOS 17 expansion; offline not addressed)
- samsonjs GitHub Gist — AVAssetExportSession Swift 6 safety: https://gist.github.com/samsonjs/2f006c5f62f53c9aef820bc050e37809 (MEDIUM confidence — community, not Apple official)
- AVAudioEngine Tips (November 2024): https://snakamura.github.io/log/2024/11/audio_engine.html (voice processing config change gotcha confirmed; MEDIUM confidence)
- DSWaveformImage GitHub: https://github.com/dmrschmidt/DSWaveformImage (v14.0.0, iOS 15.0+, SwiftUI WaveformView confirmed; HIGH confidence)
- Swift Package Index — spfk-loudness: https://swiftpackageindex.com/ryanfrancesconi/spfk-loudness (EBU R128 via libebur128; MEDIUM confidence — minimum iOS version needs verification from Package.swift)
- Apple Developer Documentation — Configuring App Groups: https://developer.apple.com/documentation/Xcode/configuring-app-groups
- AudioKit GitHub Issue #2606 — VoiceProcessing conflict: https://github.com/AudioKit/AudioKit/issues/2606 (confirms AudioKit incompatibility; HIGH confidence)
- Create with Swift — Live Audio Waveform in SwiftUI: https://www.createwithswift.com/creating-a-live-audio-waveform-in-swiftui/ (vDSP approach; MEDIUM confidence)

---

*Stack research for: iOS audio merger + on-device AI denoiser (SonicMerge)*
*Researched: 2026-03-08*
