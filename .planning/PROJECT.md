# SonicMerge

## What This Is

SonicMerge is a clean, professional iOS utility for merging multiple audio files and applying local, AI-driven noise reduction. It targets content creators, podcasters, and professionals who need to combine voice memos and clean them up — entirely on-device, no cloud required. The aesthetic is "Minimalist Soft Professional": clarity, ease of use, native iOS experience.

## Core Value

Users can merge audio clips and remove background noise in seconds — all on-device, with no quality loss and no privacy concerns.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] User can import audio files via iOS Share Sheet (.m4a, .wav, .aac)
- [ ] User can reorder clips via drag-and-drop vertical timeline
- [ ] User can insert silent gaps between clips (0.5s, 1.0s, 2.0s)
- [ ] User can apply crossfade transitions between segments
- [ ] User can apply on-device AI noise reduction to merged audio
- [ ] User can adjust noise suppression intensity via slider (0–100%)
- [ ] User can A/B compare original vs denoised audio ("Hold to Listen Original")
- [ ] User can export merged audio as high-quality .m4a or lossless .wav
- [ ] User can normalize loudness via LUFS normalization before export
- [ ] User can delete and reorder clips via swipe/long-press gestures
- [ ] User can toggle Before/After comparison with haptic feedback

### Out of Scope

- Cloud processing — on-device only, privacy-first
- Real-time recording — import-only workflow for v1
- Video files — audio-only scope
- Android / cross-platform — iOS-only

## Context

### Technical Environment

- **Language:** Swift 6 / SwiftUI
- **Audio Engine:** AVFoundation (`AVMutableComposition`, `AVAssetExportSession`)
- **DSP / Noise Reduction:** `AVAudioEngine` with Voice Processing API (primary); Core ML noise suppression model (optional/fallback)
- **Architecture:** MVVM (Model-View-ViewModel)
- **Persistence:** FileSystem (Temporary directory processing)
- **Minimum iOS Version:** iOS 17.0+

### Audio Composition Pipeline

```swift
// 1. Create composition
let composition = AVMutableComposition()
let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)

// 2. Insert each audio segment
for segment in audioSegments {
    try track?.insertTimeRange(segment.timeRange, of: segment.asset.tracks(withMediaType: .audio)[0], at: currentTime)
    currentTime = CMTimeAdd(currentTime, segment.duration)
    currentTime = CMTimeAdd(currentTime, gapDuration) // Add gap if needed
}

// 3. Export
let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A)
```

### Denoising Pipeline

```
Audio File → AVAudioEngine → Voice Processing Enabled → Processed PCM Buffers → Write to new AVAudioFile
```

Key APIs: `inputNode.setVoiceProcessingEnabled(true)`, `AVAudioSinkNode`, `AVAudioFile`

### Directory Structure

```
/SonicMerge
├── /App
│   └── SonicMergeApp.swift
├── /Features
│   ├── /Merging
│   │   ├── AudioMergerService.swift
│   │   ├── MixingStationView.swift
│   │   └── AudioCardComponent.swift
│   └── /Denoising
│       ├── NoiseReductionService.swift
│       └── CleaningLabView.swift
├── /Models
│   └── AudioSegment.swift
├── /Extensions
│   ├── CMTime+Ext.swift
│   └── Color+Theme.swift
├── /Resources
│   └── Assets.xcassets
└── /ShareExtension
    ├── ShareViewController.swift
    └── Info.plist
```

## UI/UX Architecture — Minimalist Soft Professional

### Theme

| Element            | Color     | Purpose           |
|--------------------|-----------|-------------------|
| Primary Background | `#F8F9FA` | Clean airy canvas |
| Accent Color       | `#007AFF` | Primary actions   |
| Secondary Accent   | `#5856D6` | AI features       |
| Card Background    | `#FFFFFF` | Clean UI cards    |
| Text Color         | `#1C1C1E` | High readability  |

- **Corner Radius:** 2pt
- **Shadow:** Subtle soft shadow
- **Font:** San Francisco (System Dynamic)

### Screen A: Mixing Station (MainView)

**Header:** Minimalist navigation bar with `[ Export ]` action

**Audio List:**
- White cards on off-white background
- Each card: subtle blue waveform preview, timestamp, secondary grey metadata text

**Interactions:**
- Swipe left → Delete clip
- Long press → Reorder clips
- Toggle: Before / After comparison with haptic feedback

### App Store Metadata

- **Category:** Utilities / Music
- **Keywords:** audio merger, voice memo, noise reduction, audio joiner, denoise, podcast editor
- **Target Audience:** Content creators, podcasters, students, professionals

## Constraints

- **Platform:** iOS only — Swift 6 + SwiftUI, no cross-platform frameworks
- **Processing:** On-device only — no network calls for audio processing
- **iOS Version:** iOS 17.0+ minimum — required for latest AVAudioEngine APIs
- **Dependencies:** Native Apple frameworks only (AVFoundation, AVFAudio, UniformTypeIdentifiers, CoreML optional)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| AVAudioEngine Voice Processing over Core ML | Native API, no model file to ship, lower complexity | — Pending |
| MVVM architecture | Standard SwiftUI pattern, clean separation for audio services | — Pending |
| FileSystem (temp directory) for persistence | No database needed for audio processing workflow | — Pending |
| iOS 17.0+ minimum | Latest AVAudioEngine APIs and SwiftUI features | — Pending |
| On-device only processing | Privacy-first, no server costs, offline capable | — Pending |

---
*Last updated: 2026-03-08 after initialization*
