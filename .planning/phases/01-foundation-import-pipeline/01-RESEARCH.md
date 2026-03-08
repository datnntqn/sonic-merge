# Phase 1: Foundation + Import Pipeline - Research

**Researched:** 2026-03-08
**Domain:** iOS AVFoundation audio normalization, SwiftData persistence, App Group shared container, SwiftUI document picker
**Confidence:** HIGH (core APIs verified against official Apple documentation and developer forums)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Use **SwiftData** (iOS 17+) for clip persistence
- AudioClip model stored via SwiftData so clips survive app relaunch without re-importing
- App Group container holds the actual audio files; SwiftData model holds metadata + file URL references
- Normalize all imported audio to **48,000 Hz** sample rate
- Force **stereo (2-channel)** layout — convert mono imports to stereo; prevents AVMutableComposition mixed-layout corruption
- Store normalized clips as **AAC (.m4a)** in the App Group container
- App Group shared container must be configured in Phase 1 and accessible from both the main app and the future Share Extension target (Phase 5)
- MVVM architecture; Phase 1 establishes the ViewModel pattern

### Claude's Discretion
- Import error handling UX (per-file alert vs summary vs silent skip)
- Audio session category configuration (`.playback` vs `.playAndRecord`, interruption behavior)
- Exact container directory structure (flat vs per-clip subfolder)
- Normalization implementation (AVAssetExportSession with custom output settings vs AVAudioConverter)
- AVAudioSession activation timing (on launch vs on first import)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| IMP-01 | User can import multiple audio files in a single document picker session (multi-select) | SwiftUI `.fileImporter` modifier with `allowsMultipleSelection: true`; UTType arrays for .m4a/.wav/.aac |
| IMP-03 | App normalizes all imported audio to a canonical format (sample rate, channel layout) on import to prevent silent composition corruption | AVAssetReader (Linear PCM output) + AVAssetWriter (AAC/48kHz/stereo output) pipeline; AVAudioConverter for sample rate and channel upmix |
</phase_requirements>

---

## Summary

Phase 1 builds the entire foundation that subsequent phases depend on: SwiftData persistence with an App Group-backed store, a multi-file document picker, and a normalization pipeline that converts every imported file to 48 kHz / stereo / AAC before storing it in the shared container.

The most critical technical insight is that AVMutableComposition silently corrupts compositions when audio tracks have mismatched sample rates or channel layouts — it does not resample or upmix at composition time. Therefore normalization at import time is not optional; it is a hard requirement. The normalization pipeline must run before any file URL is persisted to SwiftData.

The App Group shared container must be configured from day one because the SwiftData `ModelConfiguration` needs its `groupContainer` parameter set during initial model container creation. Changing the store location after first launch triggers an automatic migration in iOS 17+/18+, but it is safer to set it correctly in Phase 1.

SwiftData in iOS 17+ natively supports App Groups via `ModelConfiguration(groupContainer: .identifier("group.com.yourteam.SonicMerge"))`. This ensures the SQLite store is created inside the App Group container directory, which the Phase 5 Share Extension will also access.

**Primary recommendation:** Use AVAssetReader (decompress to Linear PCM) + AVAssetWriter (encode to AAC 48 kHz stereo) for the normalization pipeline — this gives full control over output format, handles all input codecs, and is the pattern AVFoundation documentation prescribes for format conversion. Use SwiftUI `.fileImporter` (native, no UIViewControllerRepresentable needed) for multi-file selection.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData | iOS 17+ (bundled) | Persist AudioClip metadata and file URL references | iOS 17+ native, replaces Core Data boilerplate, integrates with `@Observable`/SwiftUI automatically |
| AVFoundation | iOS 17+ (bundled) | Audio reading, writing, format conversion | The only Apple-sanctioned framework for AVAsset-level audio I/O on iOS |
| AVFAudio | iOS 17+ (bundled) | AVAudioSession configuration, AVAudioConverter | Part of AVFoundation umbrella; required for session category and sample-rate conversion |
| UniformTypeIdentifiers | iOS 14+ (bundled) | Declare accepted UTTypes in document picker | Required for `.fileImporter` allowedContentTypes |
| SwiftUI | iOS 17+ (bundled) | UI layer; `.fileImporter` modifier | Native SwiftUI file picker, no UIViewControllerRepresentable wrapper needed |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Accelerate / vDSP | iOS 17+ (bundled) | Future DSP — NOT needed in Phase 1 | Phase 4 loudness normalization |
| CoreML | iOS 17+ (bundled) | NOT used in Phase 1 | Phase 3 denoising |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| AVAssetReader + AVAssetWriter | AVAssetExportSession with preset | Export session preset `AVAssetExportPresetAppleM4A` does NOT let you specify exact sample rate or channel count; it preserves source settings. Use Reader+Writer when precise format control is required. |
| AVAssetReader + AVAssetWriter | AVAudioConverter directly | AVAudioConverter works but requires reading the entire file into PCM buffers; Reader+Writer pipeline streams the file and handles compressed source formats more robustly. Both are valid; Reader+Writer is preferred for file-to-file transcoding. |
| SwiftUI `.fileImporter` | UIDocumentPickerViewController wrapped in UIViewControllerRepresentable | `.fileImporter` is native SwiftUI and handles multi-select cleanly; the UIKit wrapper has known bugs where `allowsMultipleSelection` is ignored unless a coordinator is set up carefully. |
| SwiftData `groupContainer` | Core Data with NSPersistentContainer pointing at App Group URL | SwiftData is lower boilerplate and the `groupContainer` API directly supports App Groups without manually constructing a store URL. |

**Installation:** All dependencies are native Apple frameworks — no `swift package add` or `pod install` required.

---

## Architecture Patterns

### Recommended Project Structure
```
SonicMerge/
├── App/
│   └── SonicMergeApp.swift        # @main — modelContainer setup + AVAudioSession activation
├── Features/
│   └── Import/
│       ├── ImportViewModel.swift   # @Observable — fileImporter state, import trigger, clip list
│       └── ImportView.swift        # Minimal host view; shows clip list, triggers picker
├── Models/
│   └── AudioClip.swift             # @Model — SwiftData persistent entity
├── Services/
│   └── AudioNormalizationService.swift  # Actor — AVAssetReader+Writer pipeline
├── Extensions/
│   └── UTType+Audio.swift          # Convenience array [.wav, .aac, .mpeg4Audio]
└── Resources/
    └── Assets.xcassets
```

### Pattern 1: SwiftData ModelContainer with App Group

**What:** Configure the SwiftData `ModelContainer` at app startup with an App Group identifier so the store lives in the shared container accessible by the Phase 5 Share Extension.

**When to use:** Always — must be set before first launch or migration is needed.

**Example:**
```swift
// Source: https://developer.apple.com/documentation/swiftdata/modelconfiguration/init(_:schema:isstoredinmemoryonly:allowssave:groupcontainer:cloudkitdatabase:)
// SonicMergeApp.swift

import SwiftUI
import SwiftData

@main
struct SonicMergeApp: App {
    let modelContainer: ModelContainer = {
        let schema = Schema([AudioClip.self])
        let config = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier("group.com.yourteam.SonicMerge")
        )
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            ImportView()
        }
        .modelContainer(modelContainer)
    }
}
```

### Pattern 2: AudioClip SwiftData Model

**What:** Persistent model holding clip metadata and the file URL (pointing into the App Group container). Audio binary data is never stored in SwiftData — only the path.

**When to use:** Every imported clip.

**Example:**
```swift
// Source: https://developer.apple.com/videos/play/wwdc2023/10187/
import Foundation
import SwiftData

@Model
final class AudioClip {
    var id: UUID
    var displayName: String
    var fileURL: URL          // Points into App Group container; relative path preferred
    var duration: TimeInterval
    var sampleRate: Double    // Always 48000 after normalization
    var channelCount: Int     // Always 2 after normalization
    var importedAt: Date
    var sortOrder: Int

    init(displayName: String, fileURL: URL, duration: TimeInterval) {
        self.id = UUID()
        self.displayName = displayName
        self.fileURL = fileURL
        self.duration = duration
        self.sampleRate = 48000
        self.channelCount = 2
        self.importedAt = .now
        self.sortOrder = 0
    }
}
```

**Critical note:** Store `fileURL` as a path relative to `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`. Absolute URLs in the App Group container are stable on device but can theoretically shift in simulators. Storing a relative path and reconstructing the absolute URL at runtime is safer.

### Pattern 3: SwiftUI .fileImporter with Multi-Select

**What:** Native SwiftUI modifier that presents the system document picker.

**When to use:** Triggered by the "Import" button in ImportView.

**Example:**
```swift
// Source: https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncompletion:)
import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @State private var isPickerPresented = false
    @Environment(ImportViewModel.self) private var viewModel

    var body: some View {
        Button("Import Audio") { isPickerPresented = true }
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: [.wav, .aac, .mpeg4Audio],  // UTType values
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await viewModel.importFiles(urls) }
            case .failure(let error):
                viewModel.handleImportError(error)
            }
        }
    }
}
```

**UTType values for audio:**
- `.wav` — `public.wav-audio` (UTType.wav)
- `.aac` — `public.aac-audio` (UTType.aac)
- `.mpeg4Audio` — `public.mpeg-4-audio` (.m4a files)

### Pattern 4: Audio Normalization Pipeline (AVAssetReader + AVAssetWriter)

**What:** Decompress source audio to Linear PCM via AVAssetReader, re-encode as 48 kHz / stereo / AAC via AVAssetWriter. Handles any input codec AVFoundation can read (.m4a, .wav, .aac).

**When to use:** Every imported file before its URL is saved to SwiftData.

**Why not AVAssetExportSession:** Export session presets do NOT allow specifying exact sample rate or channel count. `AVAssetExportPresetAppleM4A` preserves the source audio settings. Only AVAssetWriter with explicit `outputSettings` dictionary gives precise control. (Source: Apple Developer Forums thread/717415)

**Example:**
```swift
// Source: Apple Developer Forums — AVAssetWriter audio compression settings (thread/717415)
// and AVFoundation Programming Guide — Export

import AVFoundation

actor AudioNormalizationService {

    static let canonicalSampleRate: Double = 48_000
    static let canonicalChannels: Int = 2
    static let canonicalBitRate: Int = 128_000

    func normalize(sourceURL: URL, destinationURL: URL) async throws {
        // --- Reader setup ---
        let asset = AVURLAsset(url: sourceURL)
        let reader = try AVAssetReader(asset: asset)

        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw NormalizationError.noAudioTrack
        }

        // Decompress to Linear PCM
        let readerOutputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: readerOutputSettings)
        reader.add(readerOutput)

        // --- Writer setup ---
        var acl = AudioChannelLayout()
        acl.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
        acl.mChannelBitmap = AudioChannelBitmap(rawValue: 0)
        acl.mNumberChannelDescriptions = 0

        let writerInputSettings: [String: Any] = [
            AVFormatIDKey: UInt(kAudioFormatMPEG4AAC),
            AVNumberOfChannelsKey: UInt(canonicalChannels),
            AVSampleRateKey: canonicalSampleRate,
            AVEncoderBitRateKey: canonicalBitRate,
            AVChannelLayoutKey: NSData(bytes: &acl, length: MemoryLayout<AudioChannelLayout>.size)
        ]
        let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .m4a)
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: writerInputSettings)
        writerInput.expectsMediaDataInRealTime = false
        writer.add(writerInput)

        // --- Transcode ---
        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: .zero)

        await withCheckedContinuation { continuation in
            writerInput.requestMediaDataWhenReady(on: DispatchQueue(label: "audio.normalize")) {
                while writerInput.isReadyForMoreMediaData {
                    if let buffer = readerOutput.copyNextSampleBuffer() {
                        writerInput.append(buffer)
                    } else {
                        writerInput.markAsFinished()
                        Task {
                            await writer.finishWriting()
                            continuation.resume()
                        }
                        break
                    }
                }
            }
        }

        if writer.status == .failed {
            throw writer.error ?? NormalizationError.writeFailed
        }
    }
}

enum NormalizationError: Error {
    case noAudioTrack
    case writeFailed
}
```

**Key caveat on channel upmix:** When the reader emits mono PCM and the writer expects stereo, AVAssetWriter does NOT automatically duplicate the channel. You must either: (a) use an intermediate AVAudioConverter to upmix mono PCM to stereo PCM before appending to the writer, or (b) configure the writer with `AVNumberOfChannelsKey: 1` and a mono channel layout, then upmix at the composition layer. Approach (a) is cleaner for Phase 1 since it produces a proper stereo file at rest.

**AVAudioConverter upmix pattern (mono -> stereo):**
```swift
// Source: Apple Developer Forums thread/72199
// AVAudioConverter handles mono-to-stereo duplication automatically
// when you set channelMap = [0, 0] (both output channels from input channel 0)

let inputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 1, interleaved: false)!
let stereoLayout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Stereo)!
let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channelLayout: stereoLayout)!

let converter = AVAudioConverter(from: inputFormat, to: outputFormat)!
converter.channelMap = [0, 0]  // Route mono channel to both L and R
```

### Pattern 5: Security-Scoped Resource Access

**What:** URLs returned by `.fileImporter` are security-scoped. Access must be explicitly granted and released before the file can be copied to the App Group container.

**When to use:** Immediately in the `.fileImporter` `onCompletion` handler.

**Example:**
```swift
// Source: https://developer.apple.com/documentation/foundation/nsurl/startaccessingsecurityscopedresource()
// and https://www.hackingwithswift.com/forums/ios/uidocumentviewcontroller-stopaccessingsecurityscopedresource/1250

func copyToAppGroup(from securityScopedURL: URL, groupID: String) throws -> URL {
    guard securityScopedURL.startAccessingSecurityScopedResource() else {
        throw ImportError.securityScopeAccessDenied
    }
    defer { securityScopedURL.stopAccessingSecurityScopedResource() }

    let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: groupID
    )!
    let clipsDir = containerURL.appending(path: "clips", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: clipsDir, withIntermediateDirectories: true)

    let destURL = clipsDir.appending(path: "\(UUID().uuidString).m4a")
    // Copy first; normalize overwrites destURL in-place or writes to a sibling path
    try FileManager.default.copyItem(at: securityScopedURL, to: destURL)
    return destURL
}
```

### Pattern 6: AVAudioSession Configuration

**What:** Configure the audio session category before any playback or processing. For a merge/playback app with no recording, `.playback` is the correct category.

**When to use:** App launch (in `SonicMergeApp.init` or `WindowGroup` `onAppear`).

**Recommendation for Claude's Discretion area:** Use `.playback` category (not `.playAndRecord`). The app imports pre-existing files — it never records live audio. `.playAndRecord` adds microphone access overhead and requires a `NSMicrophoneUsageDescription` plist key unnecessarily. Activate the session at launch rather than lazily on first import; this avoids a perceptible audio "pop" when the session activates mid-import.

```swift
// Source: https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback
import AVFAudio

func configureAudioSession() {
    do {
        try AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers]
        )
        try AVAudioSession.sharedInstance().setActive(true)
    } catch {
        // Non-fatal; log and continue — normalization pipeline does not require an active session
        print("AVAudioSession configuration failed: \(error)")
    }
}
```

### Pattern 7: App Group Container URL

**What:** All normalized audio files live in a shared container directory accessible to both the main app target and the Phase 5 Share Extension.

```swift
// Source: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups
// and https://developer.apple.com/documentation/Xcode/configuring-app-groups

static let appGroupID = "group.com.yourteam.SonicMerge"

static func clipsDirectory() throws -> URL {
    guard let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupID
    ) else {
        throw AppGroupError.containerNotFound
    }
    let dir = container.appending(path: "clips", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}
```

**Directory structure recommendation (Claude's Discretion):** Use a flat `clips/` directory. Each normalized file is named `{UUID}.m4a`. Rationale: per-clip subfolders add no organizational benefit since AudioClip metadata (name, date, order) lives in SwiftData. Flat structure simplifies enumeration and deletion.

### Anti-Patterns to Avoid

- **Storing audio data as `Data` in SwiftData:** Never use `@Attribute(.externalStorage)` on a `Data` property to store audio content. Even with `.externalStorage`, the limit for inline storage is ~128KB before SwiftData moves it externally — but it is still managed inside the SwiftData store. File references (URLs) are the correct pattern. (Source: HackingWithSwift SwiftData external storage guide)
- **Using `AVAssetExportPresetAppleM4A` for normalization:** This preset preserves source sample rate and channel count. It cannot resample to 48 kHz or force stereo. (Source: Apple Forums thread/717415)
- **Calling `startAccessingSecurityScopedResource()` without `defer` release:** Exceeding the system limit for concurrent security-scoped resources causes `startAccessingSecurityScopedResource()` to return `false` silently. Always use `defer` to guarantee release.
- **Building a custom UIDocumentPickerViewController wrapper:** The SwiftUI `.fileImporter` modifier handles multi-selection natively in iOS 16+. Known bugs in UIKit wrapper where `allowsMultipleSelection` is ignored. (Source: Apple Forums thread/653192)
- **Setting absolute App Group file paths in SwiftData:** App Group container paths can differ between device and simulator. Reconstruct full URL at runtime by combining `containerURL(forSecurityApplicationGroupIdentifier:)` with a stored relative path component.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Multi-file document picker | Custom UIKit file browser | SwiftUI `.fileImporter(allowsMultipleSelection: true)` | Native system UI, security-scoped URL handling built in, no permission issues |
| Sample rate conversion | Custom resampling loop | AVAssetReader + AVAssetWriter pipeline | Handles compressed input codecs; Apple provides hardware-accelerated conversion |
| Mono-to-stereo upmix | Manual PCM buffer duplication | AVAudioConverter with `channelMap = [0, 0]` | Handles all edge cases; correct channel tagging for downstream composition |
| Persistent data model | Custom JSON/Plist serialization | SwiftData `@Model` | Schema migration, concurrency isolation, predicate-based queries — all free |
| App Group store URL construction | Custom path string building | `ModelConfiguration(groupContainer: .identifier(...))` | SwiftData constructs and migrates the store path automatically |
| Security-scoped file access | Custom bookmarks | `startAccessingSecurityScopedResource()` + `defer` | System-enforced pattern; anything else will be rejected by sandbox |

**Key insight:** The AVFoundation normalization pipeline is deceptively complex — channel count negotiation, compressed input passthrough, and CMSampleBuffer format compliance all have non-obvious failure modes. Do not attempt to build this without the Reader+Writer pattern.

---

## Common Pitfalls

### Pitfall 1: AVMutableComposition Silently Corrupts Mixed-Rate Tracks
**What goes wrong:** Inserting tracks with different sample rates (e.g., 44,100 Hz + 48,000 Hz) into the same AVMutableComposition produces a composition that exports without error but the output has wrong duration, silence periods, or pitch shift.
**Why it happens:** AVMutableComposition operates in a time-domain, not sample-domain. It does not resample at composition time. If sample rates differ, the timeline math is wrong.
**How to avoid:** Normalize every file to 48,000 Hz before inserting. Never insert a raw imported URL into the composition.
**Warning signs:** Exported file duration differs from sum of clip durations; silence between clips; pitch drift audible on a single-clip export.

### Pitfall 2: AVAssetWriter Requires Linear PCM from Reader
**What goes wrong:** Attempting to pass compressed (AAC/MP3) CMSampleBuffers directly from an AVAssetReaderTrackOutput into an AVAssetWriterInput configured for AAC output causes `AVAssetWriterInput.append()` to fail with `AVErrorInvalidSourceMedia`.
**Why it happens:** AVAssetWriterInput with an `outputSettings` dictionary expects uncompressed Linear PCM input — it encodes it internally. If you want passthrough, use `outputSettings: nil` in the reader AND `outputSettings: nil` in the writer.
**How to avoid:** Set `AVFormatIDKey: kAudioFormatLinearPCM` in the reader's `outputSettings`. Let the writer encode from PCM.
**Warning signs:** `writer.status == .failed` immediately after first `append()` call; error code `AVErrorInvalidSourceMedia`.

### Pitfall 3: Security-Scoped Resource Limit Exhausted
**What goes wrong:** Importing many files in rapid succession; `startAccessingSecurityScopedResource()` returns `false` for some files mid-import.
**Why it happens:** iOS limits the number of concurrently open security-scoped resources per app. The limit is not documented but is approximately 200.
**How to avoid:** Always call `stopAccessingSecurityScopedResource()` immediately after the file is copied to the App Group container. Use `defer` to guarantee this.
**Warning signs:** Some files in a large batch silently fail to copy; no error is thrown, but the destination file is missing.

### Pitfall 4: SwiftData Model Modified Outside ModelContext
**What goes wrong:** `AudioClip` objects updated on a background thread (e.g., inside the normalization actor) cause a crash or silent data loss with SwiftData.
**Why it happens:** SwiftData `@Model` objects are thread-bound to their `ModelContext`. Modifying them across threads is undefined behavior.
**How to avoid:** Perform all normalization work before creating the `AudioClip` model. Create the `AudioClip` on the main actor (or the actor owning the `ModelContext`) after normalization completes, passing the resulting `URL` and `duration` as plain value types.
**Warning signs:** EXC_BAD_ACCESS in `PersistentModel` internals; SwiftData `ModelContext` crash logs.

### Pitfall 5: App Group Entitlement Not Added to Both Targets
**What goes wrong:** `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)` returns `nil` at runtime.
**Why it happens:** The entitlement is added to the main app target but not the Share Extension (Phase 5), or vice versa. Both targets must have the same App Group identifier in their `.entitlements` files.
**How to avoid:** In Xcode Signing & Capabilities tab, add the App Groups capability to the main app target and verify the resulting `.entitlements` file contains `com.apple.security.application-groups`. Verify the App Group ID starts with `group.`.
**Warning signs:** `containerURL(forSecurityApplicationGroupIdentifier:)` returns `nil`; `ModelContainer` initialization crashes in release builds.

### Pitfall 6: Swift 6 Strict Concurrency — AVFoundation Non-Sendable Types
**What goes wrong:** `AVAssetTrack`, `AVURLAsset`, and related types are not `Sendable`. Passing them across actor boundaries in Swift 6 produces compile-time errors.
**Why it happens:** Swift 6 enforces actor isolation strictly. AVFoundation was designed before Swift concurrency.
**How to avoid:** Load all AVFoundation resources within a single actor or task context. Do not store `AVAssetTrack` or `AVURLAsset` as actor properties — create them locally within a method and complete all work before returning. Use `@preconcurrency` on imports if needed as a temporary suppression.
**Warning signs:** "Sending 'X' risks causing data races" compile errors when passing AVFoundation objects between async functions on different actors.

### Pitfall 7: Mono Source Does Not Auto-Upmix in AVAssetWriter
**What goes wrong:** A mono source file (1 channel) is processed through the Reader+Writer pipeline with `AVNumberOfChannelsKey: 2` in writer output settings. The export completes without error but the right channel is silence.
**Why it happens:** AVAssetWriter does not duplicate the mono channel when upconverting. It places the single channel into the left channel and writes silence to the right.
**How to avoid:** Detect the source channel count via `AVAssetTrack.formatDescriptions` before normalization. If mono, use an intermediate `AVAudioConverter` with `channelMap = [0, 0]` to produce a proper stereo PCM buffer before writing.
**Warning signs:** Normalized file plays audio only in the left ear on headphones; right channel RMS is zero.

---

## Code Examples

### Accessing the App Group Container
```swift
// Source: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups
let groupID = "group.com.yourteam.SonicMerge"
guard let container = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: groupID
) else {
    fatalError("App Group container not configured. Check entitlements for target.")
}
// container is e.g. file:///private/var/mobile/Containers/Shared/AppGroup/<UUID>/
```

### SwiftData ModelConfiguration with App Group
```swift
// Source: https://developer.apple.com/documentation/swiftdata/modelconfiguration/groupcontainer-swift.struct
// and https://developer.apple.com/documentation/swiftdata/modelconfiguration/init(_:schema:isstoredinmemoryonly:allowssave:groupcontainer:cloudkitdatabase:)
let config = ModelConfiguration(
    schema: Schema([AudioClip.self]),
    groupContainer: .identifier("group.com.yourteam.SonicMerge")
)
let container = try ModelContainer(for: Schema([AudioClip.self]), configurations: [config])
```

### AVAssetWriter Output Settings for 48 kHz Stereo AAC
```swift
// Source: Apple Developer Forums — thread/717415 (AVAssetWriter audio compression settings)
var acl = AudioChannelLayout()
acl.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo

let outputSettings: [String: Any] = [
    AVFormatIDKey:        UInt(kAudioFormatMPEG4AAC),
    AVNumberOfChannelsKey: UInt(2),
    AVSampleRateKey:      48_000.0,
    AVEncoderBitRateKey:  128_000,
    AVChannelLayoutKey:   NSData(bytes: &acl, length: MemoryLayout<AudioChannelLayout>.size)
]
let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
writerInput.expectsMediaDataInRealTime = false
```

### AVAssetReader Linear PCM Output Settings
```swift
// Source: https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/05_Export.html
let readerSettings: [String: Any] = [
    AVFormatIDKey:             kAudioFormatLinearPCM,
    AVLinearPCMBitDepthKey:    16,
    AVLinearPCMIsBigEndianKey: false,
    AVLinearPCMIsFloatKey:     false,
    AVLinearPCMIsNonInterleaved: false
]
let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: readerSettings)
```

### Detect Source Channel Count Before Normalization
```swift
// Source: AVFoundation framework — AVAssetTrack.formatDescriptions
let formatDescriptions = try await audioTrack.load(.formatDescriptions)
let desc = formatDescriptions.first.map { $0 as! CMAudioFormatDescription }
let streamDesc = CMAudioFormatDescriptionGetStreamBasicDescription(desc!)?.pointee
let sourceChannelCount = streamDesc?.mChannelsPerFrame ?? 1
```

### SwiftUI .fileImporter with Audio UTTypes
```swift
// Source: https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncompletion:)
import UniformTypeIdentifiers

.fileImporter(
    isPresented: $showPicker,
    allowedContentTypes: [.wav, .aac, .mpeg4Audio],
    allowsMultipleSelection: true
) { result in
    // result: Result<[URL], Error>
    // Each URL is security-scoped — call startAccessingSecurityScopedResource() before reading
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UIDocumentPickerViewController in UIViewControllerRepresentable | SwiftUI `.fileImporter` modifier | iOS 14 (stable in iOS 16+) | No UIKit bridge needed; multi-select works reliably |
| Core Data with NSPersistentContainer | SwiftData `@Model` + `ModelContainer` | iOS 17 (WWDC 2023) | ~70% less boilerplate; native SwiftUI integration |
| Core Data App Group via NSPersistentContainer store URL | SwiftData `ModelConfiguration(groupContainer:)` | iOS 17 (WWDC 2023) | Direct API support; auto-migration from non-group store |
| Manual AVAudioSession category strings | `AVAudioSession.Category.playback` typed enum | iOS 10+ | Type-safe; no string typos |
| `AVURLAsset.tracks(withMediaType:)` synchronous | `asset.loadTracks(withMediaType:)` async/await | iOS 16 (Swift concurrency) | Eliminates `loadValuesAsynchronously` boilerplate |
| XCTest `XCTestCase` for unit tests | Swift Testing `@Test` / `#expect` | Xcode 16 / iOS 17 target | Cleaner syntax; parameterized tests; parallel by default |

**Deprecated/outdated:**
- `AVURLAsset.tracks(withMediaType:)` synchronous version: Deprecated in iOS 16. Use `async loadTracks(withMediaType:)`.
- `AVAudioSession.setCategory(_:)` without mode/options: Works but the richer overload with `mode:` and `options:` is preferred.
- `UIDocumentPickerViewController` with `init(documentTypes: [String])` taking UTI strings: Deprecated iOS 14. Use `init(forOpeningContentTypes:)` with `UTType` values.

---

## Open Questions

1. **Exact App Group identifier string**
   - What we know: Must start with `group.` and match the bundle ID structure (e.g., `group.com.yourteam.SonicMerge`)
   - What's unclear: The actual Team ID and bundle ID for this project have not been set up in the Apple Developer Portal yet
   - Recommendation: Use `group.com.yourteam.SonicMerge` as a placeholder in code; replace before first provisioning profile. The planner should include a task to register the App Group in the Apple Developer Portal.

2. **Mono detection and upmix strategy in the normalization pipeline**
   - What we know: AVAssetWriter does not auto-duplicate mono channels to stereo; explicit handling is required
   - What's unclear: The cleanest integration point — upmix as a separate AVAudioConverter pass after PCM decode, or configure AVAssetWriter with mono settings and let AVMutableComposition handle it later
   - Recommendation: Upmix in the normalization pipeline (during Phase 1) so every stored file is guaranteed stereo. This prevents Phase 2's composition layer from ever encountering mono tracks.

3. **AVAudioSession activation timing**
   - What we know: `.playback` category is correct; must activate before first audio output
   - What's unclear: Whether to activate at app launch (slight battery impact) or lazily before first normalization export
   - Recommendation: Activate at launch in `SonicMergeApp`. Normalization exports via AVAssetWriter do NOT require an active audio session — AVAssetWriter writes to disk regardless. The session is only needed for actual playback (Phase 2 preview). However, activating at launch avoids any mid-import audio routing interruption.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (bundled with Xcode 16, Swift 6 target) |
| Config file | None required — Xcode detects `@Test` annotations automatically |
| Quick run command | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing SonicMergeTests` |
| Full suite command | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| IMP-01 | Document picker presented with multi-select and audio UTTypes | UI / smoke | Full suite — UI test validates picker appears | Wave 0 |
| IMP-01 | `.fileImporter` completion handler receives array of URLs | Unit | `xcodebuild test ... -only-testing SonicMergeTests/ImportViewModelTests` | Wave 0 |
| IMP-03 | Normalization outputs 48,000 Hz sample rate | Unit | `xcodebuild test ... -only-testing SonicMergeTests/AudioNormalizationServiceTests/testOutputSampleRate` | Wave 0 |
| IMP-03 | Normalization outputs 2-channel stereo | Unit | `xcodebuild test ... -only-testing SonicMergeTests/AudioNormalizationServiceTests/testOutputChannelCount` | Wave 0 |
| IMP-03 | Mono source file produces stereo output (not silence in one channel) | Unit | `xcodebuild test ... -only-testing SonicMergeTests/AudioNormalizationServiceTests/testMonoUpmix` | Wave 0 |
| IMP-03 | Normalized file duration matches source file duration (within 0.1s) | Unit | `xcodebuild test ... -only-testing SonicMergeTests/AudioNormalizationServiceTests/testDurationPreserved` | Wave 0 |
| IMP-03 | Clips persist across simulated app relaunch (SwiftData reopen) | Integration | `xcodebuild test ... -only-testing SonicMergeTests/PersistenceTests/testClipSurvivesRelaunch` | Wave 0 |
| Phase SC | App Group container URL resolves without nil | Unit | `xcodebuild test ... -only-testing SonicMergeTests/AppGroupTests/testContainerURLNotNil` | Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing SonicMergeTests/AudioNormalizationServiceTests`
- **Per wave merge:** `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing SonicMergeTests`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `SonicMergeTests/` target — does not exist; must be added in Xcode (New Target > Unit Testing Bundle, Swift Testing)
- [ ] `SonicMergeTests/AudioNormalizationServiceTests.swift` — covers IMP-03 (sample rate, channel count, mono upmix, duration)
- [ ] `SonicMergeTests/ImportViewModelTests.swift` — covers IMP-01 (URL handling, security-scoped access)
- [ ] `SonicMergeTests/PersistenceTests.swift` — covers SwiftData round-trip with in-memory store
- [ ] `SonicMergeTests/AppGroupTests.swift` — covers App Group container URL resolution (may require simulator entitlements)
- [ ] Test audio fixtures: `SonicMergeTests/Fixtures/` — `mono_44100.wav`, `stereo_48000.m4a`, `aac_22050.aac` (short 1–2 second files for fast CI)

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation — SwiftData ModelConfiguration.GroupContainer — App Group container setup
- Apple Developer Documentation — `fileImporter(isPresented:allowedContentTypes:allowsMultipleSelection:onCompletion:)` — multi-file picker
- Apple Developer Documentation — `AVAudioSession.Category.playback` — audio session category
- Apple Developer Documentation — `startAccessingSecurityScopedResource()` — security-scoped URL access
- Apple Developer Documentation — Swift Testing (WWDC 2024) — test framework
- Apple Developer Forums thread/717415 — AVAssetWriter audio compression settings (AVFormatIDKey, AVSampleRateKey, AVNumberOfChannelsKey, AVChannelLayoutKey)
- Apple Developer Forums thread/72199 — AVAudioConverter mono to stereo conversion patterns

### Secondary (MEDIUM confidence)
- https://developer.apple.com/documentation/technotes/tn3136-avaudioconverter-performing-sample-rate-conversions — Apple Technical Note on AVAudioConverter (JavaScript-gated page; contents confirmed via search results cross-referencing)
- https://www.merrell.dev/ios-share-extension-with-swiftui-and-swiftdata — SwiftData + Share Extension App Group pattern (confirmed against Apple docs for `groupContainer:` parameter)
- HackingWithSwift SwiftData by Example — `@Attribute(.externalStorage)` behavior; URL storage pattern
- Apple Developer Forums thread/653192 — allowsMultipleSelection bug in UIKit wrapper (confirms use native `.fileImporter`)

### Tertiary (LOW confidence)
- Various WebSearch results on AVMutableComposition mixed sample rate corruption — confirmed directionally by the research decision captured in STATE.md; not independently verified via a single authoritative source in this session

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all frameworks are native Apple, iOS 17+ bundled, no third-party dependencies
- Architecture (MVVM, service layer, SwiftData patterns): HIGH — confirmed against Apple WWDC sessions and official docs
- Normalization pipeline (AVAssetReader + AVAssetWriter specifics): MEDIUM-HIGH — core pattern confirmed via Apple docs and developer forums; exact Swift 6 async integration has some uncertainty (AVFoundation non-Sendable types)
- Pitfalls: HIGH — AVMutableComposition corruption, security-scoped resource limits, and SwiftData threading pitfalls are well-documented in Apple forums
- Validation architecture: MEDIUM — test target does not exist yet; commands are correct for Xcode 16 + Swift Testing but need fixture files created in Wave 0

**Research date:** 2026-03-08
**Valid until:** 2026-06-08 (90 days — AVFoundation and SwiftData APIs are stable; no breaking changes expected before iOS 19 beta cycle)
