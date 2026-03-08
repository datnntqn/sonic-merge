# Phase 1: Foundation + Import Pipeline - Context

**Gathered:** 2026-03-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the stable foundation the entire app depends on: data models, audio session configuration, SwiftData persistence, and a multi-file import pipeline that normalizes audio formats at import time. Phase 2 (Mixing Station UI) and all subsequent phases build directly on what this phase delivers.

Scope: import pipeline and foundation only. No waveform thumbnails (Phase 2), no UI beyond what's needed to trigger import, no Share Extension (Phase 5).

</domain>

<decisions>
## Implementation Decisions

### Persistence
- Use **SwiftData** (iOS 17+) for clip persistence
- AudioClip model stored via SwiftData so clips survive app relaunch without re-importing
- App Group container holds the actual audio files; SwiftData model holds metadata + file URL references

### Canonical Audio Format
- Normalize all imported audio to **48,000 Hz** sample rate (broadcast/podcast standard)
- Force **stereo (2-channel)** layout — convert mono imports to stereo; prevents AVMutableComposition mixed-layout corruption
- Store normalized clips as **AAC (.m4a)** in the App Group container — compressed, small, AVFoundation-native

### App Group Container
- App Group shared container must be configured in Phase 1 and accessible from both the main app and the future Share Extension target (Phase 5)
- Normalized audio files live in the shared container so Phase 5 can hand files directly to Phase 1's import pipeline

### Claude's Discretion
- Import error handling UX (per-file alert vs summary vs silent skip)
- Audio session category configuration (`.playback` vs `.playAndRecord`, interruption behavior)
- Exact container directory structure (flat vs per-clip subfolder)
- Normalization implementation (AVAssetExportSession with custom output settings vs AVAudioConverter)
- AVAudioSession activation timing (on launch vs on first import)

</decisions>

<specifics>
## Specific Ideas

- The canonical format (48 kHz / stereo / AAC) is chosen to match podcast export expectations — no resampling needed at export time
- SwiftData chosen over Core Data for lower boilerplate and native iOS 17+ fit with the Swift 6 + SwiftUI stack

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- None yet — fresh Xcode template only (`SonicMergeApp.swift`, `ContentView.swift`)

### Established Patterns
- None established — Phase 1 sets the patterns all subsequent phases follow
- MVVM is the decided architecture; Phase 1 should establish the ViewModel pattern for Phase 2 to follow

### Integration Points
- `SonicMergeApp.swift` — entry point; audio session configuration and SwiftData `modelContainer` setup go here
- `ContentView.swift` — will become or route to the Mixing Station view (Phase 2); Phase 1 needs a minimal host view to trigger the document picker

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-foundation-import-pipeline*
*Context gathered: 2026-03-08*
