# CleanCut Onboarding — Design

**Date:** 2026-05-03
**Status:** Approved (awaiting user review of written spec)
**Branch target:** `main`

---

## 1. Goals

1. Introduce CleanCut's three core features (Smart Cut, Denoise, Merge) to a first-time user without overwhelming them.
2. Establish the "private by design / on-device AI" positioning before the user touches any data.
3. Deliver a hands-on magic moment in under 60 seconds — the user should *experience* Smart Cut working on a real audio clip during onboarding, not just read about it.
4. Move the speech-recognition permission prompt to a known, contextually-justified moment instead of surprising the user mid-Analyze.
5. Keep the flow ≤45s end-to-end and skippable on the brand opener only — required from the trust primer onward.
6. Re-show on app reinstall only (not on version bumps).

## 2. Non-goals

- A personalized question funnel / quiz (rejected during brainstorming — funnels suit paywalled apps; CleanCut has no paywall yet)
- A feature tour / carousel (rejected as the dead 2018 pattern)
- A persona-picker ("I'm a podcaster vs voice memo-er") — adds extraction without payoff for our 3-feature scope
- A Merge demo during onboarding — Merge needs ≥2 clips to be meaningful; deferring to organic discovery via the tab bar
- Account creation / sign-in — "no account required" is a privacy proof point we want to keep
- iCloud sync setup — out of scope; opt-in via Settings later
- A Settings → About → Credits screen as a deliverable (the onboarding spec only requires the *file* `onboarding-sample-credit.txt`; the Settings UI to render it is a follow-up)

## 3. Architecture overview

A single new file `SonicMerge/Features/Onboarding/OnboardingFlow.swift` (~280 lines — see §9 for the full file table) hosts the entire flow as a `View` named `OnboardingFlow` with five private nested step views. `RootTabView` gains a `.fullScreenCover(isPresented:)` that presents `OnboardingFlow` whenever `@AppStorage("sonicMerge.hasOnboarded") == false`. Completion writes `true` to that key and dismisses the cover; tabs become interactive and the user lands on the Smart Cut tab.

The flow's internal state is a `@State private var step: Int` driven by Continue / Skip taps. Step 3 (speech-recognition permission) is not a SwiftUI screen but a transient modal — it triggers `SFSpeechRecognizer.requestAuthorization` and immediately advances to step 4 on either response. Step 4 loads a bundled `onboarding-sample.m4a` from the app bundle, renders a card, and lets the user run Smart Cut against it (or skip to home if speech was denied). Step 5 shows the Smart Cut result card with an A/B Original/Cleaned toggle and a TipKit-style nudge toward Denoise.

The existing `LocalFirstTrustStrip` and `hasImportedFirstClip` first-launch banners are unchanged — they continue to render after onboarding completes, until the user imports their first real clip. The two affordances complement each other: onboarding sets the *thesis*; the inline trust strip reinforces it on the empty home screens.

## 4. Visual identity

Onboarding adheres to the existing CleanCut design system established in `2026-05-03-three-tab-ui-unification-design.md`. Color discipline:

- Indigo `accentAction` (`#5856D6`) — Continue / Skip-to-home / brand-level chrome
- Lime green `accentAI` (`#A7C957`) — the "Smart Cut This Sample" CTA on step 4 (it's the AI moment); the savings pill on step 5; the celebration accent in the result card

The flow uses `PremiumBackground()` as its full-screen-cover backdrop. Each step is a vertically-centered `VStack` with a 5-dot progress indicator at the top. The 5 dots are 14×4pt rounded rectangles, indigo when active, neutral grey when inactive (`#D1D1D6`).

## 5. Step-by-step content

All copy is locked. No A/B copy variants in v1.

### Step 1 — Brand opener

**Layout:** Large hero badge (80×80 rounded-rect, lime/indigo gradient at 20% alpha, `sparkles` icon) + title + tagline + 3 feature pills + Continue. Skip in top-trailing.

**Copy:**
- Title: `"Cut. Clean. Merge."`
- Tagline: `"Your audio toolkit, all on this device."`
- Feature pill 1: `Image("sparkles", lime)` + `"Smart Cut · remove fillers"`
- Feature pill 2: `Image("waveform.badge.minus", lime)` + `"Denoise · clean noisy clips"`
- Feature pill 3: `Image("rectangle.stack", indigo)` + `"Merge · combine audio"`
- Primary CTA: `"Continue"` (indigo pill)
- Skip link: `"Skip"` (top-right, plain text, secondary)

**Skip behavior:** advances to step 2 (NOT to home — trust primer + sample step are required per user decision).

### Step 2 — Trust primer

**Layout:** Hero badge (80×80 rounded-rect, indigo at 14% alpha, `lock.shield.fill` icon) + 3-line stacked title + tagline + 2 trust rows + Continue. No Skip.

**Copy:**
- Title: `"Your audio\nnever leaves\nthis device."` (3 lines, large)
- Tagline: `"No upload. No cloud. No account."`
- Trust row 1: 🛡 + `"Apple's on-device AI handles every cut"`
- Trust row 2: 🛡 + `"Files stay in CleanCut's private folder"`
- Primary CTA: `"Continue"` (indigo pill)

The two trust rows reuse the visual treatment of the existing `LocalFirstTrustStrip` (glass background w/ accent-glow border, `surfaceCard` solid fallback for `accessibilityReduceTransparency`).

### Step 3 — Speech-recognition permission

**Not a SwiftUI screen.** When the user taps Continue on step 2:
1. The flow calls `SFSpeechRecognizer.requestAuthorization { ... }` (bridge to async/await with `withCheckedContinuation`, matching the existing pattern at `SmartCutViewModel.swift:212`).
2. iOS displays its standard permission dialog with the `NSSpeechRecognitionUsageDescription` already in `Info.plist`: `"CleanCut uses on-device speech recognition to detect filler words and long silences in your audio. Recognition runs entirely on your device — your audio is never uploaded."`
3. Whatever the user picks (Authorized / Denied / Restricted / Notdetermined), the flow advances to step 4. The branch state (granted vs denied) is stored as `@State private var speechGranted: Bool` on the flow.
4. If `notDetermined` (user dismissed the dialog without choosing — rare on iOS), treat as denied for this run.

The progress indicator briefly shows step 3 active during the OS dialog. We do NOT show a pre-prompt explainer screen — the system dialog with our usage description does that work.

### Step 4 — Hands-on first cut on bundled sample

**Layout:** Step indicator + title + subtitle + sample-clip card (filename, waveform stripe, duration) + ONE TipKit-style hint banner + primary CTA at the bottom.

**Copy (granted path):**
- Title: `"Try it on a sample"`
- Subtitle: `"A 30-second podcast clip is loaded for you."`
- Sample card: `"podcast-snippet.m4a"` + `"0:00 — 0:32"` + waveform stripe
- TipKit hint: `"💡 Tap Smart Cut to remove every \"um\" and long pause from this clip."`
- Primary CTA: `"✨ Smart Cut This Sample"` (lime pill — this is the AI moment)

**Copy (denied path — speechGranted == false):**
- Title: `"Sample loaded"`
- Subtitle: `"Smart Cut needs Speech Recognition access. Enable it in Settings → CleanCut."` — **identical wording to the existing `SmartCutViewModel.analyze()` error string at line ~178**, so users who hit either path see the same canonical message. If that production string ever changes, this spec's subtitle changes with it.
- Sample card: same as granted path
- No TipKit hint (would be misleading)
- Two buttons:
  - `"Open Settings"` (indigo outline pill — opens `UIApplication.openSettingsURLString`)
  - `"Skip to home"` (text-only secondary)

When granted user taps "✨ Smart Cut This Sample": the flow runs the actual `SmartCutService.analyze(input:)` against the bundled file (same code path as production Smart Cut). Progress is visualized as a brief inline progress ring on the card (no progress modal, no analyzing scaffold — keep it tight). On `.completed` the flow auto-advances to step 5.

If analyze errors out (e.g., model load fails, simulator quirks), surface a one-line error caption *"Couldn't analyze the sample. Tap to try again or skip."* and offer retry. After 2 retries, force-skip to home with `hasOnboarded = true` set so the user is never trapped.

### Step 5 — Result + soft Denoise reveal

**Layout:** Step indicator + result title + result card + A/B toggle + Denoise TipKit + Done CTA.

**Copy (granted path with successful analyze):**
- Title: `"<N> fillers found"` (where N is the actual count from the analyze) — falls back to `"Smart Cut applied"` if N is somehow 0
- Subtitle: `"saves ~<S>s"` where S = sum of enabled filler + pause durations, rounded to nearest second (lime pill style — same shape as the existing `StudioSummaryCard` savings tag)
- Result card: filename + savings pill + 2-pill segmented A/B toggle (Original / Cleaned)
- Denoise TipKit: `"💡 Try Denoise on this clip — the AI orb removes background hiss."`
- Primary CTA: `"Done · Open Smart Cut"` (indigo pill)

The A/B toggle is functional — tapping Cleaned plays the cut output via `AVAudioPlayer`; tapping Original plays the bundled sample. This proves the cuts are real, not a slideshow. Reuse `PlaybackCoordinator` so onboarding playback respects the same single-active-player invariant the rest of the app uses.

The Denoise TipKit is **decorative-only** in v1 — no tap action wired. Tapping the Done button is the only forward action. The TipKit text seeds the user's next discovery: when they later open the Denoise tab they'll remember it can clean noise.

**Copy (denied path — Smart Cut wasn't run):**
- Title: `"You're all set"`
- Subtitle: `"Open the Smart Cut tab anytime to start."`
- No result card, no A/B toggle, no Denoise TipKit
- Primary CTA: `"Done · Open Smart Cut"` (indigo pill)

### Done flow (any path)

Tapping Done:
1. Sets `hasOnboarded = true`
2. Sets `RootTabView.selection = .smartCut` (already the default — explicit for safety)
3. Dismisses the `.fullScreenCover` with the system spring animation
4. Posts a one-time `.success` haptic via `UINotificationFeedbackGenerator`

## 6. Bundled sample podcast

Per spec §C of the brainstorm, the sample must demo BOTH Smart Cut and Denoise dramatically.

### 6.1 Required clip properties

| Property | Target |
|---|---|
| Duration | 28–32s |
| Filler density | 8–15 instances of "um", "uh", "you know", "like" |
| Long pauses | 1–3 silences ≥ 1.5s |
| Background noise | Light room hum / HVAC / faint traffic — audible on speaker but not distracting |
| Speaker | Single, conversational, mid-tempo |
| Speech only | No music, no jingles, no intro/outro stingers |
| Sample rate / format | 48 kHz stereo AAC, 256–320 kbps |
| File size | ~300–500 KB |

### 6.2 Empirical acceptance bar

The implementer runs the actual app's `SmartCutService.analyze(input:)` against the candidate clip locally before bundling and confirms:

1. **Savings ≥ 8 seconds** in `editList.enabledSavings`
2. **Filler categories ≥ 2** (`editList.categories.count >= 2`)
3. **At least one pause cut** (`editList.pauses.contains { $0.isEnabled }`)

If any check fails → pick another candidate. The empirical check matters more than the theoretical density numbers.

### 6.3 Sourcing priority

1. **CC-BY podcast/interview from Internet Archive** or similar public archive. Real = authentic. Search targets: TWiT.tv CC-licensed episodes, CC-BY conference interviews, public-domain oral history. Attribution required.
2. **Project-owner-recorded clip.** Owner records ~60s of natural conversational speech (a topic with built-in hesitancy works best — e.g., "let me tell you about the most surprising thing I learned at WWDC last year") and trims to 30s. Total control over density and noise floor.
3. **Synthesized via TTS — REJECT.** A robotic voice undermines the "AI works on real audio" claim.

The plan picks one source at planning time. Implementer's first deliverable in the implementation plan's Chunk 1 is to source + verify the clip via §6.2's acceptance bar, before any view code is written.

### 6.4 Bundle location and attribution

- Audio file: `SonicMerge/Resources/onboarding-sample.m4a`
- Attribution file (CC-BY only): `SonicMerge/Resources/onboarding-sample-credit.txt` — single-line plaintext with attribution. Loaded by future Settings → About screen (out of scope here, but the file must ship now so attribution is satisfied immediately).
- Both files are added to the main app target via the existing `PBXFileSystemSynchronizedRootGroup` Resources group (no `project.pbxproj` surgery needed).

## 7. Permissions

### 7.1 Speech recognition (step 3)

Already-existing `NSSpeechRecognitionUsageDescription` in `SonicMerge/Info.plist` is reused verbatim. The flow calls `SFSpeechRecognizer.requestAuthorization` directly. No second prompt for the same permission later in the app — `SmartCutViewModel.analyze()`'s lazy prompt at line ~212 still runs as a belt-and-suspenders safety net (it's a no-op on already-authorized status), so users who somehow miss the onboarding prompt still get prompted later.

### 7.2 Notifications

NOT prompted during onboarding. Stays where it is — `SmartCutViewModel.scheduleBackgroundTranscription()` triggers the system prompt the first time the user opts into background analyze. Onboarding doesn't need notifications, and bundling the prompt would feel grabby.

### 7.3 Microphone

NOT prompted during onboarding (CleanCut doesn't currently record — only imports). If recording lands later, the prompt happens at the record-button tap site, not retroactively in onboarding.

## 8. Migration / rollout

- **New install:** `hasOnboarded` defaults to `false` (no key in UserDefaults) → onboarding shows on first launch.
- **Existing user upgrading from a build without onboarding:** same — no `hasOnboarded` key in UserDefaults yet, defaults to `false`. They see onboarding once on the next launch after upgrading. **Acceptable** — the brand identity has shifted (CleanCut rebrand) so a one-time intro is honest, not annoying.
- **Reinstall:** UserDefaults is wiped → onboarding re-appears. Per user decision.
- **Major version bumps:** no re-show. The flag is a single `Bool`, not a versioned check.

## 9. Files to change

| File | Change | Approx. lines |
|---|---|---|
| `SonicMerge/Features/Onboarding/OnboardingFlow.swift` | **NEW** — flow root + 5 step views as private nested types + helper for sample audio | ~280 |
| `SonicMerge/App/RootTabView.swift` | Add `@AppStorage("sonicMerge.hasOnboarded")` + `.fullScreenCover(isPresented: !hasOnboarded) { OnboardingFlow() }` | +6 |
| `SonicMerge/Resources/onboarding-sample.m4a` | **NEW** asset (bundled sample) | binary |
| `SonicMerge/Resources/onboarding-sample-credit.txt` | **NEW** plaintext attribution (only if CC-BY source chosen) | 1 line |
| `SonicMergeTests/OnboardingGateTests.swift` | **NEW** — 2 unit tests on the AppStorage flag default + roundtrip | ~40 |

**No project.pbxproj edits** — the project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16 folder sync), which auto-includes new files in their containing folder's target.

## 10. Accessibility

- All text uses Dynamic Type (`.font(.title3, .body, .caption)` etc.) — no fixed point sizes for body text. Hero icons use fixed sizes (38pt within 80pt frames) since they're decorative.
- Each step's `View` declares `.accessibilityElement(children: .contain)` on the wrapping `VStack` and a top-level `.accessibilityLabel` of the form `"Step <N> of 5: <step title>"` so VoiceOver users can orient. `.contain` keeps individual children (Continue button, etc.) independently focusable for VoiceOver, while still labeling the container; `.combine` would have flattened them and made the CTA non-focusable.
- The 5-dot progress indicator carries `.accessibilityHidden(true)` (the per-step label already conveys position).
- `@Environment(\.accessibilityReduceMotion)` gates the `.symbolEffect(.bounce)` on the brand opener hero icon and the result-reveal animation — fall back to opacity-only transitions.
- `@Environment(\.accessibilityReduceTransparency)` gates the trust-primer glass background — fall back to `surfaceCard` solid fill.
- The lime CTA on step 4 has accessibility label `"Smart Cut this sample"` and hint `"Removes filler words and long pauses from the bundled audio sample."`.
- The A/B Original/Cleaned toggle on step 5 has selection state announced as `"Original audio, selected"` / `"Cleaned audio, selected"`.

## 11. Testing

### 11.1 Unit tests (Swift Testing)

`SonicMergeTests/OnboardingGateTests.swift` — **smoke tests only.** They verify the storage layer behaves as expected; they do **not** verify the `@AppStorage("sonicMerge.hasOnboarded")` SwiftUI integration in `RootTabView` or the `.fullScreenCover` presentation behavior. Both gaps are intentional — full integration coverage lives in the manual QA checklist (§11.3 items 1, 4, 5). The implementer should leave a `// SMOKE TESTS — see QA checklist for full integration coverage` header at the top of the test file so future maintainers don't expand these into a false sense of safety.

```swift
@Test func defaultGateIsFalse() {
    let defaults = UserDefaults(suiteName: "test-\(UUID())")!
    #expect(defaults.bool(forKey: "sonicMerge.hasOnboarded") == false)
}

@Test func gateRoundtripsAcrossInstances() {
    let suite = "test-\(UUID())"
    let writer = UserDefaults(suiteName: suite)!
    writer.set(true, forKey: "sonicMerge.hasOnboarded")
    let reader = UserDefaults(suiteName: suite)!
    #expect(reader.bool(forKey: "sonicMerge.hasOnboarded") == true)
}
```

### 11.2 No view tests

Consistent with the rest of the project's home views — onboarding visuals are manually verified, not snapshot-tested.

### 11.3 Manual QA checklist (run by the project owner on simulator)

1. **First install (allow path):** wipe simulator → cold launch → all 5 steps render → tap "Smart Cut This Sample" on step 4 → savings pill appears on step 5 with N≥2 fillers and savings≥8s → A/B toggle plays both versions → Done dismisses cover → app lands on Smart Cut tab.
2. **First install (deny path):** wipe simulator → cold launch → step 1 → 2 → step 3 dialog "Don't Allow" → step 4 shows "Sample loaded / Settings or Skip" copy → tap Skip → step 5 shows "You're all set" → Done dismisses.
3. **Skip on step 1:** tap Skip → advance to step 2 (NOT home) → flow continues normally.
4. **Already-onboarded:** set `hasOnboarded = true` → cold launch → tabs render directly, no cover shown.
5. **Reinstall:** delete app from sim → reinstall → onboarding re-appears.
6. **Reduce Motion ON:** Settings → Accessibility → Motion → Reduce Motion → cold launch → bounce animations replaced with opacity fades; nothing breaks.
7. **Reduce Transparency ON:** trust primer step renders with solid card background instead of glass.
8. **Dynamic Type XXL:** layout doesn't truncate or clip off-screen.
9. **VoiceOver:** all 5 steps announce step number + title; CTAs announce purpose; A/B toggle announces selection state.

## 12. Open questions

None at design-approval time. Two items deliberately deferred:

1. **Settings → About → Credits screen.** Required only if the bundled sample is CC-BY. Out of scope; the attribution text file ships now as a placeholder for the future Settings UI.
2. **Re-onboarding on major version bump.** Explicitly NOT supported in v1 per user decision. If a v2 of CleanCut introduces a fundamentally different feature set, a new onboarding revision will use a different `@AppStorage` key (e.g., `sonicMerge.hasOnboardedV2`).

## 13. References

- `docs/superpowers/specs/2026-05-03-three-tab-ui-unification-design.md` — establishes the visual identity (color tokens, spacing, button styles) onboarding inherits.
- `SonicMerge/DesignSystem/TrustSignalViews.swift` — existing `LocalFirstTrustStrip` and `TrustSignalCopy` enum that step 2 visually echoes.
- Apple HIG — Onboarding (https://developer.apple.com/design/human-interface-guidelines/onboarding) — specifically: "ask for permissions in context", "show, don't tell", "let people skip but make skipping cost something tiny".
- Brainstorming research (in-conversation, 2026-05-03): Apple Journal · Halide · Kino · CapCut · Photoroom as Hands-On First Action references; Apple Journal · Signal · Bend as Trust Primer references; Cal AI · Reflectly explicitly rejected as funnel patterns.
