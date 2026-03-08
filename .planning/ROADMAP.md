# Roadmap: SonicMerge

## Overview

SonicMerge delivers a complete on-device audio merge and denoising workflow in five phases. Phase 1 lays the data model and import foundation that every other phase builds on. Phase 2 ships the core merge pipeline and Mixing Station UI — the primary user workflow. Phase 3 integrates the Core ML denoising pipeline, the product's primary differentiator. Phase 4 adds LUFS loudness normalization to make exports podcast-ready. Phase 5 completes the intake surface with the Share Extension so users can route audio from any app into SonicMerge.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation + Import Pipeline** - Stable data models, audio session, and correct import with format normalization
- [ ] **Phase 2: Merge Pipeline + Mixing Station UI** - Full clip editing workflow and export to .m4a/.wav
- [ ] **Phase 3: AI Denoising Pipeline** - Core ML on-device denoising with A/B comparison
- [ ] **Phase 4: LUFS Normalization + Export Polish** - Podcast-standard loudness and polished export completion UX
- [ ] **Phase 5: Share Extension** - Receive audio from any app via iOS Share Sheet

## Phase Details

### Phase 1: Foundation + Import Pipeline
**Goal**: The app has a stable foundation — correct data models, a configured audio session, and a working multi-file import pipeline that normalizes formats at import time to prevent downstream corruption.
**Depends on**: Nothing (first phase)
**Requirements**: IMP-01, IMP-03
**Success Criteria** (what must be TRUE):
  1. User can open a document picker, select multiple audio files (.m4a, .wav, .aac) in one session, and see them appear as clips in the timeline.
  2. Clips imported from sources with different sample rates or channel layouts produce correct merged output (no silence, no duration drift).
  3. Imported files survive app relaunch — clips are available in the next session without re-importing.
  4. App Group shared container is configured and accessible from both the main app target and the future Share Extension target.
**Plans**: TBD

### Phase 2: Merge Pipeline + Mixing Station UI
**Goal**: Users can arrange clips, configure gaps and crossfades, and export a finished merged audio file — the complete core workflow is functional end-to-end.
**Depends on**: Phase 1
**Requirements**: IMP-04, MRG-01, MRG-02, MRG-03, MRG-04, EXP-01, EXP-02, EXP-04, UX-01
**Success Criteria** (what must be TRUE):
  1. Each audio clip card displays a waveform thumbnail, file name, and duration.
  2. User can drag clips to a new position in the timeline and the reorder persists when export is triggered.
  3. User can swipe left on a clip to delete it, and the clip is removed from the composition immediately.
  4. User can tap a gap control between clips and choose 0.5 s, 1.0 s, or 2.0 s of silence; the exported file contains the gap at the correct position.
  5. User can tap Export, see a progress indicator with a Cancel button, and receive a valid .m4a or .wav file in the system share sheet on completion.
**Plans**: TBD

### Phase 3: AI Denoising Pipeline
**Goal**: Users can apply on-device Core ML noise reduction to the merged audio, control suppression intensity, and verify the improvement with a live A/B comparison — entirely offline.
**Depends on**: Phase 2
**Requirements**: DNS-01, DNS-02, DNS-03, UX-02
**Success Criteria** (what must be TRUE):
  1. User can initiate denoising on a merged clip and see a progress indicator; the operation completes without requiring network access.
  2. User can drag a slider from 0% to 100% and the denoised output audibly reflects the chosen suppression intensity.
  3. User can hold the "Listen Original" button and hear the unprocessed audio; releasing it returns to the denoised playback.
  4. Toggling between Before and After comparison produces a distinct haptic tap.
**Plans**: TBD

### Phase 4: LUFS Normalization + Export Polish
**Goal**: Exported files meet podcast loudness standards and the export completion experience feels professional — users can normalize to -16 LUFS and share or save the output file with a single tap.
**Depends on**: Phase 3
**Requirements**: EXP-03
**Success Criteria** (what must be TRUE):
  1. User can enable LUFS normalization before export and the exported file measures -16 LUFS when analyzed in an external tool.
  2. Export completion presents a share/save sheet so the user can send the file to Files, AirDrop, or another app without leaving SonicMerge.
**Plans**: TBD

### Phase 5: Share Extension
**Goal**: Users can send audio files from Voice Memos, Files, or any app to SonicMerge via the iOS Share Sheet, and those files appear as clips ready for editing in the Mixing Station.
**Depends on**: Phase 1, Phase 2
**Requirements**: IMP-02
**Success Criteria** (what must be TRUE):
  1. User can select an audio file in another app, tap Share, choose SonicMerge, and the file appears as a clip in the Mixing Station timeline.
  2. Sharing a 30 MB+ audio file from Files does not crash the Share Extension.
  3. If the user taps Share twice for the same file, only one copy of the clip is added to the timeline (no duplicates).
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation + Import Pipeline | 0/TBD | Not started | - |
| 2. Merge Pipeline + Mixing Station UI | 0/TBD | Not started | - |
| 3. AI Denoising Pipeline | 0/TBD | Not started | - |
| 4. LUFS Normalization + Export Polish | 0/TBD | Not started | - |
| 5. Share Extension | 0/TBD | Not started | - |
