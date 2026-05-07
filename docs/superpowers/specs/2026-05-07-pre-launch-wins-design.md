# Pre-Launch Wins — Transcript Surface + Privacy Hero Copy

**Date:** 2026-05-07
**Status:** Spec — implementation-ready
**Author:** Claude (autonomous mode, user-approved decisions)
**Source:** `docs/superpowers/research/2026-05-07-competitive-audit.md` §"Recommendations" items 1–2 (G-1, G-2)

## Summary

Two pre-launch wins identified in the competitive audit, bundled into one shipping initiative. (1) **Expose transcription as a top-level feature** — surface the transcript that already exists in memory (`SmartCutViewModel.cachedSegments`) so users can preview, copy, and export. Both Cleanvoice and Descript advertise transcription as a primary value prop; CleanCut already has it but buries it inside Smart Cut. (2) **Lead the paywall hero with the privacy moat** — add the line *"Your audio never leaves your phone."* above the existing "CleanCut Pro" headline, since neither competitor can truthfully say this.

The transcript work has two surfaces: a lightweight **toolbar-icon → sheet** for quick peeks (anywhere a Smart Cut session exists), and a **segmented "Edit / Transcript" toggle** inside the Smart Cut studio that swaps the studio body to a richer cuts-marked view. Both are gated by transcript availability (post-Analyze) and free for all users — the audit's marketing argument depends on free.

## Goals

1. **Make transcription a checkable feature** in App Store comparisons against Cleanvoice and Descript.
2. **Convert the privacy moat into a paywall hero claim** that can't be matched by cloud-based competitors.
3. **Preserve the FAIL=5 baseline** — no new flaky tests, existing 233-test suite stays green.
4. **Stay free** — no Pro gating on the transcript surfaces; the moat is "privacy + free transcription," diluting either side weakens the claim.

## Non-Goals

- **No transcript editing.** Users can preview, copy, and export — but can't mutate the transcript text. Editing is Descript's value prop, requires a re-build of the audio pipeline, and is off-strategy for v1.
- **No real-time/live transcription.** Files only, post-import. Live capture is a different feature.
- **No multi-language UI** for the transcript. Transcript text inherits the user's `SFSpeechRecognizer` locale; UI labels (Edit / Transcript / Copy) are English v1.
- **No diarization** (speaker labels). Single-speaker assumption per the existing Smart Cut model.
- **No `.docx` or `.pdf` export.** Plain text formats only (`.txt`, `.srt`, `.vtt`). PDF and Word are heavier dependencies and outside the cheap-win bracket.
- **No paywall A/B testing infrastructure.** The privacy line is a single-variant change; we'll measure conversion lift via App Store Connect aggregate data post-launch.

## Architecture

```
                                                       ┌──────────────────────────────────────┐
                                                       │ SmartCutViewModel                    │
                                                       │  · cachedSegments [RecognizedSegment]│
                                                       │  · editList.enabledCutRanges         │
                                                       └──────────┬───────────────────────────┘
                                                                  │ reads (segments + cuts)
                                                                  ▼
                  ┌─────────────────────────────────────────────────────────────┐
                  │ TranscriptExporter (pure helper, @MainActor)                │
                  │  · plainText(from:) -> String                               │
                  │  · srt(from:) -> String                                     │
                  │  · vtt(from:) -> String                                     │
                  │  · UIActivityViewController helper for share-sheet present  │
                  └────────┬────────────────────────────────────────────┬───────┘
                           │ used by                                    │ used by
                           ▼                                            ▼
       ┌──────────────────────────┐                  ┌──────────────────────────────────┐
       │ TranscriptSheet           │                  │ TranscriptCanvas                  │
       │ (B-layout: paragraphs +   │                  │ (C-layout: timestamps +           │
       │  timestamp markers)       │                  │  strikethrough fillers +          │
       │                           │                  │  pause markers + cut ranges)      │
       │ Presented from new        │                  │                                   │
       │ toolbar 📄 icon on        │                  │ Shown in Smart Cut studio when    │
       │ SmartCutSessionView       │                  │ segmented control is on Transcript│
       └───────────────────────────┘                  └──────────────────────────────────┘

       Both surfaces share TranscriptExportRow (Copy + .txt + .srt + .vtt chips).
```

### Key behaviors

**TranscriptSheet (G-1a):**
- Modal `.sheet` with detents `[.medium, .large]`.
- Header: title "Transcript" + `TranscriptExportRow` (Copy + 3 format chips).
- Body: paragraphed transcript with periodic `00:NN`-style timestamp blocks. Paragraph break = gap > 1.5s between segment endTime and next segment startTime, OR sentence-end punctuation in the segment text.
- Empty state when `cachedSegments.isEmpty`: "Run Analyze first to generate the transcript." with a hint to dismiss.

**TranscriptCanvas (G-1b):**
- Full-screen view that replaces the studio body when segmented control is on "Transcript" tab.
- Renders the same paragraphed format as TranscriptSheet, plus:
  - Words whose `startTime` falls within any `editList.enabledCutRanges` → strikethrough + 18% pink-red overlay (matches the existing red-ish "ember" tone, NOT burnt orange brand chrome).
  - Pause segments that ARE cut → inline `pause-marker` chip showing duration ("2.1s").
  - Pause segments NOT cut → no marker.
- Bottom-sticky `TranscriptExportRow`.

**TranscriptExportRow:**
- 4 chips: `📋 Copy` · `.txt` · `.srt` · `.vtt`.
- Copy → `UIPasteboard.general.string = TranscriptExporter.plainText(from: segments)`.
- `.txt` / `.srt` / `.vtt` → write file to temp dir, present `UIActivityViewController` for Share / Save to Files / Mail.
- All four actions independent of state — work whenever `cachedSegments` is non-empty.

**TranscriptExporter format rules:**
- `.txt`: paragraphs separated by `\n\n`, no timestamps.
- `.srt`: standard SubRip format (`1\n00:00:00,000 --> 00:00:02,500\nText\n\n`). Each `RecognizedSegment` becomes one cue.
- `.vtt`: standard WebVTT (`WEBVTT\n\n00:00:00.000 --> 00:00:02.500\nText\n\n`). Each segment one cue.
- Words excluded by enabledCutRanges are NOT removed from the transcript export — exports show the original speech (the transcript reflects what was said, not what survives the edit).

### Studio segmented control

```
[ Edit | Transcript ]   ← always visible, Edit selected by default
```

- Position: top of `SmartCutStudioContainer`'s scroll content, above the existing first card (Long Pauses).
- Persists per-session: which tab was active is captured in `@State` on the studio view (no SwiftData persistence — re-opens default to Edit, fits user's natural flow).
- When `cachedSegments.isEmpty`: tapping "Transcript" still works but body shows the empty state.

### Privacy hero copy (G-2)

In `PaywallView.swift`'s `hero` view, add a new line ABOVE the existing "CleanCut Pro" gradient headline:

```swift
Text("Your audio never leaves your phone.")
    .font(.system(.subheadline, design: .rounded, weight: .heavy))
    .foregroundStyle(Color(uiColor: semantic.textPrimary))
    .multilineTextAlignment(.center)
```

Below the existing "CleanCut Pro" headline, the existing `reasonHeadline` (which switches per `PaywallReason`) stays. The new privacy line shows for ALL reasons (settings upgrade, post-onboarding, hit-cap, watermark, trial-expired). It's not reason-specific — it's the brand claim.

The celebratory `🎉 You're all set` badge added in Sub-project 3 stays as-is for `.endOfOnboarding`. The privacy line sits between celebratory badge and CleanCut Pro headline when both are present.

## Data flow

### Flow A — quick transcript peek (sheet from toolbar)

```
1. User on SmartCutSessionView, transcription complete (cachedSegments populated)
2. Tap new 📄 toolbar icon
3. TranscriptSheet presents with B-layout body and Copy/Export row
4. User scrolls / copies / taps export chip
5. Export chip → TranscriptExporter generates file → UIActivityViewController
6. User picks share target → file delivered
```

### Flow B — studio cuts-marked transcript

```
1. User on SmartCut studio, post-Analyze (state == .results or .applied)
2. Tap "Transcript" segment
3. Studio body swaps to TranscriptCanvas
4. TranscriptCanvas renders cachedSegments with strikethrough on words inside enabledCutRanges
5. User can read, copy, or tap any export chip in the bottom-sticky row
6. Tap "Edit" segment to swap back to existing card layout
```

### Flow C — privacy hero

```
1. Any paywall trigger fires (any PaywallReason)
2. PaywallView.body renders
3. hero subview renders new privacy line above "CleanCut Pro" headline
4. User reads "Your audio never leaves your phone." then sees pricing
5. No conditional logic — line shows on every paywall presentation
```

## Error handling

- **Empty transcript** (cachedSegments.isEmpty): TranscriptSheet body shows empty-state message; TranscriptCanvas shows same. Sheet still opens; no crash. Toolbar icon is disabled when state == .idle (no analyze run yet).
- **Export file write failure** (e.g., low disk space): UIActivityViewController is never presented; show a minimal iOS alert "Couldn't save transcript file. Try again." No retry logic — this is a system-level failure, user re-tries themselves.
- **UIPasteboard write** (Copy): no failure mode — UIKit guarantees this works.
- **`UIActivityViewController` not displayable** (rare; only happens during view-tree corruption): silently no-op; same iOS edge case as the export-audio share sheet.
- **SRT/VTT timestamp formatting overflow** (audio > 23:59:59): the standard format only goes to hh:mm:ss; for unreasonably long files (>1 day), use leading hours digits beyond 2 (`100:00:00`). YAGNI — voice memos are ≤1hr in practice.

## Testing

### `TranscriptExporterTests.swift`

```swift
@Test func plainTextConcatenatesSegments()
@Test func plainTextInsertsParagraphBreakOnLongPause()  // gap > 1.5s
@Test func plainTextHandlesEmptySegments()  // returns ""
@Test func srtFormatsZeroIndexCue()
@Test func srtFormatsCommaMillisDelimiter()  // 00:00:01,500 not .500
@Test func srtNumbersCuesSequentially()  // 1, 2, 3, ...
@Test func vttHasWebVttHeader()
@Test func vttFormatsDotMillisDelimiter()  // 00:00:01.500 not ,500
@Test func vttHandlesMultiHourTimestamp()  // 01:23:45.678
@Test func srtHandlesEmptySegments()  // empty string, no fake cue
@Test func plainTextStripsLeadingTrailingWhitespace()
```

### Manual smoke checklist

1. Open a SmartCut session, run Analyze → tap toolbar 📄 icon → sheet presents B-layout. Copy works (paste into Notes). Each export chip presents UIActivityViewController; each format saves correctly when shared to Files.
2. Same session → segmented control on Transcript → studio body swaps. Filler words show strikethrough + pink. Pause markers appear inline. Switching back to Edit returns the existing cards.
3. Open a session BEFORE running Analyze → toolbar 📄 icon is disabled (greyed out). Studio segmented control: tapping Transcript shows empty state.
4. Trigger any paywall reason (e.g., import 4th SmartCut audio same day) → privacy line appears above the gradient "CleanCut Pro" headline.
5. iPad layout: open transcript sheet on iPad simulator — sheet displays as centered card per Sub-project 4 limitation. Confirm content is still legible.

## Decisions log

- **D-1 — Free for all users (transcript surface).** The audit's G-1 thesis is marketing leverage, not direct revenue. Pro-gating dilutes the moat. Locked free.
- **D-2 — B-layout sheet (paragraphs + timestamps), not A-plain or C-with-cuts.** Sheet is the lightweight quick-peek; cuts visualization belongs on the studio screen where it provides edit context.
- **D-3 — Studio integration as segmented Edit/Transcript toggle, not inline card.** Power users want full-screen reading mode; segmented control matches Descript/Riverside conventions and avoids growing the existing studio scroll length.
- **D-4 — Export row includes Copy + 3 formats**, not Copy alone or formats alone. Copy is the most common action (paste into Notes, blog draft); formats serve power users who need .srt for video subtitles.
- **D-5 — Privacy hero copy added as a new line, not replacing existing copy.** Keeps the existing reason-headline switching logic intact; the privacy line is a brand claim that holds across all reasons.
- **D-6 — `.txt`/`.srt`/`.vtt` only, no .docx or .pdf.** Heavier formats need third-party deps; pure-Foundation string generation suffices for v1. Revisit on user demand.
- **D-7 — TranscriptExporter is a pure helper, not a service**. No state, no async, no init. All static methods. Easy to test, easy to reason about.
- **D-8 — No transcript editing.** Read-only is the entire scope. Editing is Descript's moat; replicating it is a re-architecture, not a cheap win.
- **D-9 — Single privacy line, not multi-line block.** "Your audio never leaves your phone." is one claim, simply stated. Adding more ("...not even when you upgrade...") dilutes the line.

## Risks

- **Risk: empty-state messaging is confusing.** A user who taps the toolbar 📄 icon before running Analyze sees an empty sheet. Mitigation: disable the icon when `state == .idle`. Also (defensive): empty state inside the sheet has actionable copy ("Run Analyze first to generate the transcript").
- **Risk: SRT/VTT format edge cases break for production audio.** Mitigation: comprehensive `TranscriptExporterTests.swift` covering format-spec edge cases (millisecond formatting, multi-hour timestamps, sequential cue numbering, empty input).
- **Risk: Studio segmented control adds confusion** if power users miss it. Mitigation: visible by default at top of studio. Cell A in the visual companion mockup confirms placement is ambient.
- **Risk: Privacy claim invites scrutiny / legal review.** "Your audio never leaves your phone" is a strong factual claim. It's TRUE today (DeepFilterNet3 Core ML on-device, Speech.framework on-device), but if any future feature uses cloud (e.g., a hypothetical Apple Intelligence summarization route that requires Private Cloud Compute), the claim weakens. Mitigation: tie the claim to the codebase invariant — any future cloud feature must change the paywall copy, gated by code review.
- **Risk: free transcription gets abused as a standalone transcription service.** Users could import audio just to get the transcript out, never converting. Mitigation: this is the FUNNEL — they discover Smart Cut + Denoise once inside. Conversion happens at daily caps + post-onboarding paywall (already wired).

## Out of scope (future work)

- Transcript editing (would need re-applying cuts after edits — major rework).
- Speaker diarization / multi-speaker labels.
- Translation (transcript in English from non-English audio).
- `.docx` / `.pdf` export.
- Live transcription (during recording).
- Word-level click-to-play (transcript-as-scrubber).
- AI summary / show-notes (G-4 from audit; deferred to iOS 26 Foundation Models).
