---
phase: 01-foundation-import-pipeline
plan: 02
subsystem: database
tags: [swiftdata, avfoundation, swift, ios, uniformtypeidentifiers, appgroup]

# Dependency graph
requires: []
provides:
  - AudioClip @Model with 8 SwiftData-persisted properties (id, displayName, fileURLRelativePath, duration, sampleRate, channelCount, importedAt, sortOrder)
  - AppConstants enum with appGroupID and clipsDirectory() factory
  - AppGroupError with containerNotFound case and human-readable errorDescription
  - UTType.audioImportTypes convenience array [.wav, public.aac-audio, .mpeg4Audio]
  - SonicMergeApp wired with SwiftData ModelContainer (App Group) and AVAudioSession .playback
affects: [01-03-normalization-service, 01-04-import-pipeline, 02-mixing-station-ui, 05-share-extension]

# Tech tracking
tech-stack:
  added: [SwiftData, AVFAudio, UniformTypeIdentifiers]
  patterns: [relative-path-storage-pattern, app-group-container-pattern, failable-clipsDirectory-pattern]

key-files:
  created:
    - SonicMerge/Models/AudioClip.swift
    - SonicMerge/App/AppConstants.swift
    - SonicMerge/Extensions/UTType+Audio.swift
  modified:
    - SonicMerge/SonicMergeApp.swift

key-decisions:
  - "Store fileURLRelativePath (filename only) not absolute URL — absolute App Group paths shift between device/simulator; reconstruct at runtime via AppConstants.clipsDirectory()"
  - "UTType.aac does not exist as a static member on iOS SDK; use UTType('public.aac-audio')! via identifier instead"
  - "AVAudioSession failure on launch is non-fatal — normalization via AVAssetWriter does not require active session; Phase 2 retries before first playback"
  - "ModelContainer fatalError on App Group failure is intentional — without the entitlement the app cannot store clips; developer must add capability"

patterns-established:
  - "Relative path storage: store only lastPathComponent in SwiftData, reconstruct absolute URL via AppConstants.clipsDirectory() at runtime"
  - "App Group error: AppGroupError.containerNotFound thrown when entitlement missing; callers catch and surface to user"
  - "Convenience init pattern: AudioClip(displayName:fileURL:duration:) extracts lastPathComponent for test/caller ergonomics"

requirements-completed: [IMP-01, IMP-03]

# Metrics
duration: 4min
completed: 2026-03-08
---

# Phase 1 Plan 02: Foundation Layer Summary

**SwiftData AudioClip @Model, App Group constants, UTType audio filter, and wired SonicMergeApp entry point establishing the complete data model foundation**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-08T14:28:45Z
- **Completed:** 2026-03-08T14:32:45Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- AudioClip @Model with 8 persisted properties; stores only filename component to avoid device-specific path drift
- AppConstants enum providing App Group ID and clipsDirectory() factory with AppGroupError fallback
- UTType+Audio extension with audioImportTypes array for .fileImporter
- SonicMergeApp fully wired: SwiftData ModelContainer with App Group container + AVAudioSession .playback at launch

## Task Commits

Each task was committed atomically:

1. **Task 1: AudioClip @Model and AppConstants** - `f8be8b4` (feat)
2. **Task 2: UTType+Audio extension and wire SonicMergeApp** - `80188b1` (feat)

## Files Created/Modified
- `SonicMerge/Models/AudioClip.swift` - SwiftData @Model for clip persistence with relative path storage
- `SonicMerge/App/AppConstants.swift` - App Group ID constant and clipsDirectory() factory with AppGroupError
- `SonicMerge/Extensions/UTType+Audio.swift` - audioImportTypes convenience array for .fileImporter
- `SonicMerge/SonicMergeApp.swift` - App entry point with ModelContainer (App Group) and AVAudioSession

## Decisions Made
- **Relative path storage:** FileURLRelativePath stores only the filename (lastPathComponent). Absolute App Group container paths can change between simulator restarts and device provisioning. Reconstructing via AppConstants.clipsDirectory() at runtime avoids stale paths in SwiftData store.
- **UTType.aac not available:** `UTType.aac` is not a static member on all iOS SDK versions. Used `UTType("public.aac-audio")!` via identifier string. Verified existence before force-unwrapping.
- **AVAudioSession non-fatal:** AVAudioSession failure at launch is logged but not fatal — AVAssetWriter-based normalization does not require an active audio session. Phase 2 retries session activation before first playback.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] UTType.aac does not exist as a static member**
- **Found during:** Task 2 (UTType+Audio extension and wire SonicMergeApp)
- **Issue:** Plan specified `[.wav, .aac, .mpeg4Audio]` but `UTType.aac` is not available as a static member on iOS 26 SDK — build failed with "type 'UTType' has no member 'aac'"
- **Fix:** Defined private `static let aacAudio = UTType("public.aac-audio")!` and used it in the array. The `public.aac-audio` identifier is confirmed declared in the UTType registry.
- **Files modified:** SonicMerge/Extensions/UTType+Audio.swift
- **Verification:** Build succeeded after fix; UTType("public.aac-audio") non-nil confirmed via xcrun swift
- **Committed in:** 80188b1 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Fix necessary for compilation; behavior is identical — raw AAC files are accepted by .fileImporter. No scope creep.

## Issues Encountered
- `xcodebuild build -destination 'platform=iOS Simulator,name=iPhone 16'` failed — iPhone 16 simulator not available (iOS 26.2 only has iPhone 17 and Air). Used `name=iPhone 17` instead.

## User Setup Required
**App Group entitlement must be configured manually in Xcode before the app can run on a real device.**

Steps:
1. Open `SonicMerge.xcodeproj` in Xcode
2. Select the `SonicMerge` target
3. Go to Signing & Capabilities
4. Click `+` > App Groups
5. Add: `group.com.yourteam.SonicMerge`

Without this entitlement, `containerURL(forSecurityApplicationGroupIdentifier:)` returns nil in the simulator and `ModelContainer` will `fatalError`. The entitlement is also required for the future Share Extension target (Phase 5).

## Next Phase Readiness
- AudioClip, AppConstants, and UTType.audioImportTypes are available for Plans 03 and 04 to import
- Plan 01 test stubs (PersistenceTests, AppGroupTests) can now compile against these types
- Plan 03 (normalization service) can proceed: it uses AppConstants.clipsDirectory() for output files
- Plan 04 (import pipeline) can proceed: it uses AudioClip, AppConstants, and UTType.audioImportTypes

**Blockers:**
- App Group entitlement not yet added — required before end-to-end testing on device (covered by Plan 04's human-verify checkpoint)

## Self-Check: PASSED

| Item | Status |
|------|--------|
| SonicMerge/Models/AudioClip.swift | FOUND |
| SonicMerge/App/AppConstants.swift | FOUND |
| SonicMerge/Extensions/UTType+Audio.swift | FOUND |
| SonicMerge/SonicMergeApp.swift | FOUND |
| .planning/phases/01-foundation-import-pipeline/01-02-SUMMARY.md | FOUND |
| Commit f8be8b4 (Task 1) | FOUND |
| Commit 80188b1 (Task 2) | FOUND |
| xcodebuild BUILD SUCCEEDED | VERIFIED |

---
*Phase: 01-foundation-import-pipeline*
*Completed: 2026-03-08*
