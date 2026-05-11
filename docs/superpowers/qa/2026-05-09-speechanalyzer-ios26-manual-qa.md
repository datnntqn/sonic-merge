# SpeechAnalyzer (iOS 26) — Manual QA Checklist

**Spec:** docs/superpowers/specs/2026-05-09-speechanalyzer-ios26-design.md
**Plan:** docs/superpowers/plans/2026-05-09-speechanalyzer-ios26.md
**Date:** 2026-05-10

> **Scope note:** the spec's "bilingual auto-detect" promise (LocalePicker
> "Auto-detect" row + FillerLibrary auto-locale union) was dropped during
> implementation: iOS 26's `SpeechTranscriber.init(locale:preset:)` requires
> a non-optional `Locale` — the SDK exposes no nil-locale / multi-locale
> auto-detect path. Per-locale transcription works as planned. See the
> SDK divergence section below.

Run on **iPhone 17 simulator** (iOS 26.2) AND a real iOS 17 device or
simulator where noted. Verify each row visually; the unit tests cover the
seam, not the end-to-end UX.

## Foreground analyze — iOS 26, English file

- [ ] Import a 60-second English clip (or use the `smart_cut_60s.wav` fixture).
- [ ] Tap Analyze.
- [ ] Live transcript pane appears collapsed below the progress bar.
- [ ] Expanding the disclosure shows growing English text within ~2s.
- [ ] Auto-scroll keeps the latest words visible without manual scrolling.
- [ ] Progress percentage advances smoothly (no stuck-at-0%).
- [ ] On completion, results page shows fillers detected.

## Foreground analyze — iOS 26, non-English file

- [ ] Open LocalePicker → pick Spanish (es-ES) or Portuguese (pt-BR).
- [ ] Import a clip in that language.
- [ ] Tap Analyze.
- [ ] Live transcript shows words in the selected language.
- [ ] Filler detection picks up locale-specific fillers (e.g., "este", "tipo").

## Background resume — iOS 26

- [ ] Start an analyze on a 5+ minute clip.
- [ ] Tap "Run in BG" (or background the app).
- [ ] Wait 2–3 minutes.
- [ ] System notification "Smart Cut finished" fires.
- [ ] Reopening the app shows the completed results.

## Cancel + resume — iOS 26

- [ ] Start an analyze.
- [ ] Tap Cancel mid-stream.
- [ ] State returns to .idle but partial transcript on disk is preserved.
- [ ] Tapping Analyze again resumes from the snapshot (transcript continues
      where it left off, not from t=0).

## iOS 17 regression check

- [ ] Build the app for iPhone 15 simulator (iOS 17), if available.
- [ ] Smart Cut analyze completes normally on an English clip.
- [ ] EditFillerListStudioSheet shows the "Better filler detection (cloud)"
      toggle (visible on iOS 17, hidden on iOS 26).
- [ ] No live transcript pane in the analyzing state (gated by
      `#available(iOS 26, *)`).
- [ ] Cloud toggle still works as before — flipping it does change the
      cache key namespace (`#cloud` vs `#local`).

## Live transcript pane — visual

- [ ] Disclosure starts collapsed.
- [ ] Header reads "Live transcript" with a waveform icon.
- [ ] Header color is `accentAI` (flat magenta), NOT `accentAction` (violet,
      reserved for chrome) and NOT the fire gradient (reserved for AI moments
      hosting a gradient like the orb itself).
- [ ] Expanded body shows callout-style text in `textPrimary`.
- [ ] Pane height caps at ~160 pt before scrolling.

## Spec assumptions

- [x] **2026-05-10:** Confirmed SpeechAnalyzer is on-device-only (no cloud
      variant). `EditFillerListStudioSheet` correctly hides the toggle on
      iOS 26.
- [x] **2026-05-10:** Confirmed `SFSpeechRecognizer.requestAuthorization`
      covers SpeechAnalyzer. `SmartCutViewModel.requestSpeechAuthorization`
      and `OnboardingFlow`'s permission seed remain unchanged.

## SDK divergence from spec

The plan's Chunk 3 placeholders did not match the iOS 26 Speech.framework
as shipped in Xcode 26.3 / iOS 26.2 SDK. Adapted as follows:

- `SpeechTranscriber.init(locale: nil)` for auto-detect — **does not exist.**
  `SpeechTranscriber.init(locale: Foundation.Locale, preset:)` requires a
  non-optional Locale. **Auto-detect dropped from scope** (spec's Component 6
  + 8 + Chunk 5 Task 5.1 + Chunk 6 are all no-ops). Only per-locale
  transcription is supported.
- `result.tokens[]` with `text/timestamp/duration/confidence` — **does not
  exist.** `SpeechTranscriber.Result` exposes `range: CMTimeRange`,
  `text: AttributedString` (with optional per-character `audioTimeRange` /
  `transcriptionConfidence` attributes via `AttributeScopes.SpeechAttributes`),
  and `alternatives: [AttributedString]`. Implementation uses `result.range`
  for segment timing and a constant 1.0 confidence (FillerDetector
  propagates confidence but doesn't gate on it).
- `analyzer.input.send(buffer)` + `analyzer.input.finish()` —  **doesn't
  match.** Used `SpeechAnalyzer.init(inputAudioFile: AVAudioFile, modules:,
  finishAfterFile: true)` instead, which bypasses the manual
  `AVAssetReader` + feeder loop.
- `result.isFinal` — **does not exist.** `SpeechTranscriber.Result` has no
  isFinal flag. Used `Preset.progressiveTranscription` which only emits
  finalized progress chunks (no `volatileResults` reporting option).

The protocol contract (`TranscriptionServicing.transcribe(input:) ->
AsyncThrowingStream<TranscriptionState>`) and the namespaced cache key
strategy (`<rawHash>#analyzer`) remain stable.
