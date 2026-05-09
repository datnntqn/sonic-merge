# Multi-Language Smart Cut Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Smart Cut analyze non-English audio. Per-session `SmartCutSession.localeIdentifier`, `LanguagePill` + `LocalePicker` UI, and per-locale `FillerLibrary` default-off lists for **English / Spanish / Portuguese / French**. UI strings and onboarding sample stay English (deferred).

**Architecture:** Locale lives on `SmartCutSession` (SwiftData lightweight migration adds `localeIdentifier: String?`). `SmartCutViewModel` resolves it at analyze time and threads it through `SmartCutService.analyze(... locale:)`. `TranscriptionService` is constructed per-analyze with the locale (no per-call API churn). `FillerLibrary` gains per-locale default-off lists. Background-resume honors the locale via a new field on the persisted `TranscriptionState`. `BackgroundTranscriptionTask` reads the persisted locale rather than doing a SwiftData lookup — simpler, avoids ModelContainer plumbing in the BG path.

**Tech Stack:** Swift 6, SwiftUI, SwiftData (`@Model`), AVFoundation, Speech.framework (`SFSpeechRecognizer.supportedLocales()`). iOS 17.0 deployment floor. Swift Testing for new tests.

**Spec:** `docs/superpowers/specs/2026-05-09-multi-language-smart-cut-design.md`

**Build/test commands** (from repo root, absolute paths):

```bash
# Build
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5

# Single test suite
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/<SuiteName> test 2>&1 | tail -10

# Full suite (FAIL=5 baseline expected)
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

**Architectural deviations from the spec, locked in here:**

1. **Background-resume locale via `TranscriptionState`, not SwiftData lookup.** The spec floated "BackgroundTranscriptionTask does a SwiftData lookup for session.localeIdentifier." Cleaner alternative: add `localeIdentifier: String?` to `TranscriptionState` (already persisted by chunk in `cachesDirectory/SmartCut/<hash>.transcription-state.json`). `TranscriptionService` writes it on first save; the BG task reads it on resume. No ModelContainer plumbing in the BG path.

2. **`SmartCutService` keeps its `transcriptionService` field as a stub-friendly seam**, but `analyze(... locale:)` constructs a fresh `TranscriptionService(locale:)` for each non-default locale and only uses the injected stub when the locale is the init default. Tests that pass a stub still work; production gets per-call locale. Implementation detail covered in Task 2.1.

---

## Chunk 1: Data layer foundation (locale fields + per-locale FillerLibrary)

**Why this chunk:** Lay the persistence + library foundation before any service or UI code touches it. Each task ends with a passing build and tests; nothing is exposed to the user yet.

**At end of chunk:** `SmartCutSession` and `TranscriptionState` carry `localeIdentifier`; `FillerLibrary` returns per-locale defaults. No behavior change for existing English sessions (all new fields default to nil).

### Task 1.1: Add `localeIdentifier` to `SmartCutSession`

**Files:**
- Modify: `SonicMerge/Models/SmartCutSession.swift`

- [ ] **Step 1.1.1: Add the new optional field**

In `SonicMerge/Models/SmartCutSession.swift`, locate the existing `var editListJSON: Data?` line. Insert this property immediately after:

```swift
    /// BCP-47 locale identifier for Smart Cut analysis (e.g. "en-US", "es-ES").
    /// `nil` (the default for fresh sessions and pre-migration sessions) resolves
    /// to the device's preferred language at analyze time, falling back to "en-US".
    var localeIdentifier: String?
```

- [ ] **Step 1.1.2: Update the model's initializer to accept the new field with a `nil` default**

Find the `init(...)` of `SmartCutSession`. Add `localeIdentifier: String? = nil` as the last parameter and assign `self.localeIdentifier = localeIdentifier` inside the body.

- [ ] **Step 1.1.3: Build to confirm SwiftData accepts the addition**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. SwiftData's lightweight migration handles the addition of an optional field automatically — no schema-version bump required.

- [ ] **Step 1.1.4: Commit**

```bash
git add SonicMerge/Models/SmartCutSession.swift
git commit -m "feat(smart-cut): add localeIdentifier field to SmartCutSession

SwiftData lightweight migration. Optional String, default nil. nil
resolves to device preferred language at analyze time (handled in a
later task). Existing sessions are byte-for-byte unaffected.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 1.2: Add `localeIdentifier` to `TranscriptionState`

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Models/TranscriptionState.swift`

This is what lets the background-resume path (Task 2.4) honor the session's locale without doing a SwiftData lookup.

- [ ] **Step 1.2.1: Add the new field**

In `SonicMerge/Features/SmartCut/Models/TranscriptionState.swift`, find the existing `let sourceHash: String` line. Insert this property immediately after:

```swift
    /// BCP-47 locale identifier the recognizer used for this state. Persisted
    /// so background-resume (BackgroundTranscriptionTask) can construct the
    /// recognizer with the same locale, avoiding a SwiftData lookup. `nil`
    /// for pre-migration cached state JSON — read sites fall back to "en-US".
    let localeIdentifier: String?
```

- [ ] **Step 1.2.2: Update the initializer**

Find `init(sourceHash:sourceDuration:chunkDurationSeconds:completedChunkCount:recognizedSegments:isComplete:)` (or whatever the synthesized memberwise init looks like — `TranscriptionState` is a struct with `let` fields, so Swift synthesizes the memberwise init). Either:

(a) **No change required** if the project relies on synthesized memberwise init AND all callers can be updated to pass `localeIdentifier:`. Search for `TranscriptionState(` and update each callsite to pass `localeIdentifier:`.

(b) **Add an explicit init** with `localeIdentifier: String? = nil` so existing callsites continue to compile without edits. Recommended:

```swift
    init(sourceHash: String,
         sourceDuration: TimeInterval,
         chunkDurationSeconds: TimeInterval,
         completedChunkCount: Int,
         recognizedSegments: [RecognizedSegment],
         isComplete: Bool,
         localeIdentifier: String? = nil) {
        self.sourceHash = sourceHash
        self.sourceDuration = sourceDuration
        self.chunkDurationSeconds = chunkDurationSeconds
        self.completedChunkCount = completedChunkCount
        self.recognizedSegments = recognizedSegments
        self.isComplete = isComplete
        self.localeIdentifier = localeIdentifier
    }
```

Use approach (b) — minimizes downstream churn.

- [ ] **Step 1.2.3: Build**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. JSON decoding of older `*.transcription-state.json` files (no `localeIdentifier` key) decodes the optional as nil — defensive by Swift's standard `Codable` semantics.

- [ ] **Step 1.2.4: Run existing TranscriptionStateTests**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/TranscriptionStateTests test 2>&1 | tail -10
```

Expected: all tests pass. The new optional field with default `nil` is back-compat with existing JSON fixtures.

- [ ] **Step 1.2.5: Commit**

```bash
git add SonicMerge/Features/SmartCut/Models/TranscriptionState.swift
git commit -m "feat(smart-cut): add localeIdentifier to TranscriptionState

Persists the recognizer locale alongside chunk progress so
BackgroundTranscriptionTask can resume with the same locale on
re-entry. Optional with default nil; older cached state JSON files
without this key decode as nil and the read sites fall back to en-US.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 1.3: Per-locale `FillerLibrary` defaults + tests

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Models/FillerLibrary.swift`
- Test: `SonicMergeTests/Features/SmartCut/FillerLibraryLocaleTests.swift`

- [ ] **Step 1.3.1: Write the failing tests**

Create `SonicMergeTests/Features/SmartCut/FillerLibraryLocaleTests.swift`:

```swift
import Testing
import Foundation
@testable import SonicMerge

struct FillerLibraryLocaleTests {

    private func freshLibrary() -> FillerLibrary {
        let suite = "FillerLibraryLocaleTests-\(UUID().uuidString)"
        return FillerLibrary(defaults: UserDefaults(suiteName: suite)!)
    }

    @Test func englishDefaultsForEnUS() {
        let lib = freshLibrary()
        let words = lib.defaultOffWords(for: Locale(identifier: "en-US"))
        #expect(words.contains("you know"))
        #expect(words.contains("like"))
    }

    @Test func englishDefaultsForEnGB() {
        // Any en-* region falls back to en defaults.
        let lib = freshLibrary()
        let words = lib.defaultOffWords(for: Locale(identifier: "en-GB"))
        #expect(words.contains("you know"))
    }

    @Test func spanishDefaultsForEsES() {
        let lib = freshLibrary()
        let words = lib.defaultOffWords(for: Locale(identifier: "es-ES"))
        #expect(words.contains("este"))
        #expect(words.contains("o sea"))
    }

    @Test func spanishDefaultsForEsMX() {
        // Any es-* region falls back to es defaults.
        let lib = freshLibrary()
        let words = lib.defaultOffWords(for: Locale(identifier: "es-MX"))
        #expect(words.contains("este"))
    }

    @Test func portugueseDefaultsForPtBR() {
        let lib = freshLibrary()
        let words = lib.defaultOffWords(for: Locale(identifier: "pt-BR"))
        #expect(words.contains("tipo"))
        #expect(words.contains("né"))
    }

    @Test func frenchDefaultsForFrFR() {
        let lib = freshLibrary()
        let words = lib.defaultOffWords(for: Locale(identifier: "fr-FR"))
        #expect(words.contains("euh"))
        #expect(words.contains("du coup"))
    }

    @Test func emptyDefaultsForKorean() {
        let lib = freshLibrary()
        let words = lib.defaultOffWords(for: Locale(identifier: "ko-KR"))
        #expect(words.isEmpty)
    }

    @Test func customWordsAppearAcrossAllLocales() {
        var lib = freshLibrary()
        lib.addCustom("anyway")
        let en = lib.allWords(for: Locale(identifier: "en-US"))
        let es = lib.allWords(for: Locale(identifier: "es-ES"))
        let ko = lib.allWords(for: Locale(identifier: "ko-KR"))
        #expect(en.contains("anyway"))
        #expect(es.contains("anyway"))
        #expect(ko.contains("anyway"))
    }

    @Test func removingDefaultPersistsAcrossLocales() {
        // Spec: customWords + removedDefaults are global. Removing "tipo" while
        // pt-BR removes it everywhere — including es-ES (which also has "tipo").
        var lib = freshLibrary()
        lib.remove("tipo")
        let pt = lib.allWords(for: Locale(identifier: "pt-BR"))
        let es = lib.allWords(for: Locale(identifier: "es-ES"))
        #expect(!pt.contains("tipo"))
        #expect(!es.contains("tipo"))
    }
}
```

- [ ] **Step 1.3.2: Run the tests — verify build error**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/FillerLibraryLocaleTests test 2>&1 | tail -10
```

Expected: build error `cannot find member 'defaultOffWords(for:)' on type 'FillerLibrary'` (or similar).

- [ ] **Step 1.3.3: Refactor `FillerLibrary`**

In `SonicMerge/Features/SmartCut/Models/FillerLibrary.swift`, replace the existing `defaultOffWords` constant with a per-locale dictionary and add the locale-aware accessors. The full updated file content:

```swift
import Foundation

/// Words Smart Cut considers fillers. Two tiers:
/// - `defaultOnWords` — shipped, on by default in EditList (verbal hesitations only).
/// - `defaultOffWords(for:)` — shipped, off by default; per-locale.
/// User additions land in `customWords` (off by default).
/// User can also remove default words; their removal is persisted globally
/// (across locales — see file-header rationale in
/// docs/superpowers/specs/2026-05-09-multi-language-smart-cut-design.md
/// "Per-locale custom word lists" Non-Goal).
struct FillerLibrary: Equatable {
    let defaults: UserDefaults

    /// Empty by default. The on-device SFSpeechRecognizer is unreliable on
    /// short hesitation tokens ("um", "uh", "ah", "er", "oh") — it frequently
    /// drops or mistags them, producing inconsistent Smart Cut results that
    /// erode user trust. Rather than ship false confidence, ship nothing
    /// on by default and let the user opt in via the Edit list sheet
    /// (custom-added words are off-by-default; users explicitly enable them).
    let defaultOnWords: [String] = []

    /// SPEC: standard set, off by default — pulled in when the user opts in.
    /// Lookup by language code only (region-insensitive: "en-GB" → "en").
    /// "como" and "tipo" in Spanish are flagged as high-collision (they have
    /// common non-filler senses); manual QA verifies the false-positive rate.
    private static let defaultsByLanguage: [String: [String]] = [
        "en": ["like", "you know", "sort of", "basically", "actually", "literally"],
        "es": ["este", "eh", "o sea", "pues", "tipo", "como"],
        "pt": ["tipo", "né", "então", "sabe", "meio que"],
        "fr": ["euh", "ben", "genre", "en fait", "du coup", "tu sais"]
    ]

    private let customKey = "SmartCut.FillerLibrary.customWords"
    private let removedKey = "SmartCut.FillerLibrary.removedDefaults"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var customWords: [String] {
        defaults.array(forKey: customKey) as? [String] ?? []
    }

    var removedDefaults: Set<String> {
        Set(defaults.array(forKey: removedKey) as? [String] ?? [])
    }

    /// Default-off list for the given locale. Falls back to `[]` for
    /// uncurated languages (callers should still get pause detection +
    /// custom words elsewhere).
    func defaultOffWords(for locale: Locale) -> [String] {
        let code = locale.language.languageCode?.identifier ?? "en"
        return Self.defaultsByLanguage[code] ?? []
    }

    /// Combined list (per-locale defaults minus removed + global custom),
    /// preserving order. Deduped against the kept-defaults set.
    func allWords(for locale: Locale) -> [String] {
        let removed = removedDefaults
        let kept = (defaultOnWords + defaultOffWords(for: locale)).filter { !removed.contains($0) }
        let keptSet = Set(kept)
        let uniqueCustom = customWords.filter { !keptSet.contains($0) }
        return kept + uniqueCustom
    }

    func isEnabledByDefault(_ word: String) -> Bool {
        defaultOnWords.contains(word)
    }

    mutating func addCustom(_ word: String) {
        let normalized = word.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else { return }
        // Dedupe against ALL curated defaults (across all locales) plus existing
        // custom — adding "tipo" while editing English shouldn't collide with
        // the Spanish/Portuguese curated default.
        let allDefaultWords = Set(Self.defaultsByLanguage.values.flatMap { $0 })
        guard !allDefaultWords.contains(normalized) else { return }
        guard !customWords.contains(normalized) else { return }
        var current = customWords
        current.append(normalized)
        defaults.set(current, forKey: customKey)
    }

    mutating func remove(_ word: String) {
        let normalized = word.lowercased().trimmingCharacters(in: .whitespaces)
        if customWords.contains(normalized) {
            defaults.set(customWords.filter { $0 != normalized }, forKey: customKey)
            return
        }
        // If the word is a curated default (in any locale), persist the
        // removal globally — matches the spec's global-state-for-removals
        // decision. Re-curated defaults across all locales hide it.
        let allDefaultWords = Set(Self.defaultsByLanguage.values.flatMap { $0 })
        if allDefaultWords.contains(normalized) {
            var removed = removedDefaults
            removed.insert(normalized)
            defaults.set(Array(removed), forKey: removedKey)
        }
    }

    /// Phase 12 (existing API): clear the persisted set of removed default
    /// words. Custom words are not affected.
    mutating func restoreAllDefaults() {
        defaults.removeObject(forKey: removedKey)
    }
}
```

> **Important behavioral changes from the previous file:**
> 1. The single `let defaultOffWords` array is gone. There is no longer a global default-off list — every read goes through `defaultOffWords(for:)`.
> 2. `allWords` (no parameter) is gone. Callers must pass a locale: `allWords(for:)`.
> 3. `addCustom` and `remove` now check against ALL curated defaults across all locales (previously only checked the single English list). This means a user can't accidentally re-add "tipo" as a custom because it's already a Portuguese curated default.
>
> **Find every existing caller** of the deleted APIs:
>
> ```bash
> grep -rn "library.allWords\|library\.defaultOffWords\|FillerLibrary().*allWords\|.allWords[^(]" \
>   /Users/datnnt/Desktop/DatNNT/App/SonicMerge --include="*.swift"
> ```
>
> Each callsite must either pass a `Locale` (for `allWords(for:)`) or be deleted. Tasks 2.1, 2.3, 3.4 each handle a specific callsite.

- [ ] **Step 1.3.4: Run the new tests — verify they pass**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/FillerLibraryLocaleTests test 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **` with 9 tests passing.

> **Build will fail elsewhere** at this point because callers of the old `library.allWords` (no parameter) haven't been migrated yet. That's intentional — Tasks 2.1 / 2.3 / 3.4 fix those. You'll see compile errors in `SmartCutService.swift`, `SmartCutViewModel.swift`, etc. Don't try to fix them in this task.
>
> If you want to confirm the FillerLibrary tests pass standalone (the test target may not build because the test target depends on the main target which now has compile errors), you can temporarily add an `allWords(for:)` no-op alias for the old `allWords`, but it's cleaner to **proceed straight to Task 2.1** and let the chunk-2 cascade fix everything. The plan reviewer will catch any missed callsite.

- [ ] **Step 1.3.5: Delete the existing `FillerLibraryTests.swift`**

`SonicMergeTests/Features/SmartCut/FillerLibraryTests.swift` (existing) reads `lib.defaultOffWords` and `lib.allWords` (no-arg) — both deleted in Step 1.3.3. Rather than migrate each test (their assertions are now subsumed by the new per-locale tests), delete the file:

```bash
git rm SonicMergeTests/Features/SmartCut/FillerLibraryTests.swift
```

The behavioral coverage that file provided (custom-add dedup, removal persistence, restoreAllDefaults) is preserved by the new `FillerLibraryLocaleTests` cases (`customWordsAppearAcrossAllLocales`, `removingDefaultPersistsAcrossLocales`) plus implicit coverage from integration tests.

Verify no other tests reference the deleted accessors:

```bash
grep -rn "library\.allWords\b\|library\.defaultOffWords\b\|\.allWords[^(]" \
  /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMergeTests --include="*.swift"
```

Expected: zero matches.

- [ ] **Step 1.3.6: Commit**

```bash
git add SonicMerge/Features/SmartCut/Models/FillerLibrary.swift \
        SonicMergeTests/Features/SmartCut/FillerLibraryLocaleTests.swift \
        SonicMergeTests/Features/SmartCut/FillerLibraryTests.swift
git commit -m "feat(smart-cut): per-locale FillerLibrary defaults

Replace the single English default-off list with a per-language
dictionary keyed by Locale.language.languageCode. Curated v1 lists for
en, es, pt, fr; other locales return [] (caller still gets pause
detection + custom words). Custom words and removed-defaults stay
global per spec Non-Goals.

addCustom/remove now check against ALL curated defaults across
locales (not just one) so a user editing in English can't add 'tipo'
as a custom — it's already a pt/es default.

Tests: 9 cases covering region-fallback, uncurated-locale empty list,
global custom across locales, global remove across locales.

Caller sites (SmartCutService, SmartCutViewModel, etc.) will fail to
compile until tasks 2.1/2.3/3.4 land — intentional, fixed in chunk 2.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

**End of Chunk 1.** Stop here for plan-document review before continuing to Chunk 2.

---

## Chunk 2: Service-layer wiring

**Why this chunk:** Plumbs locale through the analyze pipeline. After this chunk, the existing analyze flow works with a session locale (defaulting to nil → en-US, so legacy sessions are unaffected). UI still has no language picker — that's Chunk 3.

**At end of chunk:** Build green. Existing `SmartCutHomeViewGatingTests` and `SmartCutServicePauseThresholdTests` still pass. New `TranscriptionServiceLocaleTests` verifies the supportedLocales fallback. Manual smoke: open an existing English session, analyze, get the same result as before.

### Task 2.1: `SmartCutService.analyze(... locale:)` threads locale to TranscriptionService + FillerDetector

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Services/SmartCutService.swift`

- [ ] **Step 2.1.1: Update the public method signature**

In `SonicMerge/Features/SmartCut/Services/SmartCutService.swift`, change:

```swift
    func analyze(input: URL, pauseThreshold: TimeInterval) -> AsyncThrowingStream<Update, Error> {
```

to:

```swift
    func analyze(input: URL,
                 pauseThreshold: TimeInterval,
                 locale: Locale) -> AsyncThrowingStream<Update, Error> {
```

- [ ] **Step 2.1.2: Update the actor's `transcriptionService` field to be locale-aware**

Today the actor holds `private let transcriptionService: any TranscriptionServicing` initialized at construction with a default `TranscriptionService()`. After this task: production callers construct one `TranscriptionService` per analyze with the requested locale. Stub injection (used by tests) keeps the existing field for back-compat.

Change the actor body. The existing init takes `transcriptionService: any TranscriptionServicing = TranscriptionService()`. We keep that — it's the stub seam. But inside `analyze`, we swap: if the caller passed a real (non-stubbed) production `TranscriptionService`, we ignore it and construct a fresh `TranscriptionService(locale:)`. We can't easily distinguish stub from real, so use a cleaner approach: change `transcriptionService` to a closure-based factory.

Replace:

```swift
    private let transcriptionService: any TranscriptionServicing

    init(library: FillerLibrary,
         transcriptionService: any TranscriptionServicing = TranscriptionService()) {
        self.library = library
        self.transcriptionService = transcriptionService
    }
```

with:

```swift
    private let transcriptionServiceFactory: (Locale) -> any TranscriptionServicing

    init(library: FillerLibrary,
         transcriptionServiceFactory: @escaping (Locale) -> any TranscriptionServicing
            = { locale in TranscriptionService(locale: locale) }) {
        self.library = library
        self.transcriptionServiceFactory = transcriptionServiceFactory
    }
```

- [ ] **Step 2.1.3: Use the factory + per-locale words inside `analyze`**

Inside `analyze`, replace the existing `for try await state in await transcriptionService.transcribe(input: input)` loop's setup. Update the implementation to:

```swift
    func analyze(input: URL,
                 pauseThreshold: TimeInterval,
                 locale: Locale) -> AsyncThrowingStream<Update, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let transcriptionService = transcriptionServiceFactory(locale)
                    var lastState: TranscriptionState?
                    for try await state in await transcriptionService.transcribe(input: input) {
                        continuation.yield(.progress(state.progressFraction))
                        lastState = state
                    }
                    guard let state = lastState else {
                        continuation.finish(throwing: NSError(domain: "SmartCutService", code: -1))
                        return
                    }
                    let fillers = FillerDetector.detect(
                        in: state.recognizedSegments,
                        words: library.allWords(for: locale),
                        enabledByDefault: { library.isEnabledByDefault($0) }
                    )
                    let pauses = PauseDetector.detect(
                        in: state.recognizedSegments,
                        totalDuration: state.sourceDuration,
                        threshold: pauseThreshold
                    )
                    let editList = EditList(fillers: fillers, pauses: pauses)
                    continuation.yield(.completed(editList,
                                                   segments: state.recognizedSegments,
                                                   duration: state.sourceDuration))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
```

- [ ] **Step 2.1.4: Build to surface remaining callsites**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -20
```

Expected: build fails with errors at:
- `SonicMerge/Features/SmartCut/SmartCutViewModel.swift` — `service.analyze(input:pauseThreshold:)` is missing `locale:` argument.
- `SonicMergeTests/Features/SmartCut/SmartCutServiceIntegrationTests.swift` and `SmartCutServicePauseThresholdTests.swift` — test instantiations still pass `transcriptionService:` parameter (now `transcriptionServiceFactory:`).

These get fixed in Tasks 2.3 (VM) and 2.5 (test fixups).

- [ ] **Step 2.1.5: Commit**

```bash
git add SonicMerge/Features/SmartCut/Services/SmartCutService.swift
git commit -m "refactor(smart-cut): SmartCutService.analyze takes locale

Threads locale to a per-analyze TranscriptionService construction (via
factory closure injected at SmartCutService init) and to FillerDetector
via library.allWords(for: locale). Stub seam preserved: tests pass a
factory closure that returns their stub.

Existing analyze callsites (SmartCutViewModel, integration tests) will
fail to compile until tasks 2.3 / 2.5 land — intentional.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.2: `TranscriptionService` validates locale + persists in TranscriptionState + tests

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Services/TranscriptionService.swift`
- Test: `SonicMergeTests/Features/SmartCut/TranscriptionServiceLocaleTests.swift`

- [ ] **Step 2.2.1: Write the failing tests**

Create `SonicMergeTests/Features/SmartCut/TranscriptionServiceLocaleTests.swift`:

```swift
import Testing
import Foundation
import Speech
@testable import SonicMerge

struct TranscriptionServiceLocaleTests {

    /// Pure-data test: the helper that resolves an unsupported locale to en-US.
    /// We test the fallback rule, not the recognizer (avoids the FAIL=5
    /// flake-class).
    @Test func unsupportedLocaleFallsBackToEnUS() {
        let unsupported = Locale(identifier: "xx-YY")  // not a real BCP-47 locale
        let resolved = TranscriptionService.resolveSupportedLocale(unsupported)
        #expect(resolved.identifier == "en-US")
    }

    @Test func supportedLocalePassesThrough() {
        // en-US is always in supportedLocales() on iOS.
        let supported = Locale(identifier: "en-US")
        let resolved = TranscriptionService.resolveSupportedLocale(supported)
        #expect(resolved.identifier == "en-US")
    }

    @Test func spanishPassesThrough() {
        // es-ES is in supportedLocales() — Apple ships Spanish on iOS 17+.
        let supported = Locale(identifier: "es-ES")
        let resolved = TranscriptionService.resolveSupportedLocale(supported)
        #expect(resolved.language.languageCode?.identifier == "es")
    }
}
```

- [ ] **Step 2.2.2: Run the tests — verify build error**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/TranscriptionServiceLocaleTests test 2>&1 | tail -10
```

Expected: build error `cannot find 'resolveSupportedLocale' on type 'TranscriptionService'`.

- [ ] **Step 2.2.3: Add `resolveSupportedLocale` and persist locale in TranscriptionState**

In `SonicMerge/Features/SmartCut/Services/TranscriptionService.swift`, add the static helper near the top of the actor body (above `init`):

```swift
    /// Returns `requested` if it's in `SFSpeechRecognizer.supportedLocales()`,
    /// otherwise returns `Locale(identifier: "en-US")`. Pure data, safe for tests.
    static func resolveSupportedLocale(_ requested: Locale) -> Locale {
        let supported = SFSpeechRecognizer.supportedLocales()
        // Match either by exact identifier OR by language code (so "es-AR" matches
        // when Apple ships "es-ES" — recognizer accepts the variant).
        if supported.contains(requested) { return requested }
        if let code = requested.language.languageCode?.identifier,
           supported.contains(where: { $0.language.languageCode?.identifier == code }) {
            return requested
        }
        return Locale(identifier: "en-US")
    }
```

In `transcribe(input:)`, immediately after `guard let recognizer = SFSpeechRecognizer(locale: locale) else { ... }`, validate (the recognizer init might still succeed for unsupported locales but produce useless results — defense in depth):

```swift
        // Hard-validate against supportedLocales(); fall back to en-US if
        // the requested locale isn't supported (e.g. a session was created
        // on a future iOS that supported a locale a downgrade later doesn't).
        let effectiveLocale = Self.resolveSupportedLocale(self.locale)
        guard let recognizer = SFSpeechRecognizer(locale: effectiveLocale),
              recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }
```

> Replace the existing `SFSpeechRecognizer(locale: locale)` with `SFSpeechRecognizer(locale: effectiveLocale)`. The remainder of the method (isAvailable retry, supportsOnDeviceRecognition check, etc.) stays unchanged.

Then, where `TranscriptionState` is constructed (look for the `state = TranscriptionState(...)` initializer call), pass `localeIdentifier: effectiveLocale.identifier`:

```swift
                    var state = (try? await stateStore.load(sourceHash))
                        ?? TranscriptionState(
                            sourceHash: sourceHash,
                            sourceDuration: totalDuration,
                            chunkDurationSeconds: chunkDurationSeconds,
                            completedChunkCount: 0,
                            recognizedSegments: [],
                            isComplete: false,
                            localeIdentifier: effectiveLocale.identifier
                        )
```

(There's exactly one `TranscriptionState(...)` construction in the file, around line 116. Updates happen by mutating `state` in place — no other construction sites.)

- [ ] **Step 2.2.4: Run the tests — verify they pass**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/TranscriptionServiceLocaleTests test 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **` with 3 tests passing.

- [ ] **Step 2.2.5: Commit**

```bash
git add SonicMerge/Features/SmartCut/Services/TranscriptionService.swift \
        SonicMergeTests/Features/SmartCut/TranscriptionServiceLocaleTests.swift
git commit -m "feat(smart-cut): TranscriptionService validates + persists locale

resolveSupportedLocale: pure helper that returns the requested locale if
it (or its language code) is in SFSpeechRecognizer.supportedLocales(),
falls back to en-US otherwise. Used by transcribe() before constructing
the recognizer, and persisted in TranscriptionState.localeIdentifier so
the BG resume path knows which locale to use.

3 tests cover: unsupported → en-US fallback, en-US passthrough, es-ES
language-code passthrough.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.3: `SmartCutViewModel` resolves session locale + adds `setLocale(_:on:)`

**Files:**
- Modify: `SonicMerge/Features/SmartCut/SmartCutViewModel.swift`

- [ ] **Step 2.3.1: Add `currentLocale` stored property**

In `SonicMerge/Features/SmartCut/SmartCutViewModel.swift`, find the existing `var pauseThreshold: TimeInterval = 1.5` line. Add immediately after:

```swift
    /// Resolved locale used for the next analyze. Set from
    /// `session.localeIdentifier` by the session-driven init; mutated by
    /// `setLocale(_:on:)`. Defaults to the device's preferred language
    /// (filtered through SFSpeechRecognizer.supportedLocales()).
    var currentLocale: Locale = TranscriptionService.resolveSupportedLocale(
        Locale(identifier: Locale.preferredLanguages.first ?? "en-US")
    )
```

- [ ] **Step 2.3.2: Update the session-driven init to read `localeIdentifier`**

In the existing `convenience init(session: SmartCutSession, ...)` body, after `setInput(url: sourceURL)` (~line 113), add:

```swift
        if let stored = session.localeIdentifier, !stored.isEmpty {
            currentLocale = TranscriptionService.resolveSupportedLocale(Locale(identifier: stored))
        }
```

- [ ] **Step 2.3.3: Add `setLocale(_:on:)`**

Add this method on the VM, near `requestReanalyze`:

```swift
    /// Persists a new locale onto the session and invalidates any cached
    /// transcript / edit list. Caller is responsible for `modelContext.save()`
    /// (matches today's `persist(to:)` shape).
    func setLocale(_ identifier: String, on session: SmartCutSession) {
        session.localeIdentifier = identifier
        currentLocale = TranscriptionService.resolveSupportedLocale(Locale(identifier: identifier))
        invalidate()
    }
```

- [ ] **Step 2.3.4: Pass `locale` to `service.analyze(...)`**

Find the existing call (around line 193):

```swift
                for try await update in await service.analyze(input: inputURL, pauseThreshold: pauseThreshold) {
```

Change to:

```swift
                for try await update in await service.analyze(input: inputURL,
                                                              pauseThreshold: pauseThreshold,
                                                              locale: currentLocale) {
```

- [ ] **Step 2.3.5: Build**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -10
```

Expected: build still fails. Remaining errors after this task:

- **Production:** `OnboardingFlow.swift` (constructs `SmartCutService(library:)` and calls `service.analyze(input:pauseThreshold:)`); `IdleSettingsCards.swift` (reads `library.allWords` no-arg); `EditFillerListStudioSheet.swift` (reads `library.allWords` no-arg).
- **Tests:** `SmartCutServiceIntegrationTests.swift`, `SmartCutServicePauseThresholdTests.swift` (need updated factory + `locale:` arg).

OnboardingFlow + IdleSettingsCards get fixed in **Task 2.6**. Tests get fixed in **Task 2.5**. EditFillerListStudioSheet gets fixed in Chunk 3's **Task 3.4**.

- [ ] **Step 2.3.6: Run gating tests — confirm no regression**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/SmartCutHomeViewGatingTests test 2>&1 | tail -10
```

Expected: gating tests pass — they don't touch locale or analyze, so they're unaffected.

> If you can't yet run the full target due to leftover compile errors in `EditFillerListStudioSheet` or the integration tests, **do Task 2.5 first** to unblock the build, then come back to confirm gating tests pass. Tasks 2.5 and 2.4 are order-independent.

- [ ] **Step 2.3.7: Commit**

```bash
git add SonicMerge/Features/SmartCut/SmartCutViewModel.swift
git commit -m "feat(smart-cut): VM threads session locale into analyze

currentLocale resolved at init from session.localeIdentifier (when
non-nil), defaults to device preferred language filtered through
SFSpeechRecognizer.supportedLocales(). setLocale(_:on:) persists +
invalidates. analyze() passes currentLocale to SmartCutService.analyze.

VM does not retain SmartCutSession — caller passes it to setLocale,
matching the existing persist(to:) pattern.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.4: `BackgroundTranscriptionTask` resumes with persisted locale

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Services/BackgroundTranscriptionTask.swift`

- [ ] **Step 2.4.1: Read locale from cached state on resume**

In `SonicMerge/Features/SmartCut/Services/BackgroundTranscriptionTask.swift`, find the existing line `let service = TranscriptionService()`. Replace with:

```swift
                let resumedLocale: Locale = state.localeIdentifier
                    .flatMap { Locale(identifier: $0) }
                    ?? Locale(identifier: "en-US")
                let service = TranscriptionService(locale: resumedLocale)
```

(The `state` variable is already defined a few lines above as the decoded `TranscriptionState`.)

- [ ] **Step 2.4.2: Build**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: build status depends on whether Task 2.5 has run — if not, integration tests still fail. Main app target should be clean.

- [ ] **Step 2.4.3: Run BG task tests — confirm no regression**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/BackgroundTranscriptionTaskTests test 2>&1 | tail -10
```

Expected: existing BG task tests pass. The locale-resume path adds new behavior (read from optional field with nil fallback) but doesn't break the existing flow.

- [ ] **Step 2.4.4: Commit**

```bash
git add SonicMerge/Features/SmartCut/Services/BackgroundTranscriptionTask.swift
git commit -m "feat(smart-cut): BG resume honors persisted locale

Reads localeIdentifier from the decoded TranscriptionState and
constructs TranscriptionService(locale:) accordingly. nil falls back
to en-US — back-compat with cached state JSON written before this
field existed.

Avoids SwiftData lookup from the BG path (would require ModelContainer
plumbing).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.5: Update existing tests for the new SmartCutService factory shape

**Files:**
- Modify: `SonicMergeTests/Features/SmartCut/SmartCutServiceIntegrationTests.swift`
- Modify: `SonicMergeTests/Features/SmartCut/SmartCutServicePauseThresholdTests.swift` (if it exists at that path; otherwise grep for `SmartCutService(transcriptionService:` and update each match)

- [ ] **Step 2.5.1: Find every test that constructs `SmartCutService` with a stub**

```bash
grep -rn "SmartCutService(transcriptionService:" /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMergeTests --include="*.swift"
grep -rn "SmartCutService(library:" /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMergeTests --include="*.swift"
```

- [ ] **Step 2.5.2: Update each callsite from the old `transcriptionService:` parameter to the new factory closure**

Old shape:

```swift
let svc = SmartCutService(library: lib, transcriptionService: stub)
```

New shape:

```swift
let svc = SmartCutService(library: lib, transcriptionServiceFactory: { _ in stub })
```

The closure ignores the locale argument because the stub doesn't care.

- [ ] **Step 2.5.3: Update each `service.analyze(input:pauseThreshold:)` call to pass `locale:`**

```bash
grep -rn "\.analyze(input:" /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMergeTests --include="*.swift"
```

For each match, add `locale: Locale(identifier: "en-US")` as the third argument.

- [ ] **Step 2.5.4: Build the full test target**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO build-for-testing 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`. (The remaining `EditFillerListStudioSheet` `library.allWords` callsite gets fixed in Task 3.4. If that callsite blocks the build here too, jump ahead to Task 3.4 first — Tasks 2.5 and 3.4 are order-independent.)

- [ ] **Step 2.5.5: Run the full suite — confirm `FAIL=5` baseline preserved**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`. Baseline names:
- `compositionWithCrossfadeHasNonNilAudioMix`
- `testFileCopyToClipsDirectory`
- `testLargeFileCopyDoesNotCrash`
- `testPendingKeyWrittenAndCleared`
- `testPositionPreservedOnSwitch`

- [ ] **Step 2.5.6: Commit**

```bash
git add SonicMergeTests/Features/SmartCut/
git commit -m "test(smart-cut): migrate tests to factory + locale params

SmartCutService(transcriptionService:) became (transcriptionServiceFactory:).
analyze(input:pauseThreshold:) became analyze(input:pauseThreshold:locale:).
Existing tests pass an en-US locale and a closure that ignores locale.

Full suite at FAIL=5 baseline.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.6: Fix remaining production callsites of removed FillerLibrary APIs

**Files:**
- Modify: `SonicMerge/Features/Onboarding/OnboardingFlow.swift`
- Modify: `SonicMerge/Features/SmartCut/Views/Studio/IdleSettingsCards.swift`

After Task 1.3 deleted `FillerLibrary.allWords` (no-arg) and Task 2.1 changed `SmartCutService.analyze` to require `locale:` + factory closure, two production callsites still need migration. Both unrelated to UI-facing locale picking — they're internal usages that just need an explicit locale.

- [ ] **Step 2.6.1: Update `OnboardingFlow.swift`**

The onboarding flow analyzes a hardcoded English sample. Both lines need updating.

```bash
grep -n "SmartCutService(library:\|service\.analyze(input:" \
  /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMerge/Features/Onboarding/OnboardingFlow.swift
```

Expected: 2 matches around lines 493 and 496.

Edit:

- The `SmartCutService(library: libraryStore.library)` callsite stays as-is — the factory has a default that constructs `TranscriptionService(locale:)` per analyze, so no caller change is needed for the constructor.
- The `service.analyze(input: url, pauseThreshold: 1.5)` callsite needs `locale: Locale(identifier: "en-US")`:

  ```swift
  for try await update in service.analyze(input: url,
                                          pauseThreshold: 1.5,
                                          locale: Locale(identifier: "en-US")) {
  ```

- [ ] **Step 2.6.2: Update `IdleSettingsCards.swift`**

The idle scaffold shows the user their current filler list. Find the `library.allWords` callsite:

```bash
grep -n "library\.allWords\|\.allWords" \
  /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMerge/Features/SmartCut/Views/Studio/IdleSettingsCards.swift
```

Expected: 1 match around line 90.

The component receives or has access to the FillerLibrary; it now also needs the active locale. Add a `locale: Locale` parameter on `IdleSettingsCards.init` and update the single call site (search `IdleSettingsCards(`):

```bash
grep -rn "IdleSettingsCards(" /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMerge --include="*.swift"
```

The caller is `SmartCutStudioContainer` (in `idleScaffold`). Pass `locale: vm.currentLocale`. Inside `IdleSettingsCards`, replace `library.allWords` with `library.allWords(for: locale)`.

- [ ] **Step 2.6.3: Build**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **` for the main app target. (Test target may still fail until Task 2.5 ran; if Task 2.5 completed before this task, the full build is now green.)

- [ ] **Step 2.6.4: Commit**

```bash
git add SonicMerge/Features/Onboarding/OnboardingFlow.swift \
        SonicMerge/Features/SmartCut/Views/Studio/IdleSettingsCards.swift \
        SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift
git commit -m "feat(smart-cut): migrate remaining production callsites

OnboardingFlow.swift: pass locale=en-US to service.analyze() — sample
is hardcoded English.

IdleSettingsCards.swift: take a Locale parameter, read
library.allWords(for: locale). Container's idleScaffold passes
vm.currentLocale.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

**End of Chunk 2.** Stop here for plan-document review before continuing to Chunk 3.

---

## Chunk 3: UI layer (LanguagePill, LocalePicker, Edit-list sheet locale-awareness)

**Why this chunk:** Surfaces the locale to users. After this chunk, a user can pick a language for any session, see which language's defaults the Edit Filler List sheet is showing, and the studio renders the language pill in every state.

**At end of chunk:** Build green, FAIL=5 preserved, manual smoke test of the picker passes.

### Task 3.1: `LanguagePill` view

**Files:**
- Create: `SonicMerge/Features/SmartCut/Views/Studio/LanguagePill.swift`

- [ ] **Step 3.1.1: Write the view**

Create `SonicMerge/Features/SmartCut/Views/Studio/LanguagePill.swift`:

```swift
// SonicMerge/Features/SmartCut/Views/Studio/LanguagePill.swift
//
// Compact tappable pill showing the session's analysis language. Tap opens
// LocalePicker. Pinned to ENGLISH names regardless of device locale until
// full UI localization lands (see spec Non-Goals — visual consistency with
// the rest of the English-only studio).
//

import SwiftUI

struct LanguagePill: View {
    let localeIdentifier: String  // BCP-47, e.g. "es-ES"
    let onTap: () -> Void
    var isDisabled: Bool = false

    @Environment(\.sonicMergeSemantic) private var semantic

    private var displayName: String {
        Locale(identifier: "en")
            .localizedString(forIdentifier: localeIdentifier)
            ?? localeIdentifier
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 13, weight: .semibold))
                    .accessibilityHidden(true)
                Text("Language: ")
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
                + Text(displayName)
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
                    .fontWeight(.semibold)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
                    .accessibilityHidden(true)
            }
            .font(.system(.subheadline, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color(uiColor: semantic.surfaceCard))
            )
            .overlay(
                Capsule().strokeBorder(Color(uiColor: .systemGray5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
        .accessibilityLabel("Language: \(displayName). Tap to change.")
    }
}
```

- [ ] **Step 3.1.2: Build**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. No callers yet.

- [ ] **Step 3.1.3: Commit**

```bash
git add SonicMerge/Features/SmartCut/Views/Studio/LanguagePill.swift
git commit -m "feat(smart-cut): LanguagePill component

Pill displaying the session's analysis language with a chevron-down.
Tap → onTap closure (host opens LocalePicker). Names pinned to English
until full UI localization lands. Disabled state for the .analyzing
studio state.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3.2: `LocalePicker` sheet

**Files:**
- Create: `SonicMerge/Features/SmartCut/Views/Studio/LocalePicker.swift`

- [ ] **Step 3.2.1: Write the view**

Create `SonicMerge/Features/SmartCut/Views/Studio/LocalePicker.swift`:

```swift
// SonicMerge/Features/SmartCut/Views/Studio/LocalePicker.swift
//
// Sheet listing all locales SFSpeechRecognizer supports. Sorted by user's
// preferred-languages first ("Suggested" header), then alphabetical. Names
// pinned to English (see LanguagePill rationale).
//

import SwiftUI
import Speech

struct LocalePicker: View {

    let currentIdentifier: String
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.sonicMergeSemantic) private var semantic

    @State private var searchText = ""

    private var allLocales: [Locale] {
        Array(SFSpeechRecognizer.supportedLocales())
    }

    private var suggested: [Locale] {
        // Locales whose language code matches the user's preferredLanguages.
        let preferredCodes = Locale.preferredLanguages
            .compactMap { Locale(identifier: $0).language.languageCode?.identifier }
        let preferredSet = Set(preferredCodes)
        return allLocales
            .filter { preferredSet.contains($0.language.languageCode?.identifier ?? "") }
            .sorted { displayName($0) < displayName($1) }
    }

    private var others: [Locale] {
        let suggestedSet = Set(suggested.map(\.identifier))
        return allLocales
            .filter { !suggestedSet.contains($0.identifier) }
            .sorted { displayName($0) < displayName($1) }
    }

    private var filteredSuggested: [Locale] {
        guard !searchText.isEmpty else { return suggested }
        return suggested.filter { matches(searchText, in: $0) }
    }

    private var filteredOthers: [Locale] {
        guard !searchText.isEmpty else { return others }
        return others.filter { matches(searchText, in: $0) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !filteredSuggested.isEmpty {
                    Section("Suggested") {
                        ForEach(filteredSuggested, id: \.identifier) { locale in
                            row(locale)
                        }
                    }
                }
                if !filteredOthers.isEmpty {
                    Section(filteredSuggested.isEmpty ? "" : "All languages") {
                        ForEach(filteredOthers, id: \.identifier) { locale in
                            row(locale)
                        }
                    }
                }
            }
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search languages")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color(uiColor: semantic.accentAction))
                }
            }
        }
    }

    private func row(_ locale: Locale) -> some View {
        Button {
            onPick(locale.identifier)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName(locale))
                        .foregroundStyle(Color(uiColor: semantic.textPrimary))
                    Text(locale.identifier)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                }
                Spacer()
                if locale.identifier == currentIdentifier {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color(uiColor: semantic.accentAction))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func displayName(_ locale: Locale) -> String {
        Locale(identifier: "en")
            .localizedString(forIdentifier: locale.identifier)
            ?? locale.identifier
    }

    private func matches(_ query: String, in locale: Locale) -> Bool {
        let q = query.lowercased()
        return displayName(locale).lowercased().contains(q)
            || locale.identifier.lowercased().contains(q)
    }
}
```

- [ ] **Step 3.2.2: Build**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. No callers yet.

- [ ] **Step 3.2.3: Commit**

```bash
git add SonicMerge/Features/SmartCut/Views/Studio/LocalePicker.swift
git commit -m "feat(smart-cut): LocalePicker sheet

Sheet listing SFSpeechRecognizer.supportedLocales() in two sections:
'Suggested' (matches user's preferredLanguages) + 'All languages'
alphabetical. Search bar filters by English-pinned localized name or
BCP-47 identifier. Tap row → onPick(identifier) + dismiss.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3.3: Mount `LanguagePill` in `SmartCutStudioContainer` (all states)

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift`

- [ ] **Step 3.3.1: Add picker presentation state**

In `SmartCutStudioContainer`, find the existing `@State private var openCategory: String?` declaration. Add immediately after:

```swift
    @State private var showLocalePicker = false
```

- [ ] **Step 3.3.2: Wire the pill into the container's outer layout**

Locate the studio container's `body` — it's a top-level `VStack` that switches on `vm.state` to render different scaffolds. Wrap the existing body content with the LanguagePill and the LocalePicker sheet at the OUTER VStack level (so the pill is visible in every state).

Insert the pill above the existing state-switch content:

```swift
        VStack(spacing: 12) {
            LanguagePill(
                localeIdentifier: vm.currentLocale.identifier,
                onTap: { showLocalePicker = true },
                isDisabled: {
                    if case .analyzing = vm.state { return true }
                    return false
                }()
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)

            // ... existing state-switch content here ...
        }
        .sheet(isPresented: $showLocalePicker) {
            LocalePicker(
                currentIdentifier: vm.currentLocale.identifier,
                onPick: { identifier in
                    vm.setLocale(identifier, on: session)
                }
            )
        }
```

> **Important:** `setLocale(_:on:)` requires `session: SmartCutSession`. The container needs access to it. If the container doesn't already receive a `SmartCutSession`, **add it as a parameter** on `SmartCutStudioContainer.init` and update the single callsite in `SmartCutSessionView` (the only caller).
>
> The view file `SmartCutSessionView.swift` instantiates the container — search:
>
> ```bash
> grep -rn "SmartCutStudioContainer(" /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMerge --include="*.swift"
> ```
>
> Pass the session: `SmartCutStudioContainer(vm: vm, library: $library, session: session)`.

- [ ] **Step 3.3.3: Build**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. The session-threading change to `SmartCutStudioContainer` ripples through the single `SmartCutSessionView` callsite.

- [ ] **Step 3.3.4: Commit**

```bash
git add SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift \
        SonicMerge/Features/SmartCut/Views/Home/SmartCutSessionView.swift
git commit -m "feat(smart-cut): mount LanguagePill across studio states

Pill renders at the outer VStack of SmartCutStudioContainer so it
appears in idle/analyzing/results/applied/stale/error. Disabled in
.analyzing. Tap opens LocalePicker sheet → vm.setLocale(_:on:) →
session is persisted, cached transcript invalidated, view re-enters
.idle so user can re-analyze in the new locale.

Container now takes the SmartCutSession as a constructor parameter so
it can pass it to setLocale. SmartCutSessionView updated.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3.4: `EditFillerListStudioSheet` reads per-locale defaults + footer

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Studio/EditFillerListStudioSheet.swift`

- [ ] **Step 3.4.1: Find the existing `library.allWords` callsite**

```bash
grep -n "library\.allWords\|\.allWords\b" /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMerge/Features/SmartCut/Views/Studio/EditFillerListStudioSheet.swift
```

There should be 1–3 matches.

- [ ] **Step 3.4.2: Pass locale into the sheet**

Add a `locale: Locale` parameter to `EditFillerListStudioSheet.init` (or, if the sheet already takes a `vm: SmartCutViewModel` ref, just read `vm.currentLocale` inside). The simpler change: take a `Locale` parameter so the sheet stays VM-agnostic.

Update each `library.allWords` call to `library.allWords(for: locale)`.

- [ ] **Step 3.4.3: Add the footer line**

Find the end of the sheet body (likely a `VStack` or `List`). Add this footer:

```swift
            VStack(spacing: 4) {
                Text("Showing default words for ")
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
                + Text(Locale(identifier: "en")
                    .localizedString(forIdentifier: locale.identifier)
                    ?? locale.identifier)
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
                    .fontWeight(.semibold)
                Text("Switch language in the studio to see a different list.")
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
            }
            .font(.caption)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            .padding(.horizontal, 16)
```

- [ ] **Step 3.4.4: Update the sheet's callsite**

Find the place where `EditFillerListStudioSheet` is presented (it's mounted from inside `SmartCutStudioContainer.editStudioBody` based on existing code). Pass `locale: vm.currentLocale`.

- [ ] **Step 3.4.5: Build**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3.4.6: Run the full suite — confirm `FAIL=5` baseline preserved**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5` exact.

- [ ] **Step 3.4.7: Commit**

```bash
git add SonicMerge/Features/SmartCut/Views/Studio/EditFillerListStudioSheet.swift \
        SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift
git commit -m "feat(smart-cut): EditFillerList shows per-locale defaults

Sheet now takes a Locale parameter and renders library.allWords(for:)
instead of the global accessor. Footer line indicates which language's
defaults are visible: 'Showing default words for Spanish. Switch
language in the studio to see a different list.'

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

**End of Chunk 3.** Stop here for plan-document review before continuing to Chunk 4.

---

## Chunk 4: Manual verification of curated filler lists

**Why this chunk:** The curated default-off lists for es / pt / fr were assembled from linguistic intuition. Empirical verification on real audio is the only way to know they actually match what `SFSpeechRecognizer` (cloud) transcribes. This is a manual-QA chunk — no production code changes by default; if a curated word repeatedly fails to match, drop it from `FillerLibrary.defaultsByLanguage` and document why.

**At end of chunk:** All four curated languages have a documented manual-QA result. Words that don't match in practice are removed from the curated list. The team has a reference clip per language (kept locally, NOT committed unless CC-BY) for future regression checking.

### Task 4.1: Verify Spanish curated list

- [ ] **Step 4.1.1: Source a Spanish-language conversational audio clip**

Acceptance criteria for the test clip:
- 30–60s of natural Spanish speech (any region — recognizer is region-flexible).
- Single speaker, conversational tempo.
- Light noise floor, audibly clear words.
- Real disfluencies (the speaker says some "este", "eh", "o sea", or similar at least 3 times total).

Sources to try:
- Internet Archive CC-BY Spanish podcasts.
- Common Voice Spanish dataset (CC0).
- A user recording (see in-app recorder — record in Spanish if you speak it; otherwise ask a Spanish-speaking colleague).

Save locally to `~/Desktop/qa-clips/spanish-test.m4a` (or wherever convenient — DO NOT commit unless the source is CC-BY-licensed and attribution is added).

- [ ] **Step 4.1.2: Import into the app, set language to Spanish, analyze**

1. Build + install on the simulator.
2. Open Smart Cut, import the file.
3. Tap the LanguagePill → pick "Spanish (Spain)" or "Spanish (Mexico)" — either should work.
4. Tap Analyze.

- [ ] **Step 4.1.3: Inspect the EditList**

Expected: Smart Cut found ≥1 of the curated Spanish defaults: `["este", "eh", "o sea", "pues", "tipo", "como"]`.

If yes → curated list is good. If 0 matches BUT the clip has audible disfluencies, two possibilities:

(a) Cloud recognizer dropped them (rare with `taskHint = .dictation` — Apple preserves disfluencies in dictation mode).
(b) The recognized text differs from what we curated (e.g. "o sea" is transcribed as "osea" or "o sé").

Inspect the transcript via the Transcript tab; check whether the curated words appear at all. Words that NEVER appear in the recognized text on multiple test clips should be removed from `defaultsByLanguage["es"]`.

- [ ] **Step 4.1.4: Specifically verify "como" and "tipo" false-positive rate**

Per the spec's risk note, both have non-filler senses (interrogative "how/like" and "type/kind"). Count the number of detected occurrences vs the number that were genuinely fillers (the user reviews each occurrence in the FillerOccurrenceSheet's per-occurrence cards).

If false-positive rate > 50% for either word, remove it from the curated list:

```swift
"es": ["este", "eh", "o sea", "pues"]  // dropped "tipo" and "como"
```

- [ ] **Step 4.1.5: Document findings**

Append to `docs/superpowers/specs/2026-05-09-multi-language-smart-cut-design.md` under a new "Empirical Verification" section:

```markdown
## Empirical Verification (Manual QA)

### Spanish (es) — verified YYYY-MM-DD

Test clip: <description, length, disfluency-density>
Curated default-off words tested: este, eh, o sea, pues, tipo, como
Words confirmed matching: <list>
Words removed (never matched / high false-positive rate): <list>

Resulting curated list shipped:
\`\`\`
"es": [<final list>]
\`\`\`
```

- [ ] **Step 4.1.6: If words were removed, update FillerLibrary and re-run tests + commit**

```bash
# only if changes were made
git add SonicMerge/Features/SmartCut/Models/FillerLibrary.swift \
        docs/superpowers/specs/2026-05-09-multi-language-smart-cut-design.md
git commit -m "fix(smart-cut): trim Spanish curated list per empirical QA

<words> removed because <reason — e.g. high false-positive rate, never
matched recognizer output>. Test clip details in spec
Empirical Verification section.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4.2: Verify Brazilian Portuguese curated list

- [ ] **Step 4.2.1–4.2.5: Repeat 4.1 for pt-BR**

Curated words to verify: `["tipo", "né", "então", "sabe", "meio que"]`.

Watch out: "tipo" same false-positive risk as Spanish. "Né" is very colloquial — verify it transcribes as `"né"` (with accent) and not `"ne"` or `"é"`.

- [ ] **Step 4.2.6: Document + commit changes (if any)**

---

### Task 4.3: Verify French curated list

- [ ] **Step 4.3.1–4.3.5: Repeat 4.1 for fr-FR**

Curated words to verify: `["euh", "ben", "genre", "en fait", "du coup", "tu sais"]`.

Watch out: `"euh"` is the canonical French hesitation but may transcribe as `"hein"`, `"hé"`, or `"eh"`. `"ben"` is informal for `"bien"` — confirm it's transcribed as the casual form.

- [ ] **Step 4.3.6: Document + commit changes (if any)**

---

### Task 4.4: Final smoke + FAIL=5 baseline

- [ ] **Step 4.4.1: Full suite**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5` with the documented baseline names.

- [ ] **Step 4.4.2: Manual smoke — English session unaffected**

- Build + install. Open an existing English Smart Cut session (one created before this branch).
- Verify it loads with `LanguagePill` showing "English" (resolved from device locale, since the session has `localeIdentifier == nil`).
- Re-analyze. Expected: identical edit list to before this work landed (within recognizer non-determinism — content-equivalent).

- [ ] **Step 4.4.3: Manual smoke — fresh Spanish session works**

- Import the Spanish test clip from Task 4.1.
- Pill should show "English" by default (device default — change if you switched the device locale).
- Tap pill → pick Spanish → confirm pill updates → tap Analyze.
- Verify Spanish defaults are detected.
- Tap Edit Filler List → footer should say "Showing default words for Spanish."

- [ ] **Step 4.4.4: Manual smoke — picker UX**

- Open LocalePicker.
- Verify "Suggested" section appears at top with locales matching the device's preferred languages.
- Verify the search bar filters correctly: typing "españ" should narrow to Spanish variants; typing "es-" should also narrow (identifier match).
- Verify Cancel dismisses without changes.

- [ ] **Step 4.4.5: Manual smoke — language change invalidates cache**

- On a Smart Cut session that already has results displayed, tap LanguagePill → pick a different language.
- Expected: the studio re-enters `.idle` (cached transcript and edit list dropped), prompting a re-analyze.

- [ ] **Step 4.4.6: No commit needed for this verification step**

---

**End of plan.** All chunks complete.
