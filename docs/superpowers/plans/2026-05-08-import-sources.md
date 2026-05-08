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

**End of Chunk 2.** Reviewed and approved 2026-05-08.

---

## Chunk 3: Photos & Videos source

**Why this chunk:** Wire the third source (extract audio from a video picked via PHPicker). After this, all three Smart Cut import sources work end to end.

**At the end of this chunk:** Tapping "Photos & Videos" on Smart Cut presents `PHPickerViewController`. Picking a video copies it to a temp file, extracts the audio track to an `.m4a`, and funnels the result into the existing `createSession(from:)` path. Picking a silent video shows an alert "This video has no audio to import." Picking a video that fails to extract shows an alert with the underlying error.

**New files:**
- `SonicMerge/Services/VideoAudioExtractor.swift`
- `SonicMerge/Features/Photos/PHPickerWrapper.swift`
- `SonicMergeTests/Services/VideoAudioExtractorTests.swift`
- `SonicMergeTests/Fixtures/silent-video.mp4` (a 1-second silent video committed as test fixture)
- `SonicMergeTests/Fixtures/audible-video.mp4` (a 2-second video with a 440 Hz sine tone)

**Modified files:**
- `SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift` — replace the Photos stub

### Task 3.1: `VideoAudioExtractor` service + tests

**Files:**
- Create: `SonicMerge/Services/VideoAudioExtractor.swift`
- Test: `SonicMergeTests/Services/VideoAudioExtractorTests.swift`
- Create: `SonicMergeTests/Fixtures/silent-video.mp4`
- Create: `SonicMergeTests/Fixtures/audible-video.mp4`

- [ ] **Step 3.1.1: Generate the test fixtures**

The fixtures are small (≪ 100 KB each) and deterministic so they can be checked in without bloating the repo. Generate via `ffmpeg` (Homebrew or system install):

```bash
mkdir -p SonicMergeTests/Fixtures

# Silent 1s video — black frame, no audio track
ffmpeg -y -f lavfi -i color=c=black:s=64x64:d=1 \
  -c:v h264 -pix_fmt yuv420p \
  SonicMergeTests/Fixtures/silent-video.mp4

# 2s video with a 440 Hz sine tone audio track
ffmpeg -y -f lavfi -i color=c=black:s=64x64:d=2 \
       -f lavfi -i sine=frequency=440:duration=2 \
  -c:v h264 -pix_fmt yuv420p \
  -c:a aac -b:a 64k -shortest \
  SonicMergeTests/Fixtures/audible-video.mp4

# Sanity check
ffprobe -v error -show_streams \
  SonicMergeTests/Fixtures/audible-video.mp4 | grep codec_type
ffprobe -v error -show_streams \
  SonicMergeTests/Fixtures/silent-video.mp4 | grep codec_type
```

Expected `ffprobe` output:
- `audible-video.mp4` — two `codec_type=` lines (one `video`, one `audio`).
- `silent-video.mp4` — one `codec_type=video` line, no audio.

If `ffmpeg` is unavailable, alternate path: write a one-shot SwiftPM script that uses `AVAssetWriter` to synthesize the same fixtures. Skipped here for brevity — `ffmpeg` is the standard.

- [ ] **Step 3.1.2: Write the failing tests**

Create `SonicMergeTests/Services/VideoAudioExtractorTests.swift`:

```swift
// SonicMergeTests/Services/VideoAudioExtractorTests.swift
import Testing
import Foundation
import AVFoundation
@testable import SonicMerge

@MainActor
struct VideoAudioExtractorTests {

    private func fixture(_ name: String) -> URL {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: name, withExtension: nil) else {
            fatalError("Missing test fixture: \(name)")
        }
        return url
    }

    @Test func extractFromAudibleVideoReturnsM4A() async throws {
        let src = fixture("audible-video.mp4")
        let out = try await VideoAudioExtractor.extractAudio(from: src)
        defer { try? FileManager.default.removeItem(at: out) }

        #expect(out.pathExtension == "m4a")
        #expect(FileManager.default.fileExists(atPath: out.path))

        // Decoded duration should be in the same ballpark as the source
        // (within 50 ms — encoder bookends sometimes drop a few samples).
        let asset = AVURLAsset(url: out)
        let dur = try await asset.load(.duration).seconds
        #expect(abs(dur - 2.0) < 0.05)
    }

    @Test func extractFromSilentVideoThrowsNoAudioTrack() async {
        let src = fixture("silent-video.mp4")
        await #expect(throws: VideoAudioExtractor.ExtractError.noAudioTrack) {
            _ = try await VideoAudioExtractor.extractAudio(from: src)
        }
    }
}

/// Marker class used to resolve the test bundle for fixture loading.
private final class BundleToken {}
```

- [ ] **Step 3.1.3: Run the test — verify build error**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/VideoAudioExtractorTests test 2>&1 | tail -10
```

Expected: build error `cannot find 'VideoAudioExtractor' in scope`.

- [ ] **Step 3.1.4: Implement the extractor**

Create `SonicMerge/Services/VideoAudioExtractor.swift`:

```swift
// SonicMerge/Services/VideoAudioExtractor.swift
//
// Extract the audio track from a video file and export it as a standalone
// .m4a. Used by the Photos & Videos import source.
//

import AVFoundation
import Foundation

enum VideoAudioExtractor {

    enum ExtractError: Error, Equatable {
        case noAudioTrack
        case exportFailed(String)  // wraps the underlying error description
        case unsupportedFile
    }

    /// Extracts the audio track from `videoURL` and writes it to a temp .m4a.
    /// The caller owns the returned URL and is responsible for moving or
    /// deleting it once consumed.
    static func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else { throw ExtractError.noAudioTrack }

        guard let session = AVAssetExportSession(asset: asset,
                                                 presetName: AVAssetExportPresetAppleM4A) else {
            throw ExtractError.unsupportedFile
        }

        let outURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("extracted-\(UUID().uuidString).m4a")

        session.outputURL = outURL
        session.outputFileType = .m4a

        // iOS 17 compatible: bare `export()` async overload is iOS 18+.
        // Mirror the pattern in AudioMergerService.swift:418-428.
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                switch session.status {
                case .completed:
                    cont.resume()
                case .failed, .cancelled:
                    cont.resume(throwing: ExtractError.exportFailed(
                        session.error?.localizedDescription ?? "unknown"))
                default:
                    cont.resume(throwing: ExtractError.exportFailed(
                        "unexpected status: \(session.status.rawValue)"))
                }
            }
        }
        return outURL
    }
}
```

- [ ] **Step 3.1.5: Add the fixtures to the test target**

Synchronized folder groups pick up `.swift` files automatically, but **resource files (`.mp4`) need to be declared as resources in the test target**. Verify the fixtures are bundled by:

```bash
# Build for testing, then check the test bundle contains the fixtures
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build-for-testing 2>&1 | tail -3

# Find the test xctest bundle and list its resources
TEST_BUNDLE=$(find ~/Library/Developer/Xcode/DerivedData/SonicMerge-* \
  -name "SonicMergeTests.xctest" -type d 2>/dev/null | head -1)
echo "Test bundle: $TEST_BUNDLE"
ls "$TEST_BUNDLE"/*.mp4 2>/dev/null
```

Expected: `audible-video.mp4` and `silent-video.mp4` listed under the test bundle.

If they're missing, the synchronized folder group does NOT include `.mp4` for the test target by default. Open `SonicMerge.xcodeproj` in Xcode → SonicMergeTests target → Build Phases → "Copy Bundle Resources" → drag the two fixtures in. Re-run the build-for-testing and re-check.

> **Why this manual step:** Xcode synchronized folder groups auto-include source files matching the target's `.swift`/`.m`/`.h` patterns, but resource extensions like `.mp4` typically require an explicit Build Phase entry. This is a one-time per-fixture project edit; once added, the files persist via path reference.

- [ ] **Step 3.1.6: Run the tests — verify they pass**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/VideoAudioExtractorTests test 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **` with 2 tests passing.

- [ ] **Step 3.1.7: Commit**

```bash
git add SonicMerge/Services/VideoAudioExtractor.swift \
        SonicMergeTests/Services/VideoAudioExtractorTests.swift \
        SonicMergeTests/Fixtures/silent-video.mp4 \
        SonicMergeTests/Fixtures/audible-video.mp4
git commit -m "feat(import): VideoAudioExtractor

Pure-function helper that extracts the audio track from a video into a
standalone .m4a via AVAssetExportSession. Throws .noAudioTrack on silent
videos, .exportFailed otherwise. Tests use a 1s silent fixture and a 2s
sine-tone fixture (~30 KB total).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3.2: `PHPickerWrapper` UIViewControllerRepresentable

**Files:**
- Create: `SonicMerge/Features/Photos/PHPickerWrapper.swift`

The wrapper presents `PHPickerViewController` filtered to videos and hands the picked URL to a callback. The host view chains the result into `VideoAudioExtractor.extractAudio` and then `createSession`.

- [ ] **Step 3.2.1: Write the wrapper**

Create `SonicMerge/Features/Photos/PHPickerWrapper.swift`:

```swift
// SonicMerge/Features/Photos/PHPickerWrapper.swift
//
// SwiftUI bridge over PHPickerViewController for the Photos & Videos
// import source. Filter is video-only, single-selection. The picked
// asset is loaded as a file representation and handed back as a URL.
//
// PHPickerViewController is Apple-mediated and runs out-of-process, so
// no NSPhotoLibraryUsageDescription is required.
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct PHPickerWrapper: UIViewControllerRepresentable {

    enum PickError: LocalizedError, Equatable {
        case loadFailed(String)
        case missingFile

        var errorDescription: String? {
            switch self {
            case .loadFailed(let msg):
                return "Couldn't load this video. \(msg)"
            case .missingFile:
                return "Couldn't read the picked video."
            }
        }
    }

    let onPickResult: (Result<URL, Error>) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: PHPickerViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPickResult: onPickResult, onCancel: onCancel)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPickResult: (Result<URL, Error>) -> Void
        let onCancel: () -> Void

        init(onPickResult: @escaping (Result<URL, Error>) -> Void,
             onCancel: @escaping () -> Void) {
            self.onPickResult = onPickResult
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController,
                    didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let result = results.first else {
                onCancel()
                return
            }

            let provider = result.itemProvider
            // Prefer the most specific UTI the asset advertises; fall back to
            // generic movie. PHPicker exposes whatever the asset has.
            let typeId = provider.registeredTypeIdentifiers.first(where: {
                UTType($0)?.conforms(to: .movie) == true
            }) ?? UTType.movie.identifier

            provider.loadFileRepresentation(forTypeIdentifier: typeId) { [weak self] tempURL, error in
                guard let self else { return }
                if let error {
                    DispatchQueue.main.async {
                        self.onPickResult(.failure(PickError.loadFailed(error.localizedDescription)))
                    }
                    return
                }
                guard let tempURL else {
                    DispatchQueue.main.async {
                        self.onPickResult(.failure(PickError.missingFile))
                    }
                    return
                }
                // Defensive copy: tempURL is invalidated when this closure
                // returns. Mirror the pattern in ShareExtensionViewController.
                let copyURL = FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent("phpicker-\(UUID().uuidString).\(tempURL.pathExtension)")
                do {
                    try FileManager.default.copyItem(at: tempURL, to: copyURL)
                    DispatchQueue.main.async {
                        self.onPickResult(.success(copyURL))
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.onPickResult(.failure(PickError.loadFailed(error.localizedDescription)))
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3.2.2: Build**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3.2.3: Commit**

```bash
git add SonicMerge/Features/Photos/PHPickerWrapper.swift
git commit -m "feat(import): PHPickerWrapper for video selection

SwiftUI bridge over PHPickerViewController. Video-only filter, single
selection, defensive temp-file copy because PHPicker invalidates the
provider URL when the load callback returns. No photo-library usage
description needed — PHPicker runs out-of-process.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3.3: Wire Photos source onto `SmartCutHomeView`

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift`

Replace the Photos stub with a `.sheet` presenting `PHPickerWrapper`. The picker callback chains: `loadFileRepresentation` → `VideoAudioExtractor.extractAudio` → `createSession(from:)` → temp cleanup.

- [ ] **Step 3.3.1: Add `showPhotoPicker` state and wire the photo path**

In `SmartCutHomeView.swift`, locate the `@State private var showRecorder = false` line from Chunk 2. Add immediately after:

```swift
@State private var showPhotoPicker = false
@State private var photoExtractError: String?
@State private var photoLoading = false
```

In the existing `.sheet(isPresented: $showSourceSheet, onDismiss: { ... })` block, replace the `case .photos:` arm. The whole `case .photos:` should now read in full:

```swift
case .photos:
    showPhotoPicker = true
```

Verify no `print("[ImportSourceSheet] photos tapped...")` line remains anywhere in the file (search for `photos tapped`).

Then add a new `.sheet` modifier on the same view chain (next to the recorder sheet):

```swift
.sheet(isPresented: $showPhotoPicker) {
    PHPickerWrapper(
        onPickResult: { result in
            showPhotoPicker = false
            Task { await handlePhotoPickResult(result) }
        },
        onCancel: { showPhotoPicker = false }
    )
}
.alert(
    "Couldn't import this video",
    isPresented: Binding(
        get: { photoExtractError != nil },
        set: { if !$0 { photoExtractError = nil } }
    )
) {
    Button("OK") {}
} message: {
    Text(photoExtractError ?? "")
}
.overlay {
    // iCloud-resident videos can take seconds to load; PHPicker silently
    // hangs without a hint. Show an indeterminate spinner overlay only if
    // loading runs longer than 500ms, so resident videos don't flash one.
    if photoLoading {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large)
            Text("Loading video…")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
```

Add the new private method `handlePhotoPickResult` to the view (place it next to the existing `createSession(from:)` private method):

```swift
private func handlePhotoPickResult(_ result: Result<URL, Error>) async {
    // Schedule the loading overlay to appear only if work runs > 500ms.
    let overlayTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(500))
        if !Task.isCancelled { photoLoading = true }
    }
    defer {
        overlayTask.cancel()
        photoLoading = false
    }

    switch result {
    case .success(let videoURL):
        defer { try? FileManager.default.removeItem(at: videoURL) }
        do {
            let audioURL = try await VideoAudioExtractor.extractAudio(from: videoURL)
            await createSession(from: audioURL)
            try? FileManager.default.removeItem(at: audioURL)
        } catch VideoAudioExtractor.ExtractError.noAudioTrack {
            photoExtractError = "This video has no audio to import."
        } catch {
            photoExtractError = "Couldn't extract audio. \(error.localizedDescription)"
        }
    case .failure(let error):
        photoExtractError = error.localizedDescription
    }
}
```

- [ ] **Step 3.3.2: Build**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3.3.3: Run full suite — confirm `FAIL=5` baseline preserved**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`. Two new tests (`VideoAudioExtractorTests`) pushed the total up further.

- [ ] **Step 3.3.4: Manual smoke test on the simulator**

The simulator's Photos library starts empty; you need to seed at least one video before testing.

```bash
# Drag a small mp4 into the simulator's Photos to seed it, OR via CLI:
xcrun simctl addmedia booted SonicMergeTests/Fixtures/audible-video.mp4
xcrun simctl addmedia booted SonicMergeTests/Fixtures/silent-video.mp4
```

Then in the app:

- Tap import button → tap "Photos & Videos" → PHPicker appears.
- Pick `audible-video.mp4` → picker dismisses → after a moment, navigation pushes into a new Smart Cut session with the extracted 2-second m4a.
- Tap import again → tap "Photos & Videos" → pick `silent-video.mp4` → alert "This video has no audio to import." dismisses cleanly with OK.
- Tap import again → tap "Photos & Videos" → tap Cancel in the picker → returns to home with no error.
- **iCloud progress overlay (best-effort manual check):** if you have access to an iCloud Photos library with a non-resident video, sign in on the simulator (Settings → Apple ID), wait for Photos to populate, then pick a video that hasn't been downloaded yet. Expected: after ~500ms the "Loading video…" overlay appears, dismisses when the audio extraction completes. Resident videos should NOT flash the overlay.

- [ ] **Step 3.3.5: Commit**

```bash
git add SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift
git commit -m "feat(import): wire Photos & Videos onto Smart Cut home

Tapping 'Photos & Videos' on the source sheet now presents PHPicker.
Picked video → VideoAudioExtractor extracts audio → createSession.
Silent videos surface a friendly alert. Both temp files (the picker
copy and the extracted m4a) are cleaned up after createSession. iCloud
videos: a 'Loading video…' overlay appears after 500ms so the user has
visual feedback while a non-resident asset downloads.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

**End of Chunk 3.** Reviewed and approved 2026-05-08.

---

## Chunk 4: Roll out to Denoise + Merge tabs

**Why this chunk:** Smart Cut already has all three sources (Chunks 1-3). This chunk replicates the same source-sheet wiring on Denoise and Merge, using each tab's existing import target. Denoise mirrors Smart Cut exactly (single-URL → `createSession(from:)`, with its own `ImportDecision.gate`). Merge has two views with their own source sheets (per the spec's "two entry points, each owns its own showSourceSheet" decision); both funnel into `MixingStationViewModel.importFiles([URL])` with no length/quota gate.

**At the end of this chunk:** Every Import button on every tab opens the same Source Picker sheet. Files / Record / Photos all work end to end on Smart Cut, Denoise, and Merge. Full suite still at `FAIL=5` baseline.

**Modified files only — no new files:**
- `SonicMerge/Features/Denoising/Views/Home/DenoiseHomeView.swift`
- `SonicMerge/Features/MixingStation/MixingStationView.swift`
- `SonicMerge/Features/MixingStation/MergeTimelineView.swift`

### Task 4.1: Wire all three sources onto `DenoiseHomeView`

`DenoiseHomeView` mirrors `SmartCutHomeView` almost exactly — single empty + loaded state, two `CircularImportButton` callsites (line 86 hero, line 94 pinned), one `.fileImporter` (line 45), one private `createSession(from:)` method (line 129). The diff shape is identical to Tasks 1.3, 2.5, and 3.3 combined.

**Files:**
- Modify: `SonicMerge/Features/Denoising/Views/Home/DenoiseHomeView.swift`

- [ ] **Step 4.1.1: Add the new state vars**

Locate the existing `@State private var showFileImporter = false` line. Add:

```swift
@State private var showSourceSheet = false
@State private var pendingAction: ImportSourceAction?
@State private var showRecorder = false
@State private var showPhotoPicker = false
@State private var photoExtractError: String?
@State private var photoLoading = false
```

- [ ] **Step 4.1.2: Repoint both `CircularImportButton` callsites**

Find the `CircularImportButton(size: .hero) { showFileImporter = true }` (line 86) and `CircularImportButton(size: .pinned) { showFileImporter = true }` (line 94). Change both closures to `{ showSourceSheet = true }`.

- [ ] **Step 4.1.3: Add the source sheet, recorder sheet, photo picker, alert, and overlay modifiers**

On the same view chain that holds the existing `.fileImporter` (line 45), add — immediately above the `.fileImporter`:

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
            showRecorder = true
        case .photos:
            showPhotoPicker = true
        }
    }
) {
    ImportSourceSheet(pendingAction: $pendingAction)
}
.sheet(isPresented: $showRecorder) {
    RecorderSheet { url in
        Task {
            await createSession(from: url)
            try? FileManager.default.removeItem(at: url)
        }
    }
}
.sheet(isPresented: $showPhotoPicker) {
    PHPickerWrapper(
        onPickResult: { result in
            showPhotoPicker = false
            Task { await handlePhotoPickResult(result) }
        },
        onCancel: { showPhotoPicker = false }
    )
}
.alert(
    "Couldn't import this video",
    isPresented: Binding(
        get: { photoExtractError != nil },
        set: { if !$0 { photoExtractError = nil } }
    )
) {
    Button("OK") {}
} message: {
    Text(photoExtractError ?? "")
}
.overlay {
    if photoLoading {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large)
            Text("Loading video…")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
```

- [ ] **Step 4.1.4: Add `handlePhotoPickResult` next to the existing `createSession(from:)`**

Place this private method right after `createSession(from:)` ends:

```swift
private func handlePhotoPickResult(_ result: Result<URL, Error>) async {
    let overlayTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(500))
        if !Task.isCancelled { photoLoading = true }
    }
    defer {
        overlayTask.cancel()
        photoLoading = false
    }

    switch result {
    case .success(let videoURL):
        defer { try? FileManager.default.removeItem(at: videoURL) }
        do {
            let audioURL = try await VideoAudioExtractor.extractAudio(from: videoURL)
            await createSession(from: audioURL)
            try? FileManager.default.removeItem(at: audioURL)
        } catch VideoAudioExtractor.ExtractError.noAudioTrack {
            photoExtractError = "This video has no audio to import."
        } catch {
            photoExtractError = "Couldn't extract audio. \(error.localizedDescription)"
        }
    case .failure(let error):
        photoExtractError = error.localizedDescription
    }
}
```

> **Symmetry note:** the wiring on `DenoiseHomeView` is byte-for-byte the same as `SmartCutHomeView`, just on a different `createSession(from:)` and a different `ImportDecision.gate(...)`. Resist the urge to extract a shared "ImportablePicker" view modifier — there are exactly two callers of this pattern (Smart Cut + Denoise) and the rule of three says don't extract yet. If a fourth caller appears, that's the time to abstract.

- [ ] **Step 4.1.5: Build**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4.1.6: Run Denoise gating tests — confirm no regression**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:SonicMergeTests/DenoiseHomeViewGatingTests test 2>&1 | tail -10
```

Expected: all tests in `DenoiseHomeViewGatingTests` pass — the gate logic is unchanged.

- [ ] **Step 4.1.7: Commit**

```bash
git add SonicMerge/Features/Denoising/Views/Home/DenoiseHomeView.swift
git commit -m "feat(import): three-source sheet on Denoise home

Mirrors the Smart Cut home wiring: tapping the import button opens the
source sheet; Files / Record / Photos all funnel into the existing
DenoiseHomeView.createSession(from:) path so the per-tab ImportDecision
gate stays intact.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4.2: Wire all three sources onto `MixingStationView` (Merge tab)

Merge has two views with their own importers per the spec; this task handles `MixingStationView`. The downstream target is `viewModel.importFiles([URL])` rather than a `createSession(from:)`.

**Files:**
- Modify: `SonicMerge/Features/MixingStation/MixingStationView.swift`

- [ ] **Step 4.2.1: Add the new state vars**

Locate the existing `@State private var showDocumentPicker = false` line (line 20). Add:

```swift
@State private var showSourceSheet = false
@State private var pendingAction: ImportSourceAction?
@State private var showRecorder = false
@State private var showPhotoPicker = false
@State private var photoExtractError: String?
@State private var photoLoading = false
```

- [ ] **Step 4.2.2: Repoint both `CircularImportButton` callsites**

Find both `CircularImportButton(...) { showDocumentPicker = true }` callsites (line 39 in the loaded state, and the corresponding one in `emptyState` — search for `CircularImportButton(size: .hero)` to find it). Change both closures to `{ showSourceSheet = true }`.

- [ ] **Step 4.2.3: Add the source sheet, recorder sheet, photo picker, alert, and overlay**

On the same view chain that holds the existing `.fileImporter` (line 78), add **immediately above** the `.fileImporter`:

```swift
.sheet(
    isPresented: $showSourceSheet,
    onDismiss: {
        guard let action = pendingAction else { return }
        pendingAction = nil
        switch action {
        case .files:
            showDocumentPicker = true
        case .record:
            showRecorder = true
        case .photos:
            showPhotoPicker = true
        }
    }
) {
    ImportSourceSheet(pendingAction: $pendingAction)
}
.sheet(isPresented: $showRecorder) {
    RecorderSheet { url in
        Task {
            // Merge has no per-tab gate; importFiles handles paywall reasons.
            if let reason = viewModel.importFiles([url]) {
                paywallReason = reason
            }
            try? FileManager.default.removeItem(at: url)
        }
    }
}
.sheet(isPresented: $showPhotoPicker) {
    PHPickerWrapper(
        onPickResult: { result in
            showPhotoPicker = false
            Task { await handleMergePhotoResult(result) }
        },
        onCancel: { showPhotoPicker = false }
    )
}
.alert(
    "Couldn't import this video",
    isPresented: Binding(
        get: { photoExtractError != nil },
        set: { if !$0 { photoExtractError = nil } }
    )
) {
    Button("OK") {}
} message: {
    Text(photoExtractError ?? "")
}
.overlay {
    if photoLoading {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large)
            Text("Loading video…")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
```

- [ ] **Step 4.2.4: Add `handleMergePhotoResult` private method**

Place this near the existing helper methods on `MixingStationView`:

```swift
private func handleMergePhotoResult(_ result: Result<URL, Error>) async {
    let overlayTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(500))
        if !Task.isCancelled { photoLoading = true }
    }
    defer {
        overlayTask.cancel()
        photoLoading = false
    }

    switch result {
    case .success(let videoURL):
        defer { try? FileManager.default.removeItem(at: videoURL) }
        do {
            let audioURL = try await VideoAudioExtractor.extractAudio(from: videoURL)
            if let reason = viewModel.importFiles([audioURL]) {
                paywallReason = reason
            }
            try? FileManager.default.removeItem(at: audioURL)
        } catch VideoAudioExtractor.ExtractError.noAudioTrack {
            photoExtractError = "This video has no audio to import."
        } catch {
            photoExtractError = "Couldn't extract audio. \(error.localizedDescription)"
        }
    case .failure(let error):
        photoExtractError = error.localizedDescription
    }
}
```

- [ ] **Step 4.2.5: Build**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4.2.6: Commit**

```bash
git add SonicMerge/Features/MixingStation/MixingStationView.swift
git commit -m "feat(import): three-source sheet on Merge (MixingStationView)

Merge tab's primary entry points (empty + loaded states) now open the
shared source sheet. Files keeps its existing multi-select fileImporter;
Record + Photos add single clips via viewModel.importFiles([url]).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4.3: Wire all three sources onto `MergeTimelineView` (junction-insert path)

`MergeTimelineView` is the second Merge entry point — used when the user taps a junction between clips to insert a new one. It has its own `@State showInsertPicker` and `.fileImporter`.

**Files:**
- Modify: `SonicMerge/Features/MixingStation/MergeTimelineView.swift`

- [ ] **Step 4.3.1: Add the new state vars**

Locate the existing `@State private var showInsertPicker = false` declaration. Add:

```swift
@State private var showSourceSheet = false
@State private var pendingAction: ImportSourceAction?
@State private var showRecorder = false
@State private var showPhotoPicker = false
@State private var photoExtractError: String?
@State private var photoLoading = false
```

- [ ] **Step 4.3.2: Find and repoint the junction-insert trigger**

`MergeTimelineView` uses `showInsertPicker = true` to trigger the existing fileImporter from junction taps. Search for that line (likely inside a `JunctionView` callback or a sheet binding). Replace the value flip with `showSourceSheet = true`.

After the change, search the file again for `showInsertPicker = true` — there should be **zero remaining occurrences**.

- [ ] **Step 4.3.3: Add the source sheet, recorder sheet, photo picker, alert, and overlay**

On the same view chain that holds the existing `.fileImporter` (line 70), add immediately above:

```swift
.sheet(
    isPresented: $showSourceSheet,
    onDismiss: {
        guard let action = pendingAction else { return }
        pendingAction = nil
        switch action {
        case .files:
            showInsertPicker = true
        case .record:
            showRecorder = true
        case .photos:
            showPhotoPicker = true
        }
    }
) {
    ImportSourceSheet(pendingAction: $pendingAction)
}
.sheet(isPresented: $showRecorder) {
    RecorderSheet { url in
        Task {
            // Junction-insert path: pendingInsert was set by the junction tap
            // before the source sheet appeared — it's still valid here. The
            // existing onChange(of: clips.count) hook will move the new clip
            // to the requested position.
            viewModel.importFiles([url])
            try? FileManager.default.removeItem(at: url)
        }
    }
}
.sheet(isPresented: $showPhotoPicker) {
    PHPickerWrapper(
        onPickResult: { result in
            showPhotoPicker = false
            Task { await handleTimelinePhotoResult(result) }
        },
        onCancel: { showPhotoPicker = false }
    )
}
.alert(
    "Couldn't import this video",
    isPresented: Binding(
        get: { photoExtractError != nil },
        set: { if !$0 { photoExtractError = nil } }
    )
) {
    Button("OK") {}
} message: {
    Text(photoExtractError ?? "")
}
.overlay {
    if photoLoading {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large)
            Text("Loading video…")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
```

- [ ] **Step 4.3.4: Add `handleTimelinePhotoResult` private method**

Place this near the existing helper methods on `MergeTimelineView`:

```swift
private func handleTimelinePhotoResult(_ result: Result<URL, Error>) async {
    let overlayTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(500))
        if !Task.isCancelled { photoLoading = true }
    }
    defer {
        overlayTask.cancel()
        photoLoading = false
    }

    switch result {
    case .success(let videoURL):
        defer { try? FileManager.default.removeItem(at: videoURL) }
        do {
            let audioURL = try await VideoAudioExtractor.extractAudio(from: videoURL)
            viewModel.importFiles([audioURL])
            try? FileManager.default.removeItem(at: audioURL)
        } catch VideoAudioExtractor.ExtractError.noAudioTrack {
            photoExtractError = "This video has no audio to import."
        } catch {
            photoExtractError = "Couldn't extract audio. \(error.localizedDescription)"
        }
    case .failure(let error):
        photoExtractError = error.localizedDescription
    }
}
```

> **Re junction-insert ordering:** the existing `pendingInsert` state on `MergeTimelineView` is set by the `JunctionView` tap before `showSourceSheet = true` is set. The `onChange(of: viewModel.clips.count)` hook (line 86) re-orders any newly-imported clips to the junction position regardless of which source produced them. Recording and Photos go through the same `viewModel.importFiles(...)` call, so the same hook handles their reordering automatically. No new ordering logic needed here.

- [ ] **Step 4.3.5: Build**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4.3.6: Commit**

```bash
git add SonicMerge/Features/MixingStation/MergeTimelineView.swift
git commit -m "feat(import): three-source sheet on Merge timeline junctions

Tapping a junction between clips to insert a new one now goes through
the shared source sheet. Files / Record / Photos all funnel into
viewModel.importFiles([url]); the existing pendingInsert + onChange
ordering hook handles repositioning the new clip to the junction.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4.4: Final manual QA across all three tabs + full suite

This task is verification only.

- [ ] **Step 4.4.1: Run the full suite — confirm `FAIL=5` baseline preserved**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5` exactly. Total tests = baseline + 4 (`ImportSourceDispatcherTests`) + 1 (`AudioRecorderServiceTests`) + 2 (`VideoAudioExtractorTests`) = baseline + 7.

- [ ] **Step 4.4.2: Manual QA — Smart Cut tab (full re-test)**

Already verified in Chunks 1-3, but re-confirm now that the ImportSourceSheet is shared with the other tabs and nothing diverged:
- Tap Smart Cut import → source sheet appears.
- All three rows route correctly: Files presents the document picker, Record presents the recorder, Photos presents PHPicker.
- One end-to-end Smart Cut session created from each source.

- [ ] **Step 4.4.3: Manual QA — Denoise tab**

- Switch to Denoise tab. Tap import button (hero or pinned) → source sheet appears, identical to Smart Cut's.
- Tap Files → pick an audio file → Denoise session is created (existing behavior unchanged).
- Tap Record → recorder appears → record 3 seconds → Save → Denoise session is created.
- Tap Photos → pick `audible-video.mp4` → Denoise session created from extracted m4a.
- Tap Photos → pick `silent-video.mp4` → "This video has no audio to import." alert.

- [ ] **Step 4.4.4: Manual QA — Merge tab**

- Switch to Merge tab. Empty state → tap import → source sheet appears.
- Tap Files → pick **two** audio files (multi-select still works) → both clips appear in the timeline.
- Pinned import button (with clips present) → source sheet appears.
- Tap Record → record → Save → recording appears as a new clip at the end of the timeline.
- Tap Photos → pick a video → extracted audio appears as a new clip at the end.
- Tap a junction between two clips → source sheet appears (this is the `MergeTimelineView` path).
- From the junction sheet: tap Files → pick one audio file → it inserts at the junction position.
- From the junction sheet: tap Record → record → Save → the new recording inserts at the junction position (verifies the `pendingInsert` + `onChange(of: clips.count)` reordering hook).
- From the junction sheet: tap Photos → pick a video → extracted audio inserts at the junction position.

- [ ] **Step 4.4.5: Manual QA — sheet-chain stability**

Stress-test the dismiss-then-present chain:
- Tap import → source sheet appears → tap Record → recorder appears.
- Cancel the recorder → recorder dismisses, source sheet does NOT reappear.
- Tap import again immediately → source sheet appears with a fresh state (no leftover `pendingAction`).
- Repeat with Photos: tap import → source sheet → Photos → Cancel in PHPicker → returns to home cleanly.

- [ ] **Step 4.4.6: No commit needed**

This task is verification only. If any step fails, fix in the relevant prior task and re-run.

---

**End of Chunk 4.** Plan complete.
