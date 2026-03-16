---
status: complete
phase: 03-ai-denoising-pipeline
source: 03-01-SUMMARY.md, 03-02-SUMMARY.md, 03-03-SUMMARY.md, 03-04-SUMMARY.md
started: 2026-03-16T00:00:00Z
updated: 2026-03-16T00:00:00Z
---

## Current Test

## Current Test

[testing complete]

## Tests

### 1. Denoise Toolbar Button in MixingStation

expected: In MixingStationView (with at least one audio clip loaded), a toolbar button with the "wand.and.sparkles" icon appears. Tapping it triggers a merge-to-WAV and navigates to the Cleaning Lab screen.
result: pass

### 2. Cleaning Lab Layout

expected: CleaningLabView shows all major sections: a full-width waveform canvas (bar visualization), a "Denoise Intensity" slider, an "A/B Compare" button, a "Denoise" action button, and an export button in the toolbar.
result: pass

### 3. Non-Dismissible Denoising Progress Sheet

expected: Tapping the Denoise button shows a full-screen modal progress sheet. Attempting to swipe it down or dismiss it does nothing — it stays locked on screen until processing completes or is cancelled.
result: pass

### 4. Cancel Denoising

expected: While the denoising progress sheet is visible, tapping Cancel immediately dismisses the modal and stops processing. No denoised result is kept.
result: pass

### 5. Intensity Slider — Fast Re-Blend Without Re-Inference

expected: After denoising completes, moving the intensity slider (wet/dry blend) quickly re-applies the blend without showing the full-screen progress modal. The result updates fast (no AI re-inference triggered).
result: skipped
reason: DeepFilterNet3.mlpackage not yet imported — denoising cannot run. Follow docs/DENOISING_SETUP.md to unblock.

### 6. A/B Hold-to-Compare with Haptic

expected: After denoising completes, pressing and holding the "A/B Compare" button switches playback to the original audio. Releasing returns playback to the denoised version. The playback position is preserved across the switch (audio continues from same timestamp). A haptic pulse fires on release.
result: skipped
reason: DeepFilterNet3.mlpackage not yet imported — denoising cannot run. Follow docs/DENOISING_SETUP.md to unblock.

### 7. Stale Result Banner

expected: After denoising completes, navigate back to MixingStation and modify the clips (add or remove one). Then navigate back to Cleaning Lab — a stale warning banner appears at the top of the screen indicating the result may be outdated.
result: skipped
reason: DeepFilterNet3.mlpackage not yet imported — denoising cannot run. Follow docs/DENOISING_SETUP.md to unblock.

### 8. Export Denoised Audio

expected: Tapping the export toolbar item in CleaningLabView presents format options. Selecting a format triggers conversion and displays the system share sheet (UIActivityViewController) so the file can be saved or shared.
result: skipped
reason: DeepFilterNet3.mlpackage not yet imported — denoising cannot run. Follow docs/DENOISING_SETUP.md to unblock.

## Summary

total: 8
passed: 4
issues: 0
pending: 0
skipped: 4

## Gaps

[none yet]
