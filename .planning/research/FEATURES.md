# Feature Research

**Domain:** iOS Audio Merger + AI Denoiser Utility
**Researched:** 2026-03-08
**Confidence:** MEDIUM-HIGH (verified against App Store competitors, Apple developer docs, and user review analysis)

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features that users assume exist in any serious audio editing app. Missing these makes the product feel broken or incomplete — users will leave and not leave a review.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Multi-file import (batch select) | Users discovered the #1 complaint in competitor apps (Audio Joiner, Music Joiner) is single-file-at-a-time import. Selecting files one by one kills the workflow. | LOW | Use `UIDocumentPickerViewController` with `allowsMultipleSelection: true`. Share Sheet extension covers the inbound flow. |
| Drag-and-drop reorder | Standard iOS interaction pattern since iOS 11. Every audio editor (Ferrite, Hokusai, SoundLab) provides this. Absence feels like a missing basic. | MEDIUM | SwiftUI `List` with `.onMove` modifier. Haptic feedback on lift/drop. |
| Swipe-to-delete | Universal iOS list interaction. Users expect it for clip management. | LOW | SwiftUI `.onDelete` modifier on `List`. |
| Playback preview per clip | Users must be able to hear a clip before committing it to the merge. | LOW | `AVPlayer` or `AVAudioPlayer` per `AudioSegment`. |
| Full merged preview playback | Users expect to hear the result before exporting. | MEDIUM | Play back the `AVMutableComposition` before export using `AVPlayerItem`. |
| Export to .m4a | The universal iOS audio export format. Not having it is a blocker. | LOW | `AVAssetExportSession` with `AVAssetExportPresetAppleM4A`. Already in pipeline. |
| Export to .wav / lossless | Power users (podcasters, content creators) require lossless. Absence is a one-star review trigger. | LOW | `AVAssetExportPresetPassthrough` or custom `AVAudioFile` write with PCM format. |
| Waveform visualization per clip | Every competitor (Ferrite, SoundLab, TwistedWave) shows waveforms. A plain list with no waveform looks cheap and makes it impossible to identify clips visually. | MEDIUM | Use `DSWaveformImage` library or render via `AVAssetImageGenerator` + custom Core Graphics drawing. Render once on import, cache. |
| Silence gap insertion | Standard in any voice memo workflow — users pause between thoughts and need to clean up or add breathing room. | LOW | Handled by `CMTime` gap insertion in `AVMutableComposition`. Provide 0.5s / 1.0s / 2.0s presets as PROJECT.md specifies. |
| Share / save output | After export, users expect to share via AirDrop, save to Files app, or open in another app. The iOS share sheet is mandatory. | LOW | `UIActivityViewController` with the exported file URL. |
| Undo / re-add clips | Users make mistakes. No undo = frustration and 1-star reviews. | MEDIUM | Maintain an `[AudioSegment]` stack in ViewModel. Simple array mutation with SwiftUI state propagation. |
| iOS Files app import | Users store audio in iCloud Drive, Dropbox (via Files), and on-device. Files integration is expected. | LOW | `UTType.audio` in document picker. Already covered by Share Sheet extension. |

---

### Differentiators (Competitive Advantage)

Features that most simple audio merger apps do NOT have, and that directly serve SonicMerge's "Minimalist Soft Professional" positioning and on-device AI angle.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| On-device AI noise reduction | Privacy-first positioning is a real market advantage in 2025-2026. 94% of users report that Privacy Nutrition Labels influence download decisions. No competitor in the simple audio merger category offers this. | HIGH | `AVAudioEngine` + `inputNode.setVoiceProcessingEnabled(true)` for Voice Processing API path. Core ML fallback for non-voice audio. This is the primary differentiator. |
| Before/After A/B toggle with haptics | No simple merger app offers instant A/B comparison. Power users (podcasters, creators) need to validate denoising quality before committing. The haptic feedback makes it feel premium and native. | MEDIUM | Swap `AVPlayerItem` on toggle. Use `UIImpactFeedbackGenerator(.medium)` on toggle — prefer `AudioServicesPlaySystemSound` if AVAudioSession routing causes haptic delivery failures. |
| Adjustable noise suppression slider (0–100%) | Competitors offer binary on/off noise reduction. A continuous slider gives professional control and lets users tune for voice vs ambient content. | MEDIUM | Map slider 0.0–1.0 to Voice Processing mode intensity, or apply gain scaling on processed buffer amplitude. |
| LUFS loudness normalization before export | Podcasters targeting platforms (Apple Podcasts = -16 LUFS, Spotify = -14 LUFS) need this. No simple merger app offers it. Differentiates from toy apps. | MEDIUM | Use `AVAudioMixInputParameters` with volume automation or post-process via `AVAudioUnitEQ` + custom gain calculation. Target: -16 LUFS (Apple/podcast standard). |
| Crossfade transitions between clips | Smooth transitions vs hard cuts. Expected in any "professional" output. Competitors like Ferrite offer it; simple merger apps do not. | MEDIUM | Overlap time ranges in `AVMutableCompositionTrack` insertions and use `AVAudioMixInputParameters` with `setVolumeRamp` to create the fade curve. |
| Clean "Minimalist Soft Professional" UI | The iOS audio merger market is dominated by cluttered, ad-heavy, or dated-looking apps. A polished SwiftUI interface with clear visual hierarchy is itself a differentiator. | MEDIUM | Already defined in PROJECT.md: `#F8F9FA` background, white cards, `#007AFF` accent, subtle shadows. San Francisco system font. |
| Zero network calls / full offline | Privacy Nutrition Label shows "No data collected." This is visible in App Store and influences downloads. Krisp (a competitor) still sends transcription data to the cloud; SonicMerge does not. | LOW | Architecture constraint already in PROJECT.md. Enforce in code by never importing `Foundation.URLSession` in audio processing paths. |
| Share Sheet extension (inbound) | Many iOS users live in Voice Memos or Files app. A Share Extension that lets them push audio into SonicMerge without launching the app first dramatically reduces friction vs competitors that require in-app import. | MEDIUM | `NSExtension` + `ShareViewController.swift`. Already in directory structure. Handle `NSExtensionItem` with `kUTTypeAudio` attachment. |
| Clip duration display + metadata | Showing `[0:42 · m4a · 44.1kHz]` on each card helps users identify clips. Competitors show bare filenames. | LOW | Derive from `AVAsset.duration` and `AVAssetTrack` format descriptions at import time. |

---

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem like good ideas but would undermine SonicMerge's scope, stability, or positioning.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| In-app audio recording | Users want an all-in-one app. "Can I also record in it?" is a natural question. | Adds significant complexity (microphone permissions, recording session management, waveform monitoring during record), doubles the scope, and competes directly with Apple's own Voice Memos. Not the core value. | Keep import-only for v1. Users record in Voice Memos, then merge in SonicMerge. Share Sheet extension makes this frictionless. Re-evaluate in v2 only if user demand is validated. |
| Real-time noise cancellation during phone/VoIP calls | Krisp positions on this. Users may request it. | iOS restricts real-time call audio processing without CallKit integration, which adds significant complexity and requires special entitlements. Krisp's own iOS app does NOT support real-time call cancellation due to platform restrictions. | Focus on post-recording noise reduction, which is the validated use case for the target audience. |
| Cloud sync / backup of processed audio | Users might want iCloud auto-backup of their merged files. | Breaks the "no network calls" privacy guarantee that is a core differentiator. Adds backend complexity. | Export flow via `UIActivityViewController` naturally lets users save to Files/iCloud manually. "You choose where it goes" is actually a stronger privacy message. |
| Multi-track mixing / layering | Advanced users will ask for it — "can I put music under my voice?" | Full multi-track mixing is a different product category (GarageBand, Ferrite). Implementing it correctly requires a complete mixing graph with per-track volume/panning automation. Way out of scope. | Serial clip merging with crossfade is the right boundary for this product. Point users who need mixing to GarageBand. |
| Video file support | Some users have .mp4 with audio they want to extract. | Adds complexity (video processing pipeline, format handling, thumbnail extraction). Dilutes the "audio utility" positioning. | Out of scope per PROJECT.md. A future "extract audio from video" flow could be added as a separate screen in v2+ only. |
| Transcription / AI summaries | AI-adjacent — users may ask given the AI denoising angle. | Transcription requires either a large on-device model (significant bundle size, memory) or a cloud API (breaks privacy guarantee). Krisp and Whisper-based apps already own this niche. | Stay focused: noise reduction + merging. AI transcription is a different product. |
| Subscription monetization model | Maximizes revenue. | Audio utility apps with aggressive paywalls get destroyed in reviews. The competitor "Denoise" (Hits Apps) uses a reasonable one-time IAP model. Subscriptions feel punitive for a simple utility. | One-time in-app purchase to unlock AI denoising or export to lossless. Freemium with clear value gating is more defensible. |
| Undo history with unlimited steps | Developers love this; users rarely use it past 1-2 steps. | Maintaining a deep `AudioSegment` history array with full asset copies would be memory-intensive on iOS, especially for large files. | Maintain a lightweight ordered-array snapshot model for undo (just the `[AudioSegment]` order + metadata, not the audio data itself). Deep undo of actual processed audio is overkill for v1. |

---

## Feature Dependencies

```
[Share Sheet Extension (inbound)]
    └──requires──> [Multi-file import infrastructure]
                       └──requires──> [AudioSegment model]

[On-device AI noise reduction]
    └──requires──> [AVAudioEngine pipeline]
                       └──requires──> [AudioSegment model]
                       └──requires──> [Full merged preview playback]

[Before/After A/B toggle]
    └──requires──> [On-device AI noise reduction]
    └──requires──> [Full merged preview playback]

[LUFS loudness normalization]
    └──requires──> [Audio merge pipeline (AVMutableComposition)]
    └──enhances──> [Export to .m4a / .wav]

[Crossfade transitions]
    └──requires──> [Audio merge pipeline (AVMutableComposition)]
    └──enhances──> [Full merged preview playback]

[Waveform visualization]
    └──requires──> [AudioSegment model with loaded AVAsset]
    └──enhances──> [Drag-and-drop reorder] (visual clarity)

[Adjustable noise suppression slider]
    └──requires──> [On-device AI noise reduction]

[Clip duration display]
    └──requires──> [AudioSegment model with loaded AVAsset]

[Export (share output)]
    └──requires──> [Audio merge pipeline]
    └──optionally-requires──> [LUFS normalization]
    └──optionally-requires──> [On-device AI noise reduction]
```

### Dependency Notes

- **AI noise reduction requires the full AVAudioEngine pipeline:** The Voice Processing API requires a running audio engine with properly configured audio session. This is architecturally separate from the `AVMutableComposition` merge pipeline. Both pipelines must be stable before the A/B toggle can work.
- **LUFS normalization enhances export but is not a blocker:** The merge and export pipeline works without normalization. Add normalization as a post-processing step between composition export and final file write.
- **Waveform visualization requires loaded AVAsset:** Waveforms must be rendered asynchronously after import. Render on background queue, cache as `UIImage` or `CGImage` in the `AudioSegment` model. Do not block UI.
- **Crossfade conflicts with silence gap insertion at the same transition point:** A gap and a crossfade are mutually exclusive options for the same clip boundary. The UI should offer a per-boundary toggle: Gap | None | Crossfade.

---

## MVP Definition

### Launch With (v1)

Minimum viable product that validates the core proposition: merge + denoise, on-device, clean UI.

- [x] Multi-file import via Share Sheet and Files document picker — without batch import, the app is unusable for its primary use case
- [x] Drag-and-drop reorder of clips — fundamental to the merge workflow
- [x] Swipe-to-delete clips — basic list management, mandatory
- [x] Silence gap insertion (0.5s / 1.0s / 2.0s) — differentiates from simple concatenation
- [x] Crossfade transitions between clips — elevates output quality, part of "professional" positioning
- [x] Full merged preview playback — users must hear result before exporting
- [x] On-device AI noise reduction (AVAudioEngine Voice Processing) — the primary differentiator; without it SonicMerge is just another audio joiner
- [x] Adjustable noise suppression slider — makes the AI feature feel controllable, not magic-box
- [x] Before/After A/B toggle with haptic feedback — lets users validate denoising quality
- [x] LUFS loudness normalization (-16 LUFS default) — needed for podcasters and content creators
- [x] Export to .m4a and .wav — non-negotiable table stakes
- [x] Waveform visualization per clip — makes the app feel professional, not like a basic utility

### Add After Validation (v1.x)

Features to add once core workflow is stable and users have provided feedback.

- [ ] Clip trimming (set in/out points per clip) — high user value but adds significant UI complexity (waveform scrubber, time markers). Add when users report wanting to trim before merging.
- [ ] Multiple LUFS targets (-14, -16, -18, -23 LUFS) — add when podcasters specifically request platform-specific normalization targets.
- [ ] Batch processing mode (denoise all, then merge) — add when usage data shows users running the full pipeline repeatedly.
- [ ] iCloud document persistence (save session state) — add when users report losing work between sessions.
- [ ] Lock screen / Control Center widget for quick share-to-SonicMerge — add when engagement metrics show users import frequently from Voice Memos.

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] In-app audio recording — validate import-only workflow first; recording adds scope and competes with Voice Memos
- [ ] Clip trimming timeline editor — full timeline editor is a significant scope increase; v1 trims via silence gap insertion
- [ ] Video audio extraction — different use case, different user, different UX; defer until user demand is explicit
- [ ] Background audio enhancement (EQ presets: voice warmth, noise gate, presence boost) — natural extension of denoising, but requires audio DSP expertise beyond Voice Processing API
- [ ] Apple Watch companion (quick record → share to SonicMerge) — only after core iPhone workflow is validated

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Multi-file batch import | HIGH | LOW | P1 |
| Drag-and-drop reorder | HIGH | LOW | P1 |
| On-device AI noise reduction | HIGH | HIGH | P1 |
| Before/After A/B toggle | HIGH | MEDIUM | P1 |
| Export .m4a + .wav | HIGH | LOW | P1 |
| Full merged preview playback | HIGH | MEDIUM | P1 |
| Waveform visualization per clip | HIGH | MEDIUM | P1 |
| LUFS loudness normalization | MEDIUM | MEDIUM | P1 |
| Crossfade transitions | MEDIUM | MEDIUM | P1 |
| Adjustable noise suppression slider | MEDIUM | LOW | P1 |
| Silence gap insertion | MEDIUM | LOW | P1 |
| Share Sheet extension (inbound) | HIGH | MEDIUM | P1 |
| Clip duration + metadata display | MEDIUM | LOW | P1 |
| Swipe-to-delete | HIGH | LOW | P1 |
| Clip trimming (in/out points) | HIGH | HIGH | P2 |
| Multiple LUFS targets | MEDIUM | LOW | P2 |
| iCloud session persistence | MEDIUM | MEDIUM | P2 |
| EQ / audio enhancement presets | MEDIUM | HIGH | P3 |
| In-app recording | MEDIUM | HIGH | P3 |
| Video audio extraction | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

---

## Competitor Feature Analysis

| Feature | Merge Voice Memos (App Store) | Audio Joiner: Merge & Recorder | Ferrite Recording Studio | SonicMerge Approach |
|---------|-------------------------------|-------------------------------|--------------------------|---------------------|
| Multi-file batch import | Unknown (voice memos context) | NO — single file at a time (top complaint) | YES | YES — document picker with `allowsMultipleSelection` |
| Drag-and-drop reorder | YES | Unknown | YES | YES — SwiftUI List `.onMove` |
| Waveform visualization | NO (basic card UI) | NO | YES | YES — rendered per clip on import |
| AI noise reduction | NO | NO | NO (EQ/compression only) | YES — on-device Voice Processing API |
| Before/After A/B toggle | NO | NO | NO | YES — primary UX differentiator |
| LUFS normalization | NO | NO | Manual volume automation | YES — -16 LUFS default |
| Crossfade | NO | NO | YES | YES |
| Lossless export (.wav) | Unknown | YES (.wav listed) | YES | YES |
| On-device only (no cloud) | YES (local merge) | Unknown | YES | YES — explicit constraint |
| Share Sheet extension | YES (core feature) | NO | NO | YES — `ShareExtension` target |
| Noise suppression slider | NO | NO | NO | YES — 0–100% slider |
| iOS-native UI quality | MEDIUM | LOW | HIGH | HIGH — Minimalist Soft Professional |
| Price model | Free + IAP | Free (ad-supported likely) | Free + $29.99 one-time Pro | Free + one-time IAP (recommended) |

---

## Sources

- [Merge Voice Memos — App Store](https://apps.apple.com/us/app/merge-voice-memos/id6476123178) — competitor feature set, user reviews
- [Audio Joiner: Merge & Recorder — App Store](https://apps.apple.com/us/app/audio-joiner-merge-recorder/id1508456179) — user complaints, missing features
- [Music Joiner - Merge Audio — App Store](https://apps.apple.com/us/app/music-joiner-merge-audio/id1552589312) — format support baseline
- [Ferrite Recording Studio — App Store](https://apps.apple.com/us/app/ferrite-recording-studio/id1018780185) — professional iOS podcast editor, feature benchmark
- [SoundLab Audio Editor — App Store](https://apps.apple.com/us/app/soundlab-audio-editor/id1450417400) — on-device AI stems, waveform UX
- [TwistedWave Audio Editor — App Store](https://apps.apple.com/us/app/twistedwave-audio-editor/id401438496) — non-destructive editing, large file handling
- [Hokusai Audio Editor — App Store](https://apps.apple.com/gb/app/hokusai-audio-editor/id432079746) — multitrack iOS editor baseline
- [The 7 Best iPhone and iPad Podcast Editing Apps — Castos](https://castos.com/iphone-ipad-podcast-editing-apps/) — standard vs premium feature analysis
- [Top Podcast Editing Apps for Creators in 2025 — DemoDazzle](https://demodazzle.com/blog/podcast-editing-apps-2025) — Ferrite vs GarageBand positioning
- [Krisp AI Noise Cancellation](https://krisp.ai/) — iOS platform limitations for real-time noise cancellation confirmed
- [6 Best Noise Cancelling Apps in 2025 — Krisp Blog](https://krisp.ai/blog/best-noise-cancelling-app/) — competitor noise reduction landscape
- [Podcast Loudness Standard 2025 — Descript](https://www.descript.com/blog/article/podcast-loudness-standard-getting-the-right-volume) — LUFS targets per platform
- [Apple Privacy Nutrition Labels — App Store Developer Docs](https://developer.apple.com/app-store/app-privacy-details/) — privacy as download decision factor
- [2025 Guide to Haptics — Saropa Medium](https://saropa-contacts.medium.com/2025-guide-to-haptics-enhancing-mobile-ux-with-tactile-feedback-676dd5937774) — haptic feedback best practices
- [DSWaveformImage — GitHub](https://github.com/dmrschmidt/DSWaveformImage) — waveform rendering library for iOS/SwiftUI

---

*Feature research for: iOS Audio Merger + AI Denoiser (SonicMerge)*
*Researched: 2026-03-08*
