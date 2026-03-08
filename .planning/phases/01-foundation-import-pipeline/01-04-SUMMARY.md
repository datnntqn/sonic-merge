---
phase: 01-foundation-import-pipeline
plan: "04"
subsystem: ui
tags: [swiftui, swiftdata, avfoundation, observable, fileimporter, import-pipeline]

# Dependency graph
requires:
  - phase: 01-foundation-import-pipeline
    plan: "02"
    provides: "AudioClip SwiftData model, AppConstants, UTType+Audio extension"
  - phase: 01-foundation-import-pipeline
    plan: "03"
    provides: "AudioNormalizationService (48kHz/stereo/AAC transcoding)"
provides:
  - "ImportViewModel: @Observable orchestrator for security-scoped access, normalization, and SwiftData persistence"
  - "ImportView: SwiftUI view with .fileImporter, clip list, spinner overlay, error alert"
  - "SonicMergeApp wired to ImportView as root with ImportViewModel environment injection"
  - "Full import pipeline end-to-end: tap +, pick files, see normalized clips, survive relaunch"
affects:
  - Phase 2 (Mixing Station) — replaces ImportView root with MixingStationView
  - Phase 5 (Share Extension) — App Group container path established by ImportViewModel

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@Observable @MainActor ViewModel with SwiftData ModelContext injected at init"
    - "Security-scoped resource access via startAccessingSecurityScopedResource/defer pattern"
    - "Actor hop to AudioNormalizationService from @MainActor context (safe: transcoding runs on background DispatchQueue)"
    - "FetchDescriptor<AudioClip> sorted by sortOrder for ordered clip list"
    - "Environment-injected ViewModel: .environment(ImportViewModel.self) from SonicMergeApp"
    - "App Group container guard: check containerURL before ModelConfiguration(groupContainer:)"

key-files:
  created:
    - "SonicMerge/Features/Import/ImportViewModel.swift"
    - "SonicMerge/Features/Import/ImportView.swift"
  modified:
    - "SonicMerge/SonicMergeApp.swift"
    - "SonicMerge/ContentView.swift"

key-decisions:
  - "ImportViewModel is @MainActor because ModelContext is main-actor-bound (SwiftData requirement); actor hop to AudioNormalizationService is safe per RESEARCH.md Pitfall 4"
  - "ContentView.swift retained as an EmptyView stub for Xcode target membership — not deleted to avoid project.pbxproj modifications"
  - "SonicMergeApp guards containerURL before ModelConfiguration(groupContainer:) to prevent assertion crash in test host without App Group entitlement"

patterns-established:
  - "ViewModel pattern: @Observable @MainActor class receiving ModelContext at init, fetchClips() called after each insert"
  - "Error isolation: processFile catches per-file errors into importErrors[], never halts batch processing"
  - "ImportView uses [UTType].audioImportTypes convenience extension for .fileImporter allowedContentTypes"

requirements-completed:
  - IMP-01
  - IMP-03

# Metrics
duration: ~15min
completed: 2026-03-08
---

# Phase 1 Plan 04: Import Pipeline UI and Wiring Summary

**End-to-end import pipeline wired: ImportViewModel orchestrates security-scoped access + AVAssetWriter normalization + SwiftData persistence; ImportView delivers .fileImporter with clip list, spinner, and error alert as the app root**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-08T15:04:31Z
- **Completed:** 2026-03-08T15:20:00Z
- **Tasks:** 2 of 3 complete (Task 3 is human verification checkpoint — awaiting)
- **Files modified:** 4

## Accomplishments

- ImportViewModel implemented as `@Observable @MainActor` class with full pipeline: security-scoped access, per-file normalization via actor hop, AVURLAsset duration extraction, SwiftData insert+save, fetchClips refresh
- ImportView implemented with NavigationStack, ContentUnavailableView empty state, List clip display (name, duration, 48kHz/Stereo), toolbar Import button, ProgressView overlay, error alert, and .fileImporter with multi-select
- SonicMergeApp updated to inject ImportViewModel as environment object and root to ImportView
- ContentView.swift kept as EmptyView stub for Xcode target membership
- Full test suite passes: 7 non-disabled tests GREEN (ImportViewModelTests x2, AudioNormalizationServiceTests x4, PersistenceTests x1)

## Task Commits

Each task was committed atomically:

1. **Task 1: ImportViewModel — orchestrate security-scoped access, normalization, and persistence** - `8866419` (feat)
2. **Task 2: ImportView and wire SonicMergeApp to use ImportView** - `ecabfed` (feat)
3. **Task 3: Human verify — full import pipeline end-to-end** — PENDING (checkpoint:human-verify)

## Files Created/Modified

- `SonicMerge/Features/Import/ImportViewModel.swift` — @Observable @MainActor ViewModel driving the import pipeline; exposes clips, isImporting, importErrors
- `SonicMerge/Features/Import/ImportView.swift` — SwiftUI root view with fileImporter, clip list, spinner overlay, error alert
- `SonicMerge/SonicMergeApp.swift` — Updated to inject ImportViewModel environment and root to ImportView; includes App Group guard for ModelContainer
- `SonicMerge/ContentView.swift` — Reduced to EmptyView stub with comment noting Phase 2 replacement

## Decisions Made

- `@MainActor` on ImportViewModel is required because SwiftData's ModelContext is main-actor-bound. The actor hop to `AudioNormalizationService.normalize()` is safe: AVAssetWriter's requestMediaDataWhenReady runs on a background DispatchQueue, so it does not block the main thread during the hop.
- ContentView.swift retained as a stub rather than deleted — removing it from both filesystem and .xcodeproj target would require project.pbxproj modifications that are fragile.
- App Group guard (`containerURL != nil` before `ModelConfiguration(groupContainer:)`) established in Plan 03 carried forward — prevents assertion crash in test host without entitlement.

## Deviations from Plan

None - plan executed exactly as written. Both implementation tasks completed in prior commits; tests verified passing.

## Issues Encountered

- xcodebuild destination `platform=iOS Simulator,name=iPhone 16` was ambiguous due to visionOS placeholder error; resolved by using device UUID `id=84EC9074-BE48-40E2-8958-DA000DDB35F8` (iPhone 16e, iOS 26.2)

## User Setup Required

**App Group entitlement must be added manually before device/simulator end-to-end verification:**

1. Open `SonicMerge.xcodeproj` in Xcode
2. Select the SonicMerge target > Signing & Capabilities tab
3. Click "+ Capability" and add "App Groups"
4. Add group identifier: `group.com.yourteam.SonicMerge` (match `AppConstants.appGroupID`)
5. Verify `.entitlements` file contains `com.apple.security.application-groups` with the group ID

Without this, the app falls back to sandbox storage (clips persist within the app sandbox, not shared with Share Extension).

## Next Phase Readiness

- Full Phase 1 import pipeline implemented and unit-tested
- Human verification checkpoint (Task 3) required before phase sign-off
- Phase 2 (Mixing Station) can begin after checkpoint approval — replace ImportView root with MixingStationView
- App Group entitlement addition is prerequisite for Phase 5 (Share Extension) sharing

---
*Phase: 01-foundation-import-pipeline*
*Completed: 2026-03-08*

## Self-Check: PASSED

Files verified:
- FOUND: SonicMerge/Features/Import/ImportViewModel.swift
- FOUND: SonicMerge/Features/Import/ImportView.swift
- FOUND: SonicMerge/SonicMergeApp.swift
- FOUND: SonicMerge/ContentView.swift

Commits verified:
- FOUND: 8866419 (feat(01-04): implement ImportViewModel with normalization and persistence)
- FOUND: ecabfed (feat(01-04): add ImportView and wire SonicMergeApp to import pipeline)

Test suite: TEST SUCCEEDED — 7 non-disabled tests passed, 1 skipped (AppGroupTests — expected)
