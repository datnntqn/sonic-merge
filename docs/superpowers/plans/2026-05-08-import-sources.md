# Many-Source Audio Import Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace each tab's Import button → `.fileImporter` flow with a shared **Source Picker sheet** offering Files / iCloud Drive · Record (microphone) · Photos & Videos. All three home tabs (Smart Cut, Denoise, Merge) consume the same sheet.

**Architecture:** One reusable `ImportSourceSheet` SwiftUI view + a pure `ImportSourceDispatcher` for testability. New `AudioRecorderService` (`@MainActor` `ObservableObject`, DI-seamed via `RecordPermissionProvider`) drives the recorder sheet. New `VideoAudioExtractor` + `PHPickerWrapper` cover the Photos path. Per-tab callbacks funnel the resulting URL into each tab's existing import path — Smart Cut and Denoise call their tab-local `ImportDecision.gate(...)`; Merge appends a clip with no gate (matching today's behavior).

**Tech Stack:** Swift 6, SwiftUI, AVFoundation (`AVAudioRecorder`, `AVAudioSession`, `AVAssetExportSession`), PhotosUI (`PHPickerViewController`). Swift Testing (`import Testing`, `@Test`, `#expect`) per project convention. iOS 17.0 deployment target.

**Spec:** `docs/superpowers/specs/2026-05-08-import-sources-design.md`

**Build/test commands** (run from repo root, paths absolute):

```bash
# Build the app
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5

# Run a single Swift Testing suite
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/<SuiteName> test 2>&1 | tail -10

# Run the full suite (FAIL=5 baseline expected)
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

**Xcode synchronized folder groups are enabled** (verified at `project.pbxproj` `PBXFileSystemSynchronizedRootGroup`). New `.swift` files dropped into `SonicMerge/` or `SonicMergeTests/` directories are auto-included in the build — **no project.pbxproj edits required**.

---

## Chunk 1: Source picker scaffolding + Smart Cut Files-only wiring

**Why this chunk:** Get the new sheet working end-to-end with the existing Files path before introducing any new sources. This proves the sheet ↔ host wiring and the dismiss-then-present chain on a known-good action, so when Record / Photos arrive in Chunks 2-3, only the new pieces are unproven.

**At the end of this chunk:** Tapping any Smart Cut import button opens the new bottom sheet with three rows. Tapping "Files / iCloud Drive" dismisses the sheet and presents the existing iOS document picker exactly as today. Tapping "Record" or "Photos & Videos" dismisses the sheet and prints a placeholder line to the console (stubbed until Chunks 2-3).

### Task 1.1: `ImportSourceAction` + `ImportSourceDispatcher` (pure helper, fully unit-tested)

**Files:**
- Create: `SonicMerge/DesignSystem/ImportSourceDispatcher.swift`
- Test: `SonicMergeTests/DesignSystem/ImportSourceDispatcherTests.swift`

- [ ] **Step 1.1.1: Write the failing test**

Create `SonicMergeTests/DesignSystem/ImportSourceDispatcherTests.swift`:

```swift
// SonicMergeTests/DesignSystem/ImportSourceDispatcherTests.swift
import Testing
@testable import SonicMerge

@MainActor
struct ImportSourceDispatcherTests {

    @Test func filesActionInvokesOnlyFilesClosure() {
        var filesCount = 0
        var recordCount = 0
        var photosCount = 0
        let d = ImportSourceDispatcher(
            onFiles:  { filesCount  += 1 },
            onRecord: { recordCount += 1 },
            onPhotos: { photosCount += 1 }
        )
        d.dispatch(.files)
        #expect(filesCount  == 1)
        #expect(recordCount == 0)
        #expect(photosCount == 0)
    }

    @Test func recordActionInvokesOnlyRecordClosure() {
        var filesCount = 0
        var recordCount = 0
        var photosCount = 0
        let d = ImportSourceDispatcher(
            onFiles:  { filesCount  += 1 },
            onRecord: { recordCount += 1 },
            onPhotos: { photosCount += 1 }
        )
        d.dispatch(.record)
        #expect(filesCount  == 0)
        #expect(recordCount == 1)
        #expect(photosCount == 0)
    }

    @Test func photosActionInvokesOnlyPhotosClosure() {
        var filesCount = 0
        var recordCount = 0
        var photosCount = 0
        let d = ImportSourceDispatcher(
            onFiles:  { filesCount  += 1 },
            onRecord: { recordCount += 1 },
            onPhotos: { photosCount += 1 }
        )
        d.dispatch(.photos)
        #expect(filesCount  == 0)
        #expect(recordCount == 0)
        #expect(photosCount == 1)
    }

    @Test func dispatchIsIdempotentPerCall() {
        var filesCount = 0
        let d = ImportSourceDispatcher(
            onFiles:  { filesCount += 1 },
            onRecord: {},
            onPhotos: {}
        )
        d.dispatch(.files)
        d.dispatch(.files)
        d.dispatch(.files)
        #expect(filesCount == 3)  // each dispatch invokes once, no swallowing
    }
}
```

- [ ] **Step 1.1.2: Run the test — verify it fails to compile**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/ImportSourceDispatcherTests test 2>&1 | tail -10
```

Expected: build error `cannot find 'ImportSourceDispatcher' in scope` (or similar). The test references symbols that don't exist yet.

- [ ] **Step 1.1.3: Write the minimal implementation**

Create `SonicMerge/DesignSystem/ImportSourceDispatcher.swift`:

```swift
// SonicMerge/DesignSystem/ImportSourceDispatcher.swift
//
// Pure helper used by ImportSourceSheet to decouple "user tapped a row"
// from "host view performs the action." Tests verify dispatch routing
// without touching the SwiftUI view tree.
//

import Foundation

enum ImportSourceAction {
    case files
    case record
    case photos
}

@MainActor
struct ImportSourceDispatcher {
    let onFiles: () -> Void
    let onRecord: () -> Void
    let onPhotos: () -> Void

    func dispatch(_ action: ImportSourceAction) {
        switch action {
        case .files:  onFiles()
        case .record: onRecord()
        case .photos: onPhotos()
        }
    }
}
```

- [ ] **Step 1.1.4: Run the test — verify it passes**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/ImportSourceDispatcherTests test 2>&1 | tail -5
```

Expected: `** TEST SUCCEEDED **` with 4 tests passing.

- [ ] **Step 1.1.5: Commit**

```bash
git add SonicMerge/DesignSystem/ImportSourceDispatcher.swift \
        SonicMergeTests/DesignSystem/ImportSourceDispatcherTests.swift
git commit -m "feat(import): ImportSourceAction + dispatcher helper

Pure helper that routes one of three source actions (files / record /
photos) to a closure. Decouples the SwiftUI sheet from the host view's
state so tests can verify routing without view-tree introspection.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 1.2: `ImportSourceSheet` SwiftUI view

**Files:**
- Create: `SonicMerge/DesignSystem/ImportSourceSheet.swift`

The sheet renders three full-width rows wrapped in `studioFrostedCapsule` (existing modifier). Tapping a row sets a binding to an `ImportSourceAction` and dismisses. The host view's `.sheet(onDismiss:)` reads the binding and presents the appropriate destination — this is the standard SwiftUI pattern for chained presentations and avoids the iOS 17 race when one sheet dismisses and another is presented in the same frame.

- [ ] **Step 1.2.1: Write the view**

Create `SonicMerge/DesignSystem/ImportSourceSheet.swift`:

```swift
// SonicMerge/DesignSystem/ImportSourceSheet.swift
//
// Bottom sheet shown when the user taps any tab's Import button. Renders
// three source rows (Files / Record / Photos & Videos) and writes the
// chosen action into a binding. The host view reads the binding from
// .sheet(onDismiss:) and presents the matching destination.
//

import SwiftUI

struct ImportSourceSheet: View {

    @Binding var pendingAction: ImportSourceAction?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color(uiColor: semantic.textSecondary).opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 4)

            Text("Import audio")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            row(action: .files,
                systemImage: "folder.fill",
                title: "Files / iCloud Drive",
                subtitle: "Browse files on your device or iCloud")
            row(action: .record,
                systemImage: "mic.fill",
                title: "Record now",
                subtitle: "Capture audio with the microphone")
            row(action: .photos,
                systemImage: "photo.on.rectangle",
                title: "Photos & Videos",
                subtitle: "Extract audio from a video")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .background(Color(uiColor: semantic.surfaceBase))
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.hidden)
    }

    private func row(action: ImportSourceAction,
                     systemImage: String,
                     title: String,
                     subtitle: String) -> some View {
        Button {
            pendingAction = action
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(uiColor: semantic.accentAction))
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(Color(uiColor: semantic.textPrimary))
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(uiColor: semantic.textSecondary).opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .studioFrostedCapsule(cornerRadius: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 1.2.2: Verify the file builds**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. Sheet has no callers yet; this just compiles.

- [ ] **Step 1.2.3: Commit**

```bash
git add SonicMerge/DesignSystem/ImportSourceSheet.swift
git commit -m "feat(import): ImportSourceSheet view

Bottom sheet with three source rows (Files / Record / Photos). Brand
accentAction on icons (navigation moments, not AI). Writes the chosen
action to a binding and dismisses; host view presents the matching
destination from .sheet(onDismiss:) to avoid iOS 17 sheet-chain races.

No callers yet — wired into Smart Cut in the next task.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 1.3: Wire `ImportSourceSheet` onto `SmartCutHomeView` (Files works; Record + Photos stubbed)

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift`

The diff replaces the two `CircularImportButton` `action: { showFileImporter = true }` callsites with `action: { showSourceSheet = true }`, adds the `.sheet` modifier, and adds an `@State pendingAction: ImportSourceAction?` to coordinate dismiss-then-present.

Existing structure (already verified, lines 48-54 / 94 / 104):

```swift
.fileImporter(isPresented: $showFileImporter, ...) { ... }
...
CircularImportButton(size: .hero) { showFileImporter = true }
...
CircularImportButton(size: .pinned) { showFileImporter = true }
```

- [ ] **Step 1.3.1: Add the new state vars and the source sheet modifier**

In `SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift`, locate the struct's `@State` declarations (search for `@State private var showFileImporter`) and add two new properties next to it:

```swift
@State private var showSourceSheet = false
@State private var pendingAction: ImportSourceAction?
```

Then locate the existing `.fileImporter(...)` block (around line 48). Insert this `.sheet` modifier **immediately above** the `.fileImporter`, on the same view chain:

```swift
.sheet(
    isPresented: $showSourceSheet,
    onDismiss: {
        guard let action = pendingAction else { return }
        pendingAction = nil
        switch action {
        case .files:
            showFileImporter = true
        case .record:
            // Wired in Chunk 2.
            print("[ImportSourceSheet] record tapped — wiring lands in Chunk 2")
        case .photos:
            // Wired in Chunk 3.
            print("[ImportSourceSheet] photos tapped — wiring lands in Chunk 3")
        }
    }
) {
    ImportSourceSheet(pendingAction: $pendingAction)
}
```

- [ ] **Step 1.3.2: Repoint the two `CircularImportButton` callsites**

Find the two `CircularImportButton(...) { showFileImporter = true }` lines (around 94 and 104) and change the closure to:

```swift
CircularImportButton(size: .hero) { showSourceSheet = true }
...
CircularImportButton(size: .pinned) { showSourceSheet = true }
```

- [ ] **Step 1.3.3: Build and verify nothing else broke**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 1.3.4: Run existing Smart Cut gating tests — confirm no regression**

The `SmartCutHomeView.ImportDecision.gate(...)` flow is unchanged; the existing tests must still pass.

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/SmartCutHomeViewGatingTests test 2>&1 | tail -10
```

Expected: all 5 tests in `SmartCutHomeViewGatingTests` pass (`freeUserUnderCapsAllowed`, `freeUserExceedsLengthCap`, `freeUserHitsDailyCap`, `proUserBypassesAllCaps`, `lengthCapTakesPrecedenceOverDailyCap`).

- [ ] **Step 1.3.5: Run the full suite — confirm `FAIL=5` baseline preserved**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5` exactly, with the five known-failing tests being the documented baseline (`compositionWithCrossfadeHasNonNilAudioMix`, `testFileCopyToClipsDirectory`, `testLargeFileCopyDoesNotCrash`, `testPendingKeyWrittenAndCleared`, `testPositionPreservedOnSwitch`). Any new failure name = regression — investigate before committing.

- [ ] **Step 1.3.6: Commit**

```bash
git add SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift
git commit -m "feat(import): wire ImportSourceSheet onto Smart Cut home

Tapping the import button now opens the source sheet; Files row falls
through to the existing .fileImporter via .sheet(onDismiss:). Record and
Photos rows print placeholders until Chunks 2 and 3 land.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 1.4: Manual smoke test on the simulator

This task is verification-only — no code changes. Confirms the chain works end-to-end before the new-source chunks land.

- [ ] **Step 1.4.1: Boot the iPhone 17 simulator and install the build**

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null || true
open -a Simulator
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -3
# Pick the most recently built .app to avoid ambiguous-glob errors when
# multiple SonicMerge-* DerivedData folders exist.
APP_PATH=$(/bin/ls -td ~/Library/Developer/Xcode/DerivedData/SonicMerge-*/Build/Products/Debug-iphonesimulator/SonicMerge.app 2>/dev/null | head -1)
echo "Installing: $APP_PATH"
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.dtech.SonicMerge
```

- [ ] **Step 1.4.2: Verify the empty-state import button on Smart Cut**

Navigate to the Smart Cut tab (it's the leftmost tab in the bottom bar). Tap the large circular import button.

Expected:
- Bottom sheet slides up showing three rows: "Files / iCloud Drive", "Record now", "Photos & Videos".
- Each row has a brand-accent system icon (the live `accentAction` token — currently burnt orange `#EA580C`), title in primary text, subtitle in secondary text, chevron on the right.
- Sheet height is fixed at 340pt — does not expand to medium/large.

- [ ] **Step 1.4.3: Verify the Files row presents the document picker**

Tap "Files / iCloud Drive".

Expected:
- Source sheet dismisses.
- iOS document picker appears (the same one that appeared before this chunk).
- Allowed types still include `.wav`, AAC, `.m4a`, `.mp3`, `.aiff`, `.caf` (the set established earlier).
- Cancelling the picker leaves the user back on the Smart Cut home with no error.
- Selecting an audio file creates a Smart Cut session as before.

- [ ] **Step 1.4.4: Verify the Record row prints a placeholder**

Tap the import button again, then tap "Record now".

Expected:
- Source sheet dismisses.
- Console (Xcode debug log) prints `[ImportSourceSheet] record tapped — wiring lands in Chunk 2`.
- No crash, no UI artifact.

- [ ] **Step 1.4.5: Verify the Photos row prints a placeholder**

Tap the import button again, then tap "Photos & Videos".

Expected:
- Source sheet dismisses.
- Console prints `[ImportSourceSheet] photos tapped — wiring lands in Chunk 3`.

- [ ] **Step 1.4.6: Verify the pinned (loaded-state) import button**

Import a file (any way) so the Smart Cut home shows the loaded-state list with sessions. Tap the pinned (top-right, smaller) import button.

Expected: same source sheet appears with the same three rows.

- [ ] **Step 1.4.7: No commit needed**

This task is verification only. If any expected behavior failed, fix in the prior task and re-run.

---

**End of Chunk 1.** Reviewed and approved 2026-05-08.

---

## Chunk 2: Microphone recording

**Why this chunk:** Wire the Record source from end to end on Smart Cut. Files works (Chunk 1); now add the recorder so users can capture audio in-app. Photos comes in Chunk 3, full rollout to Denoise + Merge in Chunk 4.

**At the end of this chunk:** Tapping "Record now" on Smart Cut opens a sheet with a record button, elapsed-time readout, and live level meter. Recording → stop → Save creates a Smart Cut session via the existing `createSession(from:)` path. Mic permission denied → inline "Open Settings" state. Cancel discards the temp file.

**New files:**
- `SonicMerge/Features/Recording/RecordPermissionProvider.swift` — protocol + system implementation
- `SonicMerge/Features/Recording/AudioRecorderService.swift` — `@MainActor` `ObservableObject` recorder
- `SonicMerge/Features/Recording/RecorderSheet.swift` — SwiftUI sheet bound to the service
- `SonicMergeTests/Features/Recording/AudioRecorderServiceTests.swift`

**Modified files:**
- `SonicMerge/Info.plist` — add `NSMicrophoneUsageDescription`
- `SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift` — replace the Record stub with the real sheet

### Task 2.1: Add `NSMicrophoneUsageDescription` to Info.plist

**Files:**
- Modify: `SonicMerge/Info.plist` (add key after existing `NSSpeechRecognitionUsageDescription` at line 65-66)

- [ ] **Step 2.1.1: Insert the microphone usage key**

In `SonicMerge/Info.plist`, find the existing `NSSpeechRecognitionUsageDescription` key (line 65-66). Immediately after its closing `</string>` and before the next `<!-- Smart Cut: BGProcessingTask` comment, insert:

```xml
	<!-- Recording: AVAudioRecorder mic capture for in-app voice recording -->
	<key>NSMicrophoneUsageDescription</key>
	<string>CleanCut records voice using the microphone so you can capture and clean audio without leaving the app. Recordings stay on your device.</string>
```

- [ ] **Step 2.1.2: Build to confirm the plist parses**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. Plist syntax errors would surface as `Could not read Info.plist` or `Property list invalid for format`.

- [ ] **Step 2.1.3: Commit**

```bash
git add SonicMerge/Info.plist
git commit -m "feat(recording): add NSMicrophoneUsageDescription

Required for AVAudioRecorder consent prompt before in-app recording.
Copy emphasizes the on-device privacy posture.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.2: `RecordPermissionProvider` protocol + system implementation

**Files:**
- Create: `SonicMerge/Features/Recording/RecordPermissionProvider.swift`

This is the DI seam so tests can stub permission state without invoking `AVAudioSession`. Tiny — one protocol and one concrete struct (`SystemRecordPermissionProvider`) used directly as a default initializer argument.

- [ ] **Step 2.2.1: Write the file**

Create `SonicMerge/Features/Recording/RecordPermissionProvider.swift`:

```swift
// SonicMerge/Features/Recording/RecordPermissionProvider.swift
//
// DI seam over AVAudioApplication's mic-permission request. Production
// uses `SystemRecordPermissionProvider()`; tests pass a stub that
// returns a fixed grant/deny result.
//

import AVFoundation

protocol RecordPermissionProvider: Sendable {
    /// Returns `true` if the user grants microphone access (or has previously
    /// granted it). `false` if denied.
    func request() async -> Bool
}

struct SystemRecordPermissionProvider: RecordPermissionProvider {
    func request() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
```

> **Why `AVAudioApplication.requestRecordPermission` and not the older `AVAudioSession.sharedInstance().requestRecordPermission(_:)`?** iOS 17 deprecated the session-level API. The new app-level call works on iOS 17+ which is the project's deployment floor. Confirm by `grep -n "requestRecordPermission" SonicMerge` returning no other usage — there isn't one today.

- [ ] **Step 2.2.2: Build**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2.2.3: Commit**

```bash
git add SonicMerge/Features/Recording/RecordPermissionProvider.swift
git commit -m "feat(recording): RecordPermissionProvider DI seam

Protocol + system implementation wrapping AVAudioApplication's
requestRecordPermission. Tests pass a stub; production uses
SystemRecordPermissionProvider directly.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.3: `AudioRecorderService` (`@MainActor` `ObservableObject`)

**Files:**
- Create: `SonicMerge/Features/Recording/AudioRecorderService.swift`
- Test: `SonicMergeTests/Features/Recording/AudioRecorderServiceTests.swift`

The service wraps `AVAudioRecorder`, polls `currentTime` and `averagePower(forChannel:)`, exposes `@Published` state for the SwiftUI sheet.

- [ ] **Step 2.3.1: Write the failing test (permission denial only)**

The test host (`SonicMergeTests`) lacks the microphone entitlement and reliable simulator audio backend, so any test that lets `start()` proceed past the permission check will trip on `AVAudioSession.setActive(true)`. We test only the permission-denied path here — the cancel/save/cleanup behavior is covered by manual QA in Step 2.5.4. (Refactoring an `AudioRecorderEngine` protocol to stub the recorder side would be the right step the day a hardware-light test is needed; YAGNI for now.)

Create `SonicMergeTests/Features/Recording/AudioRecorderServiceTests.swift`:

```swift
// SonicMergeTests/Features/Recording/AudioRecorderServiceTests.swift
import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct AudioRecorderServiceTests {

    private struct StubPermissions: RecordPermissionProvider {
        let granted: Bool
        func request() async -> Bool { granted }
    }

    @Test func startThrowsWhenPermissionDenied() async {
        let svc = AudioRecorderService(permissions: StubPermissions(granted: false))
        await #expect(throws: AudioRecorderService.RecorderError.micPermissionDenied) {
            try await svc.start()
        }
    }
}
```

- [ ] **Step 2.3.2: Run the tests — verify build error**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/AudioRecorderServiceTests test 2>&1 | tail -10
```

Expected: build error `cannot find 'AudioRecorderService' in scope`.

- [ ] **Step 2.3.3: Write the service**

Create `SonicMerge/Features/Recording/AudioRecorderService.swift`:

```swift
// SonicMerge/Features/Recording/AudioRecorderService.swift
//
// In-app voice recorder. @MainActor + ObservableObject because AVAudioRecorder
// is single-threaded and the SwiftUI sheet observes @Published state. DI seam
// for mic permission via RecordPermissionProvider.
//
// Output: AAC .m4a, 44.1 kHz, mono, 128 kbps — matches the rest of the app's
// export defaults so the recorded file decodes via AVAsset everywhere else
// without re-encoding.
//

import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioRecorderService: ObservableObject {

    enum RecorderError: Error, Equatable {
        case micPermissionDenied
        case sessionConfigurationFailed
        case recorderInitFailed
        case startFailed
    }

    // MARK: Published state (single 20 Hz timer drives both elapsed time
    // and level — the spec's "10 Hz / 20 Hz" was conservative; one timer
    // is simpler and the user can't perceive the difference at 50ms ticks).
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var levelNormalized: Float = 0  // [0, 1]

    // MARK: Identity
    private(set) var currentFileURL: URL?

    // MARK: Internals
    private let permissions: any RecordPermissionProvider
    private var recorder: AVAudioRecorder?
    private var pollTask: Task<Void, Never>?
    private var previousSessionCategory: AVAudioSession.Category?
    private var previousSessionOptions: AVAudioSession.CategoryOptions = []

    init(permissions: any RecordPermissionProvider = SystemRecordPermissionProvider()) {
        self.permissions = permissions
    }

    // No deinit cleanup needed: pollTask captures [weak self] and naturally
    // exits when self deallocates OR isRecording becomes false. Explicit
    // cleanup happens via stop() / cancel() while the sheet is on screen.

    func start() async throws {
        guard !isRecording else { return }

        let granted = await permissions.request()
        guard granted else { throw RecorderError.micPermissionDenied }

        let session = AVAudioSession.sharedInstance()
        previousSessionCategory = session.category
        previousSessionOptions = session.categoryOptions
        do {
            try session.setCategory(.playAndRecord,
                                    options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            throw RecorderError.sessionConfigurationFailed
        }

        let url = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("recording-\(UUID().uuidString).m4a")
        currentFileURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128_000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let r: AVAudioRecorder
        do {
            r = try AVAudioRecorder(url: url, settings: settings)
        } catch {
            throw RecorderError.recorderInitFailed
        }
        r.isMeteringEnabled = true
        // No delegate — we drive lifecycle explicitly via stop()/cancel(),
        // and assigning a @MainActor self to AVAudioRecorder.delegate
        // (a non-isolated weak ref) tickles Swift 6 strict-concurrency.

        guard r.prepareToRecord(), r.record() else {
            throw RecorderError.startFailed
        }
        recorder = r
        isRecording = true
        startPolling()
    }

    /// Stops recording and returns the final URL. The file is left in /tmp;
    /// caller is responsible for moving/copying it out before the temp dir
    /// is reaped.
    func stop() -> URL? {
        guard isRecording, let recorder, let url = currentFileURL else { return nil }
        recorder.stop()
        finishSession()
        return url
    }

    /// Stops recording and deletes the temp file.
    func cancel() {
        guard let recorder, let url = currentFileURL else {
            finishSession()
            return
        }
        recorder.stop()
        try? FileManager.default.removeItem(at: url)
        currentFileURL = nil
        finishSession()
    }

    private func finishSession() {
        pollTask?.cancel()
        pollTask = nil
        recorder = nil
        isRecording = false
        elapsedSeconds = 0
        levelNormalized = 0
        if let prev = previousSessionCategory {
            try? AVAudioSession.sharedInstance().setCategory(prev, options: previousSessionOptions)
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        previousSessionCategory = nil
        previousSessionOptions = []
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled, self.isRecording, let r = self.recorder {
                r.updateMeters()
                let dB = r.averagePower(forChannel: 0)
                // dB ∈ [-160, 0]. Map to [0, 1] via 10^(dB/20). Floor at -50 dB
                // for a more useful visual range (anything quieter renders as 0).
                let clamped = max(dB, -50)
                self.levelNormalized = pow(10, clamped / 20)
                self.elapsedSeconds = r.currentTime
                try? await Task.sleep(for: .milliseconds(50))  // 20 Hz
            }
        }
    }
}
```

- [ ] **Step 2.3.4: Run the tests — verify they pass**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/AudioRecorderServiceTests test 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **` with 1 test passing (`startThrowsWhenPermissionDenied`).

> **Why no save/cancel/cleanup unit tests:** the test host doesn't have a microphone entitlement and the simulator audio backend is unreliable for `AVAudioSession.setActive(true)` from a Swift Testing process. Manual QA in Step 2.5.4 covers save, cancel, swipe-dismiss-cleanup, and Settings-recover paths. If hardware-light tests become necessary later, the right move is to extract an `AudioRecorderEngine` protocol that wraps the file-write side and stub it.

- [ ] **Step 2.3.5: Commit**

```bash
git add SonicMerge/Features/Recording/AudioRecorderService.swift \
        SonicMergeTests/Features/Recording/AudioRecorderServiceTests.swift
git commit -m "feat(recording): AudioRecorderService

@MainActor ObservableObject wrapping AVAudioRecorder. Publishes
isRecording, elapsedSeconds, levelNormalized for the SwiftUI sheet.
Captures and restores AVAudioSession category around start/stop so
playback elsewhere isn't affected. Test covers the permission-denied
path via a RecordPermissionProvider stub; save/cancel are exercised
via manual QA per the simulator's audio-session limitations.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.4: `RecorderSheet` SwiftUI view

**Files:**
- Create: `SonicMerge/Features/Recording/RecorderSheet.swift`

Minimal recorder UX (option A from the spec): big timer, level meter, single Stop/Record button, Cancel + Save in the top bar. Permission-denied state replaces the controls with a Settings deep-link.

- [ ] **Step 2.4.1: Write the view**

Create `SonicMerge/Features/Recording/RecorderSheet.swift`:

```swift
// SonicMerge/Features/Recording/RecorderSheet.swift
//
// Minimal in-app recorder. Tap Record → captures audio. Tap Stop → enables
// Save. Save → invokes onComplete(url) so the host view can route the file
// to its tab's import path. Cancel → discards the temp file.
//

import SwiftUI
import UIKit

struct RecorderSheet: View {

    let onComplete: (URL) -> Void

    @StateObject private var recorder = AudioRecorderService()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sonicMergeSemantic) private var semantic

    @State private var permissionDenied = false
    @State private var startError: AudioRecorderService.RecorderError?
    @State private var savedURL: URL?
    @State private var didSave = false

    var body: some View {
        VStack(spacing: 24) {
            topBar
            if permissionDenied {
                deniedState
            } else {
                Spacer()
                timer
                levelMeter
                Spacer()
                primaryButton
                Spacer().frame(height: 16)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .background(Color(uiColor: semantic.surfaceBase))
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(recorder.isRecording)
        .onDisappear {
            // Sheet may dismiss via swipe (when not recording) without Save.
            // If user didn't save, drop any temp file we produced.
            if !didSave, let url = savedURL ?? recorder.currentFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            // No-op if recorder already stopped.
            recorder.cancel()
        }
    }

    // MARK: Subviews

    private var topBar: some View {
        HStack {
            Button("Cancel") {
                recorder.cancel()
                dismiss()
            }
            .foregroundStyle(Color(uiColor: semantic.accentAction))
            Spacer()
            Text("New Recording")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
            Spacer()
            Button("Save") {
                guard let url = savedURL else { return }
                didSave = true
                onComplete(url)
                dismiss()
            }
            .fontWeight(.semibold)
            .foregroundStyle(Color(uiColor: semantic.accentAction))
            .disabled(savedURL == nil)
        }
    }

    private var timer: some View {
        Text(format(recorder.elapsedSeconds))
            .font(.system(size: 56, weight: .ultraLight, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color(uiColor: semantic.textPrimary))
    }

    private var levelMeter: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<20, id: \.self) { i in
                Capsule()
                    .fill(Color(uiColor: semantic.accentAction))
                    .frame(width: 4, height: barHeight(for: i))
                    .opacity(recorder.isRecording ? 1.0 : 0.3)
            }
        }
        .frame(height: 56)
        // No .animation here — the 50ms polling already drives smooth-enough
        // updates. Adding implicit animation on a per-frame value triggers
        // SwiftUI to interpolate twice and over-renders.
    }

    private var primaryButton: some View {
        Button {
            primaryAction()
        } label: {
            ZStack {
                Circle()
                    .fill(recorder.isRecording ? Color(uiColor: .systemGray) : Color.red)
                    .frame(width: 88, height: 88)
                if recorder.isRecording {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                } else {
                    Circle().fill(Color.white).frame(width: 32, height: 32)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(savedURL != nil)  // can't restart after a save in Minimal UX
    }

    private var deniedState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
            Text("Microphone access is off")
                .font(.headline)
            Text("Enable microphone access for CleanCut in Settings to record audio.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(uiColor: semantic.accentAction))
            .padding(.top, 8)
        }
        .padding(.horizontal, 32)
        .padding(.top, 40)
        Spacer()
    }

    // MARK: Logic

    private func primaryAction() {
        if recorder.isRecording {
            savedURL = recorder.stop()
        } else if savedURL == nil {
            Task { await beginRecording() }
        }
    }

    private func beginRecording() async {
        guard !recorder.isRecording, savedURL == nil else { return }
        do {
            try await recorder.start()
        } catch AudioRecorderService.RecorderError.micPermissionDenied {
            permissionDenied = true
        } catch let err as AudioRecorderService.RecorderError {
            startError = err
        } catch {
            startError = .startFailed
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        // Map [0, 1] level to a smooth bar pattern. Center bars peak higher
        // when level is high; outer bars stay lower so the meter reads as
        // an audio-level visualization rather than a flat row.
        let center = 9.5
        let distance = abs(Double(index) - center)
        let centerWeight = max(0, 1.0 - distance / 12.0)
        let scaled = Double(recorder.levelNormalized) * centerWeight
        return max(4, CGFloat(8 + scaled * 40))
    }

    private func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
```

- [ ] **Step 2.4.2: Build to confirm the view compiles**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2.4.3: Commit**

```bash
git add SonicMerge/Features/Recording/RecorderSheet.swift
git commit -m "feat(recording): RecorderSheet view

Minimal recorder UX (option A): timer, level meter, single Record/Stop
button, Cancel + Save in the top bar. Permission-denied state shows an
Open Settings deep-link.

No callers yet — wired into Smart Cut in the next task.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.5: Wire `RecorderSheet` onto `SmartCutHomeView`

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift`

The Record stub from Chunk 1 (`print("[ImportSourceSheet] record tapped...")`) is replaced with a real sheet presentation.

- [ ] **Step 2.5.1: Add a `showRecorder` flag and a `.sheet` for the recorder**

Locate the existing `@State private var showSourceSheet = false` line in `SmartCutHomeView.swift`. Add immediately after:

```swift
@State private var showRecorder = false
```

Locate the existing `.sheet(isPresented: $showSourceSheet, onDismiss: { ... })` block from Chunk 1. Inside its `onDismiss` closure, **replace the entire `case .record:` arm including the placeholder `print(...)` line.** The `case .record:` should now read in full:

```swift
case .record:
    showRecorder = true
```

Verify no `print("[ImportSourceSheet] record tapped...")` line remains anywhere in the file (search for `record tapped` to confirm).

Then **outside** that sheet block, on the same view chain (next to `.fileImporter`), add:

```swift
.sheet(isPresented: $showRecorder) {
    RecorderSheet { url in
        Task {
            await createSession(from: url)
            // Recording is the only source where we own the URL outright,
            // so we delete the /tmp file after createSession's copy. Files
            // and Photos paths come from system pickers and are best left
            // to the OS reaper.
            try? FileManager.default.removeItem(at: url)
        }
    }
}
```

`createSession(from:)` is the existing private method on `SmartCutHomeView` (line 141) that handles the import path including the `ImportDecision.gate` call.

- [ ] **Step 2.5.2: Build**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2.5.3: Run full suite — confirm `FAIL=5` baseline preserved**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`. One new test (`AudioRecorderServiceTests.startThrowsWhenPermissionDenied`) brings the total up by 1, plus the four `ImportSourceDispatcherTests` from Chunk 1, with no new failures.

- [ ] **Step 2.5.4: Manual smoke test on the simulator**

Boot a fresh simulator (so the mic-permission prompt has not yet been answered), install, launch.

Expected behavior:
- Tap import button → source sheet appears.
- Tap "Record now" → recorder sheet renders: 0:00 timer, idle level meter (low alpha bars), big red Record button. (No permission prompt yet — that fires on first record tap.)
- Tap Record → first time: iOS prompts "CleanCut would like to access the microphone." Tap **Allow** → button switches to grey Stop, timer counts up, level meter responds to ambient sound.
- Tap Stop → meter freezes, Save becomes enabled.
- Tap Save → sheet dismisses → after a moment, navigation pushes into the new Smart Cut session (existing onSelect path).
- Verify temp cleanup: `xcrun simctl get_app_container booted com.dtech.SonicMerge tmp` and `ls $TMP/recording-*.m4a` should return no files after a save. (The temp file is removed in `onComplete`.)
- Reopen, tap "Record now" again, tap Cancel mid-recording → file is discarded, sheet closes, no session created.
- **Swipe-dismiss while recording is blocked** (`.interactiveDismissDisabled`). Verify by starting a recording and trying to swipe the sheet down — it should resist.
- Reset permissions: `xcrun simctl privacy booted reset microphone com.dtech.SonicMerge` → re-launch → tap Record → deny when prompted → recorder sheet shows the "Microphone access is off" state with Open Settings button.
- **Recover-from-Settings path:** while in the denied state, tap Open Settings → enable Microphone → return to the app. The sheet still shows the denied state (Minimal UX — the user has to dismiss and reopen the recorder). Confirm that dismissing and reopening then works normally.

- [ ] **Step 2.5.5: Commit**

```bash
git add SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift
git commit -m "feat(recording): wire RecorderSheet onto Smart Cut home

Tapping 'Record now' on the source sheet now opens the recorder. Save
funnels the URL into the existing createSession(from:) path so the
ImportDecision gate and SwiftData session creation are reused.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

**End of Chunk 2.** Stop here for plan-document review before continuing to Chunk 3.
