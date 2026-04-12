# Roadmap: SonicMerge

## Overview

SonicMerge delivers a complete on-device audio merge and denoising workflow in five phases. Phase 1 lays the data model and import foundation that every other phase builds on. Phase 2 ships the core merge pipeline and Mixing Station UI — the primary user workflow. Phase 3 integrates the Core ML denoising pipeline, the product's primary differentiator. Phase 4 adds LUFS loudness normalization to make exports podcast-ready. Phase 5 completes the intake surface with the Share Extension so users can route audio from any app into SonicMerge.

**Milestone v1.1 (Phases 6–9)** reskins the entire UI to the "Modern Spatial Utility" aesthetic. All four phases are visual-only — no ViewModel or service changes. Phase 6 builds the design system tokens and reusable components that phases 7–9 consume. Phase 7 applies them to the Mixing Station. Phase 8 handles the highest-complexity screen (Cleaning Lab + AI Orb). Phase 9 locks in app-wide haptics, dark mode completeness, and accessibility fallbacks.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

### Milestone v1.0

- [x] **Phase 1: Foundation + Import Pipeline** - Stable data models, audio session, and correct import with format normalization (completed 2026-03-08)
- [ ] **Phase 2: Merge Pipeline + Mixing Station UI** - Full clip editing workflow and export to .m4a/.wav
- [x] **Phase 3: AI Denoising Pipeline** - Core ML on-device denoising with A/B comparison (completed 2026-03-12)
- [x] **Phase 4: LUFS Normalization + Export Polish** - Podcast-standard loudness and polished export completion UX (completed 2026-03-28)
- [x] **Phase 5: Share Extension** - Receive audio from any app via iOS Share Sheet (completed 2026-04-08)

### Milestone v1.1 — Modern Spatial Utility Restyle

- [x] **Phase 6: Design System Foundation** - Color tokens, SquircleCard, PillButton, and glassmorphism header primitives (completed 2026-04-11)
- [ ] **Phase 7: Mixing Station Restyle** - Apply design system to Mixing Station screens (timeline, cards, waveforms, gaps)
- [ ] **Phase 8: Cleaning Lab + AI Orb** - Restyle Cleaning Lab and implement AI Orb pulsating nebula visualizer
- [ ] **Phase 9: Polish + Accessibility Audit** - App-wide haptics, dark mode completeness, and accessibility fallbacks

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
**Plans**: 4 plans

Plans:
- [ ] 01-01-PLAN.md — Test infrastructure: SonicMergeTests target, audio fixtures, failing @Test stubs (Wave 1)
- [ ] 01-02-PLAN.md — Foundation types: AudioClip @Model, AppConstants, UTType+Audio, SonicMergeApp wiring (Wave 1, parallel)
- [ ] 01-03-PLAN.md — AudioNormalizationService: AVAssetReader+Writer pipeline, mono upmix (Wave 2, TDD)
- [ ] 01-04-PLAN.md — Import pipeline: ImportViewModel, ImportView, end-to-end verification checkpoint (Wave 3)

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
**Plans**: 5 plans

Plans:
- [ ] 02-01-PLAN.md — Wave 0 test stubs: WaveformServiceTests, MixingStationViewModelTests, AudioMergerServiceTests (Wave 1)
- [ ] 02-02-PLAN.md — Foundation: GapTransition model, WaveformService, AudioClip extensions (Wave 2)
- [ ] 02-03-PLAN.md — MixingStationViewModel: clip management, import, export orchestration (Wave 2)
- [ ] 02-04-PLAN.md — AudioMergerService: composition builder, m4a export, wav export, crossfade (Wave 3)
- [ ] 02-05-PLAN.md — Mixing Station UI: MixingStationView, ClipCardView, GapRowView, export sheets, app rewire (Wave 4)

### Phase 3: AI Denoising Pipeline
**Goal**: Users can apply on-device Core ML noise reduction to the merged audio, control suppression intensity, and verify the improvement with a live A/B comparison — entirely offline.
**Depends on**: Phase 2
**Requirements**: DNS-01, DNS-02, DNS-03, UX-02
**Success Criteria** (what must be TRUE):
  1. User can initiate denoising on a merged clip and see a progress indicator; the operation completes without requiring network access.
  2. User can drag a slider from 0% to 100% and the denoised output audibly reflects the chosen suppression intensity.
  3. User can hold the "Listen Original" button and hear the unprocessed audio; releasing it returns to the denoised playback.
  4. Toggling between Before and After comparison produces a distinct haptic tap.
**Plans**: 4 plans

Plans:
- [ ] 03-01-PLAN.md — Wave 0: failing test stubs (NoiseReductionServiceTests, WetDryBlendTests, ABPlaybackTests) + coremltools conversion script and developer setup guide (Wave 1)
- [ ] 03-02-PLAN.md — NoiseReductionService actor: DeepFilterNet3 Core ML inference, streaming 480-sample chunks, explicit RNN state, vDSP wet/dry blend (Wave 2, TDD)
- [ ] 03-03-PLAN.md — CleaningLabViewModel: @Observable orchestration, A/B dual-player, haptic, stale banner, intensity blend (Wave 3)
- [ ] 03-04-PLAN.md — CleaningLabView: full UI + MixingStationView Denoise toolbar integration + human verification checkpoint (Wave 4)

### Phase 4: LUFS Normalization + Export Polish
**Goal**: Exported files meet podcast loudness standards and the export completion experience feels professional — users can normalize to -16 LUFS and share or save the output file with a single tap.
**Depends on**: Phase 3
**Requirements**: EXP-03
**Success Criteria** (what must be TRUE):
  1. User can enable LUFS normalization before export and the exported file measures -16 LUFS when analyzed in an external tool.
  2. Export completion presents a share/save sheet so the user can send the file to Files, AirDrop, or another app without leaving SonicMerge.
**Plans**: 5 plans

Plans:
- [ ] 04-01-PLAN.md — Wave 0: test stubs (LUFSNormalizationServiceTests), MixingStationViewModelTests additions, stereo_-24lufs_48000.wav fixture (Wave 1)
- [ ] 04-02-PLAN.md — LUFSNormalizationService actor (BS.1770-3 K-weighting, gainScalar), ExportOptions struct, AudioMergerService LUFS gain integration (Wave 2, TDD)
- [ ] 04-03-PLAN.md — MixingStation UI wiring: ExportFormatSheet toggle, ExportProgressSheet dynamic title, MixingStationViewModel.exportMerged(options:), ActivityViewController state reset (Wave 3)
- [ ] 04-04-PLAN.md — CleaningLabView export path polish: ExportOptions threading, ActivityViewController wrapper, state reset on dismiss (Wave 4)
- [ ] 04-05-PLAN.md — Full test suite validation + human verification checkpoint (Wave 5)

### Phase 5: Share Extension
**Goal**: Users can send audio files from Voice Memos, Files, or any app to SonicMerge via the iOS Share Sheet, and those files appear as clips ready for editing in the Mixing Station.
**Depends on**: Phase 1, Phase 2
**Requirements**: IMP-02
**Success Criteria** (what must be TRUE):
  1. User can select an audio file in another app, tap Share, choose SonicMerge, and the file appears as a clip in the Mixing Station timeline.
  2. Sharing a 30 MB+ audio file from Files does not crash the Share Extension.
  3. If the user taps Share twice for the same file, only one copy of the clip is added to the timeline (no duplicates).
**Plans**: 2 plans

Plans:
- [x] 05-01-PLAN.md — Main app wiring: duplicate detection in importFiles, scenePhase pending import handler, URL scheme registration, tests (Wave 1)
- [x] 05-02-PLAN.md — Share Extension target: ShareExtensionViewController, HUD UI, Info.plist, entitlements, Xcode project wiring + human verification (Wave 2)

---

## Milestone v1.1 — Modern Spatial Utility Restyle

### Phase 6: Design System Foundation
**Goal**: Every screen in the app has access to a centralized color token system, reusable SquircleCard and PillButton components, and a glassmorphism header — the visual language that all v1.1 restyling phases consume.
**Depends on**: Phase 5 (v1.0 complete)
**Requirements**: DS-01, DS-02, DS-03, DS-04
**Success Criteria** (what must be TRUE):
  1. Switching the device to dark mode shows pure black backgrounds with Deep Indigo accents; switching to light mode shows off-white backgrounds with Deep Indigo accents — across all screens.
  2. A SquircleCard component renders with a continuous 24pt corner radius and optional glass material background visible in both light and dark modes.
  3. A PillButton renders with an inner glow highlight, fires a distinct haptic tap on press, and shows a visually distinct disabled state.
  4. The app header displays the "Private by Design" banner with a Deep Indigo glow accent rendered through an ultraThinMaterial blur layer.
**Plans**: 2 plans

Plans:
- [x] 06-01-PLAN.md — Color token migration: v1.1 palette hex values, 4 new semantic slots, Radius.card 24pt, Spacing enum, tests (Wave 1)
- [x] 06-02-PLAN.md — Components: SquircleCard, PillButtonStyle, glassmorphism header restyle + human verification (Wave 2)

### Phase 7: Mixing Station Restyle
**Goal**: The Mixing Station uses the Vertical Timeline Hybrid layout with a central connecting line, all audio cards are SquircleCards with mesh gradient waveforms, gap controls use pill buttons, and drag interactions show elevated shadow micro-animations.
**Depends on**: Phase 6
**Requirements**: MIX-01, MIX-02, MIX-03, MIX-04, MIX-05
**Success Criteria** (what must be TRUE):
  1. Audio clip cards display as squircle cards (24pt radius) with a Deep Indigo-to-Purple gradient waveform overlay visible in both light and dark modes.
  2. The clip list renders a visible central connecting line running through all cards in the Vertical Timeline Hybrid layout.
  3. Waveform thumbnails use MeshGradient on iOS 18 devices and fall back to a LinearGradient on iOS 17 without visual breakage.
  4. Gap row controls between clips render as pill buttons using design system tokens.
  5. Dragging an audio card produces a visible scale-up and elevated shadow animation for the duration of the drag gesture.
**Plans**: 5 plans

Plans:
- [x] 07-01-PLAN.md — Foundation: accentGradientEnd token, TimelineSpineView primitive, PillButtonStyle Variant/Size extension (Wave 1)
- [ ] 07-02-PLAN.md — MergeSlotRow: SquircleCard wrap, masked mesh gradient waveform, icon-pill play button, drag micro-animation (Wave 2)
- [x] 07-03-PLAN.md — GapRowView: HStack of 4 PillButtonStyle compact pills with filled/outline selection (Wave 2)
- [ ] 07-04-PLAN.md — MergeTimelineView: spine background on clip rows, opaque operator chips, SquircleCard output card, typography migration (Wave 3)
- [ ] 07-05-PLAN.md — Human verification checkpoint: all 5 MIX success criteria + reorder crash drill + accessibility smoke test (Wave 4)
**UI hint**: yes

### Phase 8: Cleaning Lab + AI Orb
**Goal**: The Cleaning Lab shows a pulsating nebula sphere AI Orb during denoising, all controls use Lime Green AI highlights and PillButton style, and the full screen supports dark mode with correct contrast.
**Depends on**: Phase 7
**Requirements**: CL-01, CL-02, CL-03
**Success Criteria** (what must be TRUE):
  1. While denoising is active, a pulsating nebula sphere animation (TimelineView + Canvas) fills the AI Orb area; on devices with reduceMotion enabled, a static sphere renders instead.
  2. The denoising progress indicator, noise slider, and action buttons use Lime Green (#A7C957) as their accent color.
  3. All Cleaning Lab interactive controls render as pill buttons and show correct dark mode styling (pure black background, Deep Indigo accents) without any hardcoded light-mode colors.
**Plans**: TBD
**UI hint**: yes

### Phase 9: Polish + Accessibility Audit
**Goal**: Every interactive button in the app provides haptic feedback, dark mode is complete and contrast-correct across all screens, and users with reduceTransparency or reduceMotion enabled receive solid-background and static-visual fallbacks throughout.
**Depends on**: Phase 8
**Requirements**: POL-01, POL-02, POL-03
**Success Criteria** (what must be TRUE):
  1. Tapping any interactive button anywhere in the app produces a haptic response via the sensoryFeedback modifier.
  2. Dark mode is enabled on a physical device and all screens show pure black backgrounds with no residual white or grey card backgrounds.
  3. With Accessibility > Increase Contrast + Reduce Transparency enabled, all glass/blur surfaces are replaced by solid opaque backgrounds, and all text passes a 4.5:1 contrast ratio check.
  4. With Accessibility > Reduce Motion enabled, all animated visuals (AI Orb, drag micro-animations, gradient transitions) are replaced by static equivalents with no crash or missing UI.
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
v1.0 phases execute in numeric order: 1 → 2 → 3 → 4 → 5
v1.1 phases execute in numeric order: 6 → 7 → 8 → 9

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation + Import Pipeline | 4/4 | Complete   | 2026-03-10 |
| 2. Merge Pipeline + Mixing Station UI | 1/5 | In Progress|  |
| 3. AI Denoising Pipeline | 4/4 | Complete   | 2026-03-12 |
| 4. LUFS Normalization + Export Polish | 5/5 | Complete   | 2026-03-28 |
| 5. Share Extension | 2/2 | Complete   | 2026-04-08 |
| 6. Design System Foundation | 2/2 | Complete   | 2026-04-11 |
| 7. Mixing Station Restyle | 0/TBD | Not started | — |
| 8. Cleaning Lab + AI Orb | 0/TBD | Not started | — |
| 9. Polish + Accessibility Audit | 0/TBD | Not started | — |
