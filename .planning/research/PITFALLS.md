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
