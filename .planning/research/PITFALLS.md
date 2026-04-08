# Pitfalls Research

**Domain:** iOS audio processing — AVFoundation, AVAudioEngine, Share Extensions
**Researched:** 2026-03-08
**Confidence:** HIGH (verified against Apple Developer Forums, official documentation, and community post-mortems)

---

## Critical Pitfalls

### Pitfall 1: Voice Processing Cannot Run Offline — The Core Denoising Architecture Trap

**What goes wrong:**
The SonicMerge denoising pipeline is planned as:
`Audio File → AVAudioEngine → Voice Processing Enabled → Processed PCM Buffers → Write to new AVAudioFile`

This pipeline is architecturally broken. `AVAudioEngine` Voice Processing (`setVoiceProcessingEnabled(true)`) only operates on live microphone input from the hardware I/O unit. It cannot process audio from a file player node (`AVAudioPlayerNode`). The Voice Processing I/O audio unit is designed for echo cancellation in VoIP — not for denoising pre-recorded files. When you enable Voice Processing and attach an `AVAudioPlayerNode` to play a file through the graph, the Voice Processing noise suppression acts on the microphone input, not on the player node's audio.

**Why it happens:**
The Apple documentation for `setVoiceProcessingEnabled(_:)` describes a VoIP use case. Developers assume "voice processing" means general audio signal processing, but it specifically means AEC (Acoustic Echo Cancellation) on the hardware input path.

**How to avoid:**
Two viable approaches exist for SonicMerge:
1. **Real-time loopback workaround:** Play the file through the speaker while simultaneously recording from the microphone with Voice Processing enabled. The processed mic signal captures the denoised audio. This introduces speaker → mic quality loss and is unsuitable for professional output.
2. **Core ML noise suppression model (the correct approach):** Ship a CoreML model (e.g., Apple's own SpeechDenoiser or a quantized RNNoise/DeepFilterNet model) that operates on PCM buffers entirely offline. This is the only path to true file-based denoising. Mark the Key Decision "AVAudioEngine Voice Processing over Core ML" as needing reassessment.

**Warning signs:**
- Voice processing appears to work in testing because the microphone picks up speaker bleed in a quiet room
- Denoised output sounds like it came from a microphone, not the original file (degraded quality)
- Denoising has no effect when device is muted or headphones are connected

**Phase to address:** Phase 1 (Architecture) — The denoising strategy must be decided before a single line of DSP code is written. Designing around Voice Processing for file denoising will require a full rewrite when the limitation is discovered.

---

### Pitfall 2: AVAudioEngine Stops Itself When Voice Processing Is Toggled

**What goes wrong:**
Calling `inputNode.setVoiceProcessingEnabled(true)` causes `AVAudioEngine` to internally switch from `RemoteIO` to `VoiceProcessingIO` audio unit. This configuration change triggers `AVAudioEngineConfigurationChange` notification and the engine stops itself. If the developer calls `engine.start()` immediately after `setVoiceProcessingEnabled`, the engine may not actually be running — the race condition between the unit swap and the `start()` call means the graph comes up silently with no audio flowing.

**Why it happens:**
The switch from `RemoteIO` to `VoiceProcessingIO` is asynchronous at the system level. Starting the engine before the switch completes results in no audio. This is documented in community sources but not prominently in official API documentation.

**How to avoid:**
- Enable voice processing **before** building and connecting the audio graph
- Observe `AVAudioEngineConfigurationChange` via `NotificationCenter` and restart the engine in the callback
- Never call `setVoiceProcessingEnabled` while the engine is running; always `stop()` first, toggle, then `start()` again
- Add a small delay (100ms) after toggling — though unreliable, it reduces race condition frequency

```swift
// Correct pattern
engine.stop()
try inputNode.setVoiceProcessingEnabled(true)
// Rebuild connections if needed
NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { _ in
    try? engine.start()
}
try engine.start()
```

**Warning signs:**
- Engine starts with no errors but silence is produced
- Works 80% of the time but fails unpredictably
- Works in Simulator but fails on device

**Phase to address:** Phase 2 (Denoising implementation)

---

### Pitfall 3: Share Extension Memory Limit Kills the Process Before Handoff

**What goes wrong:**
iOS Share Extensions have a hard memory limit of approximately 120 MB. Audio processing (even basic file reading for inspection) can approach this limit before any real work begins. A 50MB WAV file loaded into memory for inspection + NSExtensionItem parsing overhead + UI rendering can exceed the limit. iOS kills the extension process silently — the user sees the Share Sheet dismiss with no explanation.

**Why it happens:**
Developers test the Share Extension in Simulator where the memory limit is disabled. Everything appears to work. On device, the first time a user shares a large audio file, the extension crashes. The Simulator never surfaces this class of bug.

**How to avoid:**
- The Share Extension must **never** process audio. Its only job is to copy the file to the App Group shared container and then open the main app via `openURL`.
- Use `NSItemProvider.loadFileRepresentation(forTypeIdentifier:)` to get a URL, then immediately copy the file to the App Group container — do not read the file contents into memory.
- Open the main app via `extensionContext?.open(appURL, completionHandler:)` and let the main app handle everything.

```swift
// Share Extension: copy, don't process
itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.audio.identifier) { url, error in
    guard let url else { return }
    let dest = sharedContainerURL.appendingPathComponent(url.lastPathComponent)
    try? FileManager.default.copyItem(at: url, to: dest)
    // Save dest path to shared UserDefaults
    // Then open main app
}
```

**Warning signs:**
- Share Extension works in Simulator but crashes on device with large files
- Extension crashes silently — no crash log visible in Xcode without device console
- Memory usage approaches 80MB+ before any audio processing

**Phase to address:** Phase 1 (Share Extension scaffolding)

---

### Pitfall 4: AVMutableComposition Silent Data Loss When Source Assets Have Different Sample Rates

**What goes wrong:**
`AVMutableComposition` does not fail when audio tracks with mismatched sample rates are inserted into the same composition track. The `insertTimeRange(_:of:at:)` call succeeds, but the exported audio is corrupted — portions of clips are dropped, timing drifts, or audio is silent for segments. This is particularly common when mixing files from different sources: Voice Memos (44.1 kHz AAC), WhatsApp audio (8 kHz AMR), and professional recordings (48 kHz WAV).

**Why it happens:**
`AVMutableComposition` defers sample rate reconciliation to the export stage. The composition silently accepts mismatched formats. `AVAssetExportSession` then attempts reconciliation and either fails or produces unexpected results depending on preset.

**How to avoid:**
- Before inserting any track, read its `AVAssetTrack.naturalSize` and audio description to verify sample rate
- Transcode all input files to a canonical format (44.1 kHz or 48 kHz, stereo, AAC or PCM) before composition
- Use `AVAssetExportPresetAppleM4A` (not `AVAssetExportPresetPassthrough`) which triggers re-encoding and handles mismatches more reliably

```swift
// Read sample rate before insertion
let track = asset.tracks(withMediaType: .audio).first
let description = track?.formatDescriptions.first as? CMAudioFormatDescription
let sampleRate = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee.mSampleRate
```

**Warning signs:**
- Composition plays back correctly in `AVPlayer` preview but export has gaps
- Exported file duration differs from sum of clip durations
- `AVAssetExportSession` completes with `.completed` status but audio is wrong (no error thrown)

**Phase to address:** Phase 1 (Audio merging implementation) — build normalization into the import pipeline

---

### Pitfall 5: AVAssetExportSession Can Wedge Permanently Requiring Device Reboot

**What goes wrong:**
`AVAssetExportSession` can enter a stuck `.waiting` state where progress stays at zero and the completion handler never fires. This is a system-level bug affecting a wide range of apps. The session holds a system-wide resource lock. Subsequent export attempts (even from other apps) also block. The only recovery is a device reboot.

**Why it happens:**
This is a known iOS system bug, most commonly triggered by: cancelling an export mid-operation, force-quitting the app during export, or chaining exports (using one export's output as the next export's input without releasing all references to the first session).

**How to avoid:**
- Always `cancel()` export sessions that are no longer needed and nil out all strong references
- Never use the output file of an in-progress export as input to another session
- Implement a timeout (e.g., 60 seconds with progress at zero) that cancels and re-creates the export session
- Show the user a "Cancel Export" control so they can abort gracefully

```swift
// Timeout guard
let timeout = DispatchWorkItem {
    exporter.cancelExport()
    // Show error to user
}
DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: timeout)
exporter.exportAsynchronously {
    timeout.cancel()
    // handle completion
}
```

**Warning signs:**
- Export hangs indefinitely in release builds but not debug builds
- `exporter.progress` is 0.0 and never changes
- Issue resolves after device reboot

**Phase to address:** Phase 2 (Export pipeline) — build robust timeout and cancellation from the start

---

### Pitfall 6: AVAudioEngine with Voice Processing Breaks Screen Recording and Other Audio Sessions

**What goes wrong:**
When `AVAudioEngine` with Voice Processing I/O is active, iOS screen recording captures no audio. Additionally, any new audio session started after Voice Processing I/O is enabled runs at reduced volume. These side effects affect the user unexpectedly: users trying to record a tutorial video of the app will find no audio in their recording.

**Why it happens:**
Voice Processing I/O replaces the standard `RemoteIO` audio unit with `VoiceProcessingIO`, which holds exclusive access to the microphone path and applies aggressive automatic gain control and echo cancellation across all audio routes.

**How to avoid:**
- Scope the Voice Processing session to the shortest window necessary (enable, process, disable)
- Implement the denoising as a discrete, time-bounded operation rather than a persistent background audio session
- Document this limitation in app store notes if relevant
- If using the Core ML denoising approach (Pitfall 1's recommended fix), this pitfall is completely avoided

**Warning signs:**
- Users report that other apps' audio sounds quieter after using SonicMerge
- TestFlight testers can't record screen walkthroughs with audio

**Phase to address:** Phase 2 (Denoising implementation)

---

### Pitfall 7: Security-Scoped URL Access Stale After App Restart

**What goes wrong:**
When a user imports an audio file via the document picker or Share Extension, the app receives a security-scoped URL. This URL grants temporary sandbox-escaping access. If the app stores the URL as a string in `UserDefaults` or `@AppStorage` and restores it after relaunch, `startAccessingSecurityScopedResource()` fails silently and file operations throw permission errors. The app can read the file in-session but not after relaunch.

**Why it happens:**
Security-scoped URLs include an embedded access token that expires when the app process terminates. Storing the URL string does not persist the token. Only a properly created security-scoped bookmark (via `URL.bookmarkData(options: .withSecurityScope)`) persists access across launches.

**How to avoid:**
SonicMerge's current design uses the temp directory for processing — imported files are copied to the app's sandbox first. This is the correct approach and avoids the bookmark problem entirely. The key rule: always copy imported files into the app's own container (e.g., `FileManager.default.urls(for: .documentDirectory)`), then immediately call `stopAccessingSecurityScopedResource()` on the original URL.

```swift
// Correct pattern: copy, don't store URL
let dest = documentsDir.appendingPathComponent(sourceURL.lastPathComponent)
guard sourceURL.startAccessingSecurityScopedResource() else { return }
defer { sourceURL.stopAccessingSecurityScopedResource() }
try FileManager.default.copyItem(at: sourceURL, to: dest)
// Work with dest from here — no security scope needed
```

**Warning signs:**
- File access works during the session but fails after app restart
- `startAccessingSecurityScopedResource()` returns `false`
- `Error Domain=NSCocoaErrorDomain Code=257 "The file could not be opened because you don't have permission to view it"`

**Phase to address:** Phase 1 (Import pipeline)

---

### Pitfall 8: AVAudioFile Format vs. Processing Format Mismatch Causes Silent Writes

**What goes wrong:**
`AVAudioFile` has two formats: `fileFormat` (the format on disk) and `processingFormat` (the format used for reading/writing buffers in memory). By default, `processingFormat` is 32-bit float, deinterleaved, at the hardware sample rate — regardless of the file's actual format. Writing a buffer in the wrong format (e.g., 16-bit integer when `processingFormat` expects 32-bit float) produces a file that appears valid but plays silence or garbage audio.

Additionally, `.m4a` file extension causes `AVAudioFile` to fail to open for writing in some configurations, while `.aac` extension works. The reverse is also true for reading contexts.

**Why it happens:**
Developers create `AVAudioFile` for writing by specifying the target format (e.g., 44100 Hz, 16-bit, AAC) but then write `AVAudioPCMBuffer` objects in the default processing format (32-bit float, 48000 Hz). The write succeeds without error, but the data is wrong.

**How to avoid:**
Always use `AVAudioConverter` to convert buffers to the file's output format before writing. Explicitly set the output file's settings to match the processing format you intend to use.

```swift
// Explicit format alignment
let outputSettings: [String: Any] = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVSampleRateKey: 44100,
    AVNumberOfChannelsKey: 2,
    AVLinearPCMBitDepthKey: 16
]
let outputFile = try AVAudioFile(forWriting: url, settings: outputSettings,
                                  commonFormat: .pcmFormatFloat32, interleaved: false)
// Now write Float32 deinterleaved buffers directly — they match processingFormat
```

**Warning signs:**
- Written file size is correct but audio is silent or corrupted noise
- File plays back in `AVAudioPlayer` but contains garbage
- No errors thrown during buffer write operations

**Phase to address:** Phase 2 (Denoising output writing / Export pipeline)

---

### Pitfall 9: Swift 6 Concurrency Violations in Audio Render Callbacks

**What goes wrong:**
`AVAudioEngine` render callbacks (install tap, `AVAudioSinkNode`, `AVAudioSourceNode`) execute on a real-time audio thread. Swift 6's strict concurrency model (`@MainActor`, actor isolation) causes compiler errors when these callbacks attempt to touch any actor-isolated state. Developers work around this with `@unchecked Sendable` or `nonisolated` annotations without understanding the implications, introducing real data races.

Separately, real-time audio callbacks must not perform: memory allocation, Objective-C messaging, mutex locking, `DispatchQueue.async`, or any Swift collection operations (all potentially allocate). Violating these rules causes audio glitches or deadlocks that are extremely hard to reproduce.

**Why it happens:**
Swift 6 was designed for high-level concurrency. Audio render callbacks are a low-level real-time context that predates Swift's concurrency model. The two paradigms are fundamentally in tension.

**How to avoid:**
- Treat audio callbacks as a C-level context: pre-allocate all buffers before the engine starts, use atomic ring buffers for communication between audio thread and Swift actors
- Never call Swift async/await from within a render callback
- Use `@preconcurrency` attribute on audio delegate protocol conformances only where you can guarantee the isolation is already correct
- Keep all audio graph manipulation on the main thread, not inside `Task { }` or background actors

**Warning signs:**
- Compiler errors like "expression is not concurrency-safe because flow of non-Sendable"
- Audio clicks and pops that correlate with UI interactions (sign of mutex contention on audio thread)
- Deadlocks that only occur when the app is under memory pressure

**Phase to address:** Phase 2 (Audio engine implementation) — establish threading model before writing any callback code

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Store imported file URL directly instead of copying to sandbox | Skip copy step, faster import | URL access fails after app restart or when source file moves | Never — always copy |
| Use `AVAssetExportPresetPassthrough` for final export | Faster export, lossless | Silently fails with mismatched sample rates; no format guarantee | Never for user-facing export |
| Skip audio format normalization on import | Simpler import pipeline | Composition produces corrupted output with mixed-source files | Never |
| Use `AVAudioEngine` Voice Processing for file denoising | Simpler than Core ML integration | Fundamentally does not work on file input — silent or mic-bleed audio | Never |
| Process audio in Share Extension before handoff | One-step UX | 120MB memory limit kills process silently; Simulator hides the bug | Never |
| Call `engine.start()` immediately after `setVoiceProcessingEnabled` | Simpler code | Race condition — engine appears started but produces silence | Never |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Share Extension → Main App | Passing audio file data via `NSUserDefaults` | Copy file to App Group container, store path in shared `UserDefaults`, open main app via URL scheme |
| `NSItemProvider` audio loading | Holding all loaded URLs / buffers in memory simultaneously | Load file representation one at a time, copy to disk, release URL before loading next |
| `AVAssetExportSession` cancellation | Calling `cancelExport()` then immediately creating new session at same output URL | Nil the exporter, wait for completion handler, then create fresh session |
| `AVAudioEngine` configuration change | Ignoring `AVAudioEngineConfigurationChange` notification | Always observe and restart engine in notification handler |
| `AVAudioFile` for output | Using `.m4a` extension for writing AAC via AVAudioEngine | Use explicit settings dictionary with `AVFormatIDKey: kAudioFormatMPEG4AAC` and verify extension matches |
| Security-scoped URL | Storing `URL.absoluteString` in `UserDefaults` for cross-session access | Copy file into app sandbox immediately, stop accessing security scope, work with sandbox copy |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Loading entire audio file into `AVAudioPCMBuffer` for processing | OOM crash on files > 10 minutes at 48kHz | Stream audio through engine in chunks; never buffer entire file | Files larger than ~50MB (roughly 8 min uncompressed stereo) |
| `installTapOnBus` buffer size ignored by system | Processing glitches when system chooses different buffer size than requested | Design callback to handle any buffer size, not just the requested size | Any file; behavior varies by device generation |
| Chained composition: export output → new composition input | Progressively longer stalls, eventual session hang | Always release all references to previous exporter before starting new one | First or second chained operation |
| Main-thread-blocking `loadTracks(withMediaType:)` (old sync API) | UI freeze during import with large files | Use async `load(.tracks)` with Swift concurrency (iOS 16+) | Files larger than a few MB |
| Re-creating `AVAudioEngine` for each denoising operation | CPU spike and audio graph setup latency per file | Keep engine as a long-lived service, reset player nodes between operations | Any file; latency is ~100-300ms per init |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Logging audio file paths including user file names | Privacy leak in crash reports / analytics | Hash or truncate file names in logs; never log user content paths |
| Writing processed audio to shared App Group container permanently | Other apps (extensions) can read user's audio without explicit access | Use shared container only for transient handoff; immediately move to app's private Documents directory |
| Not calling `stopAccessingSecurityScopedResource()` | Kernel resource leak — security-scoped resource count is finite | Always use `defer { url.stopAccessingSecurityScopedResource() }` pattern |
| Trusting file extension to determine audio format | Malformed `.m4a` file that is actually WAV causes format detection to fail dangerously | Use `AVURLAsset` and check `AVAssetTrack.formatDescriptions` before assuming format |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Long-running export with no progress indicator | User force-quits, triggering the session-wedge bug (Pitfall 5) | Show `AVAssetExportSession.progress` in real time; provide cancel button |
| Denoising runs synchronously on main thread | UI freezes for the duration; watchdog kills app after ~10 seconds | Always run denoising in a `Task { }` with `await`; update UI on `@MainActor` |
| No A/B preview before export | User discovers denoising ruined the audio only after saving | Implement in-memory before/after playback toggle before any export |
| Export completes but file is in an unexpected format | User can't open `.aac` extension file in their DAW | Always export as `.m4a` container (widely compatible) or `.wav` for lossless; not `.aac` bare |
| Importing file while share extension handles handoff | Duplicate file creation if user taps import twice quickly | Disable import button during active handoff; use unique temp filenames with UUID |
| Haptic feedback firing on audio thread | Rare crash or audio glitch | Call `UIImpactFeedbackGenerator` exclusively on main thread, never from audio callback |

---

## "Looks Done But Isn't" Checklist

- [ ] **Denoising:** Appears to work in a quiet room with speaker bleed into mic — verify denoising works with headphones connected (no speaker → mic path), otherwise the output is raw mic noise, not file processing
- [ ] **Export:** Exported file plays correctly in iOS Files app — also verify it opens in QuickTime, GarageBand, and VLC (format compatibility goes beyond AVPlayer)
- [ ] **Share Extension:** Works in Simulator — must test on physical device with a real 30MB+ audio file to surface the 120MB memory limit bug
- [ ] **Composition:** Merged file sounds correct in AVPlayer preview — also verify total duration matches sum of input durations; silent drops can be inaudible in preview but visible in waveform
- [ ] **Concurrent exports:** Single export works — verify that cancelling an export mid-way and starting a new one does not wedge the session
- [ ] **Format variety:** Works with Voice Memo (.m4a 44.1kHz) — also test with: WhatsApp audio (16kHz), downloaded podcast audio (128kbps MP3), and high-quality recordings (48kHz WAV)
- [ ] **Background transition:** Export completes when app is foregrounded throughout — also verify behavior when user backgrounds the app during export (iOS may suspend the task)
- [ ] **AVAudioEngine restart:** Engine starts correctly on first launch — also test after receiving a phone call, after AirPods connect/disconnect, and after Siri activation (all trigger `AVAudioEngineConfigurationChange`)

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Voice Processing used for file denoising | HIGH | Replace entire NoiseReductionService with Core ML pipeline; affects denoising phase deliverables |
| Export session permanently wedged | LOW | Cancel session, nil references, present error to user with "Try Again" — user may need device reboot in edge cases |
| Share Extension OOM crash | MEDIUM | Redesign extension to be a pure relay (no processing); move all logic to main app |
| Composition with mixed sample rates produces corrupted output | MEDIUM | Add pre-import normalization step (transcode to canonical format before composition) |
| Security-scoped URL lost after restart | LOW | Add import flow that copies to sandbox; existing session still works |
| AVAudioEngine silent after voice processing toggle | LOW | Implement `AVAudioEngineConfigurationChange` observer and auto-restart |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Voice Processing cannot denoise files (Pitfall 1) | Phase 1 (Architecture decision) | Denoising with headphones plugged in produces clean output, not mic noise |
| Engine stops on voice processing toggle (Pitfall 2) | Phase 2 (Denoising implementation) | Engine reliably starts after `setVoiceProcessingEnabled`; test 20+ times |
| Share Extension 120MB memory limit (Pitfall 3) | Phase 1 (Share Extension scaffold) | Test with 50MB WAV on physical device; no extension crash |
| Mismatched sample rates in composition (Pitfall 4) | Phase 1 (Audio merging) | Merge Voice Memo + WAV + podcast MP3; verify duration accuracy |
| AVAssetExportSession wedge (Pitfall 5) | Phase 2 (Export pipeline) | Cancel export 10 times in rapid succession; subsequent export completes |
| Voice Processing breaks screen recording (Pitfall 6) | Phase 2 (Denoising) | Screen record during denoising; verify audio captured (or document limitation) |
| Security-scoped URL stale after restart (Pitfall 7) | Phase 1 (Import pipeline) | Import file, kill app, relaunch — verify file still accessible |
| AVAudioFile format mismatch (Pitfall 8) | Phase 2 (Denoising output / export) | Verify exported WAV and M4A play correctly in QuickTime and VLC |
| Swift 6 concurrency in audio callbacks (Pitfall 9) | Phase 2 (Audio engine) | Zero runtime concurrency warnings; no audio glitches under UI load |

---

## Sources

- [AVMutableComposition drops portion of audio track — Open Radar FB8742994](https://openradar.appspot.com/FB8742994)
- [AVAssetExportSession fails in composition — Apple Developer Forums](https://developer.apple.com/forums/thread/122384)
- [Tips about AVAudioEngine (2024) — snakamura.github.io](https://snakamura.github.io/log/2024/11/audio_engine.html)
- [Volume issue when Voice Processing IO is used — Apple Developer Forums](https://developer.apple.com/forums/thread/721535)
- [AVAudioEngine Voice Processing — WWDC23: What's new in voice processing](https://developer.apple.com/videos/play/wwdc2023/10235/)
- [Performing Offline Audio Processing — Apple Developer Documentation](https://developer.apple.com/documentation/avfaudio/audio_engine/performing_offline_audio_processing)
- [Enabling VoiceProcessing on AudioKit results in broken graph — AudioKit GitHub Issue #2606](https://github.com/AudioKit/AudioKit/issues/2606)
- [Dealing with memory limits in iOS app extensions — blog.kulman.sk](https://blog.kulman.sk/dealing-with-memory-limits-in-app-extensions/)
- [Share extension memory limit issue — element-ios GitHub Issue #2341](https://github.com/vector-im/riot-ios/issues/2341)
- [AVAudioEngine sample rate mismatch on newer devices — Apple Developer Forums](https://developer.apple.com/forums/thread/680785)
- [AVAssetExportSession stuck in waiting state — Apple Developer Forums](https://developer.apple.com/forums/thread/649671)
- [Non-Deterministic AVAssetExportSession Export Failure — copyprogramming.com](https://copyprogramming.com/howto/avassetexportsession-export-fails-non-deterministically-with-error-operation-stopped-nslocalizedfailurereason-the-video-could-not-be-composed)
- [AVAudioFile format issue GitHub reproduction — ThomasHezard/AVAudioFileFormatIssue](https://github.com/ThomasHezard/AVAudioFileFormatIssue)
- [Security-scoped bookmarks for URL access — SwiftLee](https://www.avanderlee.com/swift/security-scoped-bookmarks-for-url-access/)
- [NSItemProvider loadFileRepresentation — all-about-item-providers — humancode.us](https://www.humancode.us/2023/07/08/all-about-nsitemprovider.html)
- [AVAudioEngine thread-safety — Apple Developer Forums](https://developer.apple.com/forums/thread/123540)
- [AVAudioSourceNode / AVAudioSinkNode — orjpap.github.io (2024)](https://orjpap.github.io/swift/low-level/audio/avfoundation/2024/09/19/avAudioEffectNode.html)
- [Using voice processing — Apple Developer Documentation](https://developer.apple.com/documentation/avfaudio/audio_engine/audio_units/using_voice_processing)
- [App Group data sharing for Share Extensions — atomicbird.com](https://www.atomicbird.com/blog/sharing-with-app-extensions/)

---
*Pitfalls research for: iOS audio processing — SonicMerge (AVFoundation, AVAudioEngine, Share Extensions)*
*Researched: 2026-03-08*

---
---

# Pitfalls Research — v1.1 Milestone Addendum

**Domain:** SwiftUI Visual Restyle — Modern Spatial Utility (glassmorphism, mesh gradients, custom animations, color system)
**Researched:** 2026-04-08
**Confidence:** MEDIUM-HIGH (verified against Apple Developer Documentation, community performance reports, SwiftUI WWDC sessions, and accessibility guidelines)

---

## Critical Pitfalls

### Pitfall R-1: Animated MeshGradient Runs at Full 120Hz on ProMotion — No Throttling by Default

**What goes wrong:**
`MeshGradient` (iOS 18+) with animated point positions using `withAnimation(.easeInOut.repeatForever())` or `TimelineView` will render at the device's maximum refresh rate — 120Hz on ProMotion iPhones (15 Pro and newer). A mesh gradient used as a waveform background on every audio card in a `List` or `LazyVStack` means the GPU is compositing multiple independently-animated Metal layers at full frame rate at all times, even when the user is idle. This becomes a sustained thermal and battery load identical to running a real-time game.

**Why it happens:**
`MeshGradient` is GPU-accelerated via Metal. Unlike `LinearGradient`, it cannot be rendered as a static cached layer when its control points are changing every frame. Each animated gradient instance creates its own render pass. Placing five animated cards on screen = five concurrent Metal render passes at 120Hz.

**How to avoid:**
- Use `TimelineView` with `.animation` schedule and explicitly cap update frequency: request 30fps updates, not the default "as fast as possible"
- Better: use `MeshGradient` with **static** control points but animated colors only — color interpolation is cheaper than geometry recalculation
- Best: treat mesh gradients as **decorative static backgrounds** rendered once; animate a separate `Color` or `LinearGradient` overlay on top at low frequency
- Profile with Instruments → Core Animation FPS gauge on a physical device before shipping
- On non-ProMotion devices (iPhone 14 and older), this caps at 60Hz, masking the issue in development if you test on an older device

**Warning signs:**
- Device becomes warm during normal browsing of the audio card list
- Instruments shows GPU utilization above 40% when the app is idle (user not interacting)
- Battery drains noticeably faster compared to v1.0 in the same workflow
- `CADisplayLink` frame rate in Instruments shows consistent 120fps even when nothing is moving

**Phase to address:** Design System phase — establish the animation budget rule before any card component is built. Enforce: no mesh gradient animates its geometry at runtime unless triggered by explicit user interaction.

---

### Pitfall R-2: `.background(.ultraThinMaterial)` Fails Contrast Requirements on Pure Black Background

**What goes wrong:**
The v1.1 dark mode uses pure black (`#000000`) as the base background. `UIVisualEffectView` / SwiftUI `.ultraThinMaterial` reads the background behind it and applies a vibrancy blur. On pure black, `.ultraThinMaterial` renders as near-transparent dark glass — content on top (text, icons) is effectively dark-on-dark. WCAG 2.2 requires 4.5:1 contrast for normal text and 3:1 for large text. Text on `.ultraThinMaterial` over pure black frequently falls below 2:1, making it unreadable for users with low vision.

The problem is dynamic: when the glassmorphism header sits over the animated mesh gradient waveform (which shifts between Deep Indigo and purple), the effective contrast ratio of overlaid text changes every frame. There is no single contrast ratio to audit — it varies continuously.

**Why it happens:**
Developers test glassmorphism in light mode where `.ultraThinMaterial` produces a light frosted panel with adequate contrast. Dark mode is tested with the default dark gray system background (`#1C1C1E`), not pure black. Pure black is a distinct failure mode that only appears when `#000000` is used.

**How to avoid:**
- Use `.regularMaterial` or `.thickMaterial` instead of `.ultraThinMaterial` in dark mode — these maintain higher opacity and produce more reliable contrast
- Add a semi-opaque dark overlay (`Color.black.opacity(0.4)`) beneath text content inside the glass panel, regardless of what the blur renders
- Never place small body text directly on a material without a guaranteed minimum-opacity backing
- Use the Accessibility Inspector's contrast checker (Xcode → Open Developer Tool → Accessibility Inspector) against the worst-case dark background combination, not just the default gray
- Define separate glassmorphism implementations for light and dark: `.ultraThinMaterial` for light, `.regularMaterial` for dark

**Warning signs:**
- Text in the glassmorphism header is readable in light mode but barely visible in dark mode
- Accessibility Inspector reports contrast ratio below 4.5:1 in dark mode
- Users on OLED devices (where black is true black, not dark gray) report header text is invisible

**Phase to address:** Design System phase — color token definitions must include the glass panel opacity values and specify which `Material` thickness maps to each mode. Don't leave this to per-view implementation.

---

### Pitfall R-3: Continuous "Pulsating Orb" Animation Ignores `accessibilityReduceMotion` — App Store Rejection Risk

**What goes wrong:**
The AI Orb visualizer in the Cleaning Lab is a continuously pulsating nebula sphere using `withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true))`. If `@Environment(\.accessibilityReduceMotion)` is not checked, this animation runs permanently for users who have enabled "Reduce Motion" in iOS Settings. Apple's App Store review guidelines (Guideline 5.1.1) call out accessibility compliance. Continuous looping animations that ignore the Reduce Motion preference have triggered App Store rejections, particularly since iOS 17 tightened enforcement.

Beyond rejection risk: oscillating animations at ~0.5 Hz (one full pulse every 2 seconds) fall within the frequency range Apple's own HIG identifies as potentially causing vestibular discomfort for susceptible users.

**Why it happens:**
`withAnimation(.repeatForever())` does not consult the Reduce Motion setting. It runs regardless. Developers assume "Reduce Motion" only affects transition animations, but Apple documents it as covering all repetitive animations.

**How to avoid:**

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// In view body:
Circle()
    .scaleEffect(reduceMotion ? 1.0 : animationScale)
    .animation(
        reduceMotion ? nil : .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
        value: animationScale
    )
    .onAppear {
        if !reduceMotion { animationScale = 1.15 }
    }
```

- When Reduce Motion is active: show the orb as a static glowing circle (no pulsation), or use a very slow, subtle opacity shift (not scale/position changes) that stays below the vestibular threshold
- `withAnimation()` does **not** respect Reduce Motion automatically — you must check the environment value explicitly; using `.animation(nil, value:)` is the correct suppression

**Warning signs:**
- App runs on a device with "Reduce Motion" enabled and the orb still pulses
- No `accessibilityReduceMotion` environment usage anywhere in the Cleaning Lab view

**Phase to address:** AI Orb implementation phase — bake in the Reduce Motion check from the first line of animation code. Do not retrofit accessibility after the feature is "done."

---

### Pitfall R-4: Color Tokens Defined as Hex `Color` Extensions Break Dark Mode in Sheets and Popovers

**What goes wrong:**
SonicMerge's existing `Color+Theme.swift` extension likely defines colors as static `Color` instances with hardcoded hex values (e.g., `static let accent = Color(hex: "#5856D6")`). When a sheet or popover is presented, SwiftUI creates a new presentation host with its own color scheme context. The sheet's color scheme does not automatically inherit the parent view's overridden `colorScheme`. If the sheet uses hardcoded hex colors instead of adaptive Asset Catalog colors, the sheet will show the same colors in both light and dark mode — the dark mode adaptation is missing entirely.

This affects the Export sheet, any alert-style presentation, and the drag-reorder overlay if it uses a custom sheet layer.

**Why it happens:**
Hardcoded hex `Color` values have no light/dark mode awareness. They are always the same RGB value. Asset Catalog color sets (`Color("AccentIndigo")`) have built-in appearance variants. The `.colorScheme()` modifier on a parent view does not propagate into sheets — sheets use the system color scheme directly, bypassing any override.

**How to avoid:**
- Define all v1.1 color tokens in `Assets.xcassets` as Color Sets with separate "Any Appearance" and "Dark" variants — not as hex `Color` extensions
- From Xcode 15+, Asset Catalog colors are accessible as `Color.accentIndigo` via auto-generated code (no string literals needed)
- If extending `Color` for convenience, make the extension read from the Asset Catalog: `static let accentIndigo = Color("AccentIndigo")` — not `Color(hex: "#5856D6")`
- Use `preferredColorScheme(_:)` on sheets explicitly if the app implements a custom color scheme toggle

**Warning signs:**
- Sheets appear with light-mode colors even when the app is in dark mode
- Export or modal views look visually inconsistent with the main screen in dark mode
- `Color(hex:)` initializer appears in any file under the `/Features` directory

**Phase to address:** Design System phase — establish the Asset Catalog token structure as the first deliverable. Every subsequent view component must use only tokens from the catalog; no hex string colors in view code.

---

### Pitfall R-5: Custom `Shape` for Squircle Breaks Drag-and-Drop Hit Testing

**What goes wrong:**
The v1.1 audio card uses a squircle shape (24pt continuous corner radius via `RoundedRectangle(cornerRadius: 24, style: .continuous)` or a custom superellipse `Shape`). When a card is long-pressed for drag-and-drop reordering (the existing v1.0 gesture), the hit-test region for the drag recognizer is the card's bounding rectangle, not the shape's filled area. For a squircle with significant corner smoothing, the hot corners of the bounding box lie outside the visible card. Users tapping near the visual corners may hit the card below rather than the intended card. Additionally, applying `.clipShape(squircle)` removes the default `contentShape`, meaning SwiftUI gesture hit-testing defaults to the bounding box — the exact opposite of what's visually implied.

**Why it happens:**
SwiftUI's hit-testing uses the view's frame by default, not the shape's path. `.clipShape()` clips rendering but does not change the interaction area. The `contentShape()` modifier must be applied explicitly to match visual shape to interaction shape.

**How to avoid:**
```swift
AudioCardView()
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    // contentShape must match clipShape exactly
```

- Always pair `.clipShape()` with `.contentShape()` using the same shape definition — extract to a shared constant to prevent divergence
- After restyling each card, run the existing drag-and-drop reorder interaction and verify taps near all four corners of every card register on the correct card
- Test on the smallest supported device (iPhone SE) where cards are narrow and corner regions represent a larger proportion of the tap area

**Warning signs:**
- Tapping the upper-right or lower-left corner of a card triggers the card above or below instead
- Long-press for reorder works in the card center but not near corners
- Drag gesture activates even when tapping clearly in the gap between cards (bounding box overlap)

**Phase to address:** Audio card restyle phase — add `.contentShape()` immediately when `.clipShape()` is applied. Do not merge any card restyle PR without running the full drag-and-drop regression test.

---

### Pitfall R-6: Elevated Shadow on Dragged Card Causes Render Layer Explosion During Reorder

**What goes wrong:**
The v1.1 spec adds "elevated drag shadows on card interaction (micro-interactions)." Implementing this as `.shadow(radius: 20, y: 10)` applied conditionally during drag — combined with an existing `List` or `LazyVStack` with multiple cards, each with their own `.background(.regularMaterial)` — creates a compounding problem. Each shadowed card with a material background requires its own offscreen compositing layer. During drag, if the dragged card's shadow animates (radius 4 → radius 20 while lifting), and other cards scale/offset to make room, the number of simultaneous render layers can reach 10-15. On older A14/A15 devices this causes frame drops to 30-40fps during the reorder gesture, making the interaction feel broken.

**Why it happens:**
SwiftUI promotes views to their own `CALayer` when they have: blur materials, shadows, opacity changes, or 3D transforms. Each promotion costs compositing time. Combining all three (material + animated shadow + scale transform during drag) on multiple cards simultaneously exceeds the GPU's compositing budget on lower-end devices.

**How to avoid:**
- Use `drawingGroup()` on the card component to flatten it into a single Metal layer before the shadow is applied — this makes the card render as a flat texture with a shadow, not a multi-layer composition
- Limit the elevated shadow to the **dragged card only** (it's already hoisted above others); sibling cards only need the default low-elevation shadow
- Use `compositingGroup()` as an alternative to `drawingGroup()` when the card contains text or controls (drawingGroup breaks text rendering)
- Keep shadow radius small (max 16) — shadow spread is expensive at large radii because it blurs a larger area
- Profile the drag interaction with Instruments → Core Animation on an iPhone 12 (A14 baseline) before shipping

**Warning signs:**
- Drag reorder is smooth on iPhone 15 Pro but choppy on iPhone 12 or 13
- Instruments shows "Offscreen Rendered" warnings during drag interactions
- Frame rate drops from 60fps to 30-40fps precisely when drag begins

**Phase to address:** Audio card restyle and drag interaction phase — establish the shadow/layer budget rule before implementing any card effects. Test drag performance on a non-Pro device.

---

### Pitfall R-7: Restyling Breaks Existing View Identity — Drag Reorder State Resets Mid-Gesture

**What goes wrong:**
When wrapping existing views in new container views during restyle (e.g., wrapping `AudioCardView` in a `ZStack` for the mesh gradient background layer, then wrapping that in a `VStack` for the squircle border), SwiftUI's structural identity for the original view changes. If the drag-and-drop reorder gesture stores intermediate position state in `@State` variables inside `AudioCardView`, the state is silently reset whenever SwiftUI determines the view has a new structural identity. This can manifest as the dragged card snapping back to its original position mid-gesture when a parent re-render occurs (e.g., the audio waveform `TimelineView` updates its gradient, triggering a parent body re-evaluation).

**Why it happens:**
SwiftUI assigns view identity based on structural position in the view tree. Adding wrapper views (ZStack, Group, custom container) changes the structural path to `AudioCardView`. If the drag state is in `@State` at the card level and the card's structural identity changes, SwiftUI treats it as a new view and resets `@State` to initial values.

**How to avoid:**
- Use `.id(audioSegment.id)` explicit identity on every card component — this ensures identity is tied to the data model, not the view tree structure, making it invariant to wrapper additions
- Store drag state in the parent `ViewModel`, not in `@State` inside the card — `@State` is ephemeral and tied to view identity; ViewModel state survives view tree restructuring
- During restyle, run the full drag-and-drop reorder workflow after **every** structural wrapper addition before continuing. Catch identity breaks early, not after multiple layers of nesting have been added
- Use `Self._printChanges()` during development to detect unexpected re-renders of the card view during drag

**Warning signs:**
- Dragged card suddenly jumps back to original position during slow drags
- The issue appears only after a gradient animation tick occurs during the drag
- Explicit `.id()` is missing from the `ForEach` that renders audio cards

**Phase to address:** Restyle implementation phases — add `.id(segment.id)` to all `ForEach` items as the first step before any other restyle changes. Commit this as a standalone safety commit.

---

### Pitfall R-8: Haptic Feedback on Every Button State Change Degrades Experience and Drains Battery

**What goes wrong:**
The v1.1 spec calls for "haptic-responsive button states throughout." If implemented as `UIImpactFeedbackGenerator.impactOccurred()` on every `onPressed` state change for pill buttons, and if pill buttons respond to both `.pressed` (on touch down) and `.released` (on touch up), each button interaction produces two haptic events. With multiple interactive elements on screen (audio cards with play/pause, the AI toggle, slider controls, drag handles), a user performing a sequence of interactions within a few seconds triggers rapid-fire taptic engine activations. iOS rate-limits haptics when triggered too frequently — the taptic engine silently drops events after ~5 per second, making the feature feel inconsistent.

Battery impact: the taptic engine is a physical solenoid actuator. Calling it frequently on background tasks or in response to non-user events (e.g., animation state changes triggering view updates that inadvertently call the generator) creates measurable battery drain.

**Why it happens:**
Haptic generators are easy to add (`UIImpactFeedbackGenerator(style: .medium).impactOccurred()`) and feel great in isolation. The problem emerges when multiple components add haptics independently without a central policy. SwiftUI's `.sensoryFeedback` modifier (iOS 17+) is the correct approach but developers unfamiliar with it fall back to UIKit generators.

**How to avoid:**
- Use SwiftUI's `.sensoryFeedback(.impact(weight: .medium), trigger: isPressed)` modifier — it automatically respects the system's haptic budget and Reduce Motion settings
- Apply haptics only to **confirmed actions**, not speculative state changes: one haptic on confirmed tap (touch up), zero on touch down for standard buttons
- Create a `HapticService` singleton that rate-limits calls internally — no direct `UIImpactFeedbackGenerator` usage in views
- Haptics for drag reorder: one impact on pickup, one on drop — not continuous feedback during movement
- Never trigger haptics in response to data updates, animation state changes, or timers — only in direct response to user gesture events

**Warning signs:**
- `.impactOccurred()` call sites appear directly inside `Button` bodies or `onTapGesture` modifiers
- Multiple haptic generators are instantiated (each generator has its own idle timeout — creating many wastes resources)
- Users report the haptics feel "choppy" or "some taps don't vibrate" (rate-limiting in effect)

**Phase to address:** Design System phase — define the haptic policy in the shared component library. Pill button component encapsulates its own haptic call; no downstream view adds additional haptics on top.

---

## Technical Debt Patterns (v1.1 Restyle Addendum)

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Define all color tokens as hex `Color` extensions | Quick to write, autocomplete works | Dark mode breaks in sheets; no centralized light/dark variant management | Never — use Asset Catalog Color Sets |
| Animate MeshGradient control points at 60/120Hz continuously | Visually impressive waveform effect | Sustained GPU load, thermal throttling, battery drain on all devices | Never for ambient background animations; only on explicit user interaction |
| Use `.ultraThinMaterial` for all glass surfaces regardless of mode | Single code path | Fails contrast requirements on pure black dark mode backgrounds | Light mode only; use `.regularMaterial` in dark mode |
| Add haptic generators directly in each view | Fast to implement | Rate-limiting inconsistencies; no central policy; battery waste | Never — route through `HapticService` |
| Skip `.contentShape()` when adding `.clipShape()` | Fewer lines of code | Drag hit-testing breaks at card corners; swipe-to-delete misregisters | Never — always pair them |
| Wrap existing views in multiple `ZStack`/`VStack` containers without explicit `.id()` | Easiest structural approach | View identity breaks; drag state resets mid-gesture | Never during restyle of interactive views |
| Implement Reduce Motion check as a later "polish" task | Ship animation faster | App Store rejection risk; vestibular accessibility failure | Never — must be day-one requirement |

---

## Integration Gotchas (v1.1 Restyle Addendum)

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `MeshGradient` + `List` | Placing animated `MeshGradient` as `listRowBackground` — animates every visible row simultaneously | Use static `MeshGradient` as background; animate a thin `LinearGradient` overlay at 2fps |
| `.background(.material)` + custom `colorScheme` override | Material ignores parent `.colorScheme()` — renders in system color scheme, not overridden one | Do not override `colorScheme` at the app level; use Asset Catalog adaptive colors instead |
| SwiftUI `sensoryFeedback` + iOS 16 deployment target | `.sensoryFeedback` is iOS 17+ only; using it crashes on iOS 16 | Gate behind `if #available(iOS 17, *)` or raise minimum deployment to iOS 17 (already set in this project) |
| `TimelineView` + `MeshGradient` animation | `TimelineView(.animation)` driving a `MeshGradient` update runs at screen refresh rate with no opt-out | Use `TimelineView(.periodic(from:, by:))` with a 0.5-second interval for ambient animations |
| `.shadow()` + `.background(.material)` on same view | Material requires its own compositing layer; shadow on the same view doubles layer promotion cost | Apply shadow to an outer container; apply material to an inner view — separate the layers |
| Glassmorphism header + `ScrollView` offset | Blurred header positioned as `overlay` over `ScrollView` — scroll content visible through blur but also tappable behind it | Add `.allowsHitTesting(false)` to the blur overlay; add content inset to `ScrollView` equal to header height |

---

## Performance Traps (v1.1 Restyle Addendum)

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Multiple animated MeshGradients in a LazyVStack | Device warms up; GPU utilization 60%+ at idle | Use static MeshGradient; animate overlay only | More than 3 cards visible simultaneously |
| `.blur(radius:)` on foreground elements for "frosted" effect | Blur is applied to the view's own pixels, not background — creates a smeared look, not glass | Use `.background(.material)` for background blur; `.blur()` is for blurring content, not achieving glassmorphism | Immediately — wrong technique entirely |
| Nested `withAnimation(.repeatForever)` inside ForEach | N×M animations active simultaneously (N cards × M animated properties) | Hoist animation state out of ForEach; use a single timer driving all card animations in sync | 3+ cards visible |
| `drawingGroup()` on views containing text or interactive controls | Text renders incorrectly (antialiasing breaks); buttons lose tap areas | Use `compositingGroup()` instead; only use `drawingGroup()` for pure graphic views | Immediately on any card with a label |
| Elevated shadow with `.animation(.spring)` on drag lift | Spring physics runs on every frame during drag; combined with material compositing = frame drops | Pre-compute shadow targets; use `.animation(.easeOut(duration: 0.15))` for shadow changes | A14 and A15 devices under load |

---

## UX Pitfalls (v1.1 Restyle Addendum)

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Lime green AI highlights (`#A7C957`) on dark background have poor contrast against purple mesh | Text unreadable over animated gradient sections | Test lime on Deep Indigo (`#5856D6`) specifically: this combination passes 3:1 but borderline; use white for labels, lime for decorative glows only |
| Pill button inner glow effect uses `.shadow(color: .white.opacity(0.3))` — invisible in dark mode | Button appearance looks flat in dark mode | Use `foregroundStyle` vibrancy or explicit light/dark glow colors via Asset Catalog |
| Squircle card clips content — overflow text gets clipped without warning | File names truncate at the rounded corners, appearing shorter than container | Ensure text has explicit horizontal padding ≥ corner radius value (24pt minimum inset) |
| AI orb scales in size based on "denoise intensity" — useful feedback but triggers "Reduce Motion" concerns | Users with vestibular disorders see scale changes associated with slider drag | Tie orb scale to a static display value, not live-animated; update only on slider release |
| Color system uses pure black `#000000` — true black on OLED | Most screens look great; but pure black with white text at full brightness causes "halation" (halo effect) perceived by some users | Add a minimum brightness level suggestion or slightly tinted black (`#0A0A0F`) as the base |

---

## "Looks Done But Isn't" Checklist (v1.1 Restyle Addendum)

- [ ] **Mesh gradient waveforms:** Look beautiful in Simulator — test GPU temperature and battery draw on a physical iPhone 14 or earlier (non-ProMotion baseline) with 5+ cards visible
- [ ] **Glassmorphism header dark mode:** Readable in Xcode Preview with default dark background — test on a real device with pure black OLED showing deep black behind the header; run Accessibility Inspector contrast check
- [ ] **AI orb animation:** Smooth and impressive — turn on "Reduce Motion" in iOS Settings and confirm the orb is static (no pulsation, no scale change)
- [ ] **Pill button haptics:** Fires on tap in isolation — tap 10 buttons in 3 seconds; verify each produces exactly one haptic (no doubling, no silent drops)
- [ ] **Drag reorder after restyle:** Works on new card design — long-press and drag slowly while a mesh gradient animation ticks; confirm card does not snap back to origin
- [ ] **Squircle cards:** Appear correctly shaped — tap near each corner of every card type; confirm tap registers on that card, not adjacent cards
- [ ] **Color tokens in sheets:** Correct colors in main view — present the Export sheet and any modal; verify dark mode colors match the main screen
- [ ] **Shadow during drag:** Elevates cleanly on iPhone 15 Pro — test the same drag on an iPhone 12 or SE; verify no visible frame rate drop

---

## Recovery Strategies (v1.1 Restyle Addendum)

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Animated MeshGradient causes thermal throttling | MEDIUM | Replace animated geometry with static MeshGradient + animated LinearGradient overlay; 1-2 day fix per affected view |
| Color tokens in hex extensions break dark mode in sheets | LOW-MEDIUM | Migrate Color extensions to Asset Catalog Color Sets; find-replace usage sites |
| Reduce Motion not respected on orb | LOW | Add `@Environment(\.accessibilityReduceMotion)` check; wrap animation in conditional; 30-minute fix |
| Drag state resets during restyle | MEDIUM | Add explicit `.id()` to ForEach; migrate drag state to ViewModel; regression test all card interactions |
| Hit-test mismatch on squircle cards | LOW | Add matching `.contentShape()` wherever `.clipShape()` is used; 15-minute fix per component |
| Layer explosion during drag causing frame drops | MEDIUM-HIGH | Audit every view modifier on AudioCardView; remove or flatten unnecessary layer-promoting effects; measure frame rate on A14 device |

---

## Pitfall-to-Phase Mapping (v1.1 Restyle Addendum)

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Animated MeshGradient thermal load (R-1) | Phase 1: Design System — establish animation budget rule | GPU utilization < 20% on idle list view (iPhone 14, Instruments) |
| Glassmorphism contrast on pure black (R-2) | Phase 1: Design System — specify Material thickness per mode | Accessibility Inspector: all text ≥ 4.5:1 against worst-case background |
| Pulsating orb ignores Reduce Motion (R-3) | Phase 3: AI Orb implementation | Reduce Motion enabled → orb static; no animation in any property |
| Color tokens break in sheets (R-4) | Phase 1: Design System — Asset Catalog first | Export sheet and all modals show correct dark mode colors |
| Squircle breaks hit-test (R-5) | Phase 2: Audio card restyle | Tap all four corners of every card; drag from corners; verify correct card responds |
| Shadow layer explosion during drag (R-6) | Phase 2: Audio card restyle | Frame rate ≥ 55fps during drag reorder on iPhone 12 (Instruments) |
| View identity breaks with wrapper views (R-7) | Phase 2: Audio card restyle — add `.id()` first | Slow drag while gradient animates; card never snaps back mid-gesture |
| Haptic policy not enforced (R-8) | Phase 1: Design System — create HapticService | No direct `UIImpactFeedbackGenerator` in view files; 10 rapid taps all produce exactly one haptic each |

---

## Sources (v1.1 Restyle Addendum)

- [MeshGradient — Apple Developer Documentation](https://developer.apple.com/documentation/SwiftUI/MeshGradient)
- [Animated Mesh Gradient in SwiftUI — Medium / Rishabh Sharma](https://medium.com/@rishixcode/animated-mesh-gradient-in-swiftui-e1c2e11ed6bf)
- [Understanding and Improving SwiftUI Performance — Apple Developer Documentation](https://developer.apple.com/documentation/Xcode/understanding-and-improving-swiftui-performance)
- [Demystify SwiftUI Performance — WWDC23 Session 10160](https://developer.apple.com/videos/play/wwdc2023/10160/)
- [Glassmorphism Meets Accessibility: Can Glass Be Inclusive? — Axess Lab](https://axesslab.com/glassmorphism-meets-accessibility-can-glass-be-inclusive/)
- [Glassmorphism: Definition and Best Practices — Nielsen Norman Group](https://www.nngroup.com/articles/glassmorphism/)
- [Supporting Increase Contrast in your app — Create with Swift](https://www.createwithswift.com/supporting-increase-contrast-in-your-app-to-enhance-accessibility/)
- [iOS Color Contrast Best Practice: Increase Contrast — Deque](https://www.deque.com/blog/ios-color-contrast-best-practice-increase-contrast/)
- [Blur effect and materials in SwiftUI — Swift with Majid](https://swiftwithmajid.com/2021/10/28/blur-effect-and-materials-in-swiftui/)
- [Definitive SwiftUI Background Blur: Material vs. .blur() vs. UIKit Bridge — CodeArchPedia](https://openillumi.com/en/en-swiftui-background-blur-material-comparison/)
- [SwiftUI View Identity and Lifecycle: Why Views Recreate and State Resets — DEV Community](https://dev.to/sebastienlato/swiftui-view-identity-lifecycle-why-views-recreate-state-resets-3afm)
- [Common Pitfalls Caused by Delayed State Updates in SwiftUI — fatbobman.com](https://fatbobman.com/en/posts/serious-issues-caused-by-delayed-state-updates-in-swiftui/)
- [How to detect the Reduce Motion accessibility setting — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftui/how-to-detect-the-reduce-motion-accessibility-setting)
- [Reduce Motion: How To Make Your iOS App Animations Accessible — Medium / Amos Gyamfi](https://medium.com/@amosgyamfi/reduce-motion-how-to-make-your-ios-app-animations-accessible-and-inclusive-92b9de1304fb)
- [Supporting Reduced Motion accessibility setting in SwiftUI — tanaschita.com](https://tanaschita.com/ios-accessibility-reduced-motion/)
- [Mastering TimelineView in SwiftUI — Swift with Majid](https://swiftwithmajid.com/2022/05/18/mastering-timelineview-in-swiftui/)
- [Enabling high-performance Metal rendering with drawingGroup() — Hacking with Swift](https://www.hackingwithswift.com/books/ios-swiftui/enabling-high-performance-metal-rendering-with-drawinggroup)
- [SwiftUI + Core Animation: Demystify all sorts of Groups — Juniper Photon](https://juniperphoton.substack.com/p/swiftui-core-animation-demystify)
- [Access colors and images from asset catalog via static properties in Xcode 15 — nil coalescing](https://nilcoalescing.com/blog/Xcode15Assets/)
- [Reading and Setting Color Scheme in SwiftUI — nil coalescing](https://nilcoalescing.com/blog/ReadingAndSettingColorSchemeInSwiftUI/)
- [How to Change the Background Color of a View in SwiftUI — Bleeping Swift](https://bleepingswift.com/blog/change-background-color-swiftui)
- [Sensory Feedback and Haptics in SwiftUI — Bleeping Swift](https://bleepingswift.com/blog/sensory-feedback-haptics-swiftui)
- [SwiftUI Views and @MainActor — fatbobman.com](https://fatbobman.com/en/posts/swiftui-views-and-mainactor/)
- [Parametric Corner Smoothing in SwiftUI — Medium / Kumar Sachin](https://medium.com/@zvyom/parametric-corner-smoothing-in-swiftui-108acea52874)

---
*Pitfalls research for: SwiftUI visual restyle — SonicMerge v1.1 Modern Spatial Utility*
*Researched: 2026-04-08*
