# Phase 4: LUFS Normalization + Export Polish - Context

**Gathered:** 2026-03-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Add -16 LUFS loudness normalization as an opt-in toggle in the export flow, and ensure the export completion experience (share sheet auto-presentation and post-share state reset) is polished and consistent across both MixingStationView and CleaningLabView.

Scope: LUFS normalization in export pipeline, ExportFormatSheet toggle, ExportProgressSheet label update, post-export state reset. No new screens. No per-clip normalization. No playback features.

</domain>

<decisions>
## Implementation Decisions

### LUFS UI Entry Point
- LUFS normalization toggle lives **inside the existing `ExportFormatSheet`** — an additional toggle row above the Export button (no new screen or sheet)
- Toggle label: "Normalize to -16 LUFS"
- Toggle is **off by default** (opt-in) — no surprise loudness changes to existing workflows
- Toggle state **persists via `UserDefaults`** — podcasters who turn it on don't have to toggle it every session
- The same toggle appears in **both MixingStationView and CleaningLabView** export flows — `ExportFormatSheet` already shared; normalization option is available at every export point

### LUFS Target
- **Fixed at -16 LUFS only** — no preset picker, no custom target slider
- Matches EXP-03 requirement and the podcast standard; other targets (−14, −23) are deferred
- Normalization runs as a **single inline pass**: measure integrated loudness (BS.1770), compute gain offset, apply gain during export write — no intermediate temp file

### Normalization Feedback
- **Silent normalization** — no loudness measurement displayed to the user before or after export
- When the LUFS toggle is on, the `ExportProgressSheet` title changes from **"Exporting..."** to **"Exporting & Normalizing..."** — user knows normalization is active without seeing raw LUFS numbers
- No before/after LUFS values shown anywhere in the UI

### Export Completion Polish
- After the iOS share sheet dismisses: **state resets to ready** — `exportedFileURL` clears, `exportProgress` resets to 0, sheet dismisses cleanly
- **Auto-present share sheet immediately** after export completes (keep current behavior) — progress modal dismisses → share sheet opens, no intermediate confirmation step
- No success toast, no "Share again" button, no persistent last-export reference in toolbar

### Claude's Discretion
- LUFS measurement implementation: use `spfk-loudness` Swift package if it supports iOS 17+; fall back to manual BS.1770-3 integrated loudness via vDSP if not (STATE.md blocker: minimum iOS version unverified)
- `LUFSNormalizationService` actor structure and injection pattern (should mirror `AudioNormalizationService` / `AudioMergerService` precedent)
- Gain application strategy: apply as a single scalar gain on the PCM buffer stream or via `AVAudioMixInputParameters` volume ramp
- Exact UserDefaults key naming and storage location

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — EXP-03 (LUFS normalization requirement), EXP-01/EXP-02 (export format requirements that LUFS must not break)

### Existing Export Infrastructure (read before modifying)
- `SonicMerge/Features/MixingStation/ExportFormatSheet.swift` — Current sheet to extend with LUFS toggle
- `SonicMerge/Features/MixingStation/ExportProgressSheet.swift` — Progress label to make dynamic
- `SonicMerge/Features/MixingStation/ActivityViewController.swift` — Share sheet wrapper; comment explains iOS 17 App Group URL bug with ShareLink
- `SonicMerge/Features/MixingStation/MixingStationViewModel.swift` — `exportMerged(format:)`, `exportedFileURL`, `exportProgress`, `cancelExport()`
- `SonicMerge/Features/Denoising/CleaningLabView.swift` — Second export path; LUFS toggle must be wired here too
- `SonicMerge/Services/AudioMergerService.swift` — `export(clips:transitions:format:destinationURL:)` and `exportFile(inputURL:format:destinationURL:)` — normalization integrates here or wraps these

### Codebase Patterns
- `SonicMerge/Services/AudioNormalizationService.swift` — Actor-based background service pattern to mirror for `LUFSNormalizationService`
- `SonicMerge/App/AppConstants.swift` — App Group container path resolution; temp file placement pattern

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ExportFormatSheet`: accepts `onExport: (ExportFormat) -> Void` — needs signature extension to pass LUFS flag, e.g. `onExport: (ExportFormat, Bool) -> Void` or a new `ExportOptions` struct
- `ExportProgressSheet`: `title` is hardcoded "Exporting..." — needs a `title: String` parameter (or `isNormalizing: Bool`) to support dynamic label
- `ActivityViewController`: already handles App Group URL sharing correctly — no changes needed
- `AudioMergerService.exportFile(inputURL:format:destinationURL:)`: single-file export path used by CleaningLabView — LUFS normalization can be applied as a post-processing gain here or in a wrapping service

### Established Patterns
- Actor-based background services (`AudioNormalizationService`, `AudioMergerService`) with `@MainActor` ViewModel actor-hopping — `LUFSNormalizationService` follows this
- Progress reporting via `AsyncStream<Float>` — normalization pass should report progress the same way
- `UserDefaults` for lightweight persistent settings — already used in project (pattern established)

### Integration Points
- `ExportFormatSheet`: add `@AppStorage("lufsNormalizationEnabled") var lufsEnabled = false` + `Toggle("Normalize to -16 LUFS", isOn: $lufsEnabled)` row
- `MixingStationViewModel.exportMerged(format:)`: receives LUFS flag, passes to `AudioMergerService` or wraps export with `LUFSNormalizationService`
- `CleaningLabView` export path: same flag injection via `ExportFormatSheet` callback
- `ExportProgressSheet`: add `isNormalizing: Bool` parameter → changes displayed title

</code_context>

<specifics>
## Specific Ideas

- `ExportFormatSheet` toggle should feel native iOS — a standard `Toggle` row with a subtitle or descriptive label below it ("Podcast standard (-16 LUFS)")
- Progress label change ("Exporting & Normalizing...") is the only user-visible signal that normalization is active — it should be accurate but not alarming

</specifics>

<deferred>
## Deferred Ideas

- LUFS preset picker (-14 LUFS for Apple Podcasts, -23 LUFS for broadcast EBU R128) — users may want this in v2
- Measured LUFS display ("Your audio is -24.2 LUFS") — informational but not needed for v1
- "Share again" / last export persistence in toolbar — out of scope for v1

</deferred>

---

*Phase: 04-lufs-normalization-export-polish*
*Context gathered: 2026-03-19*
