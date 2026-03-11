---
status: complete
phase: 02-merge-pipeline-mixing-station-ui
source:
  [
    02-01-SUMMARY.md,
    02-02-SUMMARY.md,
    02-03-SUMMARY.md,
    02-04-SUMMARY.md,
    02-05-PLAN.md,
  ]
started: 2026-03-11T00:00:00Z
updated: 2026-03-11T00:30:00Z
---

## Current Test

<!-- OVERWRITE each test - shows where we are -->

[testing complete]

## Tests

### 1. Cold Start Smoke Test

expected: Kill any running instance of SonicMerge. Build and launch the app fresh from Xcode (or tap the app icon cold). The app should boot without errors or crashes. The MixingStation screen should appear (not a blank screen, not a crash, not the old ImportView). If this is a fresh install with no existing clips, you should see an empty state with an Import button and some descriptive text.
result: pass

### 2. Empty State — Import Button Visible

expected: With no clips loaded, the MixingStation screen shows an empty state: an Import (or "+" / "Add Files") button and some descriptive placeholder text (e.g. "No clips yet. Tap Import to get started"). The Export toolbar button is not shown, or is disabled/hidden when there are no clips.
result: pass

### 3. Import Audio Files

expected: Tap the Import button. The system document picker opens. Select one or more audio files (.m4a, .wav, etc.). After dismissing the picker, the clips appear in the list as cards. Each card shows the file name and duration. A brief loading/processing state may be visible while normalization and waveform generation happen.
result: pass

### 4. Clip Card — Waveform, Name, Duration

expected: Each imported clip card shows: (1) a waveform thumbnail on the left (~60pt wide) drawn from the audio data — it should look like a mini waveform, not just a grey box, (2) the file name / display name, (3) the clip duration (e.g. "1:23"). The card has a white background with a slight rounded corner on a light grey page background.
result: pass

### 5. Gap Row Between Clips

expected: Between each pair of adjacent clip cards, there is a small inline gap row. It contains a segmented control with four options: 0.5s | 1.0s | 2.0s | Crossfade. One option is selected (default 0.5s or as saved). The gap row is visually distinct from the clip cards (smaller, secondary style).
result: pass

### 6. Change Gap Duration

expected: Tap a gap row's segmented control and choose a different duration (e.g., change from 0.5s to 2.0s). The selection updates immediately in the UI. Export the clips (or close and reopen the app) — the selected gap duration should be remembered (it persists to SwiftData).
result: pass

### 7. Enable Crossfade

expected: Tap a gap row's segmented control and select "Crossfade". The selection highlights. This means the two surrounding clips will crossfade during export instead of having a silence gap. The UI should reflect this selection clearly.
result: pass

### 8. Reorder Clips

expected: Long-press (or grab the drag handle) on a clip card and drag it to a new position in the list. The list reorders in real time as you drag. Release to drop. The clip is now in the new position and the gap rows adjust accordingly. The new order persists.
result: pass

### 9. Delete a Clip

expected: Swipe left on a clip card. A "Delete" button appears. Tap Delete (or complete the swipe). The clip is removed from the list. The gap row that was attached to that clip is also removed. Remaining clips and their gap rows are intact.
result: pass

### 10. Export — Format Sheet

expected: With at least one clip in the list, tap the Export button (in the toolbar or a prominent button). A bottom sheet slides up showing: a format picker with ".m4a" and ".wav" options, and an "Export" button. The sheet height is compact (roughly 200pt). The rest of the screen is dimmed.
result: pass

### 11. Export Progress Modal

expected: In the export format sheet, select a format and tap Export. The sheet dismisses and a non-dismissible modal appears showing: a progress bar or circular ProgressView, a percentage or progress label, and a Cancel button. You cannot dismiss this modal by swiping down. The progress indicator animates/advances while export is happening.
result: pass

### 12. Cancel Export

expected: While the export progress modal is showing, tap the Cancel button. The modal dismisses and export stops. The app returns to the normal MixingStation list view with clips intact. No exported file is produced (or a partial file is not shared).
result: pass

### 13. Successful Export — Share Sheet

expected: Start an export (format sheet → pick format → Export). Let it complete without cancelling. When the progress reaches 100% / completes, the progress modal dismisses and the iOS share sheet (UIActivityViewController) appears with the exported audio file ready to share, save to Files, AirDrop, etc. The file has the correct extension (.m4a or .wav based on your choice).
result: pass

### 14. Export as WAV

expected: Go through the export flow but select ".wav" as the format. After export completes and the share sheet opens, the file should have a .wav extension. (This tests the AVAssetReader+Writer WAV export path which is separate from the m4a path.)
result: pass

## Summary

total: 14
passed: 14
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
