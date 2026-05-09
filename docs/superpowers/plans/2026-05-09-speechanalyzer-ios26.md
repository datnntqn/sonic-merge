# SpeechAnalyzer (iOS 26) Parallel-Path Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Apple's `SpeechAnalyzer` (iOS 26) as a parallel transcription engine alongside the existing chunked `SFSpeechRecognizer` path, gated by `#available(iOS 26, *)`. iOS 17–25 keeps today's behavior byte-for-byte; iOS 26+ users get long-form streaming, multilingual auto-detect, on-device disfluency support, and a live transcript pane during analysis.

**Architecture:** A new `SpeechAnalyzerTranscriptionService` actor sits behind the existing `TranscriptionServicing` protocol. A new `TranscriptionServiceFactory` is the only `#available(iOS 26, *)` site for engine selection. `SmartCutService.transcriptionServiceFactory` flips from `(Locale) -> service` to `(String) -> service` so the new `"auto"` locale sentinel can flow through unmodified. `TranscriptionState` gains an `engine` discriminator + `completedRecognizedDuration` + `liveTranscriptText`, with engine-aware `progressFraction` so the existing "Transcribing X%" UI keeps working. Three iOS-26-gated UI changes: pinned auto-detect row in `LocalePicker`, hidden cloud toggle in `EditFillerListStudioSheet`, and an expandable `LiveTranscriptPane` in the analyzing state.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, AVFoundation (`AVAssetReader`, `AVAudioPCMBuffer`), Speech.framework (`SFSpeechRecognizer` legacy path; `SpeechAnalyzer` + `SpeechTranscriber` iOS 26 path). iOS 17.0 deployment floor preserved. Swift Testing for new tests.

**Spec:** `docs/superpowers/specs/2026-05-09-speechanalyzer-ios26-design.md`

**Build/test commands** (run from repo root, absolute paths):

```bash
# Build
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5

# Single suite (NO slash for Swift Testing suite name)
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/<SuiteName> test 2>&1 | tail -10

# Single XCTest case (slash works for legacy XCTest)
xcodebuild ... -only-testing:SonicMergeTests/<Class>/<test_name> test

# Full suite — FAIL=5 baseline expected
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

**Baseline failing tests on `main` (FAIL=5, expected, NOT regressions):** `compositionWithCrossfadeHasNonNilAudioMix`, `testFileCopyToClipsDirectory`, `testLargeFileCopyDoesNotCrash`, `testPendingKeyWrittenAndCleared`, `testPositionPreservedOnSwitch`. Any new failures are real regressions.

**SourceKit phantoms note:** the IDE indexer often reports "No such module 'UIKit'", "Cannot find type 'X' in scope", etc. for files that compile fine via `xcodebuild`. Trust the actual build.

---

## Chunk 1: Pre-implementation verification + `TranscriptionState` foundation

**Why this chunk:** Two assumptions in the spec must be confirmed before any iOS 26-specific Swift gets written, and the foundational data-model changes need to land first because every downstream chunk depends on them. At the end of this chunk, the iOS 17–25 codepath must be byte-for-byte identical (FAIL=5 unchanged) and the data layer must be ready to carry SpeechAnalyzer state — even though no SpeechAnalyzer code exists yet.

**At end of chunk:**
- Two assumption questions answered + checked into the spec's "Assumptions to verify" section.
- `TranscriptionState` carries `engine: Engine`, `completedRecognizedDuration: TimeInterval`, `liveTranscriptText: String`, with defaults that keep all existing call sites compiling.
- `progressFraction` is engine-aware (still chunk-based math for SF; ready for SpeechAnalyzer math when that engine arrives).
- Pre-migration JSON decodes into `engine == .sfSpeechRecognizer` with the new fields zeroed.
- Full test suite passes at FAIL=5.

### Task 1.1: Verify the two load-bearing assumptions

The spec's "Assumptions to verify before implementation" section has two open questions whose answers shape later chunks. Settle them now by reading Apple's iOS 26 `Speech` framework documentation (web search OR Xcode's API browser — both work; the goal is finding authoritative source, not guessing).

**Files:**
- Modify: `docs/superpowers/specs/2026-05-09-speechanalyzer-ios26-design.md` (annotate the assumptions with confirmed answers)

- [ ] **Step 1.1.1: Open Apple's `SpeechAnalyzer` documentation**

Open the Apple Developer documentation for the iOS 26 `Speech` framework. Two ways:
- WebSearch: `Apple SpeechAnalyzer iOS 26 documentation`
- Xcode → Window → Developer Documentation → search "SpeechAnalyzer" (requires Xcode 26+; if you don't have it locally, web is fine)

Read the class reference for `SpeechAnalyzer` and `SpeechTranscriber`.

- [ ] **Step 1.1.2: Resolve assumption #1 — on-device-only**

Look for any property or initializer parameter that controls "use cloud / use server" recognition (analogous to `SFSpeechURLRecognitionRequest.requiresOnDeviceRecognition`). Specifically check:
- `SpeechAnalyzer.init(...)` parameters
- `SpeechTranscriber.init(...)` parameters
- Any related configuration enum

**Decision matrix:**
- If **no** such property exists → assumption holds. SpeechAnalyzer is on-device-only. Component 9 (hide cloud toggle on iOS 26) stands as written. Continue.
- If **a** cloud-vs-on-device flag exists → revise the spec: do NOT hide the cloud toggle on iOS 26 in Chunk 5. Mark the §Component 9 plan task as a no-op and reframe the toggle as "Use cloud recognition" (semantics carry over).

- [ ] **Step 1.1.3: Resolve assumption #2 — authorization API**

Look for any `SpeechAnalyzer.requestAuthorization(...)` or `Speech.requestAuthorization(...)` static method. Also check whether `SFSpeechRecognizer.requestAuthorization` is documented as covering the new `Speech` framework APIs.

**Decision matrix:**
- If `SFSpeechRecognizer.requestAuthorization` is the **single** entry point for both APIs → assumption holds. `SmartCutViewModel.requestSpeechAuthorization` (line 239) and `OnboardingFlow`'s permission seed (line 110) are unchanged.
- If iOS 26 introduces a **separate** authorization API → **STOP. Pause this plan and re-plan Chunk 5** before proceeding to Chunk 2. Both `SmartCutViewModel` and `OnboardingFlow` need an iOS-26-gated parallel auth call, which expands Chunk 5's scope. Surface the finding to the human; do not silently continue.

- [ ] **Step 1.1.4: Update the spec with confirmed answers**

In `docs/superpowers/specs/2026-05-09-speechanalyzer-ios26-design.md`, locate the "Assumptions to verify before implementation" section (search for that heading). For each of the two assumptions, replace the "If true / If false" branch language with a **single resolved statement** prefixed with "**Confirmed 2026-05-09:**" and a one-line cite (URL or doc title).

Example (to replace the bullet):

```markdown
1. **SpeechAnalyzer is on-device-only with no network/cloud variant.**
   - **Confirmed 2026-05-09:** [findings here, with citation]. Component 9 (hide cloud toggle on iOS 26) proceeds as written.
```

- [ ] **Step 1.1.5: Commit the spec update**

```bash
git add docs/superpowers/specs/2026-05-09-speechanalyzer-ios26-design.md
git commit -m "$(cat <<'EOF'
docs(smart-cut): confirm SpeechAnalyzer assumptions before implementation

Resolved both pre-implementation assumptions per Apple's Speech framework
docs (iOS 26): on-device-only status and authorization-API coverage.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 1.2: Add `Engine` enum + new fields to `TranscriptionState`

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Models/TranscriptionState.swift`
- Test: `SonicMergeTests/Features/SmartCut/TranscriptionStateTests.swift` (extend, do NOT replace)

- [ ] **Step 1.2.1: Write the failing migration test (decoder default for missing fields)**

In `SonicMergeTests/Features/SmartCut/TranscriptionStateTests.swift`, append the following test inside the existing `struct TranscriptionStateTests`:

```swift
    @Test func testPreMigrationJSONDecodesWithDefaultEngine() throws {
        // Hand-rolled pre-migration JSON: NO engine, NO completedRecognizedDuration,
        // NO liveTranscriptText. Mirrors the shape of cached state files written by
        // pre-SpeechAnalyzer builds.
        let json = """
        {
          "sourceHash": "abc123",
          "localeIdentifier": "en-US",
          "sourceDuration": 1800,
          "chunkDurationSeconds": 30,
          "completedChunkCount": 4,
          "recognizedSegments": [],
          "isComplete": false
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(TranscriptionState.self, from: json)
        #expect(decoded.engine == .sfSpeechRecognizer)
        #expect(decoded.completedRecognizedDuration == 0)
        #expect(decoded.liveTranscriptText == "")
    }
```

- [ ] **Step 1.2.2: Run the test to verify it fails (compile error is fine)**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/TranscriptionStateTests test 2>&1 | tail -10
```

Expected: FAIL with "type 'TranscriptionState.Engine' (or 'TranscriptionState') has no member 'sfSpeechRecognizer'" and/or "value of type 'TranscriptionState' has no member 'completedRecognizedDuration' / 'liveTranscriptText' / 'engine'". A compile error counts as a failing test for TDD purposes here.

- [ ] **Step 1.2.3: Add the `Engine` enum and the three new fields**

In `SonicMerge/Features/SmartCut/Models/TranscriptionState.swift`, find the line `struct TranscriptionState: Hashable, Codable {` and after the opening brace add:

```swift
    /// Which transcription engine produced this state. Persisted so
    /// `BackgroundTranscriptionTask` can resume on the same engine that wrote
    /// the snapshot, regardless of what `localeIdentifier` is.
    enum Engine: String, Codable, Hashable {
        case sfSpeechRecognizer
        case speechAnalyzer
    }
```

Then locate the existing `var isComplete: Bool` line and insert immediately after it:

```swift
    /// Engine that produced this state. Defaults to `.sfSpeechRecognizer` for
    /// pre-migration JSON (decoded via `init(from:)`).
    let engine: Engine

    /// SpeechAnalyzer-only resume cursor: how many seconds of source audio
    /// have been recognized so far. SF chunked engine leaves this at 0 and
    /// uses `completedChunkCount * chunkDurationSeconds` instead.
    var completedRecognizedDuration: TimeInterval

    /// SpeechAnalyzer-only live transcript text (single space-joined). SF
    /// chunked engine leaves this empty.
    var liveTranscriptText: String
```

- [ ] **Step 1.2.4: Update the memberwise init to default the three new fields**

In the same file, find the existing `init(sourceHash: String,` line and update the parameter list. The full updated init looks like:

```swift
    init(sourceHash: String,
         sourceDuration: TimeInterval,
         chunkDurationSeconds: TimeInterval,
         completedChunkCount: Int,
         recognizedSegments: [RecognizedSegment],
         isComplete: Bool,
         localeIdentifier: String? = nil,
         engine: Engine = .sfSpeechRecognizer,
         completedRecognizedDuration: TimeInterval = 0,
         liveTranscriptText: String = "") {
        self.sourceHash = sourceHash
        self.sourceDuration = sourceDuration
        self.chunkDurationSeconds = chunkDurationSeconds
        self.completedChunkCount = completedChunkCount
        self.recognizedSegments = recognizedSegments
        self.isComplete = isComplete
        self.localeIdentifier = localeIdentifier
        self.engine = engine
        self.completedRecognizedDuration = completedRecognizedDuration
        self.liveTranscriptText = liveTranscriptText
    }
```

- [ ] **Step 1.2.5: Add the manual `init(from:)` decoder so pre-migration JSON keeps decoding**

In the same file, after the memberwise init, add:

```swift
    private enum CodingKeys: String, CodingKey {
        case sourceHash, localeIdentifier, sourceDuration, chunkDurationSeconds
        case completedChunkCount, recognizedSegments, isComplete
        case engine, completedRecognizedDuration, liveTranscriptText
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.sourceHash = try c.decode(String.self, forKey: .sourceHash)
        self.localeIdentifier = try c.decodeIfPresent(String.self, forKey: .localeIdentifier)
        self.sourceDuration = try c.decode(TimeInterval.self, forKey: .sourceDuration)
        self.chunkDurationSeconds = try c.decode(TimeInterval.self, forKey: .chunkDurationSeconds)
        self.completedChunkCount = try c.decode(Int.self, forKey: .completedChunkCount)
        self.recognizedSegments = try c.decode([RecognizedSegment].self, forKey: .recognizedSegments)
        self.isComplete = try c.decode(Bool.self, forKey: .isComplete)
        self.engine = (try? c.decode(Engine.self, forKey: .engine)) ?? .sfSpeechRecognizer
        self.completedRecognizedDuration = (try? c.decode(TimeInterval.self, forKey: .completedRecognizedDuration)) ?? 0
        self.liveTranscriptText = (try? c.decode(String.self, forKey: .liveTranscriptText)) ?? ""
    }
```

The default `Encodable` synthesis is fine; only `init(from:)` is custom.

- [ ] **Step 1.2.6: Run the migration test to verify it passes**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/TranscriptionStateTests test 2>&1 | tail -10
```

Expected: PASS (all `TranscriptionStateTests` pass, including the new `testPreMigrationJSONDecodesWithDefaultEngine`). The previously-existing `testRoundTrip` should also still pass because the default-init values round-trip identically.

- [ ] **Step 1.2.7: Commit**

```bash
git add SonicMerge/Features/SmartCut/Models/TranscriptionState.swift \
        SonicMergeTests/Features/SmartCut/TranscriptionStateTests.swift
git commit -m "$(cat <<'EOF'
feat(transcription): add Engine discriminator + SpeechAnalyzer fields to TranscriptionState

- Engine enum (sfSpeechRecognizer | speechAnalyzer)
- completedRecognizedDuration: SpeechAnalyzer resume cursor
- liveTranscriptText: SpeechAnalyzer live-transcript channel
- Manual init(from:) defaults the three new fields so pre-migration
  cache JSON keeps decoding (engine -> .sfSpeechRecognizer)
- Memberwise init defaults preserve all existing call sites

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 1.3: Make `progressFraction` engine-aware

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Models/TranscriptionState.swift`
- Test: `SonicMergeTests/Features/SmartCut/TranscriptionStateTests.swift` (extend)

- [ ] **Step 1.3.1: Write the failing test for SpeechAnalyzer-engine progress math**

Append to `TranscriptionStateTests`:

```swift
    @Test func testProgressFractionAnalyzerEngineUsesCompletedRecognizedDuration() {
        let state = TranscriptionState(
            sourceHash: "abc",
            sourceDuration: 100,
            chunkDurationSeconds: 0,             // analyzer engine ignores chunks
            completedChunkCount: 0,
            recognizedSegments: [],
            isComplete: false,
            engine: .speechAnalyzer,
            completedRecognizedDuration: 30
        )
        #expect(abs(state.progressFraction - 0.3) < 0.0001)
    }

    @Test func testProgressFractionAnalyzerEngineCapsAtOne() {
        let state = TranscriptionState(
            sourceHash: "abc",
            sourceDuration: 100,
            chunkDurationSeconds: 0,
            completedChunkCount: 0,
            recognizedSegments: [],
            isComplete: true,
            engine: .speechAnalyzer,
            completedRecognizedDuration: 150     // floating-point overshoot
        )
        #expect(state.progressFraction == 1.0)
    }
```

- [ ] **Step 1.3.2: Run to verify they fail**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/TranscriptionStateTests test 2>&1 | tail -10
```

Expected: the two new tests FAIL (current `progressFraction` returns `0` because `chunkDurationSeconds * completedChunkCount == 0`).

- [ ] **Step 1.3.3: Update `progressFraction` to switch on `engine`**

In `SonicMerge/Features/SmartCut/Models/TranscriptionState.swift`, replace the existing `progressFraction` body with:

```swift
    var progressFraction: Double {
        guard sourceDuration > 0 else { return 0 }
        switch engine {
        case .sfSpeechRecognizer:
            return min(1.0, Double(completedChunkCount) * chunkDurationSeconds / sourceDuration)
        case .speechAnalyzer:
            return min(1.0, completedRecognizedDuration / sourceDuration)
        }
    }
```

`nextChunkStartTime` stays as-is (only the SF chunked engine reads it; SpeechAnalyzer service uses `completedRecognizedDuration` directly).

- [ ] **Step 1.3.4: Run all `TranscriptionStateTests` to confirm**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/TranscriptionStateTests test 2>&1 | tail -10
```

Expected: PASS for `testProgressFractionAtMidPoint`, `testProgressFractionAtCompletion`, `testProgressFractionAnalyzerEngineUsesCompletedRecognizedDuration`, `testProgressFractionAnalyzerEngineCapsAtOne`, `testRoundTrip`, `testNextChunkStartTime`, `testPreMigrationJSONDecodesWithDefaultEngine`.

- [ ] **Step 1.3.5: Commit**

```bash
git add SonicMerge/Features/SmartCut/Models/TranscriptionState.swift \
        SonicMergeTests/Features/SmartCut/TranscriptionStateTests.swift
git commit -m "$(cat <<'EOF'
feat(transcription): engine-aware progressFraction

SF chunked engine continues to use completedChunkCount * chunkDurationSeconds;
SpeechAnalyzer engine uses completedRecognizedDuration / sourceDuration.
Same `min(1.0, ...)` cap. Keeps the existing "Transcribing X%" UI working
once SpeechAnalyzer engine arrives.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 1.4: Confirm baseline regression — full suite at FAIL=5

**Files:** none modified — pure verification.

- [ ] **Step 1.4.1: Run the full suite**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`. The five names should match the baseline list (`compositionWithCrossfadeHasNonNilAudioMix`, `testFileCopyToClipsDirectory`, `testLargeFileCopyDoesNotCrash`, `testPendingKeyWrittenAndCleared`, `testPositionPreservedOnSwitch`).

**Known false positive:** if `testOutputFormatIsValid` appears as a 6th failure, it's the documented CoreML "E5RT zero-shape error" flake (CLAUDE.md). Re-run it in isolation before declaring a regression:

```bash
xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SonicMergeTests/NoiseReductionServiceTests/testOutputFormatIsValid test 2>&1 | tail -10
```

If `FAIL > 5` after excluding that flake, list the new failures and stop. The TranscriptionState changes are intended to be byte-for-byte invisible to the SF path; any new failure means a default-init / decoder regression slipped in. Diagnose before proceeding to Chunk 2.

- [ ] **Step 1.4.2: No commit needed (verification only).** Move to Chunk 2.

---

## Chunk 2: `TranscriptionServiceFactory` + `SmartCutService` refactor

**Why this chunk:** Introduce the factory (the only `#available(iOS 26, *)` engine-selection site) and flip `SmartCutService.transcriptionServiceFactory` from `(Locale) -> service` to `(String) -> service` so the `"auto"` sentinel can flow end-to-end. The factory still returns `TranscriptionService` for both branches at this point — no SpeechAnalyzer code yet — so the iOS 17–25 path stays byte-for-byte identical and the iOS 26 path falls through to SF temporarily. This isolates the refactor risk from the new-engine risk.

**At end of chunk:**
- New `TranscriptionServiceFactory` enum with one static method.
- `SmartCutService.transcriptionServiceFactory: (String) -> any TranscriptionServicing` and `analyze(... localeIdentifier: String)`.
- All existing `service.analyze(..., locale: Locale(...))` call sites updated to pass the identifier string.
- Factory unit tests pass on both iOS 17 and iOS 26 simulators (where applicable).
- Full suite at FAIL=5.

### Task 2.1: Create `TranscriptionServiceFactory` (returns SF for both branches initially)

**Files:**
- Create: `SonicMerge/Features/SmartCut/Services/TranscriptionServiceFactory.swift`
- Test: `SonicMergeTests/Features/SmartCut/TranscriptionServiceFactoryTests.swift`

- [ ] **Step 2.1.1: Write the failing factory tests**

Create `SonicMergeTests/Features/SmartCut/TranscriptionServiceFactoryTests.swift`:

```swift
import Testing
import Foundation
@testable import SonicMerge

struct TranscriptionServiceFactoryTests {

    @Test func makeReturnsServiceConformingToTranscriptionServicing_explicitLocale() {
        let service: any TranscriptionServicing =
            TranscriptionServiceFactory.make(localeIdentifier: "en-US")
        #expect(service is TranscriptionService || isSpeechAnalyzerService(service))
    }

    @Test func makeReturnsServiceConformingToTranscriptionServicing_autoSentinel() {
        let service: any TranscriptionServicing =
            TranscriptionServiceFactory.make(localeIdentifier: "auto")
        // On iOS 17–25 this falls through to TranscriptionService (SF) per the
        // defensive branch in the factory. On iOS 26+ it returns SpeechAnalyzer.
        #expect(service is TranscriptionService || isSpeechAnalyzerService(service))
    }

    @Test func makeReturnsServiceConformingToTranscriptionServicing_unknownLocale() {
        // Unknown locale strings are still accepted by the factory; the underlying
        // service may throw at transcribe time. Factory itself should not throw.
        let service: any TranscriptionServicing =
            TranscriptionServiceFactory.make(localeIdentifier: "xx-ZZ")
        #expect(service is TranscriptionService || isSpeechAnalyzerService(service))
    }

    /// Type-erased check that survives whether SpeechAnalyzerTranscriptionService
    /// exists yet. Returns false if the symbol isn't compiled (Chunk 2 state).
    private func isSpeechAnalyzerService(_ service: any TranscriptionServicing) -> Bool {
        if #available(iOS 26, *) {
            return service is SpeechAnalyzerTranscriptionService
        }
        return false
    }
}
```

The `isSpeechAnalyzerService` helper references a symbol that doesn't exist yet (`SpeechAnalyzerTranscriptionService`). That's intentional — it's gated behind `#available(iOS 26, *)`, so on iOS 17–25 the helper just returns `false` without touching the symbol. The test compiles AFTER Chunk 3 lands the type. **For Chunk 2,** stub the helper to return `false` unconditionally and remove the `if #available` block; we'll restore it in Chunk 3 once the type exists. Use this Chunk-2-only body:

```swift
    private func isSpeechAnalyzerService(_ service: any TranscriptionServicing) -> Bool {
        return false  // Chunk 3 restores the iOS-26 check once the type exists.
    }
```

- [ ] **Step 2.1.2: Run the test to verify it fails**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/TranscriptionServiceFactoryTests test 2>&1 | tail -10
```

Expected: FAIL with "cannot find 'TranscriptionServiceFactory' in scope" (compile error).

- [ ] **Step 2.1.3: Create the factory**

Create `SonicMerge/Features/SmartCut/Services/TranscriptionServiceFactory.swift`:

```swift
import Foundation

/// Single entry point for choosing between the legacy chunked
/// `TranscriptionService` (SFSpeechRecognizer, iOS 17–25) and the long-form
/// `SpeechAnalyzerTranscriptionService` (iOS 26+). The only `#available(iOS 26, *)`
/// site in the engine-selection path; UI files have their own gates.
///
/// `localeIdentifier == "auto"` is a sentinel meaning "let SpeechAnalyzer
/// auto-detect bilingual audio." On iOS 17–25 it falls back to en-US SF
/// defensively (LocalePicker only emits "auto" on iOS 26).
enum TranscriptionServiceFactory {
    static func make(localeIdentifier: String) -> any TranscriptionServicing {
        if localeIdentifier == "auto" {
            // Chunk 3 wires SpeechAnalyzerTranscriptionService here. Until then,
            // both branches return SF. The defensive en-US fallback for iOS 17–25
            // stays as the permanent behavior for that branch.
            return TranscriptionService(locale: Locale(identifier: "en-US"))
        }
        return TranscriptionService(locale: Locale(identifier: localeIdentifier))
    }
}
```

This is the **Chunk-2-shape** factory — both branches still return SF. Chunk 3 will edit this file to add the SpeechAnalyzer branches.

- [ ] **Step 2.1.4: Run the factory tests to verify they pass**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/TranscriptionServiceFactoryTests test 2>&1 | tail -10
```

Expected: PASS for all three test cases.

- [ ] **Step 2.1.5: Commit**

```bash
git add SonicMerge/Features/SmartCut/Services/TranscriptionServiceFactory.swift \
        SonicMergeTests/Features/SmartCut/TranscriptionServiceFactoryTests.swift
git commit -m "$(cat <<'EOF'
feat(transcription): add TranscriptionServiceFactory (SF-only initially)

Single entry point for engine selection. Both branches return SF in this
chunk; Chunk 3 wires SpeechAnalyzer for the iOS 26 path. The "auto"
sentinel falls through to en-US SF defensively for iOS 17–25.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 2.2: Flip `SmartCutService.transcriptionServiceFactory` from `(Locale)` to `(String)`

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Services/SmartCutService.swift`
- Modify: `SonicMerge/Features/SmartCut/SmartCutViewModel.swift` (add raw-identifier property + update call site)
- Modify: `SonicMerge/Features/Onboarding/OnboardingFlow.swift` (single call site at line 498)
- Modify: `SonicMergeTests/SmartCutServicePauseThresholdTests.swift` (two call sites)
- Modify: `SonicMergeTests/Features/SmartCut/SmartCutServiceIntegrationTests.swift` (one call site)

**Background — why a new VM property is needed:** `SmartCutViewModel.setLocale(_:on:)` runs the user-picked identifier through `TranscriptionService.resolveSupportedLocale(Locale(identifier:))`. That helper substitutes `"auto"` (which isn't in `SFSpeechRecognizer.supportedLocales()`) with `Locale(identifier: "en-US")`. So `currentLocale.identifier == "en-US"` whether the user picked English or auto-detect — the `"auto"` sentinel is lost before `analyze()` runs. The fix is a small new stored property `currentLocaleIdentifier: String` that keeps the **raw** picked identifier; `setLocale` updates both, and `analyze()` reads `currentLocaleIdentifier` for engine selection while `currentLocale` keeps doing its job for the SF supported-locale check.

- [ ] **Step 2.2.1: Update `SmartCutService.swift` — closure type, default closure, and `analyze` parameter**

Open `SonicMerge/Features/SmartCut/Services/SmartCutService.swift`. Make these three edits:

**Edit 1** — line 12 (the field declaration):

```swift
    private let transcriptionServiceFactory: (String) -> any TranscriptionServicing
```

**Edit 2** — lines 14–18 (the init), update the parameter type AND the default closure:

```swift
    init(library: FillerLibrary,
         transcriptionServiceFactory: @escaping (String) -> any TranscriptionServicing
            = { TranscriptionServiceFactory.make(localeIdentifier: $0) }) {
        self.library = library
        self.transcriptionServiceFactory = transcriptionServiceFactory
    }
```

**Edit 3** — lines 21–23 (the `analyze` signature), rename the parameter:

```swift
    func analyze(input: URL,
                 pauseThreshold: TimeInterval,
                 localeIdentifier: String) -> AsyncThrowingStream<Update, Error> {
```

**Edit 4** — line 27 (inside `analyze`'s body), use the renamed parameter:

```swift
                    let transcriptionService = transcriptionServiceFactory(localeIdentifier)
```

**Edit 5** — line 39 (`library.allWords(for:)` call). Today it passes `locale: Locale`. We need to derive the `Locale` for the filler-library lookup from the `localeIdentifier` string. Replace the existing call site with:

```swift
                    let fillers = FillerDetector.detect(
                        in: state.recognizedSegments,
                        words: library.allWords(for: Locale(identifier: localeIdentifier)),
                        enabledByDefault: { library.isEnabledByDefault($0) }
                    )
```

> **Note:** the `"auto"` sentinel now flows into `Locale(identifier: "auto")`, which is a non-curated locale → `FillerLibrary.allWords(for:)` returns the empty default-off list. That's a degraded experience for auto-detect users until Chunk 6 adds `allWordsAcrossCuratedLocales()`. **Do not fix this here** — Chunk 6 owns the auto-locale union behavior.

- [ ] **Step 2.2.2: Add `currentLocaleIdentifier` property + update `setLocale` + update `analyze()` call site**

Open `SonicMerge/Features/SmartCut/SmartCutViewModel.swift`. Make three edits:

**Edit 1** — declare the new stored property next to the existing `currentLocale` field. The existing declaration spans multiple lines (around line 41); search for the literal text `var currentLocale: Locale =` to find the start, then add the new property immediately after the closing of that declaration:

```swift
    /// Raw picked locale identifier (BCP-47 string OR the literal sentinel
    /// "auto" on iOS 26). Distinct from `currentLocale` because
    /// `resolveSupportedLocale` collapses "auto" → en-US — fine for SF runtime
    /// usage, but the SpeechAnalyzer factory needs the raw value to route
    /// auto-detect correctly. Kept in sync by `setLocale(_:on:)`.
    var currentLocaleIdentifier: String = "en-US"
```

**Edit 2** — keep `currentLocaleIdentifier` in sync inside `setLocale(_:on:)`. Open the function (around line 183) and add ONE line at the end of the body, after `invalidate()`:

```swift
    func setLocale(_ identifier: String, on session: SmartCutSession) {
        session.localeIdentifier = identifier
        currentLocale = TranscriptionService.resolveSupportedLocale(Locale(identifier: identifier))
        currentLocaleIdentifier = identifier   // NEW — preserves "auto" sentinel
        invalidate()
    }
```

**Edit 3** — also seed `currentLocaleIdentifier` from the persisted session at construction time. Open the convenience init (around line 86–135). Find the existing block:

```swift
        if let stored = session.localeIdentifier, !stored.isEmpty {
            currentLocale = TranscriptionService.resolveSupportedLocale(Locale(identifier: stored))
        }
```

Add a sibling assignment:

```swift
        if let stored = session.localeIdentifier, !stored.isEmpty {
            currentLocale = TranscriptionService.resolveSupportedLocale(Locale(identifier: stored))
            currentLocaleIdentifier = stored
        }
```

**Edit 4** — update the analyze call site (around line 216):

```swift
                for try await update in await service.analyze(input: inputURL,
                                                              pauseThreshold: pauseThreshold,
                                                              localeIdentifier: currentLocaleIdentifier) {
```

(Replaces `locale: currentLocale` with `localeIdentifier: currentLocaleIdentifier`. Nothing else in this loop body changes.)

- [ ] **Step 2.2.2b: Update `OnboardingFlow.runAnalyze()` call site**

Open `SonicMerge/Features/Onboarding/OnboardingFlow.swift`. Locate the call (around line 496–498):

```swift
            for try await update in service.analyze(input: url,
                                                    pauseThreshold: 1.5,
                                                    locale: Locale(identifier: "en-US")) {
```

Replace `locale: Locale(identifier: "en-US")` with `localeIdentifier: "en-US"`.

- [ ] **Step 2.2.3: Update `SmartCutServicePauseThresholdTests.swift` (two call sites)**

Open `SonicMergeTests/SmartCutServicePauseThresholdTests.swift`. Find the two `service.analyze(...locale: Locale(identifier: "en-US"))` calls (lines 52–54 and 74–76). Replace each `locale: Locale(identifier: "en-US")` with `localeIdentifier: "en-US"`. The closure body `{ _ in stub }` is type-inferred from the new factory signature — no edits needed there because it ignores its input.

- [ ] **Step 2.2.4: Update `SmartCutServiceIntegrationTests.swift` (one call site)**

Open `SonicMergeTests/Features/SmartCut/SmartCutServiceIntegrationTests.swift`. Find the line:

```swift
        for try await update in service.analyze(input: url, pauseThreshold: 1.5, locale: Locale(identifier: "en-US")) {
```

Replace with:

```swift
        for try await update in service.analyze(input: url, pauseThreshold: 1.5, localeIdentifier: "en-US") {
```

- [ ] **Step 2.2.5: Build to verify the refactor compiles**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. If you get errors, the most likely cause is a call site you missed — search the entire project for stragglers:

```bash
grep -rn 'analyze.*locale:' --include='*.swift'
```

The expected list of call sites is `SmartCutService.swift` (the definition itself), `SmartCutViewModel.swift`, `OnboardingFlow.swift`, `SmartCutServicePauseThresholdTests.swift`, `SmartCutServiceIntegrationTests.swift`. Anything else needs the same `locale: Locale(...)` → `localeIdentifier: "..."` rename.

- [ ] **Step 2.2.6: Run the full SmartCut test scope to confirm no regressions**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/SmartCutServicePauseThresholdTests \
  -only-testing:SonicMergeTests/SmartCutServiceIntegrationTests \
  -only-testing:SonicMergeTests/TranscriptionServiceFactoryTests \
  -only-testing:SonicMergeTests/TranscriptionStateTests test 2>&1 | tail -10
```

Expected: PASS for every test in the four suites. If anything fails, the refactor is wrong — diagnose before committing.

- [ ] **Step 2.2.7: Commit**

```bash
git add SonicMerge/Features/SmartCut/Services/SmartCutService.swift \
        SonicMerge/Features/SmartCut/SmartCutViewModel.swift \
        SonicMerge/Features/Onboarding/OnboardingFlow.swift \
        SonicMergeTests/SmartCutServicePauseThresholdTests.swift \
        SonicMergeTests/Features/SmartCut/SmartCutServiceIntegrationTests.swift
git commit -m "$(cat <<'EOF'
refactor(smart-cut): flip SmartCutService factory closure to (String) → service

The "auto" sentinel introduced for SpeechAnalyzer auto-detect cannot be
expressed as a Locale, so the factory closure and analyze() parameter
both flip from Locale to String. SmartCutViewModel adds currentLocaleIdentifier
to preserve the raw picked value (resolveSupportedLocale collapses "auto" →
en-US for SF runtime use, which would otherwise lose the sentinel). All
analyze() call sites — VM, OnboardingFlow, two test files — updated.
FillerLibrary lookup still uses Locale(identifier: identifier);
auto-locale union is a follow-up chunk.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 2.3: Confirm full-suite regression — FAIL=5

**Files:** none modified.

- [ ] **Step 2.3.1: Run the full suite**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`. The five names match the baseline. Apply the same `testOutputFormatIsValid` flake check from Step 1.4.1 if a 6th appears.

- [ ] **Step 2.3.2: No commit needed (verification only).** Move to Chunk 3.

---

## Chunk 3: `SpeechAnalyzerTranscriptionService` (the iOS 26 engine)

**Why this chunk:** Implement the actual SpeechAnalyzer engine and wire it into the factory. After this chunk, an iPhone 17 simulator (iOS 26) running Smart Cut analyze on an English audio file goes through SpeechAnalyzer end-to-end; iOS 17–25 still goes through SF; the factory picks correctly; live transcript text is populated on the iOS 26 path (but the UI to display it doesn't land until Chunk 5).

**At end of chunk:**
- `SpeechAnalyzerTranscriptionService.swift` exists, `@available(iOS 26, *)`, conforms to `TranscriptionServicing`.
- Factory routes correctly (iOS 26 + explicit locale → analyzer; iOS 26 + "auto" → analyzer with nil locale; iOS 17–25 → SF).
- A new test suite `SpeechAnalyzerTranscriptionServiceTests` (iOS 26 only) confirms streaming, non-empty results, snapshot persistence, and engine field on completion.
- Pre-existing factory tests' `isSpeechAnalyzerService` helper restored to use `#available(iOS 26, *)`.
- Full suite at FAIL=5 on iPhone 17.

> **Pre-implementation reading:** Step 1.1.1 already had you read Apple's `SpeechAnalyzer` and `SpeechTranscriber` reference. Re-skim before writing code, especially: how to construct an analyzer with locale (or nil for auto-detect), how to feed audio buffers, and how the results `AsyncSequence` is shaped (final-vs-partial result discrimination, segment timing fields, confidence — equivalent of `SFTranscriptionSegment.timestamp + duration + confidence`). The code below uses placeholder API surface that you may need to adapt to what Apple actually shipped.

### Task 3.1: Create the `SpeechAnalyzerTranscriptionService` actor

**Files:**
- Create: `SonicMerge/Features/SmartCut/Services/SpeechAnalyzerTranscriptionService.swift`

- [ ] **Step 3.1.1: Create the file with the actor scaffold + protocol conformance**

Create `SonicMerge/Features/SmartCut/Services/SpeechAnalyzerTranscriptionService.swift`:

```swift
//
//  SpeechAnalyzerTranscriptionService.swift
//  SonicMerge
//
//  iOS 26+ long-form transcription engine. SpeechAnalyzer + SpeechTranscriber
//  stream audio buffers in and finalized segments out, no chunking. State is
//  snapshotted every ~30s of recognized audio so BackgroundTranscriptionTask
//  can resume on the same engine via TranscriptionServiceFactory.
//

import Foundation
import Speech
import AVFoundation

@available(iOS 26, *)
actor SpeechAnalyzerTranscriptionService: TranscriptionServicing {

    enum AnalyzerError: LocalizedError {
        case assetReaderFailed(Error)
        case modelDownloadRequired
        case localeNotSupported(String)

        var errorDescription: String? {
            switch self {
            case .assetReaderFailed:
                return "Couldn't read this audio file. Try re-importing."
            case .modelDownloadRequired:
                return "Language model is downloading. Please try again in a moment."
            case .localeNotSupported(let identifier):
                return "Speech recognition isn't available for \(identifier) on this device."
            }
        }
    }

    private let stateStore: TranscriptionStateStore
    private let locale: Locale?              // nil = auto-detect (bilingual)
    private let snapshotInterval: TimeInterval

    init(locale: Locale?,
         stateStore: TranscriptionStateStore = .default,
         snapshotInterval: TimeInterval = 30) {
        self.locale = locale
        self.stateStore = stateStore
        self.snapshotInterval = snapshotInterval
    }

    func transcribe(input: URL) -> AsyncThrowingStream<TranscriptionState, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await runTranscription(input: input, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Internals (see Steps 3.1.2 – 3.1.4)
}
```

The body of `runTranscription(input:continuation:)` is split across the next steps. Build now to confirm the scaffold compiles:

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: a single warning about an unused `runTranscription` (or none if you stub it). If the file doesn't compile because `TranscriptionServicing` requires a body, add a temporary stub:

```swift
    private func runTranscription(input: URL,
                                  continuation: AsyncThrowingStream<TranscriptionState, Error>.Continuation) async throws {
        // filled in by Steps 3.1.2 – 3.1.4
    }
```

- [ ] **Step 3.1.2: Implement the source-hash + state load/create logic**

Inside the actor (replacing the stub from 3.1.1), add:

```swift
    private func runTranscription(input: URL,
                                  continuation: AsyncThrowingStream<TranscriptionState, Error>.Continuation) async throws {
        let rawHash = try await SourceHasher.sha256Hex(of: input)
        // Namespaced key (mirrors TranscriptionService.swift:130's "#cloud" / "#local")
        // so SF and SpeechAnalyzer caches never collide for the same source.
        let sourceHash = "\(rawHash)#analyzer"

        let asset = AVURLAsset(url: input)
        let totalDuration = try await asset.load(.duration).seconds

        // Load existing snapshot if one matches; otherwise create fresh.
        // The CREATE branch sets engine + localeIdentifier; the LOAD branch
        // leaves them untouched (the namespaced cache key guarantees the
        // loaded state already has engine == .speechAnalyzer).
        var state: TranscriptionState
        if let existing = try? await stateStore.load(sourceHash) {
            state = existing
        } else {
            // Write the literal sentinel "auto" for auto-detect runs (NOT a
            // resolved identifier — the factory's resume path keys on the
            // exact string "auto").
            let storedLocaleIdentifier: String? = locale?.identifier ?? "auto"
            state = TranscriptionState(
                sourceHash: sourceHash,
                sourceDuration: totalDuration,
                chunkDurationSeconds: 0,                  // unused by analyzer engine
                completedChunkCount: 0,                   // unused by analyzer engine
                recognizedSegments: [],
                isComplete: false,
                localeIdentifier: storedLocaleIdentifier,
                engine: .speechAnalyzer,
                completedRecognizedDuration: 0,
                liveTranscriptText: ""
            )
        }

        // If already complete (e.g. user opened a previously-finished session),
        // yield the loaded state and return — no need to re-run the analyzer.
        if state.isComplete {
            continuation.yield(state)
            return
        }

        // Steps 3.1.3 + 3.1.4 implement the streaming loop here.
        try await streamRecognition(asset: asset,
                                    totalDuration: totalDuration,
                                    initialState: state,
                                    continuation: continuation)
    }
```

- [ ] **Step 3.1.3: Implement `streamRecognition` — analyzer setup + audio feeder**

The audio feeder is a fire-and-forget `Task` so the consumer loop runs in the actor's own isolation context — no `inout`-across-tasks problem, no inner-actor box, just sequential `for try await` over the results. Below `runTranscription`, add:

```swift
    /// Drives the SpeechAnalyzer pipeline end-to-end:
    /// 1. Build the analyzer + transcriber with the requested locale (or auto-detect).
    /// 2. Read the source asset's audio track via AVAssetReader, starting at
    ///    `state.completedRecognizedDuration` for resume.
    /// 3. Spin up an unstructured Task that feeds PCM buffers into the analyzer's
    ///    input stream (and closes it when the reader is done).
    /// 4. Consume the transcriber's results AsyncSequence in the actor's own
    ///    isolation, translating finalized segments into RecognizedSegment.
    /// 5. Snapshot every `snapshotInterval` seconds of recognized audio.
    /// 6. Yield TranscriptionState updates on every finalized segment.
    private func streamRecognition(asset: AVURLAsset,
                                   totalDuration: TimeInterval,
                                   initialState: TranscriptionState,
                                   continuation: AsyncThrowingStream<TranscriptionState, Error>.Continuation) async throws {
        // Empty-input guard: 0-duration sources, fully-recognized resumes,
        // or sessions that already finished. Mirrors the runTranscription
        // already-complete short-circuit.
        guard totalDuration > initialState.completedRecognizedDuration else {
            var state = initialState
            state.isComplete = true
            try await stateStore.save(state)
            continuation.yield(state)
            return
        }

        var state = initialState
        var lastSnapshotAt = state.completedRecognizedDuration

        // ---- Build the analyzer + transcriber ----
        // PLACEHOLDER API SHAPE — confirm against the iOS 26 SDK headers.
        // Apple ships SpeechAnalyzer with a SpeechTranscriber module:
        //   let transcriber = SpeechTranscriber(locale: locale, options: ...)
        //   let analyzer = SpeechAnalyzer(modules: [transcriber])
        // Adjust the type names / init parameters to whatever Apple shipped.
        let transcriber = try makeTranscriber()
        let analyzer = try makeAnalyzer(with: transcriber)

        // ---- Build the audio reader, seeking to resume position ----
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AnalyzerError.assetReaderFailed(NSError(
                domain: "SpeechAnalyzerTranscriptionService",
                code: -10,
                userInfo: [NSLocalizedDescriptionKey: "Source has no audio track."]))
        }
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(
            start: CMTime(seconds: state.completedRecognizedDuration, preferredTimescale: 44100),
            end: CMTime(seconds: totalDuration, preferredTimescale: 44100)
        )
        let pcmSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: assetTrack, outputSettings: pcmSettings)
        reader.add(readerOutput)
        guard reader.startReading() else {
            throw AnalyzerError.assetReaderFailed(reader.error
                ?? NSError(domain: "SpeechAnalyzerTranscriptionService", code: -11))
        }

        // ---- Feeder Task (unstructured) — pumps PCM into the analyzer ----
        // The feeder closes the analyzer's input on completion, which causes
        // `transcriber.results` to terminate; then the consumer loop below
        // exits naturally. If the feeder throws, we cancel and rethrow at the
        // bottom of this function via `feederTask.value`.
        let feederTask = Task { [analyzer] in
            try await Self.feedAudio(reader: reader, output: readerOutput, into: analyzer)
        }

        // ---- Consumer: sequential loop in the actor's own isolation ----
        // No inout-across-tasks: state and lastSnapshotAt are this function's
        // locals. The for-await runs synchronously with the actor.
        do {
            for try await result in transcriber.results where result.isFinal {
                appendResult(result, into: &state)
                if state.completedRecognizedDuration - lastSnapshotAt >= snapshotInterval {
                    try await stateStore.save(state)
                    lastSnapshotAt = state.completedRecognizedDuration
                }
                continuation.yield(state)
            }
        } catch {
            feederTask.cancel()
            throw error
        }

        // Wait for the feeder to finish so any of its errors surface.
        try await feederTask.value

        // ---- Final snapshot + completion yield ----
        state.isComplete = true
        try await stateStore.save(state)
        continuation.yield(state)
    }

    /// Translate one finalized SpeechTranscriber result into RecognizedSegments,
    /// append them to `state`, update `liveTranscriptText` (no leading space on
    /// the first append), and bump `completedRecognizedDuration`.
    /// PLACEHOLDER: the result's per-token field names depend on the iOS 26 API.
    private func appendResult(_ result: SpeechTranscriber.Result,
                              into state: inout TranscriptionState) {
        let mapped: [TranscriptionState.RecognizedSegment] = result.tokens.map { token in
            .init(text: token.text,
                  startTime: token.timestamp,
                  endTime: token.timestamp + token.duration,
                  confidence: token.confidence)
        }
        state.recognizedSegments.append(contentsOf: mapped)

        if state.liveTranscriptText.isEmpty {
            state.liveTranscriptText = result.text
        } else {
            state.liveTranscriptText += " \(result.text)"
        }

        if let last = mapped.last {
            state.completedRecognizedDuration = max(state.completedRecognizedDuration, last.endTime)
        }
    }
```

> **Note on `appendResult`:** `inout` works fine here because it's a same-actor synchronous mutation, not cross-task. The earlier `consumeResults` helper (with its `state` and `lastSnapshotAt` `inout`s) is replaced by inlining the consumer loop directly into `streamRecognition` — the loop body is small enough to read in place, and inlining eliminates the cross-function `inout` ceremony.

- [ ] **Step 3.1.4: Implement `feedAudio`, `makeTranscriber`, `makeAnalyzer`**

Add the three helper methods. The transcriber/analyzer constructors are **placeholders** to be reconciled against the iOS 26 SDK:

```swift
    /// Reads PCM sample buffers out of `output` and feeds them into the
    /// analyzer's input stream until the reader is exhausted, then closes
    /// the input so the results AsyncSequence terminates.
    private static func feedAudio(reader: AVAssetReader,
                                  output: AVAssetReaderTrackOutput,
                                  into analyzer: SpeechAnalyzer) async throws {
        // PLACEHOLDER: replace `analyzer.input.send(buffer)` and
        // `analyzer.input.finish()` with the actual SDK methods.
        while reader.status == .reading,
              let buffer = output.copyNextSampleBuffer() {
            try await analyzer.input.send(buffer)
        }
        analyzer.input.finish()
    }

    /// PLACEHOLDER: build the SpeechTranscriber for our locale. `nil` locale
    /// requests bilingual auto-detection. Map any "locale not supported" error
    /// to AnalyzerError.localeNotSupported, and "model needs download" to
    /// AnalyzerError.modelDownloadRequired.
    private func makeTranscriber() throws -> SpeechTranscriber {
        do {
            // The exact API may be `SpeechTranscriber(locale:)` or a builder —
            // check the iOS 26 docs.
            return try SpeechTranscriber(locale: locale)
        } catch let nsError as NSError where nsError.domain == "PLACEHOLDER_DOMAIN_FOR_LOCALE_UNSUPPORTED" {
            throw AnalyzerError.localeNotSupported(locale?.identifier ?? "auto")
        } catch let nsError as NSError where nsError.domain == "PLACEHOLDER_DOMAIN_FOR_MODEL_DOWNLOAD" {
            throw AnalyzerError.modelDownloadRequired
        }
    }

    /// PLACEHOLDER: assemble the analyzer with the transcriber module.
    private func makeAnalyzer(with transcriber: SpeechTranscriber) throws -> SpeechAnalyzer {
        return try SpeechAnalyzer(modules: [transcriber])
    }
```

> **Implementation note:** the four `PLACEHOLDER` markers above are real API gaps. The exact Speech.framework iOS 26 surface (initializer parameter labels, error domains, input-stream method names) must be reconciled against Apple's headers / sample code before any of this compiles. **Do not invent symbol names** — read the SDK and adapt these stubs. If the SDK exposes a markedly different shape (e.g. `SpeechAnalyzer.start(...)` instead of an `input` stream), restructure `feedAudio` / `streamRecognition` to match. The algorithm and the protocol contract are stable; the concrete API calls are not.

- [ ] **Step 3.1.5: Build and reconcile placeholders**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -30
```

Expected on first build: compile errors from the four placeholders. Open `SonicMerge/Features/SmartCut/Services/SpeechAnalyzerTranscriptionService.swift`, fix each placeholder against the real API. Iterate until the file compiles cleanly. Do NOT proceed until `** BUILD SUCCEEDED **`.

- [ ] **Step 3.1.6: Commit the engine**

```bash
git add SonicMerge/Features/SmartCut/Services/SpeechAnalyzerTranscriptionService.swift
git commit -m "$(cat <<'EOF'
feat(transcription): SpeechAnalyzerTranscriptionService (iOS 26 engine)

Long-form streaming transcription via SpeechAnalyzer + SpeechTranscriber.
Reads PCM buffers from AVAssetReader, feeds the analyzer's input stream,
consumes finalized results, snapshots TranscriptionState every 30s of
recognized audio. Resumes from state.completedRecognizedDuration on
re-entry. State cache key namespaced as "<hash>#analyzer" to avoid
collisions with the SF chunked engine. Auto-detect when locale == nil.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 3.2: Wire the analyzer into the factory

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Services/TranscriptionServiceFactory.swift`
- Modify: `SonicMergeTests/Features/SmartCut/TranscriptionServiceFactoryTests.swift` (restore the iOS-26 helper body)

- [ ] **Step 3.2.1: Update the factory to route iOS 26 callers to the analyzer**

Open `SonicMerge/Features/SmartCut/Services/TranscriptionServiceFactory.swift`. Replace the body of `make(localeIdentifier:)` with the spec's final shape:

```swift
    static func make(localeIdentifier: String) -> any TranscriptionServicing {
        if localeIdentifier == "auto" {
            if #available(iOS 26, *) {
                return SpeechAnalyzerTranscriptionService(locale: nil)
            }
            // Defensive: "auto" should never reach this path because LocalePicker
            // only emits it on iOS 26. Fall back to en-US SF for safety.
            return TranscriptionService(locale: Locale(identifier: "en-US"))
        }
        if #available(iOS 26, *) {
            return SpeechAnalyzerTranscriptionService(locale: Locale(identifier: localeIdentifier))
        }
        return TranscriptionService(locale: Locale(identifier: localeIdentifier))
    }
```

- [ ] **Step 3.2.2: Restore the iOS-26 helper in the factory tests**

Open `SonicMergeTests/Features/SmartCut/TranscriptionServiceFactoryTests.swift`. Replace the Chunk-2 stub body:

```swift
    private func isSpeechAnalyzerService(_ service: any TranscriptionServicing) -> Bool {
        return false  // Chunk 3 restores the iOS-26 check once the type exists.
    }
```

…with the gated check:

```swift
    private func isSpeechAnalyzerService(_ service: any TranscriptionServicing) -> Bool {
        if #available(iOS 26, *) {
            return service is SpeechAnalyzerTranscriptionService
        }
        return false
    }
```

- [ ] **Step 3.2.3: Run the factory tests**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/TranscriptionServiceFactoryTests test 2>&1 | tail -10
```

Expected: PASS. On iPhone 17 (iOS 26 sim) the helper now returns `true` for analyzer-backed cases. The three `#expect(... || ...)` clauses now have the analyzer side actually firing.

- [ ] **Step 3.2.4: Commit**

```bash
git add SonicMerge/Features/SmartCut/Services/TranscriptionServiceFactory.swift \
        SonicMergeTests/Features/SmartCut/TranscriptionServiceFactoryTests.swift
git commit -m "$(cat <<'EOF'
feat(transcription): factory routes iOS 26 to SpeechAnalyzerTranscriptionService

Restores the spec's final factory shape: explicit locale on iOS 26 → analyzer
with that locale; "auto" on iOS 26 → analyzer with nil locale (auto-detect);
iOS 17–25 → existing chunked SF service. Factory tests' iOS-26 helper restored.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 3.3: New test suite — `SpeechAnalyzerTranscriptionServiceTests`

**Files:**
- Create: `SonicMergeTests/Features/SmartCut/SpeechAnalyzerTranscriptionServiceTests.swift`

> **Test fixture:** reuse `smart_cut_60s.wav`, the same fixture loaded by `SmartCutServiceIntegrationTests` via `Bundle(for: BundleMarker.self).url(forResource: "smart_cut_60s", withExtension: "wav")`. Don't add a new fixture.

- [ ] **Step 3.3.1: Create the test file**

Create `SonicMergeTests/Features/SmartCut/SpeechAnalyzerTranscriptionServiceTests.swift`:

```swift
import Testing
import Foundation
@testable import SonicMerge

@available(iOS 26, *)
@Suite struct SpeechAnalyzerTranscriptionServiceTests {

    private final class BundleMarker {}

    private func fixtureURL() throws -> URL {
        guard let url = Bundle(for: BundleMarker.self)
                .url(forResource: "smart_cut_60s", withExtension: "wav") else {
            throw NSError(domain: "fixture", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "smart_cut_60s.wav missing"])
        }
        return url
    }

    @Test func streamingYieldsAtLeastOneUpdateBeforeCompletion() async throws {
        let service = SpeechAnalyzerTranscriptionService(locale: Locale(identifier: "en-US"))
        let stream = await service.transcribe(input: try fixtureURL())
        var nonFinalCount = 0
        for try await state in stream {
            if !state.isComplete { nonFinalCount += 1 }
        }
        #expect(nonFinalCount > 0, "Expected at least one mid-stream update before completion")
    }

    @Test func finalStateHasNonEmptyRecognizedSegments() async throws {
        let service = SpeechAnalyzerTranscriptionService(locale: Locale(identifier: "en-US"))
        var final: TranscriptionState?
        for try await state in await service.transcribe(input: try fixtureURL()) {
            if state.isComplete { final = state }
        }
        let f = try #require(final)
        #expect(!f.recognizedSegments.isEmpty)
    }

    @Test func finalStateHasAnalyzerEngineAndPositiveCompletedDuration() async throws {
        let service = SpeechAnalyzerTranscriptionService(locale: Locale(identifier: "en-US"))
        var final: TranscriptionState?
        for try await state in await service.transcribe(input: try fixtureURL()) {
            if state.isComplete { final = state }
        }
        let f = try #require(final)
        #expect(f.engine == .speechAnalyzer)
        #expect(f.completedRecognizedDuration > 0)
    }

    @Test func snapshotPersistedMidStream() async throws {
        // Use a custom store that records every save.
        actor SaveRecorder {
            var saves: [TranscriptionState] = []
            func add(_ state: TranscriptionState) { saves.append(state) }
        }
        let recorder = SaveRecorder()
        let store = TranscriptionStateStore(
            load: { _ in nil },
            save: { state in await recorder.add(state) }
        )
        let service = SpeechAnalyzerTranscriptionService(
            locale: Locale(identifier: "en-US"),
            stateStore: store,
            snapshotInterval: 5  // shorter than default to guarantee a mid-stream snapshot
        )
        for try await _ in await service.transcribe(input: try fixtureURL()) {}
        let count = await recorder.saves.count
        #expect(count >= 2, "Expected at least one mid-stream snapshot plus the final save")
    }
}
```

- [ ] **Step 3.3.2: Run the new suite (iPhone 17 only — gated by `@available`)**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/SpeechAnalyzerTranscriptionServiceTests test 2>&1 | tail -15
```

Expected: PASS for all four cases. If the iPhone 17 simulator hasn't downloaded the SpeechAnalyzer language model for en-US yet, the first run may error with `AnalyzerError.modelDownloadRequired`. Wait a minute (the OS downloads in background) and re-run.

If a test fails for transcription quality reasons (segments empty, etc.), the SDK reconciliation in Step 3.1.5 likely got something subtly wrong — re-read the SpeechAnalyzer headers and adjust.

- [ ] **Step 3.3.3: Commit the test suite**

```bash
git add SonicMergeTests/Features/SmartCut/SpeechAnalyzerTranscriptionServiceTests.swift
git commit -m "$(cat <<'EOF'
test(transcription): SpeechAnalyzerTranscriptionServiceTests (iOS 26 only)

Four cases against smart_cut_60s.wav fixture: mid-stream yields,
non-empty final segments, analyzer engine + positive completedRecognizedDuration
on completion, and at-least-one mid-stream snapshot via injected store.
Gated by @available(iOS 26, *) so iOS 17–25 destinations skip.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 3.4: Confirm full-suite regression — FAIL=5 still

**Files:** none modified.

- [ ] **Step 3.4.1: Run the full suite**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`. The five baseline names. Apply the `testOutputFormatIsValid` flake check from Step 1.4.1 if a 6th appears.

- [ ] **Step 3.4.2: No commit needed.** Move to Chunk 4.

---

## Chunk 4: `BackgroundTranscriptionTask` resume routing + hash-suffix strip

**Why this chunk:** Today's `BackgroundTranscriptionTask.handle(_:)` constructs `TranscriptionService(locale:)` directly. After Chunk 3 the foreground path uses the factory; the BG path must too, otherwise resumed states write to the SF engine when they were authored by the analyzer. Additionally, the spec's "Snapshot + BG resume" diagram has a `> Note:` callout pointing out a pre-existing latent bug: `state.sourceHash` is namespaced (`<raw>#cloud` / `<raw>#local` / `<raw>#analyzer`) but `SmartCutSourceLocator` is keyed by the raw hash — `lookupURL(forHash: state.sourceHash)` will silently miss. Fix both engines together.

**At end of chunk:**
- `BackgroundTranscriptionTask` constructs services via `TranscriptionServiceFactory.make(localeIdentifier:)`.
- A new `rawHash(from:)` helper strips the `#cloud` / `#local` / `#analyzer` suffix before any `SmartCutSourceLocator.lookupURL(forHash:)` call.
- New tests in `BackgroundTranscriptionTaskTests` cover both the strip-suffix lookup and the engine-routing pin.
- Full suite at FAIL=5.

### Task 4.1: Add a hash-suffix-strip helper + route via the factory

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Services/BackgroundTranscriptionTask.swift`
- Test: `SonicMergeTests/Features/SmartCut/BackgroundTranscriptionTaskTests.swift` (extend)

- [ ] **Step 4.1.1: Write the failing test for the strip-suffix helper**

Open `SonicMergeTests/Features/SmartCut/BackgroundTranscriptionTaskTests.swift` and append a new test inside the existing struct:

```swift
    @Test func testRawHashStripsKnownEngineSuffixes() {
        #expect(BackgroundTranscriptionTask.rawHash(from: "abcdef#cloud") == "abcdef")
        #expect(BackgroundTranscriptionTask.rawHash(from: "abcdef#local") == "abcdef")
        #expect(BackgroundTranscriptionTask.rawHash(from: "abcdef#analyzer") == "abcdef")
        #expect(BackgroundTranscriptionTask.rawHash(from: "abcdef") == "abcdef") // already raw
        #expect(BackgroundTranscriptionTask.rawHash(from: "abcdef#unknown") == "abcdef#unknown") // leave unknowns alone
    }
```

- [ ] **Step 4.1.2: Run to verify it fails**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/BackgroundTranscriptionTaskTests test 2>&1 | tail -10
```

Expected: FAIL with "type 'BackgroundTranscriptionTask' has no member 'rawHash'". Compile error counts.

- [ ] **Step 4.1.3: Add the helper + route resume through the factory**

Open `SonicMerge/Features/SmartCut/Services/BackgroundTranscriptionTask.swift`. Make two edits:

**Edit 1** — add the helper as a static function inside `enum BackgroundTranscriptionTask`. Place it near the top of the enum body, after `static let identifier = ...`:

```swift
    /// Strips a known engine-namespace suffix from a TranscriptionState.sourceHash
    /// so it can be passed to SmartCutSourceLocator.lookupURL (which is keyed by
    /// raw SHA-256 only). Known suffixes: "#cloud", "#local" (SF chunked engine),
    /// "#analyzer" (SpeechAnalyzer engine). Unknown suffixes are left untouched.
    static func rawHash(from sourceHash: String) -> String {
        for suffix in ["#cloud", "#local", "#analyzer"] {
            if sourceHash.hasSuffix(suffix) {
                return String(sourceHash.dropLast(suffix.count))
            }
        }
        return sourceHash
    }
```

**Edit 2** — locate the existing block inside `handle(_:)`'s Task body that resolves the resume URL + service. Find this passage (around lines 72–82):

```swift
                guard let inputURL = SmartCutSourceLocator.lookupURL(forHash: state.sourceHash) else {
                    try? schedule()
                    completeIfNotExpired(success: true)
                    return
                }

                let resumedLocale: Locale = state.localeIdentifier
                    .flatMap { Locale(identifier: $0) }
                    ?? Locale(identifier: "en-US")
                let service = TranscriptionService(locale: resumedLocale)
```

Replace with:

```swift
                guard let inputURL = SmartCutSourceLocator.lookupURL(
                    forHash: rawHash(from: state.sourceHash)
                ) else {
                    try? schedule()
                    completeIfNotExpired(success: true)
                    return
                }

                let resumedIdentifier = state.localeIdentifier ?? "en-US"
                let service = TranscriptionServiceFactory.make(localeIdentifier: resumedIdentifier)
```

> **Note:** the factory routes by `#available(iOS 26, *)` AND by sentinel — the persisted `state.engine` field isn't read here directly. The factory's correctness on resume relies on the invariant that *for any source, the engine that wrote the snapshot is the engine the factory returns when given the same `localeIdentifier`*. That holds by construction: SF writes states with non-`"auto"` identifiers and is the only path on iOS 17–25; SpeechAnalyzer writes either `"auto"` or a real identifier and runs only on iOS 26+. The only edge case is "user upgrades from iOS 17–25 to iOS 26 mid-resume on a non-`"auto"` session," where the factory will route to SpeechAnalyzer for a state SF wrote. **This is intended per the spec** — the SpeechAnalyzer service's `runTranscription` will hit the namespace-key mismatch (`<raw>#cloud` vs `<raw>#analyzer`), fail to load the existing state, and start fresh from t=0. Acceptable for a rollback-style edge case.

- [ ] **Step 4.1.4: Run the test to verify it passes**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/BackgroundTranscriptionTaskTests test 2>&1 | tail -10
```

Expected: PASS for `testRawHashStripsKnownEngineSuffixes` and all pre-existing tests in the suite.

- [ ] **Step 4.1.5: Add the engine-routing pin test (spec §`BackgroundTranscriptionTaskTests`)**

The strip-suffix test only covers the helper. The spec also asks for a test that validates the resume composition: given a persisted `TranscriptionState` with a specific engine + locale, the factory returns the right service when fed `state.localeIdentifier`. We don't drive `BGProcessingTask.handle(_:)` directly (it requires a live `BGProcessingTask` from the OS) — instead we exercise the same two helpers `handle(_:)` calls, in the order it calls them.

Append two cases to `BackgroundTranscriptionTaskTests`:

```swift
    @Test func testResumeRoutingForSFState_returnsSFService() {
        let state = TranscriptionState(
            sourceHash: "abc#cloud",
            sourceDuration: 60,
            chunkDurationSeconds: 30,
            completedChunkCount: 1,
            recognizedSegments: [],
            isComplete: false,
            localeIdentifier: "en-US",
            engine: .sfSpeechRecognizer,
            completedRecognizedDuration: 0,
            liveTranscriptText: ""
        )
        // 1. The locator is keyed by the RAW hash; the helper must strip #cloud.
        #expect(BackgroundTranscriptionTask.rawHash(from: state.sourceHash) == "abc")
        // 2. The factory takes localeIdentifier and returns the engine the BG task uses.
        let service = TranscriptionServiceFactory.make(
            localeIdentifier: state.localeIdentifier ?? "en-US"
        )
        #expect(service is TranscriptionService)
    }

    @available(iOS 26, *)
    @Test func testResumeRoutingForAnalyzerState_returnsAnalyzerServiceOniOS26() {
        let state = TranscriptionState(
            sourceHash: "abc#analyzer",
            sourceDuration: 60,
            chunkDurationSeconds: 0,
            completedChunkCount: 0,
            recognizedSegments: [],
            isComplete: false,
            localeIdentifier: "auto",
            engine: .speechAnalyzer,
            completedRecognizedDuration: 12,
            liveTranscriptText: "Hello world"
        )
        #expect(BackgroundTranscriptionTask.rawHash(from: state.sourceHash) == "abc")
        let service = TranscriptionServiceFactory.make(
            localeIdentifier: state.localeIdentifier ?? "en-US"
        )
        #expect(service is SpeechAnalyzerTranscriptionService)
    }
```

The first case validates the SF resume path — runs on every destination because the factory always returns SF for non-`"auto"` locales below iOS 26 and the same on iOS 17–25. The second is iOS 26 only (the `@available` on the test gates execution on older sims).

- [ ] **Step 4.1.6: Run the BG task suite**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/BackgroundTranscriptionTaskTests test 2>&1 | tail -10
```

Expected: PASS for the strip-suffix test, the two new routing tests, and all pre-existing tests in the suite.

- [ ] **Step 4.1.7: Commit**

```bash
git add SonicMerge/Features/SmartCut/Services/BackgroundTranscriptionTask.swift \
        SonicMergeTests/Features/SmartCut/BackgroundTranscriptionTaskTests.swift
git commit -m "$(cat <<'EOF'
feat(smart-cut): BG resume routes via factory + strips namespace suffix

BackgroundTranscriptionTask.handle now uses TranscriptionServiceFactory.make
so iOS 26 resumes hit SpeechAnalyzer and iOS 17–25 stays on SF. New
rawHash(from:) helper strips #cloud / #local / #analyzer before the
SmartCutSourceLocator lookup — fixes a latent bug where namespaced
state.sourceHash never matched the raw-hash key in the locator.

New tests cover both the strip-suffix helper and the engine-routing pin
(SF resume returns TranscriptionService; analyzer resume on iOS 26 returns
SpeechAnalyzerTranscriptionService).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 4.2: Confirm full-suite regression — FAIL=5

**Files:** none modified.

- [ ] **Step 4.2.1: Run the full suite**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`. Apply the `testOutputFormatIsValid` flake check from Step 1.4.1 if a 6th appears.

- [ ] **Step 4.2.2: No commit needed.** Move to Chunk 5.

---

## Chunk 5: UI changes — auto-detect row, hidden cloud toggle, live transcript pane

**Why this chunk:** Engine + factory + BG resume are all in place. iOS 26 users can now hit SpeechAnalyzer through code paths, but they can't pick "auto-detect" yet (LocalePicker doesn't offer it), the now-redundant cloud toggle is still showing, and the live transcript text is being computed but never displayed. This chunk closes those three gaps.

**At end of chunk:**
- iOS 26 users see a pinned "Auto-detect (multilingual)" row at the top of `LocalePicker`. iOS 17–25 users see the picker exactly as today.
- iOS 26 users do NOT see the "Better filler detection (cloud)" toggle in `EditFillerListStudioSheet`. iOS 17–25 users see it exactly as today.
- iOS 26 users see a collapsed "Live transcript" disclosure below the progress bar during analyze; expanding shows the streaming transcript text.
- `SmartCutViewModel` exposes a stored `var liveTranscriptText: String = ""` populated from each yielded `state.liveTranscriptText`.
- `LocalePickerTests` extended with two cases (auto-detect row visible iOS 26, absent iOS 17–25).
- Full suite at FAIL=5.

> **iOS 17 destination check:** Chunks 1–4 only validated against iPhone 17 (iOS 26). The UI gates added here have observable behavior on iOS 17–25 too. After committing the changes, **also build** (you don't need to run the full test suite) against an iOS 17 simulator to confirm `if #available` / `if #unavailable` blocks compile both ways. If you don't have an iOS 17 sim installed locally, the per-platform conditionals are well-tested at compile time — `xcodebuild build` against iPhone 17 with `-arch arm64` is sufficient because Swift's `#available` is a runtime check on a compile-time-known minimum.

### Task 5.1: `LocalePicker` — pinned "Auto-detect" row on iOS 26

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Studio/LocalePicker.swift`
- Test: `SonicMergeTests/Features/SmartCut/LocalePickerTests.swift` (NEW — no existing test file for this view)

- [ ] **Step 5.1.1: Write the failing test for auto-detect row visibility**

Create `SonicMergeTests/Features/SmartCut/LocalePickerTests.swift`:

```swift
import Testing
import SwiftUI
@testable import SonicMerge

struct LocalePickerTests {

    /// Static-seam smoke tests: verify the OS-availability gate and the
    /// sentinel constant. These guarantee the row is offered to the right
    /// users and emits the right identifier. Rendering coverage is left to
    /// manual QA — adding ViewInspector-style introspection is overkill for
    /// a one-line conditional.
    @available(iOS 26, *)
    @Test func testAutoDetectRowAvailableOniOS26() {
        #expect(LocalePicker.autoDetectRowIsAvailable == true)
    }

    @Test func testAutoDetectRowAbsentBelowiOS26() {
        // Compile-time gate: this assertion is meaningful only when the
        // running simulator is iOS 17–25. On iOS 26+ the static returns
        // true, which the @available test above covers.
        if #unavailable(iOS 26, *) {
            #expect(LocalePicker.autoDetectRowIsAvailable == false)
        }
    }

    @Test func testAutoSentinelIsTheLiteralString() {
        // The factory keys on the literal string "auto"; the picker must
        // emit exactly that.
        #expect(LocalePicker.autoSentinelIdentifier == "auto")
    }

    /// End-to-end string contract: the LocalePicker sentinel and the
    /// TranscriptionServiceFactory key must agree. If either changes, this
    /// test catches the drift.
    @available(iOS 26, *)
    @Test func testAutoSentinelRoutesToAnalyzerInFactory() {
        let service = TranscriptionServiceFactory.make(
            localeIdentifier: LocalePicker.autoSentinelIdentifier
        )
        #expect(service is SpeechAnalyzerTranscriptionService)
    }
}
```

- [ ] **Step 5.1.2: Run to verify it fails**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/LocalePickerTests test 2>&1 | tail -10
```

Expected: FAIL with "type 'LocalePicker' has no member 'autoDetectRowIsAvailable'" / "no member 'autoSentinelIdentifier'". The fourth test (`testAutoSentinelRoutesToAnalyzerInFactory`) compiles after Chunk 3 — the symbol exists. It will pass once the new statics land.

- [ ] **Step 5.1.3: Add the auto-detect row + the two static seams**

Open `SonicMerge/Features/SmartCut/Views/Studio/LocalePicker.swift`. Make three edits:

**Edit 1** — add two static constants near the top of the struct, before `currentIdentifier`:

```swift
struct LocalePicker: View {

    /// Sentinel identifier passed to TranscriptionServiceFactory when the
    /// user chooses bilingual auto-detect on iOS 26. Must match the literal
    /// string the factory keys on.
    static let autoSentinelIdentifier = "auto"

    /// True when the running OS supports SpeechAnalyzer auto-detect. UI
    /// reads this to decide whether to render the pinned auto-detect row.
    static var autoDetectRowIsAvailable: Bool {
        if #available(iOS 26, *) { return true }
        return false
    }

    let currentIdentifier: String
    // ...rest of properties unchanged
```

**Edit 2** — add the row builder. Inside the struct, add a private computed view above `private func row(_ locale: Locale) -> some View`:

```swift
    @ViewBuilder
    private var autoDetectRow: some View {
        Button {
            onPick(Self.autoSentinelIdentifier)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-detect (multilingual)")
                        .foregroundStyle(Color(uiColor: semantic.textPrimary))
                    Text("SpeechAnalyzer detects two languages on iOS 26.")
                        .font(.caption)
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                }
                Spacer()
                if currentIdentifier == Self.autoSentinelIdentifier {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color(uiColor: semantic.accentAction))
                }
            }
        }
        .buttonStyle(.plain)
    }
```

**Edit 3** — render it at the top of the `List` body. Find the existing `var body: some View { NavigationStack { List { ... } } }`. The list begins with `if !filteredSuggested.isEmpty { Section("Suggested") { ... } }`. Insert before it:

```swift
                List {
                    if Self.autoDetectRowIsAvailable {
                        Section { autoDetectRow }
                    }
                    if !filteredSuggested.isEmpty {
                        // ...existing content unchanged
```

> **Note:** wrapping the row in a `Section { autoDetectRow }` (no header) gives it a visual separation from "Suggested" without a leftover empty-section header on iOS 17–25 (where `autoDetectRowIsAvailable` is false and the whole branch is elided).

- [ ] **Step 5.1.4: Run the test to verify it passes**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/LocalePickerTests test 2>&1 | tail -10
```

Expected: PASS for all three test cases.

- [ ] **Step 5.1.5: Commit**

```bash
git add SonicMerge/Features/SmartCut/Views/Studio/LocalePicker.swift \
        SonicMergeTests/Features/SmartCut/LocalePickerTests.swift
git commit -m "$(cat <<'EOF'
feat(smart-cut): pinned 'Auto-detect (multilingual)' row in LocalePicker (iOS 26)

iOS 26 users see a Section-wrapped row above 'Suggested' that emits the
literal "auto" sentinel to the SmartCutSession.localeIdentifier. iOS 17–25
LocalePicker is unchanged. Two static seams expose the behavior to tests
(autoDetectRowIsAvailable, autoSentinelIdentifier).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 5.2: `EditFillerListStudioSheet` — hide the cloud toggle on iOS 26

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Studio/EditFillerListStudioSheet.swift`

- [ ] **Step 5.2.1: Wrap the toggle in `#unavailable(iOS 26, *)`**

Open `SonicMerge/Features/SmartCut/Views/Studio/EditFillerListStudioSheet.swift`. Locate line 72 (in the body's `VStack`):

```swift
                    cloudRecognitionToggle
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
```

Replace with:

```swift
                    if #unavailable(iOS 26, *) {
                        cloudRecognitionToggle
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }
```

`cloudRecognitionToggle` itself stays defined — the underlying `useCloudRecognition` `@AppStorage` flag is still read by `TranscriptionService.useCloudRecognitionDefault()` for users who flipped it on iOS 17–25 and later upgraded; SpeechAnalyzer just ignores it.

- [ ] **Step 5.2.2: Build to confirm**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. There is no test for this UI gate — the conditional is trivial and the existing `EditFillerListStudioSheet` tests (if any) cover everything else. A test would have to spin up the SwiftUI body and walk the view hierarchy to confirm the toggle is absent on iOS 26 — high cost, low value for a one-line gate.

- [ ] **Step 5.2.3: Commit**

```bash
git add SonicMerge/Features/SmartCut/Views/Studio/EditFillerListStudioSheet.swift
git commit -m "$(cat <<'EOF'
feat(smart-cut): hide 'Better filler detection (cloud)' toggle on iOS 26

SpeechAnalyzer is on-device and already preserves disfluencies + per-word
timestamps, which is the sole reason the toggle exists. Hiding it on iOS 26
removes a now-redundant control. iOS 17–25 still see it. The underlying
@AppStorage key is left intact so toggle state survives upgrades.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 5.3: `LiveTranscriptPane` — new view + `SmartCutViewModel` wiring

**Files:**
- Create: `SonicMerge/Features/SmartCut/Views/Studio/LiveTranscriptPane.swift`
- Modify: `SonicMerge/Features/SmartCut/SmartCutViewModel.swift`
- Modify: `SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift`

- [ ] **Step 5.3.1: Create the `LiveTranscriptPane` view**

Create `SonicMerge/Features/SmartCut/Views/Studio/LiveTranscriptPane.swift`:

```swift
//
//  LiveTranscriptPane.swift
//  SonicMerge
//
//  Expandable disclosure showing the streaming SpeechAnalyzer transcript
//  during Smart Cut analysis. iOS 26+ only — gated by callers, not by
//  this file (so the type compiles on the iOS 17 floor).
//

import SwiftUI

struct LiveTranscriptPane: View {

    let text: String

    @State private var isExpanded: Bool = false
    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        if text.isEmpty {
            EmptyView()
        } else {
            DisclosureGroup(isExpanded: $isExpanded) {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(text)
                            .font(.callout)
                            .foregroundStyle(Color(uiColor: semantic.textPrimary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .id("liveTranscriptTail")
                    }
                    .frame(maxHeight: 160)
                    .onChange(of: text) { _, _ in
                        // Auto-scroll to the end as new words arrive.
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("liveTranscriptTail", anchor: .bottom)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .foregroundStyle(Color(uiColor: semantic.accentAI))
                    Text("Live transcript")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(uiColor: semantic.accentAI))
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
```

> **Color discipline** (per CLAUDE.md + MEMORY: post-2026-05-04 rebrand): the live transcript is "AI is doing something now," so the disclosure header uses `accentAI` (flat magenta — the AI single-color callsite). Body text uses `textPrimary` (theme-default). Do NOT use `accentAction` (violet — that's chrome only) and do NOT use the fire gradient (reserved for AI moments that *host* a gradient, like the orb itself; a static disclosure header is single-color territory).

- [ ] **Step 5.3.2: Add `liveTranscriptText` to `SmartCutViewModel`**

Open `SonicMerge/Features/SmartCut/SmartCutViewModel.swift`. Add a stored property near the existing `var currentLocale` and `var currentLocaleIdentifier`:

```swift
    /// SpeechAnalyzer-engine live transcript text. Populated from each
    /// yielded `state.liveTranscriptText` during analyze(). Empty for the
    /// SF chunked engine. The studio's `LiveTranscriptPane` reads this.
    var liveTranscriptText: String = ""
```

The class is `@Observable`, so plain stored `var`s are auto-observed by SwiftUI — no `@Published` (and there's no `ObservableObject` here).

- [ ] **Step 5.3.3: Mirror `state.liveTranscriptText` into the VM during analyze**

In the same file, locate the `analyze()` body (around line 191–237). Find the `for try await update in await service.analyze(...)` loop. Inside the `case .progress(let p)` branch, just before `state = .analyzing(progress: p)`, add the mirroring. The current loop body is:

```swift
                    switch update {
                    case .progress(let p):
                        state = .analyzing(progress: p)
                    case .completed(let list, let segments, let duration):
                        editList = list
                        cachedSegments = segments
                        cachedDuration = duration
                        state = .results
                    }
```

The trouble is `update` (`SmartCutService.Update`) carries `.progress(Double)` — no transcript text. The transcript text lives upstream on `TranscriptionState`. The clean fix is a third `Update` case OR a callback. Use a callback to avoid changing the public `Update` enum.

**Edit A** — open `SonicMerge/Features/SmartCut/Services/SmartCutService.swift`. Inside `analyze`'s `for try await state in await transcriptionService.transcribe(input: input)` loop, add a yield BEFORE the `.progress` yield. The current body is:

```swift
                    for try await state in await transcriptionService.transcribe(input: input) {
                        continuation.yield(.progress(state.progressFraction))
                        lastState = state
                    }
```

Replace with:

```swift
                    for try await state in await transcriptionService.transcribe(input: input) {
                        if !state.liveTranscriptText.isEmpty {
                            continuation.yield(.liveTranscript(state.liveTranscriptText))
                        }
                        continuation.yield(.progress(state.progressFraction))
                        lastState = state
                    }
```

Add the new case to the `Update` enum (above the existing cases):

```swift
    enum Update: Sendable {
        case progress(Double)        // 0...1
        case liveTranscript(String)  // SpeechAnalyzer engine only; cumulative text
        case completed(EditList, segments: [TranscriptionState.RecognizedSegment], duration: TimeInterval)
    }
```

**Edit B** — back in `SmartCutViewModel.swift` `analyze()`, extend the switch:

```swift
                    switch update {
                    case .progress(let p):
                        state = .analyzing(progress: p)
                    case .liveTranscript(let text):
                        liveTranscriptText = text
                    case .completed(let list, let segments, let duration):
                        editList = list
                        cachedSegments = segments
                        cachedDuration = duration
                        state = .results
                    }
```

**Edit C** — reset `liveTranscriptText` at the top of `analyze()` so a re-run doesn't show stale text. Find the line `state = .analyzing(progress: 0)` and add immediately after:

```swift
        liveTranscriptText = ""
```

- [ ] **Step 5.3.4: Confirm no other `Update` consumer needs touching**

`Update` is consumed in five places. `SmartCutViewModel.swift` (handled by Edit B) is the only **exhaustive** switch. The four others — `SmartCutServicePauseThresholdTests.swift`, `SmartCutServiceIntegrationTests.swift`, `OnboardingFlow.swift`, and any test stubs — all use `if case .completed(...)`, which is non-exhaustive and silently ignores the new `.liveTranscript` case. No edits needed at those sites; their stubs don't populate `state.liveTranscriptText`, so the new branch never fires for them anyway.

- [ ] **Step 5.3.5: Mount `LiveTranscriptPane` in `SmartCutStudioContainer.analyzingScaffold`**

Open `SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift`. Find `private func analyzingScaffold(progress: Double) -> some View` (around line 238). Add the live transcript pane between `ProgressView(value: progress)` and the `HStack` with the buttons. Updated body:

```swift
    private func analyzingScaffold(progress: Double) -> some View {
        VStack(spacing: 12) {
            smartCutOrb(active: true)
                .tint(.green)
            Text("Transcribing \(Int(progress * 100))%")
            ProgressView(value: progress)
            if #available(iOS 26, *) {
                LiveTranscriptPane(text: vm.liveTranscriptText)
            }
            HStack {
                Button("Cancel") { vm.cancelAnalyze() }
                    .buttonStyle(PillButtonStyle(variant: .outline, size: .regular, tint: .accent))
                Button("Run in BG") { vm.scheduleBackgroundTranscription() }
                    .buttonStyle(PillButtonStyle(variant: .outline, size: .regular, tint: .ai))
            }
        }
        .padding()
    }
```

- [ ] **Step 5.3.6: Build to confirm everything compiles**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`. If there's an exhaustive-switch error on `Update` outside the two files I already mentioned, add `case .liveTranscript: break` to that switch site.

- [ ] **Step 5.3.7: Run the SmartCut test scope**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/SmartCutServicePauseThresholdTests \
  -only-testing:SonicMergeTests/SmartCutServiceIntegrationTests \
  -only-testing:SonicMergeTests/LocalePickerTests test 2>&1 | tail -10
```

Expected: PASS for every test in the three suites.

- [ ] **Step 5.3.8: Commit**

```bash
git add SonicMerge/Features/SmartCut/Views/Studio/LiveTranscriptPane.swift \
        SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift \
        SonicMerge/Features/SmartCut/SmartCutViewModel.swift \
        SonicMerge/Features/SmartCut/Services/SmartCutService.swift \
        SonicMergeTests/SmartCutServicePauseThresholdTests.swift
git commit -m "$(cat <<'EOF'
feat(smart-cut): live transcript pane + Update.liveTranscript channel

New LiveTranscriptPane (DisclosureGroup, default collapsed, auto-scrolls)
mounts in analyzingScaffold under #available(iOS 26, *). SmartCutViewModel
gains liveTranscriptText (auto-observed via @Observable). New Update
.liveTranscript(String) case piped from SpeechAnalyzer's state stream
without changing the existing .progress / .completed contract.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 5.4: Confirm full-suite regression — FAIL=5

**Files:** none modified.

- [ ] **Step 5.4.1: Run the full suite**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`. Apply the `testOutputFormatIsValid` flake check from Step 1.4.1 if a 6th appears.

- [ ] **Step 5.4.2: No commit needed.** Move to Chunk 6.

---

## Chunk 6: `FillerLibrary` auto-locale union + manual QA + final regression

**Why this chunk:** Today's `SmartCutService.analyze` (post-Chunk 2 refactor) calls `library.allWords(for: Locale(identifier: localeIdentifier))` — when `localeIdentifier == "auto"`, that's `Locale(identifier: "auto")` whose language code is nil, so `FillerLibrary.defaultOffWords(for:)` falls through to `Self.defaultsByLanguage["en"] ?? []`. So an auto-detect run gets only English fillers, not the union of all curated languages. The spec requires a union (Component 6) so a bilingual session catches fillers from both languages.

After this chunk, the implementation matches the spec end-to-end. The final tasks are the manual QA checklist and a final full-suite confirmation.

**At end of chunk:**
- `FillerLibrary.allWordsAcrossCuratedLocales()` returns the deduped union of every curated locale's filler list.
- `SmartCutService.analyze` calls `allWordsAcrossCuratedLocales()` when `localeIdentifier == "auto"`.
- New unit tests cover both behaviors.
- `docs/superpowers/qa/2026-05-09-speechanalyzer-ios26-manual-qa.md` exists and is committed.
- Full suite at FAIL=5; spec assumptions resolved; no TODOs left in the spec or plan.

### Task 6.1: `FillerLibrary.allWordsAcrossCuratedLocales()` + tests

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Models/FillerLibrary.swift`
- Test: `SonicMergeTests/Features/SmartCut/FillerLibraryLocaleTests.swift` (extend the existing suite — locale + auto-locale-union are the same concern)

- [ ] **Step 6.1.1: Confirm the existing test file**

```bash
ls /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMergeTests/Features/SmartCut/FillerLibrary*
```

Expected: prints `FillerLibraryLocaleTests.swift`. If the layout has shifted, find any `FillerLibrary*Tests.swift` file and append there; only create a new file if no existing one is found at all.

- [ ] **Step 6.1.2: Write the failing test for the union method**

Append the four cases below to the existing `struct FillerLibraryLocaleTests` (or whatever struct name the file uses — keep it consistent with what's already there):

```swift
    @Test func testAllWordsAcrossCuratedLocalesIncludesAllCuratedLanguages() {
        let suiteName = "FillerLibrary.union.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let library = FillerLibrary(defaults: defaults)

        let union = library.allWordsAcrossCuratedLocales()

        // Sample one well-known word from each curated language.
        #expect(union.contains("like"))    // en
        #expect(union.contains("este"))    // es
        #expect(union.contains("né"))      // pt
        #expect(union.contains("euh"))     // fr
    }

    @Test func testAllWordsAcrossCuratedLocalesIsDeduped() {
        let suiteName = "FillerLibrary.union.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let library = FillerLibrary(defaults: defaults)

        let union = library.allWordsAcrossCuratedLocales()

        // "tipo" appears in both Spanish and Portuguese curated lists; the
        // union should contain it once, not twice.
        let tipoCount = union.filter { $0 == "tipo" }.count
        #expect(tipoCount == 1)
    }

    @Test func testAllWordsAcrossCuratedLocalesIncludesCustomWords() {
        let suiteName = "FillerLibrary.union.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var library = FillerLibrary(defaults: defaults)
        library.addCustom("blarg")  // a custom user word

        let union = library.allWordsAcrossCuratedLocales()
        #expect(union.contains("blarg"))
    }

    @Test func testAllWordsAcrossCuratedLocalesHonorsRemovedDefaults() {
        let suiteName = "FillerLibrary.union.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var library = FillerLibrary(defaults: defaults)
        library.remove("like")  // user removed an English curated default

        let union = library.allWordsAcrossCuratedLocales()
        #expect(!union.contains("like"))
    }
```

- [ ] **Step 6.1.3: Run to verify they fail**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/FillerLibraryLocaleTests test 2>&1 | tail -10
```

Expected: FAIL with "type 'FillerLibrary' has no member 'allWordsAcrossCuratedLocales'".

- [ ] **Step 6.1.4: Implement the method**

Open `SonicMerge/Features/SmartCut/Models/FillerLibrary.swift`. Add the method after `allWords(for locale: Locale)` (around line 64):

```swift
    /// Union of `defaultOnWords` + curated default-off words across every
    /// curated locale + global custom words, with `removedDefaults` honored
    /// and duplicates collapsed. Used when SpeechAnalyzer runs in bilingual
    /// auto-detect mode and we cannot pre-pick a single language to drive
    /// `defaultOffWords(for:)`. Semantics match `allWords(for:)` minus the
    /// per-locale narrowing.
    /// Order: defaultOnWords first (matches allWords(for:) order), then
    /// curated default-off groups in stable language order (en, es, pt, fr),
    /// then custom words. The hardcoded language order must stay in sync
    /// with `defaultsByLanguage` keys — adding a new curated language
    /// requires adding its code to this array.
    func allWordsAcrossCuratedLocales() -> [String] {
        let removed = removedDefaults
        var seen = Set<String>()
        var ordered: [String] = []
        // 1. defaultOnWords (parity with allWords(for:))
        for word in defaultOnWords where !removed.contains(word) && seen.insert(word).inserted {
            ordered.append(word)
        }
        // 2. defaultOffWords across curated locales, in stable language order
        //    so test output is deterministic.
        for code in ["en", "es", "pt", "fr"] {
            for word in (Self.defaultsByLanguage[code] ?? []) {
                guard !removed.contains(word), seen.insert(word).inserted else { continue }
                ordered.append(word)
            }
        }
        // 3. customWords
        for word in customWords where seen.insert(word).inserted {
            ordered.append(word)
        }
        return ordered
    }
```

- [ ] **Step 6.1.5: Run the tests to verify they pass**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/FillerLibraryLocaleTests test 2>&1 | tail -10
```

Expected: PASS for all four new test cases (and any existing tests in the suite).

- [ ] **Step 6.1.6: Commit**

```bash
git add SonicMerge/Features/SmartCut/Models/FillerLibrary.swift \
        SonicMergeTests/Features/SmartCut/FillerLibraryLocaleTests.swift
git commit -m "$(cat <<'EOF'
feat(smart-cut): FillerLibrary.allWordsAcrossCuratedLocales

Returns deduped union of every curated locale's default-off list plus
custom words, honoring removedDefaults. Used by SmartCutService when
SpeechAnalyzer runs in bilingual auto-detect mode (locale identifier
"auto") — a single explicit locale wouldn't catch fillers from the
other detected language.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 6.2: Wire `allWordsAcrossCuratedLocales()` into `SmartCutService.analyze`

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Services/SmartCutService.swift`

- [ ] **Step 6.2.1: Branch on the `"auto"` sentinel for filler-list selection**

Open `SonicMerge/Features/SmartCut/Services/SmartCutService.swift`. Find the `library.allWords(for: ...)` call inside `analyze` (the call site updated in Chunk 2 Step 2.2.1 Edit 5). Replace:

```swift
                    let fillers = FillerDetector.detect(
                        in: state.recognizedSegments,
                        words: library.allWords(for: Locale(identifier: localeIdentifier)),
                        enabledByDefault: { library.isEnabledByDefault($0) }
                    )
```

With:

```swift
                    let fillerWords: [String]
                    if localeIdentifier == "auto" {
                        fillerWords = library.allWordsAcrossCuratedLocales()
                    } else {
                        fillerWords = library.allWords(for: Locale(identifier: localeIdentifier))
                    }
                    let fillers = FillerDetector.detect(
                        in: state.recognizedSegments,
                        words: fillerWords,
                        enabledByDefault: { library.isEnabledByDefault($0) }
                    )
```

- [ ] **Step 6.2.2: Build to confirm**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6.2.3: Run the SmartCut test scope to confirm no regressions**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/SmartCutServicePauseThresholdTests \
  -only-testing:SonicMergeTests/SmartCutServiceIntegrationTests \
  -only-testing:SonicMergeTests/FillerLibraryLocaleTests test 2>&1 | tail -10
```

Expected: PASS for every test.

- [ ] **Step 6.2.4: Commit**

```bash
git add SonicMerge/Features/SmartCut/Services/SmartCutService.swift
git commit -m "$(cat <<'EOF'
feat(smart-cut): use union filler list when locale is "auto"

SmartCutService.analyze branches on the "auto" sentinel: bilingual
auto-detect runs use FillerLibrary.allWordsAcrossCuratedLocales() so
fillers from both detected languages match. Explicit locales continue to
use the per-locale list.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 6.3: Manual QA checklist

**Files:**
- Create: `docs/superpowers/qa/2026-05-09-speechanalyzer-ios26-manual-qa.md`

- [ ] **Step 6.3.1: Confirm the QA directory exists**

```bash
ls /Users/datnnt/Desktop/DatNNT/App/SonicMerge/docs/superpowers/qa/ 2>/dev/null \
  || mkdir -p /Users/datnnt/Desktop/DatNNT/App/SonicMerge/docs/superpowers/qa/
```

- [ ] **Step 6.3.2: Create the QA document**

Create `docs/superpowers/qa/2026-05-09-speechanalyzer-ios26-manual-qa.md`:

```markdown
# SpeechAnalyzer (iOS 26) — Manual QA Checklist

**Spec:** docs/superpowers/specs/2026-05-09-speechanalyzer-ios26-design.md
**Plan:** docs/superpowers/plans/2026-05-09-speechanalyzer-ios26.md
**Date:** 2026-05-09

Run on **iPhone 17 Pro simulator** (iOS 26) AND a real iOS 17 device or simulator
where noted. Verify each row visually; the unit tests cover the seam, not the
end-to-end UX.

## Foreground analyze — iOS 26, English file

- [ ] Import a 60-second English clip (or use the smart_cut_60s.wav fixture).
- [ ] Tap Analyze.
- [ ] Live transcript pane appears collapsed below the progress bar.
- [ ] Expanding the disclosure shows growing English text within ~2s.
- [ ] Auto-scroll keeps the latest words visible without manual scrolling.
- [ ] Progress percentage advances smoothly (no stuck-at-0%).
- [ ] On completion, results page shows fillers detected.

## Foreground analyze — iOS 26, bilingual file with auto-detect

- [ ] Import a clip containing English AND Spanish (or English + Portuguese).
- [ ] Open LocalePicker → tap the pinned "Auto-detect (multilingual)" row.
- [ ] Tap Analyze.
- [ ] Live transcript shows words in both languages.
- [ ] Filler detection picks up fillers from both languages (e.g. "like" + "este").

## Background resume — iOS 26

- [ ] Start an analyze on a 5+ minute clip.
- [ ] Tap "Run in BG" (or background the app).
- [ ] Wait 2-3 minutes.
- [ ] System notification "Smart Cut finished" fires.
- [ ] Reopening the app shows the completed results.

## Cancel + resume — iOS 26

- [ ] Start an analyze.
- [ ] Tap Cancel mid-stream.
- [ ] State returns to .idle but partial transcript on disk is preserved.
- [ ] Tapping Analyze again resumes from the snapshot (transcript continues
      where it left off, not from t=0).

## iOS 17 regression check

- [ ] Build the app for iPhone 15 simulator (iOS 17).
- [ ] Smart Cut analyze completes normally on an English clip.
- [ ] EditFillerListStudioSheet shows the "Better filler detection (cloud)"
      toggle (visible on iOS 17, hidden on iOS 26).
- [ ] LocalePicker has NO "Auto-detect" row (visible only on iOS 26).
- [ ] No live transcript pane in the analyzing state (gated by
      #available(iOS 26, *)).
- [ ] Cloud toggle still works as before — flipping it does change the
      cache key namespace (#cloud vs #local).

## Live transcript pane — visual

- [ ] Disclosure starts collapsed.
- [ ] Header reads "Live transcript" with a waveform icon.
- [ ] Header color is flat magenta (accentAI), NOT violet (accentAction)
      and NOT the fire gradient (reserved for the orb itself).
- [ ] Expanded body shows monospaced-callout-style text in textPrimary.
- [ ] Pane height caps at ~160pt before scrolling.

## Spec assumptions

- [ ] Confirmed during Chunk 1: SpeechAnalyzer is on-device-only (no cloud
      variant). If this is wrong, EditFillerListStudioSheet plan needs
      revisiting (toggle should NOT be hidden).
- [ ] Confirmed during Chunk 1: SFSpeechRecognizer.requestAuthorization
      covers SpeechAnalyzer. If wrong, OnboardingFlow + SmartCutViewModel
      need parallel auth calls.
```

- [ ] **Step 6.3.3: Commit**

```bash
git add docs/superpowers/qa/2026-05-09-speechanalyzer-ios26-manual-qa.md
git commit -m "$(cat <<'EOF'
docs(smart-cut): manual QA checklist for SpeechAnalyzer iOS 26

Six sections — foreground analyze on iOS 26, bilingual auto-detect, BG
resume, cancel-and-resume, iOS 17 regression check, live transcript
visuals, and spec-assumption confirmations.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 6.4: Final regression — full suite at FAIL=5

**Files:** none modified.

- [ ] **Step 6.4.1: Run the full suite**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`. The five baseline names (`compositionWithCrossfadeHasNonNilAudioMix`, `testFileCopyToClipsDirectory`, `testLargeFileCopyDoesNotCrash`, `testPendingKeyWrittenAndCleared`, `testPositionPreservedOnSwitch`).

If `FAIL > 5`, list the new failures and stop. New failures are real regressions; diagnose before declaring the implementation complete. Apply the `testOutputFormatIsValid` flake check from Step 1.4.1 if a 6th appears.

- [ ] **Step 6.4.2: Build the iOS 17 destination as a final smoke check**

Pick any iOS 17 simulator the dev machine has. If none is installed, skip this step and rely on the `#available` compiler proof.

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. Confirms every `if #available(iOS 26, *)` and `if #unavailable(iOS 26, *)` branch compiles in both directions.

- [ ] **Step 6.4.3: Walk the manual QA checklist (or hand off to a human reviewer)**

Open `docs/superpowers/qa/2026-05-09-speechanalyzer-ios26-manual-qa.md` and run through every checkbox on a real iPhone 17 simulator. Any failure that doesn't have an obvious explanation (network glitch, model still downloading) is a real bug and needs a follow-up commit before the work is "done."

- [ ] **Step 6.4.4: Implementation complete**

If the full suite is at FAIL=5, the iOS 17 build succeeds, and the manual QA checklist passes, the implementation is complete. The branch is ready for merge or PR.

---
