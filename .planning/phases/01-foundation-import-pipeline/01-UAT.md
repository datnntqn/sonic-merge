---
status: complete
phase: 01-foundation-import-pipeline
source: [01-01-SUMMARY.md, 01-02-SUMMARY.md, 01-03-SUMMARY.md, 01-04-SUMMARY.md]
started: 2026-03-10T00:00:00Z
updated: 2026-03-10T00:10:00Z
---

## Current Test

[testing complete]

## Tests

### 1. App Launch & Empty State
expected: Launch the app fresh (or after a clean install). The main screen shows an empty state — something like "No Audio Clips" with an icon or message, and a "+" or import button in the toolbar.
result: pass

### 2. Import Audio Files
expected: Tap the "+" toolbar button — the system document picker opens. Select 2–3 audio files (.m4a, .wav, or .aac). Tap Open. A "Normalizing…" spinner appears briefly, then dismisses. The clip list now shows each imported file with its name, duration, and "48kHz · Stereo" label.
result: pass

### 3. Format Normalization
expected: Among the files you imported, pick one that was NOT already 48kHz stereo (e.g. a mono WAV or a 44.1kHz file). Its entry in the clip list still shows "48kHz · Stereo" — meaning it was normalized at import time.
result: pass

### 4. Clip Persistence
expected: Force-quit the app (swipe up from app switcher) and relaunch it. The same clips you imported are still listed — they were not lost.
result: pass

### 5. Import Error Alert
expected: If any selected file fails to import (e.g. corrupt file, unsupported format), an "Import Errors" alert appears naming the file and the reason. Other valid files still import successfully.
result: pass

## Summary

total: 5
passed: 5
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
