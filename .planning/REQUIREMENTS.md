# Requirements: SonicMerge

**Defined:** 2026-03-08
**Core Value:** Users can merge audio clips and remove background noise in seconds — all on-device, with no quality loss and no privacy concerns.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Import

- [x] **IMP-01**: User can import multiple audio files in a single document picker session (multi-select)
- [x] **IMP-02**: User can receive audio files (.m4a, .wav, .aac) via iOS Share Sheet from other apps
- [x] **IMP-03**: App normalizes all imported audio to a canonical format (sample rate, channel layout) on import to prevent silent composition corruption
- [x] **IMP-04**: Each imported clip displays a waveform preview thumbnail on its audio card

### Merge & Editing

- [x] **MRG-01**: User can reorder clips via drag-and-drop in a vertical timeline
- [x] **MRG-02**: User can delete a clip via swipe-left gesture
- [x] **MRG-03**: User can insert a silent gap between clips (0.5s, 1.0s, or 2.0s)
- [x] **MRG-04**: User can apply a crossfade transition between adjacent segments

### AI Denoising

- [x] **DNS-01**: User can apply on-device noise reduction to merged audio using a Core ML model (not AVAudioEngine Voice Processing — see PITFALLS.md)
- [x] **DNS-02**: User can adjust noise suppression intensity via a 0–100% slider
- [x] **DNS-03**: User can hold a "Listen Original" button to temporarily hear the unprocessed audio for A/B comparison

### Export

- [x] **EXP-01**: User can export merged audio as high-quality .m4a
- [x] **EXP-02**: User can export merged audio as lossless .wav
- [x] **EXP-03**: User can apply LUFS loudness normalization (-16 LUFS podcast standard) before export
- [x] **EXP-04**: User can see export progress and cancel an in-progress export

### UI / UX

- [x] **UX-01**: App applies "Minimalist Soft Professional" theme throughout (background #F8F9FA, accent #007AFF, AI accent #5856D6, card #FFFFFF, text #1C1C1E; corner radius 2pt; SF font)
- [x] **UX-02**: User receives haptic feedback when toggling Before/After comparison

## v1.1 Requirements

Requirements for v1.1 "Modern Spatial Utility Restyle". Visual-only milestone — no functional changes to ViewModels or services.

### Design System

- [x] **DS-01**: App uses a centralized color token system with distinct light mode (off-white #FBFBFC, Deep Indigo #5856D6) and dark mode (pure black #000000, Deep Indigo #5856D6, Lime Green #A7C957) palettes
- [x] **DS-02**: Reusable SquircleCard component with continuous 24pt corner radius, optional glass material background, and configurable glow shadow
- [x] **DS-03**: PillButton ButtonStyle with inner glow highlight, haptic press feedback via sensoryFeedback, and proper disabled state styling
- [x] **DS-04**: Glassmorphism header using .ultraThinMaterial with "Private by Design" banner text and Deep Indigo glow accent

### Mixing Station

- [x] **MIX-01**: Audio clip cards use SquircleCard with gradient waveform overlay (Deep Indigo → Purple) and elevated drag shadow on interaction
- [x] **MIX-02**: Mixing Station uses Vertical Timeline Hybrid layout with a central connecting line between audio cards
- [x] **MIX-03**: Waveform thumbnails render with mesh gradient (iOS 18 MeshGradient with LinearGradient fallback for iOS 17)
- [x] **MIX-04**: Gap row controls are restyled with pill buttons and design system tokens
- [x] **MIX-05**: Dragging an audio card shows elevated shadow and scale micro-interaction animation

### Cleaning Lab

- [x] **CL-01**: AI Orb visualizer displays a pulsating nebula sphere animation (TimelineView + Canvas) during denoising, with reduceMotion static fallback
- [x] **CL-02**: AI-specific controls use Lime Green (#A7C957) accent color for denoise progress, slider, and action indicators
- [x] **CL-03**: All Cleaning Lab controls use PillButton style and design system color tokens for full dark mode support

### Polish

- [x] **POL-01**: All interactive buttons throughout the app provide haptic feedback via sensoryFeedback modifier
- [x] **POL-02**: Full dark mode support across all screens: pure black background, Deep Indigo accent, proper contrast ratios
- [x] **POL-03**: Accessibility fallbacks: solid backgrounds when reduceTransparency is on, static visuals when reduceMotion is on, minimum 4.5:1 text contrast on all glass surfaces

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
| Functional ViewModel/service changes | v1.1 is visual-only restyle; no business logic changes |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| IMP-01 | Phase 1 | Complete |
| IMP-02 | Phase 5 | Complete |
| IMP-03 | Phase 1 | Complete |
| IMP-04 | Phase 2 | Complete |
| MRG-01 | Phase 2 | Complete |
| MRG-02 | Phase 2 | Complete |
| MRG-03 | Phase 2 | Complete |
| MRG-04 | Phase 2 | Complete |
| DNS-01 | Phase 3 | Complete |
| DNS-02 | Phase 3 | Complete |
| DNS-03 | Phase 3 | Complete |
| EXP-01 | Phase 2 | Complete |
| EXP-02 | Phase 2 | Complete |
| EXP-03 | Phase 4 | Complete |
| EXP-04 | Phase 2 | Complete |
| UX-01 | Phase 2 | Complete |
| UX-02 | Phase 3 | Complete |
| DS-01 | Phase 6 | Complete |
| DS-02 | Phase 6 | Complete |
| DS-03 | Phase 6 | Complete |
| DS-04 | Phase 6 | Complete |
| MIX-01 | Phase 7 | Complete |
| MIX-02 | Phase 7 | Complete |
| MIX-03 | Phase 7 | Complete |
| MIX-04 | Phase 7 | Complete |
| MIX-05 | Phase 7 | Complete |
| CL-01 | Phase 8 | Complete |
| CL-02 | Phase 8 | Complete |
| CL-03 | Phase 8 | Complete |
| POL-01 | Phase 9 | Complete |
| POL-02 | Phase 9 | Complete |
| POL-03 | Phase 9 | Complete |

**Coverage:**
- v1 requirements: 17 total, 17 mapped (Complete)
- v1.1 requirements: 13 total, 13 mapped (Complete)
- Unmapped: 0

---
*Requirements defined: 2026-03-08*
*Last updated: 2026-04-11 — v1.1 traceability mapped to Phases 6–9*
