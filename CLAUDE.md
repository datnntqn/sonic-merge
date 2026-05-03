# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Native iOS audio utility — merge multiple clips, on-device AI noise reduction, on-device filler-word + long-pause cutting (Smart Cut). Privacy-first, no cloud. The app's user-facing name is **CleanCut** but the bundle ID, Xcode scheme, module name, type names (`SonicMergeApp`, `SonicMergeTheme`, `SonicMergeSemantic`), entitlements, App Group ID (`group.com.yourteam.SonicMerge`), and `@AppStorage` keys (`sonicMergeThemePreference`, `sonicMerge.hasImportedFirstClip`) all remain `SonicMerge*`. Don't try to "fix" the inconsistency — it's deliberate (see `docs/superpowers/specs/2026-05-03-three-tab-ui-unification-design.md` §9).

- **Stack:** Swift 6, SwiftUI, SwiftData, AVFoundation, Core ML / Speech, Accelerate / vDSP. Deployment target iOS 26.2 (iPhone 17 sim is the standard build target).
- **Test framework:** Swift Testing (`import Testing`, `@Test`, `#expect`) is the project convention. A few legacy files still use XCTest — match what the file already uses; prefer Swift Testing for new files.

## Build & test commands

```bash
# Standard build (run from repo root — paths in this project assume absolute paths)
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5

# Full test suite
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3

# Single Swift Testing suite (notice: NO -only-testing slash for the test name)
xcodebuild ... -only-testing:SonicMergeTests/ThemeMigrationTests test

# Single XCTest case (slash works for legacy XCTest files)
xcodebuild ... -only-testing:SonicMergeTests/SessionModelPersistenceTests/test_smartCutSession test

# Share extension target
xcodebuild -scheme SonicMergeShareExtension ... build

# Failure-count summary across the suite
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

**Baseline failing tests on `main` (5, expected, NOT regressions):**
- `compositionWithCrossfadeHasNonNilAudioMix` — AudioMerger crossfade timing assertion
- `testFileCopyToClipsDirectory`, `testLargeFileCopyDoesNotCrash`, `testPendingKeyWrittenAndCleared` — ShareExtension entitlement-gated (the test host lacks the App Group)
- `testPositionPreservedOnSwitch` — A/B playback timing flake

When running tests after a change, expect `FAIL=5` with exactly these names. New regressions show as additional failures or different names. `testOutputFormatIsValid` (NoiseReductionService) is a known CoreML flake (E5RT zero-shape error) — re-run in isolation if it appears once.

**SourceKit phantoms:** the IDE indexer often reports "No such module 'UIKit'", "Cannot find type 'X' in scope", "No exact matches in call to initializer" for files that compile fine via `xcodebuild`. Trust the actual build, not the inline diagnostics.

## Architecture

### Three-tab shell
```
SonicMergeApp                                 — @main, owns ModelContainer, theme migration .onAppear
└─ RootTabView                                — single source of truth for theme; injects \.sonicMergeSemantic
   ├─ NavigationStack (Smart Cut)             — list-of-sessions tab; @Query<SmartCutSession>
   │  └─ SmartCutHomeView → SmartCutSessionView (push by UUID) → SmartCutStudioContainer
   ├─ NavigationStack (Denoise)               — list-of-sessions tab; @Query<DenoiseSession>
   │  └─ DenoiseHomeView → DenoiseSessionView (push by UUID)
   └─ NavigationStack (Merge)                 — single-workspace tab (NOT a list)
      └─ MixingStationView → MergeTimelineView
```

`RootTabView` (`SonicMerge/App/RootTabView.swift`) is the architectural hinge. It owns the `themePreferenceRaw` `@AppStorage`, resolves `SonicMergeSemantic`, and applies BOTH `.environment(\.sonicMergeSemantic, ...)` and `.preferredColorScheme(...)` so custom palette **and** OS chrome (status bar, NavigationBar, TabBar) flip together. Don't add a second `.environment(\.sonicMergeSemantic, ...)` injection downstream — it would shadow the root and create two-source-of-truth bugs.

### Theme & color discipline
Two semantic tokens, deliberately split:
- **`accentAction` Deep Indigo `#5856D6`** — tab bar selection, primary CTAs (import buttons, Add Clip, Export, theme toggle), back-chevrons. The brand-level color across the whole app.
- **`accentAI` Lime Green `#A7C957`** — AI moments only: the AI Orb, intensity slider, "Apply Cuts" / "Re-denoise" floating CTAs, AI summary card pill, AI hero icons in empty states.

The user-felt rule: **indigo = navigation / move data; lime = AI is doing something now.** "Upload Audio" is *navigation* (file picker), not an AI moment, so it's indigo. The toggle button (`ThemeToggleButton`) is brand chrome → indigo.

`ThemePreference` is binary (`.light` / `.dark`); `.system` was removed. `migrateLegacyTheme(_:)` in `SonicMergeApp` normalizes any pre-existing `"system"` (or unrecognized) raw value to `.light` on first appear.

### Persistence + App Group
SwiftData `ModelContainer` is configured with App Group `group.com.yourteam.SonicMerge` when entitled, falling back to the default sandbox container in unit-test hosts. Per-session content lives at:

| Layout | Helper | Owner |
|---|---|---|
| `<AppGroup>/clips/` | `AppConstants.clipsDirectory()` | Merge timeline, Share Extension legacy import path |
| `<AppGroup>/smart-cut/<UUID>/` | `AppConstants.smartCutSessionDirectory(for:)` | One Smart Cut session — source audio + edit-list cache |
| `<AppGroup>/denoise/<UUID>/` | `AppConstants.denoiseSessionDirectory(for:)` | One Denoise session — source + processed.wav |

Schema: `AudioClip`, `GapTransition`, `SmartCutSession`, `DenoiseSession`. The Share Extension has its own `AppConstants.swift` mirror — keep both copies in sync.

### Audio + AI services
`SonicMerge/Services/`:
- `AudioMergerService` — `AVMutableComposition` build, crossfades, format-aware export (m4a via `AVAssetExportSession`, wav via `AVAssetReader+Writer`). Has both a clips-based and a single-file `exportFile(...)` API.
- `NoiseReductionService` — DeepFilterNet3 Core ML pipeline (vDSP STFT/iSTFT in Swift, model files at `temp-dfn/`).
- `WaveformService` — actor; writes a 50-peak `Float` sidecar `.waveform` next to the source.
- `LUFSNormalizationService` — manual BS.1770 K-weighting biquad cascade (no third-party dep).
- `PlaybackCoordinator` — cross-card playback arbitration (only one player active at a time).
- `SourceHasher` — SHA-256 of audio bytes; used to dedupe + route background-transcription deep-links.

The Smart Cut transcription pipeline uses `SFSpeechRecognizer` (request authorization explicitly via `Task` since `isAvailable` returns `true` even when unauthorized) and `BackgroundTranscriptionTask` for off-screen analysis with an OS notification on completion.

### View layer conventions
- Home views and design-system components read `@Environment(\.sonicMergeSemantic) private var semantic` and pull colors as `Color(uiColor: semantic.accentAction)` etc. Never hardcode hex.
- The circular import button is `CircularImportButton(size: .hero | .pinned, action: ...)` — six callsites consume it, do NOT inline new copies.
- The theme toggle is `ThemeToggleButton()` — zero-arg, self-contained, lives in three home toolbars.
- Test seams on view models follow the `_injectResultsForTesting(_:)` / `_injectAppliedSnapshotForTesting(_:)` pattern — keep them prefix-underscored and only call from tests.

## Workflow artifacts

`.planning/` is the older gsd workflow tree (PROJECT.md, STATE.md, ROADMAP.md, phases/, research/). New work uses `docs/superpowers/`:

- `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` — design specs (one per non-trivial change)
- `docs/superpowers/plans/YYYY-MM-DD-<topic>.md` — implementation plans, chunked
- `docs/superpowers/qa/YYYY-MM-DD-<topic>-manual-qa.md` — manual QA checklists when present

Read the relevant `.planning/research/{ARCHITECTURE,STACK,PITFALLS}.md` for v1.0/v1.1 context. PITFALLS.md is especially valuable — it catalogs known gotchas (SwiftData + ModelConfiguration assertions without entitlement, AVAudioPlayer prepareToPlay timing, `Picker` raw-value storage edge cases).

## Code style — Karpathy guidelines (alwaysApply)

`.cursor/rules/karpathy-guidelines.mdc` is enforced for all code work. The rules that bite most often:

1. **Surgical changes only.** Don't "improve" adjacent code, comments, or formatting. If you notice unrelated dead code, mention it — don't delete it.
2. **Surface assumptions.** If multiple interpretations exist, present them; don't pick silently.
3. **YAGNI.** No abstractions for single-use code, no flexibility that wasn't requested. Three identical lines is better than a premature abstraction (rule of three before extracting; rule of six is overdue).
4. **Match existing style.** Even if you'd write it differently. The two-color brand discipline above is one such example — fix the violation, don't reinvent the system.
