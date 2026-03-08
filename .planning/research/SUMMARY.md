# Project Research Summary

**Project:** SonicMerge — iOS Audio Merger + On-Device AI Denoiser
**Domain:** iOS audio processing utility (clip merging, denoising, LUFS normalization)
**Researched:** 2026-03-08
**Confidence:** MEDIUM-HIGH

## Executive Summary

SonicMerge is an iOS audio utility in a well-understood product category (audio merger), differentiated by on-device AI denoising. The Apple-native stack (Swift 6, SwiftUI, AVFoundation, AVFAudio) is the correct foundation — no third-party audio framework is warranted. The merge pipeline (`AVMutableComposition` + `AVAssetExportSession`) is mature and well-documented. The two optional SPM dependencies (DSWaveformImage for waveform rendering, spfk-loudness for LUFS measurement) are contained to specific concerns and can be deferred without blocking the core workflow. Overall, the stack and architecture research is high-confidence and actionable.

The single most critical finding — and the decision that must be made before writing any DSP code — concerns the denoising strategy. Research confirms that `AVAudioEngine`'s Voice Processing (`setVoiceProcessingEnabled`) operates exclusively on live hardware microphone input. It cannot process pre-recorded audio files. The STACK.md research outlined this as the recommended path; the PITFALLS.md research definitively shows it does not work for file-based denoising (a device with headphones connected will produce silence or raw mic noise, not a cleaned version of the source file). The correct denoising approach for SonicMerge is a Core ML model (e.g., Apple's SpeechDenoiser or a quantized RNNoise/DeepFilterNet model) operating on PCM buffers entirely offline. This keeps the privacy-first constraint intact, eliminates the AVAudioSession loopback workaround, and avoids all of the Voice Processing I/O side effects (screen recording interference, global audio session volume reduction).

The remaining risks are procedural rather than architectural. Import pipelines must copy files to the app sandbox immediately (security-scoped URLs expire at process termination). The Share Extension must remain a thin relay — never touch audio data — due to the 120 MB process memory ceiling. Audio format normalization (canonical sample rate) must happen at import time, not at export time, to prevent silent data corruption in `AVMutableComposition`. The export pipeline needs a timeout-and-cancellation guard from day one to prevent `AVAssetExportSession` from entering a permanently wedged state. None of these are blockers; they are known patterns with established solutions.

## Key Findings

### Recommended Stack

The recommended stack is entirely Apple-native for audio processing, with two focused SPM dependencies. Swift 6 strict concurrency (`@Observable`, `@MainActor`, `actor`) is the correct concurrency model and enforces the isolation required for a correct audio pipeline. The minimum deployment target is iOS 17.0 as specified in PROJECT.md — all recommended APIs are available within that target. The one notable iOS 17 compatibility constraint is `AVAssetExportSession`: the native `async/await` export method is iOS 18+ only; for iOS 17 targets, wrap `exportAsynchronously(completionHandler:)` in `withCheckedContinuation`.

**Core technologies:**
- Swift 6 / Xcode 16+: language — strict concurrency prevents data races in AVFoundation callbacks
- SwiftUI (iOS 17+): UI layer — drag-and-drop, gesture, and timeline APIs are mature for the clip-ordering UX
- AVFoundation / AVMutableComposition: audio composition and export — the only first-party API for non-destructive multi-track assembly
- AVFAudio / AVAudioEngine: DSP graph host — required for Core ML denoising pipeline integration
- Core ML (recommended): on-device denoising — the only viable path for file-based noise suppression; Voice Processing is not usable here
- Accelerate / vDSP: PCM downsampling for waveform, buffer math for intensity blending — vectorized, no overhead
- DSWaveformImage 14.0 (SPM): per-clip waveform thumbnails in SwiftUI — avoids ~100-150 lines of custom AVAssetReader + Canvas code for v1
- spfk-loudness (SPM): EBU R128 LUFS measurement — can be deferred to after core merge pipeline is validated

**What to avoid:**
- AudioKit: known incompatibility with `setVoiceProcessingEnabled`; binary size overhead
- Core Audio C API directly: AVAudioEngine covers all requirements with a Swift-friendly surface
- Cloud audio APIs (Dolby.io, Auphonic): violates the explicit on-device, privacy-first constraint
- AVAudioEngine Voice Processing for file denoising: fundamentally does not work (see Critical Pitfalls)

### Expected Features

The competitive landscape (Ferrite, Audio Joiner, Merge Voice Memos) confirms that a minimal audio merger without waveform visualization, batch import, or professional output quality will not retain users. SonicMerge's primary differentiator — on-device AI denoising with an A/B toggle — exists in no competing simple-merger app. This creates a clear v1 scope that is ambitious but bounded.

**Must have (table stakes):**
- Multi-file batch import (document picker + share extension) — single-file import is the top complaint in competitor reviews
- Drag-and-drop clip reorder — SwiftUI `.onMove`; absence feels broken on iOS
- Swipe-to-delete — universal iOS list pattern
- Playback preview per clip and full merged preview — users must hear before committing
- Export to .m4a and .wav — .m4a is universal; .wav is required for podcasters and DAW users
- Waveform visualization per clip — every professional audio editor shows waveforms; its absence signals a toy app
- Share / save output via system share sheet
- Silence gap insertion (0.5s / 1.0s / 2.0s presets)

**Should have (competitive differentiators):**
- On-device AI noise reduction (Core ML, privacy-first) — the primary differentiator; no simple merger offers this
- Before/After A/B toggle with haptic feedback — validates denoising quality; unique in the category
- Adjustable noise suppression slider (0–100%) — continuous control vs binary on/off
- LUFS loudness normalization (-16 LUFS default) — required by podcasters targeting Apple Podcasts / Spotify
- Crossfade transitions between clips — elevates output from "joined" to "produced"
- Share Extension (inbound from Voice Memos, Files) — reduces friction for the core workflow
- Clip duration and format metadata display

**Defer to v2+:**
- Clip trimming with timeline scrubber (high value, high UI complexity)
- In-app audio recording (competes with Voice Memos; doubles scope)
- Multiple LUFS targets (-14, -16, -18, -23 LUFS)
- iCloud document persistence
- Video audio extraction
- EQ / audio enhancement presets

### Architecture Approach

The recommended architecture is MVVM with `@Observable` (iOS 17+) at the presentation layer, Swift `actor` types for audio processing services, and clean value-type models (`AudioSegment`, `MergeConfig`). This ensures all UI state lives on `@MainActor`, all audio I/O happens off the main thread via actor hopping, and no mutable AVFoundation objects are shared across task boundaries. The Share Extension is a separate Xcode target and functions as a pure file relay — it copies audio to the App Group shared container and notifies the main app, then immediately dismisses.

**Major components:**
1. `MixingStationView / ViewModel` — clip list, drag-reorder, gap insertion, export trigger; all UI state on `@MainActor`
2. `CleaningLabView / ViewModel` — denoising intensity, A/B comparison playback, progress display
3. `AudioMergerService (actor)` — builds AVMutableComposition, applies crossfades, exports to temp file via AVAssetExportSession
4. `NoiseReductionService (actor)` — loads Core ML model, processes PCM buffers offline, writes denoised output to temp file
5. `AudioSessionManager` — configures AVAudioSession, handles interruptions (Bluetooth connect/disconnect, phone call, Siri)
6. `AudioSegment (struct)` — immutable value type: URL, duration, CMTimeRange, display name; no audio data in memory
7. `TempFileStore` — tracks and cleans intermediate temp files; prevents storage accumulation across sessions
8. `ShareViewController` — thin relay: NSItemProvider → copy to App Group container → notify main app → dismiss

**Build order:** Models → AudioSessionManager → AudioMergerService → MixingStation UI → NoiseReductionService → CleaningLab UI → ShareExtension (last, requires App Group setup in both targets).

### Critical Pitfalls

1. **AVAudioEngine Voice Processing cannot denoise audio files** — `setVoiceProcessingEnabled` processes only live hardware microphone input, not `AVAudioPlayerNode` output. The correct approach is a Core ML denoising model operating on PCM buffers offline. This must be decided before any DSP code is written; building on Voice Processing requires a full `NoiseReductionService` rewrite when discovered. Verify with headphones connected: correct implementation produces clean output; incorrect implementation produces silence.

2. **AVMutableComposition silently corrupts audio when source tracks have mismatched sample rates** — `insertTimeRange` succeeds but export produces dropped frames, duration drift, or silent segments. Prevention: normalize all input files to a canonical format (44.1 kHz or 48 kHz stereo AAC) at import time, before any composition. Do not rely on `AVAssetExportPresetPassthrough` to reconcile formats.

3. **Share Extension process is killed silently by iOS at ~120 MB** — any audio file reading, processing, or large buffer allocation in the extension hits the limit. The extension must only copy the file URL to the App Group shared container and exit. All processing stays in the main app. This bug is invisible in Simulator; always test with a 30MB+ file on a physical device.

4. **AVAssetExportSession can wedge permanently (system-wide resource lock)** — cancelling an export mid-operation or force-quitting during export can prevent all subsequent exports from completing until device reboot. Prevention: implement a 60-second timeout that calls `cancelExport()`, nil all strong references to the session before creating a new one, and always show a Cancel button to the user.

5. **Security-scoped URLs expire when the app process terminates** — storing an imported file's URL across app restarts causes silent permission failures. Prevention: copy every imported file into the app's own sandbox immediately on import, call `stopAccessingSecurityScopedResource()` on the original URL, and work only with the sandbox copy from that point forward.

6. **AVAudioFile format vs. processing format mismatch produces valid-sized files containing silence** — writing buffers in the wrong format (e.g., 16-bit integer when `processingFormat` expects 32-bit float) succeeds without error. Always use `AVAudioConverter` and explicit output settings matching the intended processing format.

## Implications for Roadmap

Based on the combined research, the dependency graph and pitfall-prevention requirements suggest the following phase structure. The architecture research's own build-order recommendation aligns exactly with pitfall phase mapping, providing high confidence in this ordering.

### Phase 1: Foundation and Import Pipeline

**Rationale:** All subsequent phases depend on stable models, a working audio session, and a correct import pipeline. The most severe data-corruption pitfall (mismatched sample rates) must be prevented at the import boundary. Security-scoped URL handling must be correct from day one. Getting this layer right unblocks all other work.

**Delivers:** `AudioSegment` model, `MergeConfig`, `ProcessingState`, `TempFileStore`, `AudioSessionManager`, file import via document picker (with canonical format normalization), and App Group infrastructure for the Share Extension.

**Addresses:** Multi-file batch import, clip duration/metadata display, iOS Files integration.

**Avoids:** Security-scoped URL expiration (Pitfall 7), mismatched sample rate corruption (Pitfall 4), Share Extension memory limit crash (Pitfall 3 — App Group scaffolding established here).

**Research flag:** Standard patterns — document picker, App Group setup, AVAsset metadata loading are well-documented. Skip research-phase.

### Phase 2: Core Merge Pipeline

**Rationale:** `AudioMergerService` has no dependency on denoising. Delivering a working merge + export pipeline validates the core value proposition (merge + export) and provides the merged output file that the denoising phase requires for testing. Crossfade and gap insertion are part of the composition configuration, not addons.

**Delivers:** `AudioMergerService` (actor), `MixingStationView` + `MixingStationViewModel`, `AudioCardView`, `WaveformView` (via DSWaveformImage), drag-reorder, swipe-delete, gap insertion, crossfade configuration, merged preview playback via AVPlayer, export to .m4a and .wav, export progress with cancel.

**Uses:** AVMutableComposition, AVAssetExportSession (with `withCheckedContinuation` wrapper for iOS 17), DSWaveformImage, AsyncStream for progress polling.

**Avoids:** AVAssetExportSession wedge (Pitfall 5 — timeout and cancel guard built in from start), main-thread blocking on AVAsset loading (use async `load(.tracks)`).

**Research flag:** Well-documented Apple APIs with community validation. Skip research-phase. The `withCheckedContinuation` wrapper for export session is a known solution (samsonjs gist, MEDIUM confidence — validate during implementation).

### Phase 3: Denoising Pipeline (Core Differentiator)

**Rationale:** Denoising depends on a stable merged output file from Phase 2. The Core ML denoising strategy must be confirmed before this phase begins — this is the highest-risk architectural decision in the project. Phase 3 is where SonicMerge diverges from every competitor in the category.

**Delivers:** `NoiseReductionService` (actor, Core ML-based), `CleaningLabView` + `CleaningLabViewModel`, noise suppression slider (0–100%), before/after A/B toggle with haptic feedback, in-progress denoising UI with cancel.

**Implements:** Core ML model selection and integration (SpeechDenoiser or quantized RNNoise/DeepFilterNet), PCM buffer processing pipeline, AVAudioFile output writing with explicit format alignment, intensity blending via vDSP.

**Avoids:** Voice Processing for file denoising (Pitfall 1 — Core ML is the correct path), AVAudioFile format mismatch producing silent output (Pitfall 8), Swift 6 concurrency violations in audio render callbacks (Pitfall 9 — pre-allocate buffers, no allocation in callback path), AVAudioEngine side effects on screen recording (Pitfall 6 — avoided entirely by Core ML path).

**Research flag:** NEEDS DEEPER RESEARCH. Core ML model selection, conversion toolchain (coremltools), and integration with AVAudioEngine's buffer pipeline for offline inference are not thoroughly covered in the current research files. Run `/gsd:research-phase` before planning Phase 3 tasks. Key questions: which Core ML model to ship (Apple SpeechDenoiser availability, RNNoise size vs. quality tradeoff), model bundle size impact, inference latency on A13/A14 vs A16.

### Phase 4: LUFS Normalization and Export Polish

**Rationale:** LUFS normalization enhances the export pipeline but is not a blocker for core workflow validation. It depends on a stable merge pipeline (Phase 2). Adding it as a discrete post-processing step after merge and before final file write keeps it cleanly isolated.

**Delivers:** LUFS measurement via spfk-loudness (or manual BS.1770 vDSP implementation), gain adjustment pass, -16 LUFS default with export settings UI, polished export completion sheet with share/save options via UIActivityViewController.

**Avoids:** Bypassing normalization and shipping without a LUFS target, which would make the app feel amateur to the podcaster audience.

**Research flag:** spfk-loudness minimum iOS version needs verification from Package.swift before integration (PITFALLS research flagged MEDIUM confidence on this library). If minimum is above iOS 17, use manual BS.1770 vDSP implementation. Standard patterns otherwise — skip research-phase.

### Phase 5: Share Extension

**Rationale:** The Share Extension is the last component because it requires both targets to have the App Group capability configured (established in Phase 1), and it is only meaningfully testable once the main app's import and merge workflows are stable. The extension itself is minimal code — the risk is in the integration, not the implementation.

**Delivers:** `ShareViewController` (thin relay), NSItemProvider audio type matching, copy to App Group shared container, main app open via URL scheme, pending import pickup in main app on launch.

**Avoids:** Processing audio in the extension (Pitfall 3 — memory limit), holding loaded URLs in memory (load one at a time, copy, release), duplicate imports when user taps twice (unique UUID temp filenames).

**Research flag:** Standard patterns (App Group, NSItemProvider, URL scheme dispatch). The responder-chain workaround for `openURL` from an extension is a known technique. Skip research-phase, but always test on physical device with large files — Simulator hides the memory limit bug.

### Phase Ordering Rationale

- **Models and import first:** Every other phase consumes `AudioSegment`. Getting the model correct and the import pipeline right (format normalization, security scope handling, App Group scaffolding) prevents the two most damaging silent-corruption pitfalls from appearing in later phases.
- **Merge before denoise:** The denoising service takes a merged file as input. Having a real merged output file makes Phase 3 testable from day one and isolates merge pipeline bugs from denoising bugs.
- **Denoising before normalization:** LUFS normalization should operate on the denoised file, not the raw merged file, to produce the correct final loudness target.
- **Share Extension last:** Lowest risk, highest integration dependency. The main app must be stable before testing the extension handoff flow.

### Research Flags

Phases requiring `/gsd:research-phase` before planning:
- **Phase 3 (Denoising Pipeline):** Core ML model selection, coremltools conversion pipeline, and offline inference integration with AVAudioEngine buffers are not covered with sufficient depth in current research. This is the highest-risk technical area.

Phases with well-established patterns (skip research-phase):
- **Phase 1 (Foundation):** Document picker, App Group setup, AVAsset metadata loading — extensively documented by Apple.
- **Phase 2 (Merge Pipeline):** AVMutableComposition + AVAssetExportSession — mature APIs with deep community coverage. The `withCheckedContinuation` wrapper pattern is known; validate during implementation.
- **Phase 4 (LUFS):** spfk-loudness integration is straightforward; validate Package.swift minimum iOS version before committing.
- **Phase 5 (Share Extension):** Standard App Group / NSItemProvider pattern; integration-test on device.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM-HIGH | Apple-native APIs (AVFoundation, AVFAudio, AVMutableComposition) are HIGH confidence — official docs, WWDC sessions confirmed. Core ML denoising path is MEDIUM — correct direction but model selection and conversion details need Phase 3 research. spfk-loudness minimum iOS version unverified. |
| Features | MEDIUM-HIGH | Competitor analysis is strong (App Store reviews, direct competitor inspection). LUFS targets are documented standards. Haptic feedback pattern is MEDIUM — community consensus. |
| Architecture | HIGH | MVVM + @Observable + actor services pattern is confirmed by Apple documentation and multiple authoritative community sources. Build order confirmed by both architecture research and pitfall phase mapping. |
| Pitfalls | HIGH | Most pitfalls verified against Apple Developer Forums, official docs, and open-source issue trackers. Voice Processing file-denoising limitation is the most critical finding and is definitively confirmed. |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Core ML denoising model:** Which specific model to ship, its bundle size, coremltools conversion, and inference latency on older devices (A13/A14) are not resolved. This must be researched before Phase 3 planning begins.
- **spfk-loudness iOS minimum version:** Verify `Package.swift` minimum iOS before integrating in Phase 4. If above iOS 17, fall back to manual BS.1770 vDSP implementation (~200 lines; feasible but needs careful testing against reference audio).
- **AVAssetExportSession `withCheckedContinuation` wrapper:** The samsonjs gist solution is MEDIUM confidence (community, not Apple official). Validate the Swift 6 sendability behavior during Phase 2 implementation.
- **AVAudioEngine configuration change in denoising context:** If the Core ML path still uses AVAudioEngine for buffer I/O (likely for the audio graph), the engine restart pattern on `AVAudioEngineConfigurationChange` (Bluetooth, phone call, Siri) must be explicitly handled in `NoiseReductionService`.

## Sources

### Primary (HIGH confidence)

- Apple Developer Documentation — AVMutableComposition: https://developer.apple.com/documentation/avfoundation/avmutablecomposition
- Apple Developer Documentation — setVoiceProcessingEnabled: https://developer.apple.com/documentation/avfaudio/avaudioionode/setvoiceprocessingenabled(_:)
- Apple Developer Documentation — Performing Offline Audio Processing: https://developer.apple.com/documentation/avfaudio/audio_engine/performing_offline_audio_processing
- Apple Developer Documentation — Configuring App Groups: https://developer.apple.com/documentation/Xcode/configuring-app-groups
- WWDC23 — What's New in Voice Processing: https://developer.apple.com/videos/play/wwdc2023/10235/
- DSWaveformImage GitHub (v14.0.0, SwiftUI WaveformView confirmed): https://github.com/dmrschmidt/DSWaveformImage
- AudioKit GitHub Issue #2606 (VoiceProcessing conflict confirmed): https://github.com/AudioKit/AudioKit/issues/2606
- HackingWithSwift — @Observable + @MainActor pattern: https://www.hackingwithswift.com/quick-start/concurrency/important-do-not-use-an-actor-for-your-swiftui-data-models

### Secondary (MEDIUM confidence)

- snakamura.github.io AVAudioEngine tips (2024) — voice processing config change, engine restart pattern: https://snakamura.github.io/log/2024/11/audio_engine.html
- samsonjs GitHub Gist — AVAssetExportSession Swift 6 safety / withCheckedContinuation: https://gist.github.com/samsonjs/2f006c5f62f53c9aef820bc050e37809
- Swift Package Index — spfk-loudness (EBU R128 / libebur128): https://swiftpackageindex.com/ryanfrancesconi/spfk-loudness
- Podcast Loudness Standard 2025 (Descript) — LUFS targets per platform: https://www.descript.com/blog/article/podcast-loudness-standard-getting-the-right-volume
- Apple Developer Forums — AVAssetExportSession stuck in waiting state: https://developer.apple.com/forums/thread/649671
- blog.kulman.sk — Share Extension memory limits: https://blog.kulman.sk/dealing-with-memory-limits-in-app-extensions/
- App Store competitor analysis — Merge Voice Memos, Audio Joiner, Ferrite, SoundLab, TwistedWave (user reviews, feature sets)

### Tertiary (LOW confidence / inference)

- spfk-loudness minimum iOS version: not confirmed from Package.swift; estimated iOS 13+ based on dependency description — verify before integrating
- Core ML denoising model specifics (RNNoise, DeepFilterNet, Apple SpeechDenoiser): not researched in current pass — required before Phase 3

---
*Research completed: 2026-03-08*
*Ready for roadmap: yes*
