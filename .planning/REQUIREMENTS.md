# Requirements: SonicMerge

**Defined:** 2026-03-08
**Core Value:** Users can merge audio clips and remove background noise in seconds — all on-device, with no quality loss and no privacy concerns.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Import

- [ ] **IMP-01**: User can import multiple audio files in a single document picker session (multi-select)
- [ ] **IMP-02**: User can receive audio files (.m4a, .wav, .aac) via iOS Share Sheet from other apps
- [ ] **IMP-03**: App normalizes all imported audio to a canonical format (sample rate, channel layout) on import to prevent silent composition corruption
- [ ] **IMP-04**: Each imported clip displays a waveform preview thumbnail on its audio card

### Merge & Editing

- [ ] **MRG-01**: User can reorder clips via drag-and-drop in a vertical timeline
- [ ] **MRG-02**: User can delete a clip via swipe-left gesture
- [ ] **MRG-03**: User can insert a silent gap between clips (0.5s, 1.0s, or 2.0s)
- [ ] **MRG-04**: User can apply a crossfade transition between adjacent segments

### AI Denoising

- [ ] **DNS-01**: User can apply on-device noise reduction to merged audio using a Core ML model (not AVAudioEngine Voice Processing — see PITFALLS.md)
- [ ] **DNS-02**: User can adjust noise suppression intensity via a 0–100% slider
- [ ] **DNS-03**: User can hold a "Listen Original" button to temporarily hear the unprocessed audio for A/B comparison

### Export

- [ ] **EXP-01**: User can export merged audio as high-quality .m4a
- [ ] **EXP-02**: User can export merged audio as lossless .wav
- [ ] **EXP-03**: User can apply LUFS loudness normalization (-16 LUFS podcast standard) before export
- [ ] **EXP-04**: User can see export progress and cancel an in-progress export

### UI / UX

- [ ] **UX-01**: App applies "Minimalist Soft Professional" theme throughout (background #F8F9FA, accent #007AFF, AI accent #5856D6, card #FFFFFF, text #1C1C1E; corner radius 2pt; SF font)
- [ ] **UX-02**: User receives haptic feedback when toggling Before/After comparison

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Playback

- **PLAY-01**: User can preview merged result before export without saving to disk
- **PLAY-02**: User can scrub to any position in a clip before adding to timeline

### History

- **HIST-01**: App maintains a list of previous exports with timestamp and duration
- **HIST-02**: User can re-open a previous export session to re-export with different settings

### Notifications

- **NOTF-01**: User receives a local notification when a long export completes in the background

### Cloud

- **CLD-01**: User can save exported files directly to iCloud Drive

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Cloud audio processing | Breaks privacy guarantee — on-device only |
| In-app audio recording | Different use case; import-only workflow for v1 |
| Video file support | Out of audio scope; storage/complexity |
| Android / cross-platform | iOS-only — Swift/SwiftUI native |
| Real-time call noise cancellation | Different product (Krisp category); AVAudioEngine Voice Processing cannot denoise files anyway |
| Multi-track mixing | Different category (GarageBand); doubles scope |
| OAuth / accounts / sync | No user data collected; privacy-first design |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| IMP-01 | Phase 1 | Pending |
| IMP-02 | Phase 3 | Pending |
| IMP-03 | Phase 1 | Pending |
| IMP-04 | Phase 2 | Pending |
| MRG-01 | Phase 2 | Pending |
| MRG-02 | Phase 2 | Pending |
| MRG-03 | Phase 1 | Pending |
| MRG-04 | Phase 5 | Pending |
| DNS-01 | Phase 4 | Pending |
| DNS-02 | Phase 4 | Pending |
| DNS-03 | Phase 4 | Pending |
| EXP-01 | Phase 1 | Pending |
| EXP-02 | Phase 1 | Pending |
| EXP-03 | Phase 5 | Pending |
| EXP-04 | Phase 1 | Pending |
| UX-01 | Phase 2 | Pending |
| UX-02 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 16 total
- Mapped to phases: 16
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-08*
*Last updated: 2026-03-08 after initial definition*
