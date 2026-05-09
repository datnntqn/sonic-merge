# Multi-Language Smart Cut — Detection-Layer Localization

**Date:** 2026-05-09
**Status:** Spec — implementation-ready
**Author:** Claude (autonomous mode, user-approved decisions)
**Source:** User request — "design the multi-language pass" (see also conversation: detection-only scope, device-locale + per-session override, top 4 curated languages)

## Summary

Smart Cut is currently English-only at the detection layer: `TranscriptionService` is hardcoded to `Locale(identifier: "en-US")` and `FillerLibrary` ships a single English default-off list. This spec makes Smart Cut analyze non-English audio without touching the UI strings or the onboarding sample.

The recognizer locale becomes a **per-session property** persisted on `SmartCutSession`, defaulting to the device's preferred language (filtered through `SFSpeechRecognizer.supportedLocales()`, falling back to `en-US` if unsupported). A new `LanguagePill` component near the Smart Cut Summary card lets the user override per session via a `LocalePicker` sheet. The filler library gains per-locale default-off lists for **English, Spanish, Brazilian Portuguese, and French** — every other supported locale still works (recognizer + pause detection + user-custom words), but starts with an empty default-off list and a hint to populate it.

## Goals

1. **A Spanish/Portuguese/French podcaster gets useful Smart Cut results** — the recognizer transcribes in their language and the default-off list contains real fillers from that language.
2. **Per-session locale**, not app-wide — multilingual producers (Spanish AND English content) don't have to re-set a global preference per import.
3. **Zero impact on existing English sessions** — sessions created before this lands have `localeIdentifier = nil`, which resolves to `en-US`, so behavior is byte-for-byte identical.
4. **No new flaky tests.** The `FAIL=5` baseline must not change. Curated filler lists are verified manually during the implementation chunk; per-locale unit tests assert dictionary lookups, not SFSpeechRecognizer behavior.

## Non-Goals

- **UI string localization.** UI labels stay English. `Localizable.xcstrings` is a separate spec.
- **Per-locale onboarding sample.** The bundled `onboarding-sample.m4a` stays English. A multilingual onboarding flow is a separate spec.
- **Automatic language detection from audio.** Would require a CoreML language-ID model; separate spec.
- **Per-locale custom word lists.** Custom words stay global (one user list across all locales). The "leak" of e.g. a Spanish custom word into an English session is harmless — it just doesn't match. Cheaper than per-locale storage and matches user mental model ("my filler list").
- **Migrating existing edit lists across locales.** Changing a session's locale invalidates the cached transcript and edit list; user re-analyzes.
- **Curated filler lists beyond the top 4.** Languages 5+ ship with an empty default list and a UI hint pointing to "Edit Filler List" so users can populate their own.
- **Apple's iOS 26 SpeechAnalyzer.** Out of scope for this spec; deployment floor stays iOS 17.

## Architecture

```
                                       SmartCutSession (SwiftData @Model)
                                       ├─ localeIdentifier: String?      ← NEW. nil = device default → en-US fallback
                                       ├─ sourceFilename, sourceHashHex, …
                                       └─ editListJSON

                                                       │
                                                       │ resolved by SmartCutViewModel
                                                       ▼
                                       ┌────────────────────────────────────┐
   Studio: LanguagePill ──tap──→ LocalePicker sheet                                  │
   "🌐 Language: English ▾"        ├─ list = SFSpeechRecognizer.supportedLocales()   │
                                   │   sorted: device-preferred first, then alpha   │
                                   ├─ search bar                                     │
                                   └─ pick → vm.setLocale(identifier)                │
                                                       │ persists session field      │
                                                       │ + vm.invalidate()           │
                                                       ▼                              │
                                       SmartCutViewModel.analyze()                    │
                                       └─ resolves locale = session.localeIdentifier  │
                                          ?? Locale.preferredLanguages.first          │
                                          ?? "en-US"                                  │
                                                       │                              │
                                                       ▼                              │
                                       SmartCutService.analyze(input:                 │
                                                                pauseThreshold:       │
                                                                locale: ←── NEW)      │
                                                       │                              │
                          ┌────────────────────────────┴────────────────────┐         │
                          ▼                                                 ▼         │
            TranscriptionService                            FillerDetector             │
            (locale per-call, not init)                     .detect(words:             │
                          │                                  library.allWords(         │
                          │                                    for: locale)            │
                          │                                  …)                        │
                          ▼                                                            │
              SFSpeechRecognizer(locale:)                                              │
              .requiresOnDeviceRecognition = !cloud  (existing)                        │
                                                                                       │
                                                                                       │
   FillerLibrary (existing instance)                                                   │
   ├─ defaultOffWords(for: Locale) ── per-locale lookup, falls back to en              │
   ├─ customWords    ── global (untagged by locale)                                    │
   └─ removedDefaults ── global (untagged by locale)                                   │
                                                                                       │
   Curated default-off words by language code:                                         │
     en: like, you know, sort of, basically, actually, literally                       │
     es: este, eh, o sea, pues, tipo, como                                             │
     pt: tipo, né, então, sabe, meio que                                               │
     fr: euh, ben, genre, en fait, du coup, tu sais                                    │
   Other languages: [] (empty; user opts in via Edit Filler List)                      │
```

## Components

### 1. `SmartCutSession.localeIdentifier: String?` (SwiftData migration)

New optional `String` field on the existing `@Model` class. SwiftData handles addition of optional fields automatically — no manual schema migration needed.

- `nil` (default for fresh sessions) → resolved at analyze time to `Locale.preferredLanguages.first` filtered through `SFSpeechRecognizer.supportedLocales()`, falling back to `"en-US"`.
- Set explicitly (e.g. `"es-ES"`) when the user picks a locale via `LocalePicker`.
- Persists with the session — re-opening the session next launch shows the same locale.

### 2. `LocalePicker` view (new, ~80 LOC)

A modal sheet (`.sheet(isPresented:)`) presenting `SFSpeechRecognizer.supportedLocales()` as a list:

- **Sort order**: device's `Locale.preferredLanguages` first (top of the list, with a small "Suggested" header), then the rest alphabetized.
- **Search bar**: filter by name. e.g. typing "españ" matches "Spanish (Spain)", "Spanish (Mexico)", etc.
- **Row content**: language+region name + locale identifier in caption (e.g. "pt-BR"). Checkmark on currently-selected locale.
- **Localized vs. English names**: pin name rendering to **English** for v1 (`Locale(identifier: "en").localizedString(forIdentifier: id)`). Reason: the rest of the UI is English-only per Non-Goals; a Vietnamese-device user seeing "Tiếng Anh" next to English UI elsewhere would feel inconsistent. Switch to device-localized names when full UI localization lands.
- **Tap row**: invokes `onPick(locale.identifier)` and dismisses. Caller persists.
- **Cancel button**: dismisses without changes.

File: `SonicMerge/Features/SmartCut/Views/Studio/LocalePicker.swift`.

### 3. `LanguagePill` view (new, ~30 LOC)

Compact tappable pill above the Smart Cut Summary card:

- Renders `🌐 Language: <name>` with a chevron-down. Name comes from `Locale(identifier: "en").localizedString(forIdentifier: localeIdentifier) ?? "English"` — pinned to English to match the rest of the UI (see Non-Goals; revisit when UI localization lands).
- Visual: light surface fill, `accentAction`-tinted text, rounded capsule (matches existing studio design tokens).
- Tap → opens `LocalePicker` sheet.
- Disabled state when the studio is in `.analyzing` (locale change mid-analyze is ignored to avoid races).

File: `SonicMerge/Features/SmartCut/Views/Studio/LanguagePill.swift`.

### 4. `FillerLibrary.defaultOffWords(for: Locale) -> [String]` (modified)

Replace the single `let defaultOffWords` array with a per-locale lookup:

```swift
private static let defaultsByLanguage: [String: [String]] = [
    "en": ["like", "you know", "sort of", "basically", "actually", "literally"],
    "es": ["este", "eh", "o sea", "pues", "tipo", "como"],
    "pt": ["tipo", "né", "então", "sabe", "meio que"],
    "fr": ["euh", "ben", "genre", "en fait", "du coup", "tu sais"]
]

func defaultOffWords(for locale: Locale) -> [String] {
    let code = locale.language.languageCode?.identifier ?? "en"
    return Self.defaultsByLanguage[code] ?? []
}
```

`allWords(for: Locale)` becomes the locale-aware accessor that `FillerDetector` calls. `defaultOnWords` stays empty (existing design — see file comment about on-device recognizer unreliability for short hesitation tokens; this still applies per-locale).

`customWords` and `removedDefaults` stay global (no locale tag). Rationale documented in Non-Goals.

### 5. `TranscriptionService` — locale stays at init (no per-call refactor)

`TranscriptionService.init(locale: Locale = Locale(identifier: "en-US"))` already takes a locale. We keep that signature and **construct one `TranscriptionService` per analyze** with the session's locale, instead of refactoring `transcribe(input:)` to take a per-call locale. Rationale:

- Avoids two ways to do the same thing (init default + per-call override).
- Keeps the `TranscriptionServicing` protocol's `transcribe(input:)` signature unchanged, which preserves the `StubTranscriptionService` used by existing tests (`SmartCutServicePauseThresholdTests`).
- Matches the existing actor lifecycle — services are cheap to construct.

The single change inside `TranscriptionService.transcribe(input:)`:

- Validate `locale` is in `SFSpeechRecognizer.supportedLocales()` at the top of `transcribe`. If not, fall back to `"en-US"` and `print` a DEBUG warning. (Equivalent guard could live in `SmartCutService.analyze(...)` before constructing the service — either is fine; spec lands the guard inside `TranscriptionService` because that's where the locale is consumed.)

The cloud-recognition default, isAvailable retry loop, and chunked pipeline are unchanged.

### 6. `SmartCutService.analyze(input:, pauseThreshold:, locale:)` (modified)

Add `locale: Locale` parameter. Constructs a per-analyze `TranscriptionService(locale:)`, passes the result of `library.allWords(for: locale)` into `FillerDetector.detect(words:)`. The shared `transcriptionService` field on `SmartCutService` becomes a factory closure (or is dropped in favor of per-call construction) — small refactor, no behavior change for callers.

### 7. `SmartCutViewModel` (modified)

The VM stays session-agnostic between init and explicit calls — it does **not** retain a `SmartCutSession` reference (matches today's `persist(to:)` pattern, which takes the session as a parameter). This avoids any SwiftData-managed-object lifetime concern.

- New stored property `currentLocale: Locale` (defaults to `deviceFallback()` at init; overridden by the session-driven init when the session has a non-nil `localeIdentifier`).
- `analyze()` reads `currentLocale` and passes to `service.analyze(input:pauseThreshold:locale:)`.
- New method `setLocale(_ identifier: String, on session: SmartCutSession)`:
  - Updates `session.localeIdentifier = identifier` (caller saves via `modelContext.save()` on next idle, same as `persist(to:)`).
  - Updates `currentLocale` on the VM.
  - Calls `invalidate()` so the cached transcript / edit list is dropped — the next analyze runs fresh in the new locale.
- The session-driven convenience initializer at line 77 reads `session.localeIdentifier` (when non-nil) into `currentLocale` once at init time. After that, `setLocale(_:on:)` is the only mutation path.

### 8. `BackgroundTranscriptionTask` (modified)

The background analyze path resumes by source hash, not by `SmartCutSession`. To honor the session's locale on resume, the task does a SwiftData lookup:

- `BackgroundTranscriptionTask.run(...)` looks up `SmartCutSession.where { $0.sourceHashHex == hash }.first` via the shared `ModelContainer`.
- If found and `session.localeIdentifier` is non-nil, constructs `TranscriptionService(locale: Locale(identifier: localeIdentifier))`. Otherwise falls back to `Locale(identifier: "en-US")` (matches the foreground-no-locale case).

The existing source-hash → URL lookup via `SmartCutSourceLocator` stays unchanged; only the locale resolution is added.

File: `SonicMerge/Features/SmartCut/Services/BackgroundTranscriptionTask.swift`.

### 9. `LanguagePill` placement across studio states

The pill must be **visible in `.idle` too**, since that's the state for a fresh non-English import — the user has to be able to pick the language *before* analyze runs, not just after. Specifically:

- `.idle` (`idleScaffold` in `SmartCutStudioContainer.swift`): pill appears between the existing description text and `IdleSettingsCards`.
- `.analyzing`: pill is rendered but **disabled** (locale change mid-analyze is a no-op).
- `.results` / `.applied` / `.stale`: pill appears above `StudioSummaryCard`.
- `.error`: pill appears above the existing error scaffold.

This means the pill is part of the studio container's outer layout, not nested inside any per-state scaffold.

### 10. `EditFillerListStudioSheet` per-locale defaults

The sheet renders `library.allWords` to show the user their current filler list. After this spec lands, `library.allWords` becomes locale-aware (`allWords(for: Locale)`). The sheet must:

- Read `vm.currentLocale` and call `library.allWords(for: currentLocale)` instead of the global accessor.
- Display a footer line: *"Showing default words for <localized language name>. Switch language in the studio to see a different list."*

Files-to-change row: ~5 LOC.

## Data flow

1. **Import** → `SmartCutSession` created with `localeIdentifier = nil`. Studio renders `LanguagePill` showing `"🌐 Language: <device locale>"` (e.g. English, or Spanish if user's device is Spanish).
2. **First analyze** → resolves locale via `currentLocale` (device default), runs `SmartCutService.analyze(input:, locale:)`. SFSpeechRecognizer transcribes; FillerDetector applies per-locale default-off list + global custom words.
3. **User taps `LanguagePill`** → `LocalePicker` opens. User picks "Spanish (Spain)". On tap: VM persists `session.localeIdentifier = "es-ES"`, invalidates the cached state, dismisses picker, returns to `.idle`. Studio prompts user to re-analyze.
4. **Re-analyze** → same flow as step 2 but with Spanish recognizer + Spanish default fillers.
5. **Apply Cuts** → unchanged. AudioCutter is language-agnostic.
6. **Reopen session next launch** → `session.localeIdentifier = "es-ES"` persists; pill shows Spanish; analyze runs in Spanish.

## Error handling

| Condition | Behavior |
|---|---|
| Stored `localeIdentifier` no longer in `SFSpeechRecognizer.supportedLocales()` (e.g., iOS update dropped support) | `TranscriptionService` falls back to `"en-US"`. Studio shows a one-line banner: *"Selected language is no longer supported. Reverted to English."* User can re-pick. |
| Device's preferred language not in `supportedLocales()` and `localeIdentifier == nil` | Falls back to `"en-US"` silently on first analyze. No banner — this is the cold-start case and we don't want to badge a fresh install. |
| User picks a locale we don't have curated fillers for (e.g., Korean) | Empty default-off list. Pause detection still works. UI hint below the summary card: *"Add common filler words for this language via Edit Filler List."* |
| `LocalePicker` sheet opened mid-analyze | `LanguagePill` is disabled in `.analyzing` state. Tap is a no-op visually grayed. |

## Free-tier / paywall implications

None. Locale is a free feature for all users. Existing length and quota gates run unchanged.

## Testing

Swift Testing per project convention. Two new test files; no integration tests against `SFSpeechRecognizer` (avoids the FAIL=5 flake-class).

### `FillerLibraryLocaleTests.swift` (new, ~60 LOC)

```swift
@Test func englishDefaultsReturnedForEnUS()
@Test func englishDefaultsReturnedForEnGB()  // any en-* falls back to en
@Test func spanishDefaultsReturnedForEsES()
@Test func spanishDefaultsReturnedForEsMX()  // any es-* falls back to es
@Test func portugueseDefaultsReturnedForPtBR()
@Test func frenchDefaultsReturnedForFrFR()
@Test func emptyDefaultsForKorean()           // uncurated language → empty
@Test func customWordsAppearAcrossAllLocales() // global custom list
```

### `TranscriptionServiceLocaleTests.swift` (new, ~40 LOC)

```swift
@Test func unsupportedLocaleFallsBackToEnglish()
@Test func supportedLocalePassesThrough()
```

These touch only the locale-resolution logic, not the recognizer itself, so no flake risk.

### Manual QA

Implementation chunk's last task. The implementer:

1. Imports a Spanish audio sample (e.g. a short CC-licensed clip from Internet Archive — the existing `onboarding-sample.m4a` stays English).
2. Picks Spanish via `LanguagePill`.
3. Runs analyze. Confirms ≥1 of `["este", "eh", "o sea", "pues", "tipo", "como"]` is detected.
4. Repeats for pt-BR and fr-FR.
5. If any default word in any of these locales never matches in practice, removes it from the curated list and documents the empirical reason in the file.

Existing English sessions: smoke-test that re-running an existing session post-migration produces an identical edit list.

## Files to change

| File | Change | Approx. LOC |
|---|---|---|
| `SonicMerge/Models/SmartCutSession.swift` | Add `var localeIdentifier: String?` field | +3 |
| `SonicMerge/Features/SmartCut/Models/FillerLibrary.swift` | Per-locale default-off dictionary; `defaultOffWords(for:)` accessor; `allWords(for:)` accessor; preserve global `customWords` and `removedDefaults` | ~30 |
| `SonicMerge/Features/SmartCut/Services/TranscriptionService.swift` | Inside `transcribe(input:)`, validate locale against `SFSpeechRecognizer.supportedLocales()`; fall back to `en-US` on miss. No new public parameter; init-level locale stays the only entry point. | ~5 |
| `SonicMerge/Features/SmartCut/Services/SmartCutService.swift` | Add `locale` parameter to `analyze`; per-analyze construct a `TranscriptionService(locale:)`; thread `library.allWords(for: locale)` into FillerDetector | ~10 |
| `SonicMerge/Features/SmartCut/Services/FillerDetector.swift` | No code change — already takes `words: [String]` parameter | 0 |
| `SonicMerge/Features/SmartCut/Services/BackgroundTranscriptionTask.swift` | Look up `SmartCutSession` by hash; resolve `localeIdentifier`; construct `TranscriptionService(locale:)` (instead of default-locale init) | ~10 |
| `SonicMerge/Features/SmartCut/SmartCutViewModel.swift` | `currentLocale` stored property; `setLocale(_:on:)` method (takes session as param, no SwiftData retain); session-driven init reads `session.localeIdentifier` | +20 |
| `SonicMerge/Features/SmartCut/Views/Studio/LanguagePill.swift` | NEW component (English-pinned name) | 30 |
| `SonicMerge/Features/SmartCut/Views/Studio/LocalePicker.swift` | NEW sheet (English-pinned names, suggested-first sort, search) | 80 |
| `SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift` | Mount `LanguagePill` at outer-layout level so it appears in `.idle`, `.results`, `.applied`, `.stale`, `.error`. Disabled in `.analyzing`. | +10 |
| `SonicMerge/Features/SmartCut/Views/Studio/EditFillerListStudioSheet.swift` | Read `library.allWords(for: vm.currentLocale)` instead of global; add footer line indicating which language's defaults are showing | ~5 |
| `SonicMergeTests/Features/SmartCut/FillerLibraryLocaleTests.swift` | NEW | 60 |
| `SonicMergeTests/Features/SmartCut/TranscriptionServiceLocaleTests.swift` | NEW | 40 |

**Total estimated:** ~290 LOC new, ~95 LOC modified, 2 new test files.

## Risks

1. **Curated filler lists may not match actual recognizer output.** SFSpeechRecognizer transcribes Spanish "este" but might split it as "es te" depending on speaker / acoustic context. Plan mitigates: implementer empirically verifies each curated word against a real clip during the manual QA step. Words that never match get removed from the default list and documented inline.

   **Highest-collision words to flag specifically during QA**: Spanish `como` (also a common interrogative "how/like" used non-fillerly) and `tipo` (also "type/kind"). These are likely to produce false positives even when correctly transcribed. If false-positive rate is unacceptable, drop them from the default list and let users add them as customs.

2. **SwiftData lightweight migration.** Adding an optional field on `@Model` is supported without a versioned schema. Tested by smoke-running the app on a populated session list; no data loss expected. If this somehow fails on a real device's existing data, the recovery path is the same as for any unrelated SwiftData breakage (delete + reinstall).

3. **Locale mismatch between transcribe and FillerDetector.** Both must use the same locale for results to be coherent. Threading both through `SmartCutService.analyze(... locale:)` makes them pull from one parameter — no drift possible.

4. **Custom words "leaking" across locales.** Acceptable per Non-Goals — they don't match in the wrong locale, just don't get used. If user-feedback later requests per-locale custom storage, that's a follow-up spec.

5. **`SFSpeechRecognizer.supportedLocales()` returning a list of `Locale` rather than identifiers.** The picker's data model must use `Locale` instances; persistence stores `.identifier`. Round-trip via `Locale(identifier:)` is well-defined and idempotent.

## Out-of-scope follow-ups (for after this lands)

- UI string localization via `Localizable.xcstrings`.
- Per-locale onboarding sample (or an "I prefer X language" question on step 1).
- Automatic language detection from a brief audio probe (CoreML language-ID model).
- Apple SpeechAnalyzer (iOS 26+) backend behind `#available` gate — would lift accuracy for all locales.
- Per-locale custom word lists if user feedback warrants.
