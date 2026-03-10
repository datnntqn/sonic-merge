# Phase 2: Merge Pipeline + Mixing Station UI - Context

**Gathered:** 2026-03-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the minimal Phase 1 ImportView with the full Mixing Station — the primary app UI. Deliver clip cards with waveform thumbnails, drag-to-reorder, swipe-to-delete, gap/crossfade controls between clips, and a complete export flow with format selection and progress. This is the complete core workflow end-to-end.

Scope: Mixing Station UI and merge/export pipeline only. No noise reduction (Phase 3), no LUFS normalization (Phase 4), no Share Extension (Phase 5).

</domain>

<decisions>
## Implementation Decisions

### Waveform Thumbnail
- Generate waveform data **at import time** (during normalization pipeline), not lazily or on demand
- Store as a **sidecar file in the App Group container** alongside the audio file (e.g. `UUID.waveform`) — avoids SwiftData binary blob concerns, easy to regenerate
- Visual style: **filled bar chart, accent blue (#007AFF)** — vertical bars, standard audio app look, matches project theme
- Position: **left side of the clip card, fixed width ~60pt** — waveform thumbnail on left, text (display name + duration) on the right

### Gap & Crossfade Controls
- Gap control appears as an **inline separator row between each pair of clip cards** — always visible, no tap needed to reveal
- Gap duration chosen via a **segmented control inline in the gap row**: `0.5s | 1.0s | 2.0s | Crossfade` — no extra tap required
- Crossfade is a **toggle option in the gap row, mutually exclusive with silence gaps** — selecting "Crossfade" sets a crossfade instead of silence
- Crossfade duration: **fixed at 0.5s** — no variable duration in v1, clean and simple

### Export Format & Flow
- Tap Export → **bottom sheet opens with format picker** (.m4a / .wav) + Export button — deliberate choice before committing
- Export progress: **non-dismissible modal sheet** with a progress bar (0–100%) and a Cancel button
- After successful export: progress modal dismisses → **iOS system share sheet opens immediately** with the exported file
- Cancel during export: **stops immediately, partial file deleted**, user returns to Mixing Station — no confirmation alert

### ViewModel Architecture
- Create a **new MixingStationViewModel** (`@Observable`, `@MainActor`); ImportViewModel is retired — its import logic migrates into MixingStationViewModel
- **MixingStationView becomes the root view** of the app — `SonicMergeApp.swift` routes directly to it; `ContentView.swift` can be deleted; `ImportView.swift` retired
- Gap/crossfade state stored in **SwiftData** on a `GapTransition` model linked to `AudioClip` — persists across app relaunches
- Merge pipeline implemented as a **new `AudioMergerService` actor** called from MixingStationViewModel — isolates AVMutableComposition + AVAssetExportSession work on a background actor; reports progress via AsyncStream. Mirrors Phase 1's `AudioNormalizationService` pattern.

### Claude's Discretion
- Exact waveform downsampling algorithm (peak, RMS, etc.) and number of bars at thumbnail scale
- `GapTransition` SwiftData model fields and relationship to `AudioClip` (1-to-1, or ordered by sortOrder)
- `AVAssetExportSession` progress polling interval
- Empty state design for the Mixing Station when no clips are imported
- Drag handle visual (grip icon vs long-press anywhere on card)
- Error handling UX for failed exports

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AudioClip` (`Models/AudioClip.swift`): `id`, `displayName`, `fileURLRelativePath`, `duration`, `sampleRate`, `channelCount`, `importedAt`, `sortOrder` — `sortOrder` field is ready for drag-to-reorder persistence
- `AudioNormalizationService` (`Services/`): actor-based background audio service — AudioMergerService should follow the same pattern
- `AppConstants.clipsDirectory()`: resolves App Group container path at runtime — waveform sidecar files go in the same directory
- `UTType+Audio.swift`: audio type extension — reusable for export type declarations

### Established Patterns
- `@Observable @MainActor` ViewModel with `ModelContext` injected in init — MixingStationViewModel follows this exactly
- Actor-based background services for audio work, actor hop from `@MainActor` ViewModel — AudioMergerService follows AudioNormalizationService
- Store only `filename` in SwiftData, reconstruct full URL via `AppConstants.clipsDirectory()` at runtime — waveform sidecar follows same pattern

### Integration Points
- `SonicMergeApp.swift`: currently routes to `ImportView` — Phase 2 replaces with `MixingStationView`
- `AudioNormalizationService.normalize()`: waveform generation should be added here or called immediately after normalization completes, before `AudioClip` is persisted
- SwiftData `modelContainer` in `SonicMergeApp.swift`: `GapTransition` model must be added to the container's schema

</code_context>

<specifics>
## Specific Ideas

- Gap row with segmented control `0.5s | 1.0s | 2.0s | Crossfade` — selecting any option takes effect immediately (no separate confirm step)
- Crossfade and silence gap are mutually exclusive per transition — selecting one clears the other
- The export bottom sheet should show format choice clearly before any processing begins — no silent defaults

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-merge-pipeline-mixing-station-ui*
*Context gathered: 2026-03-10*
