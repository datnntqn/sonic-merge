---
phase: 04-lufs-normalization-export-polish
verified: 2026-03-28T10:45:00Z
status: human_needed
score: 6/6 must-haves verified (automated checks)
re_verification: false
human_verification:
  - test: "Enable LUFS toggle and export from MixingStation; measure loudness of result"
    expected: "Exported file measures approximately -16 LUFS when analyzed in an external tool (e.g., ffmpeg -af ebur128, or Loudness Penalty)"
    why_human: "Automated tests only verify gain scalar > 1.0 for a -24 LUFS fixture; they do not measure the actual output file's integrated loudness — only a human with an external analyzer can confirm the output lands at -16 LUFS as required by ROADMAP Success Criterion 1"
  - test: "Export from MixingStation with LUFS off; confirm share/save sheet presents automatically"
    expected: "UIActivityViewController presents after export completes without any manual tap; user can tap 'Save to Files', 'AirDrop', or 'Cancel'; after cancel the view returns to normal state with no stuck progress indicator"
    why_human: "ROADMAP Success Criterion 2 requires the share sheet to auto-present and work for both MixingStation and CleaningLab — the completionWithItemsHandler wiring is confirmed in code but state-reset correctness under real share actions (not just cancel) requires device/simulator observation"
  - test: "Enable LUFS toggle and export from CleaningLab; confirm 'Exporting & Normalizing...' title"
    expected: "ExportProgressSheet title reads 'Exporting & Normalizing...' when LUFS is on; reads 'Exporting...' when LUFS is off"
    why_human: "Dynamic title depends on runtime view rendering — the isNormalizingExport @State wiring is confirmed but the actual rendered string requires visual inspection"
  - test: "Confirm LUFS toggle state persists across app restarts"
    expected: "@AppStorage key 'lufsNormalizationEnabled' retains the last toggle state after app is killed and relaunched"
    why_human: "UserDefaults persistence cannot be confirmed programmatically in a verification pass — requires launching, setting toggle, killing app, relaunching, and re-opening ExportFormatSheet"
---

# Phase 4: LUFS Normalization + Export Polish Verification Report

**Phase Goal:** Exported files meet podcast loudness standards and the export completion experience feels professional — users can normalize to -16 LUFS and share or save the output file with a single tap.
**Verified:** 2026-03-28T10:45:00Z
**Status:** human_needed — all automated checks pass; 4 items require human simulator verification
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

The ROADMAP defines two Success Criteria for Phase 4. All PLAN must_haves across plans 01–05 were derived from these criteria. Verification proceeds from criteria backward.

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | LUFSNormalizationService actor exists with gainScalar(for:) that returns > 1.0 for audio measurably below -16 LUFS | VERIFIED | `SonicMerge/Services/LUFSNormalizationService.swift` line 18: `actor LUFSNormalizationService`; line 30: `func gainScalar(for url: URL) async -> Double`; BS.1770-3 biquad cascade implemented lines 82–151; clamped to (0.001, 100.0) |
| 2 | ExportOptions struct carries lufsNormalize flag and is wired through both export paths | VERIFIED | `ExportFormatSheet.swift` lines 8–11: `struct ExportOptions: Sendable { let format: ExportFormat; let lufsNormalize: Bool }`; `MixingStationViewModel.exportMerged(options:)` line 229 passes `lufsNormalize: options.lufsNormalize` to `mergerService.export()`; `CleaningLabView.startExport(options:)` line 321 passes `lufsNormalize: options.lufsNormalize` to `mergerService.exportFile()` |
| 3 | AudioMergerService.export() and exportFile() accept lufsNormalize and apply gain when true | VERIFIED | `AudioMergerService.swift`: `lufsNormalize: Bool = false` parameter on both `export()` (line 60) and `exportFile()` (line 138); gain applied via `vDSP_vsmul` for WAV (line 485) and `setVolume` for M4A (line 345); `LUFSNormalizationService().gainScalar()` invoked at lines 78 and 169 |
| 4 | ExportFormatSheet shows Toggle row "Normalize to -16 LUFS" with subtitle and @AppStorage persistence | VERIFIED | `ExportFormatSheet.swift` line 39: `Text("Normalize to -16 LUFS")`; line 43: `Text("Podcast standard (-16 LUFS)")`; line 47: `Toggle("", isOn: $lufsEnabled)`; line 49: `.tint(Color(red: 0, green: 0.478, blue: 1.0))`; line 20: `@AppStorage("lufsNormalizationEnabled") private var lufsEnabled: Bool = false`; detent `.height(280)` at line 68 |
| 5 | ExportProgressSheet title is dynamic based on isNormalizing parameter | VERIFIED | `ExportProgressSheet.swift` line 10: `var isNormalizing: Bool = false`; line 16: `Text(isNormalizing ? "Exporting & Normalizing..." : "Exporting...")`; call sites in `MixingStationView.swift` line 55 (`isNormalizing: viewModel.isNormalizingExport`) and `CleaningLabView.swift` line 93 (`isNormalizing: isNormalizingExport`) both pass the flag |
| 6 | Share sheet state resets correctly after dismissal in both views | VERIFIED | `MixingStationViewModel.dismissShareSheet()` (line 261): resets `showShareSheet = false`, `exportedFileURL = nil`, `exportProgress = 0`; `ActivityViewController.swift` line 16: `completionWithItemsHandler` wired to `coordinator?.onDismiss?()`; `CleaningLabView` onDismiss closure (lines 109–113) resets `exportedFileURL = nil`, `exportProgress = 0`, `isNormalizingExport = false`, `showShareSheet = false` |

**Score:** 6/6 truths verified by automated code inspection

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `SonicMerge/Services/LUFSNormalizationService.swift` | Actor for BS.1770-3 loudness measurement and gain scalar computation | VERIFIED | 154 lines; substantive BS.1770-3 K-weighting biquad cascade; gainScalar clamped |
| `SonicMerge/Features/MixingStation/ExportFormatSheet.swift` | ExportOptions struct + Toggle row UI | VERIFIED | ExportOptions at lines 8–11; Toggle HStack at lines 37–51; @AppStorage at line 20 |
| `SonicMerge/Features/MixingStation/ExportProgressSheet.swift` | Dynamic title via isNormalizing parameter | VERIFIED | `var isNormalizing: Bool = false` at line 10; ternary title at line 16; height(220) unchanged |
| `SonicMerge/Features/MixingStation/MixingStationViewModel.swift` | exportMerged(options:), isNormalizingExport, fixed dismissShareSheet | VERIFIED | `func exportMerged(options: ExportOptions)` at line 211; `private(set) var isNormalizingExport: Bool = false` at line 40; `exportProgress = 0` in dismissShareSheet at line 264 |
| `SonicMerge/Features/MixingStation/ActivityViewController.swift` | completionWithItemsHandler wired to onDismiss | VERIFIED | Lines 16–18: completionWithItemsHandler assigns weak coordinator, calls `onDismiss?()` |
| `SonicMerge/Features/MixingStation/MixingStationView.swift` | ExportFormatSheet callback uses ExportOptions; ExportProgressSheet passes isNormalizing | VERIFIED | Line 46: `viewModel.exportMerged(options: options)`; line 55: `isNormalizing: viewModel.isNormalizingExport` |
| `SonicMerge/Features/Denoising/CleaningLabView.swift` | startExport(options:); lufsNormalize threaded; ActivityViewController sheet; shareExportedFile removed | VERIFIED | `func startExport(options: ExportOptions)` at line 304; lufsNormalize at line 321; ActivityViewController sheet at lines 106–115; no `shareExportedFile` function body present (only a comment at line 105) |
| `SonicMergeTests/LUFSNormalizationServiceTests.swift` | 3 test stubs for gain scalar and LUFS export integration | VERIFIED | 3 `@Test` methods: testGainScalarForKnownLoudness, testGainScalarAlreadyAtTarget, testExportWithLUFSEnabled |
| `SonicMergeTests/MixingStationViewModelTests.swift` | 5 total tests (3 original + 2 new EXP-03 stubs now green) | VERIFIED | 5 `@Test` methods confirmed; testExportOptionsLUFSFlag and testDismissShareSheetResetsState present |
| `SonicMergeTests/Fixtures/stereo_-24lufs_48000.wav` | 3-second stereo 48 kHz WAV fixture at ~-24 dBFS | VERIFIED | 580,096 bytes (matches expected 576,000 bytes for 3s stereo 16-bit 48 kHz) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `AudioMergerService.exportWAV` | `LUFSNormalizationService.gainScalar` | two-pass: measure then `vDSP_vsmul` | WIRED | Lines 78–107: LUFSNormalizationService instantiated, gainScalar called, scalar passed to exportWAV as `gainScalar` param; vDSP_vsmul at line 485 |
| `AudioMergerService.exportM4A` | `LUFSNormalizationService.gainScalar` | `AVMutableAudioMixInputParameters.setVolume` | WIRED | Lines 78–99: same gainScalar flow; `setVolume(gainScalar, at: .zero)` at line 345 |
| `ExportFormatSheet` | `MixingStationViewModel.exportMerged(options:)` | `onExport: (ExportOptions) -> Void` callback in MixingStationView | WIRED | `MixingStationView.swift` line 45–47: ExportFormatSheet callback passes options to `viewModel.exportMerged(options: options)` |
| `ExportFormatSheet` | `CleaningLabView.startExport(options:)` | `onExport: (ExportOptions) -> Void` callback in CleaningLabView | WIRED | `CleaningLabView.swift` line 86–88: ExportFormatSheet callback passes options to `startExport(options: options)` |
| `ActivityViewController.completionWithItemsHandler` | `viewModel.dismissShareSheet()` | onDismiss closure in MixingStationView | WIRED | `ActivityViewController.swift` line 16–18; `MixingStationView.swift` line 68: `onDismiss: { viewModel.dismissShareSheet() }` |
| `ActivityViewController.completionWithItemsHandler` | CleaningLabView state reset | onDismiss closure in CleaningLabView | WIRED | `CleaningLabView.swift` lines 108–113: onDismiss resets all 4 state variables |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| EXP-03 | 04-01, 04-02, 04-03, 04-04, 04-05 | User can apply LUFS loudness normalization (-16 LUFS podcast standard) before export | SATISFIED (automated) / NEEDS HUMAN (loudness measurement of output) | LUFSNormalizationService, AudioMergerService gain application, ExportFormatSheet toggle, both export paths threaded — all confirmed. Actual output loudness at -16 LUFS requires external measurement tool (human) |

No orphaned requirements: REQUIREMENTS.md marks EXP-03 as Phase 4, and all 5 plans claim EXP-03.

### Anti-Patterns Found

None. Scan across all 6 modified source files and 2 test files found:
- No TODO/FIXME/HACK/PLACEHOLDER comments
- No stub return values (return null, return {}, empty handlers)
- No console.log-only implementations
- `shareExportedFile` removed from CleaningLabView (line 105 is a comment, not a function)

### Human Verification Required

The following items require human verification in a running simulator. Automated code inspection cannot substitute for these checks.

#### 1. Output Loudness Measurement (ROADMAP Success Criterion 1)

**Test:** Export a file from MixingStation with the LUFS toggle enabled. Analyze the output file with an external loudness meter (ffmpeg's ebur128 filter, Loudness Penalty, or RMS Buddy).
**Expected:** Integrated loudness reads approximately -16 LUFS (tolerance ±2 dB is acceptable for the MVP's ungated measurement approach).
**Why human:** The automated tests verify that `gainScalar > 1.0` for a -24 dBFS fixture and that no crash occurs — they do not analyze the actual output file's loudness. ROADMAP Success Criterion 1 requires the file to "measure -16 LUFS when analyzed in an external tool," which is definitionally a human verification step.

#### 2. Share Sheet Auto-Presentation and State Reset (ROADMAP Success Criterion 2)

**Test:** Export a file from both MixingStation and CleaningLab. Observe that UIActivityViewController presents automatically after the progress sheet dismisses. Try "Save to Files", "AirDrop", and "Cancel" dismissal paths. After each, confirm no stuck progress indicator and no stale share sheet.
**Expected:** Share sheet auto-presents; all dismissal paths trigger state reset (exportProgress = 0, no stale URL); view is ready for a new export.
**Why human:** The `completionWithItemsHandler` wiring is confirmed in code, but iOS can vary in when it fires the completion handler for different activities (some fire synchronously, some after an async save). Real device/simulator observation is needed to confirm all paths work.

#### 3. Dynamic Progress Title in Both Views

**Test:** Enable LUFS toggle; start export from MixingStation. Observe ExportProgressSheet title. Disable LUFS toggle; export again. Repeat in CleaningLab.
**Expected:** Title reads "Exporting & Normalizing..." when LUFS on; "Exporting..." when LUFS off — in both views.
**Why human:** isNormalizingExport @State wiring is confirmed in code, but SwiftUI rendering correctness requires visual inspection.

#### 4. Toggle Persistence Across App Restarts

**Test:** Enable the LUFS toggle in ExportFormatSheet. Kill the app via the simulator. Relaunch. Open ExportFormatSheet.
**Expected:** Toggle is still enabled (UserDefaults via @AppStorage retained the value).
**Why human:** @AppStorage behavior with the simulator's UserDefaults cannot be confirmed programmatically in this verification pass.

### Gaps Summary

No gaps found. All automated checks pass across 6/6 observable truths, all artifacts are substantive and wired, all key links are confirmed. The `human_needed` status reflects that ROADMAP Success Criterion 1 (output file measures -16 LUFS externally) is definitionally a human check, not a code deficiency.

One known architectural simplification (documented in SUMMARY 04-02) that is acceptable for MVP but worth noting: multi-clip LUFS measurement uses the first clip as a loudness proxy rather than a full two-pass measurement on a temp WAV. This means multi-clip exports may not land exactly at -16 LUFS if clip loudness varies significantly. The single-file CleaningLab path is exact. This is an accepted MVP trade-off, not a gap.

---

_Verified: 2026-03-28T10:45:00Z_
_Verifier: Claude (gsd-verifier)_
