# SonicMerge - Pro Audio Joiner & AI Denoiser

## 1. Project Overview

**SonicMerge** is a clean, professional iOS utility designed to merge multiple voice memos and apply local, AI-driven noise reduction.

The app features a **"Minimalist Soft Professional"** aesthetic, prioritizing:

- Clarity
- Ease of use
- Native iOS experience

---

## 2. Technical Stack

| Component             | Technology                                                    |
| --------------------- | ------------------------------------------------------------- |
| Language              | Swift 6 / SwiftUI                                             |
| Audio Engine          | AVFoundation (`AVMutableComposition`, `AVAssetExportSession`) |
| DSP / Noise Reduction | `AVAudioEngine` (Voice Processing API) or Core ML             |
| Architecture          | MVVM (Model-View-ViewModel)                                   |
| Persistence           | FileSystem (Temporary directory processing)                   |

---

## 3. Core Features & Functional Requirements

### F1: System Integration (Share Extension)

Allow users to send audio files directly from other apps.

**Supported formats**

- `.m4a`
- `.wav`
- `.aac`

**Capabilities**

- Accept multiple files via **iOS Share Sheet**
- Automatically handle **security-scoped bookmarks** for shared files

---

### F2: Non-Destructive Audio Merging

#### Drag & Drop Timeline

Users can reorder clips via a **vertical timeline**.

#### Smart Gaps

Insert silent intervals between clips:

- `0.5s`
- `1.0s`
- `2.0s`

#### Crossfade

Smooth transitions between segments using volume fading.

---

### F3: AI-Powered Denoising (Local)

Audio cleaning runs **entirely on-device**.

#### Voice Isolation

Remove background noise using local processing.

Possible implementations:

- `AVAudioEngine VoiceProcessing`
- Core ML noise suppression model

#### Intensity Slider

Adjust noise suppression level:

```
0% ──────────────────── 100%
```

#### Real-Time A/B Testing

Feature:

**"Hold to Listen Original"**

User presses and holds to temporarily hear the **original audio**.

---

### F4: Pro Export

#### Loudness Normalization

Balance volume levels across merged segments using **LUFS normalization**.

#### Export Formats

Supported output:

- High quality `.m4a`
- Lossless `.wav`

---

## 4. UI/UX Architecture (Minimalist Soft Professional)

### Theme Configuration

| Element            | Color     | Purpose           |
| ------------------ | --------- | ----------------- |
| Primary Background | `#F8F9FA` | Clean airy canvas |
| Accent Color       | `#007AFF` | Primary actions   |
| Secondary Accent   | `#5856D6` | AI features       |
| Card Background    | `#FFFFFF` | Clean UI cards    |
| Text Color         | `#1C1C1E` | High readability  |

Additional styles:

- **Corner Radius:** 2pt
- **Shadow:** subtle soft shadow
- **Font:** San Francisco (System Dynamic)

---

### Screen A: Mixing Station (MainView)

#### Header

Minimalist navigation bar

Actions:

[ Export ]

---

#### Audio List Layout

Design:

- White cards
- Off-white background

Each card includes:

- Subtle **blue waveform preview**
- Timestamp
- Secondary grey metadata text

---

#### Interactions

Swipe actions:

- **Swipe left** → Delete clip
- **Long press** → Reorder clips

---

#### Audio Comparison

Toggle between:

- **Before**
- **After**

Using **haptic feedback**.

---

## 5. Logic & Implementation Details

### Audio Composition Logic

Pseudo workflow:

```swift
// 1. Create composition
let composition = AVMutableComposition()
let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)

// 2. Insert each audio segment
for segment in audioSegments {
    try track?.insertTimeRange(segment.timeRange, of: segment.asset.tracks(withMediaType: .audio)[0], at: currentTime)
    currentTime = CMTimeAdd(currentTime, segment.duration)
    // Add gap if needed
    currentTime = CMTimeAdd(currentTime, gapDuration)
}

// 3. Export
let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A)
exporter?.outputURL = outputURL
exporter?.outputFileType = .m4a
await exporter?.export()
```

### Denoising Logic

Use `AVAudioEngine` voice processing.

Concept workflow:

```
Audio File
    ↓
AVAudioEngine
    ↓
Voice Processing Enabled
    ↓
Processed PCM Buffers
    ↓
Write to new AVAudioFile
```

Key APIs:

```swift
inputNode.setVoiceProcessingEnabled(true)
AVAudioSinkNode
AVAudioFile
```

---

## 6. Directory Structure

```
/SonicMerge
├── /App
│   └── SonicMergeApp.swift
│
├── /Features
│   ├── /Merging
│   │   ├── AudioMergerService.swift
│   │   ├── MixingStationView.swift
│   │   └── AudioCardComponent.swift
│   │
│   └── /Denoising
│       ├── NoiseReductionService.swift
│       └── CleaningLabView.swift
│
├── /Models
│   └── AudioSegment.swift
│
├── /Extensions
│   ├── CMTime+Ext.swift
│   └── Color+Theme.swift
│
├── /Resources
│   └── Assets.xcassets
│
└── /ShareExtension
    ├── ShareViewController.swift
    └── Info.plist
```

---

## 7. Implementation Roadmap

### Phase 1: Core Audio Engine

**Focus:** Audio merging foundation

- [ ] Implement `AudioMergerService`
- [ ] Set up `AVMutableComposition` pipeline
- [ ] Build export functionality (`.m4a`, `.wav`)
- [ ] Add gap insertion logic

### Phase 2: Main UI

**Focus:** Mixing Station interface

- [ ] Design `MixingStationView`
- [ ] Implement timeline UI with vertical layout
- [ ] Add drag-to-reorder functionality
- [ ] Create `AudioCardComponent` with waveform preview

### Phase 3: Share Extension

**Focus:** System integration

- [ ] Build Share Extension target
- [ ] Accept multiple audio files
- [ ] Handle security-scoped bookmarks
- [ ] Pass files to main app

### Phase 4: AI Denoising

**Focus:** Local noise reduction

- [ ] Implement `NoiseReductionService`
- [ ] Integrate `AVAudioEngine` voice processing
- [ ] Add intensity slider control
- [ ] Build A/B comparison ("Hold to Listen Original")

### Phase 5: Polish & Release

**Focus:** Production readiness

- [ ] LUFS loudness normalization
- [ ] Crossfade transitions
- [ ] Haptic feedback integration
- [ ] Performance optimization
- [ ] App Store assets & submission

---

## 8. Testing Strategy

| Test Type   | Coverage                                              |
| ----------- | ----------------------------------------------------- |
| Unit Tests  | `AudioMergerService`, `NoiseReductionService`, Models |
| UI Tests    | Navigation, drag-reorder, export flow                 |
| Integration | Share Extension → Main App handoff                    |
| Performance | Large file merging, memory usage                      |

---

## 9. Dependencies

| Package                | Purpose                          |
| ---------------------- | -------------------------------- |
| AVFoundation           | Audio composition & export       |
| AVFAudio               | Audio engine & voice processing  |
| UniformTypeIdentifiers | File type handling               |
| CoreML (optional)      | Advanced noise suppression model |

---

## 10. App Store Metadata

**Category:** Utilities / Music

**Keywords:** audio merger, voice memo, noise reduction, audio joiner, denoise, podcast editor

**Target Audience:** Content creators, podcasters, students, professionals

**Minimum iOS Version:** iOS 17.0+
