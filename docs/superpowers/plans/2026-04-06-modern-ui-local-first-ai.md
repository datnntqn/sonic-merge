# Modern UI / Local-First / On-Device AI — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Elevate SonicMerge’s interface from utility-default SwiftUI into a cohesive, modern “creative audio workbench” that visibly communicates **on-device AI** (Core ML denoise) and **local-first privacy** (no cloud path), while aligning interaction patterns with category-leading mobile audio apps.

**Architecture:** Centralize visual tokens in a small design-system module consumed by existing feature views (`MixingStationView`, `ClipCardView`, `GapRowView`, `ExportFormatSheet`, `CleaningLabView`). Rework the mixing-station list hierarchy (hero summary → track cards → lightweight transition rows) and replace “always-on edit mode” affordances with **swipe-to-delete + drag-to-reorder** where feasible. Add a minimal **clip preview** controller owned by `MixingStationViewModel` for play/stop state. Keep behavior changes incremental: each task ships a testable slice.

**Tech Stack:** SwiftUI, SwiftData, Observation (`@Observable`), AVFoundation (`AVAudioPlayer` for short clip preview), Swift Testing (`import Testing`), Xcode 16+ (iOS 17+ APIs such as `scrollTargetLayout` / `contentMargins` optional), Apple [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/) and [SwiftUI documentation](https://developer.apple.com/documentation/swiftui/) (latest available in Xcode docsets).

---

## Benchmark products (patterns to borrow, not copy)

| App | What to learn | Reference |
| --- | --- | --- |
| **Ferrite Recording Studio** | Multi-clip assembly, calm hierarchy, editor-first chrome, “produced episode” mental model | [App Store — Ferrite](https://apps.apple.com/us/app/ferrite-recording-studio/id1018780185), [Wooji Juice product overview](https://wooji-juice.com/products/ferrite) |
| **Hokusai Audio Editor** | Waveform-forward editing, minimal list chrome, gesture-heavy zoom/scrub (adapt: small preview + future deep editor) | [App Store — Hokusai](https://apps.apple.com/app/hokusai-audio-editor/id432079746) |
| **GarageBand (iOS)** | Region cards, strong primary action, clear transport metaphors | Apple HIG + system patterns |

**Differentiation for SonicMerge:** Ferrite/Hokusai rarely *surface* “on-device ML” and “privacy” as first-class UI signals. SonicMerge should lead with a **Local-first strip** (lock/shield + plain-language copy) and an **On-device AI** affordance on Cleaning Lab (Core ML / neural iconography + no-upload reassurance).

---

## File structure (create / modify)

| Path | Responsibility |
| --- | --- |
| **Create** `SonicMerge/DesignSystem/SonicMergeTheme.swift` | Semantic colors, radii, spacing, shadow styles, typography wrappers aligned to existing spec (soft professional) |
| **Create** `SonicMerge/DesignSystem/TrustSignalViews.swift` | Reusable “Local processing” / “On-device AI” strips and chips |
| **Modify** `SonicMerge/Features/MixingStation/MixingStationView.swift` | Hero header, trust strip, list structure, swipe actions, bottom preview hint |
| **Modify** `SonicMerge/Features/MixingStation/MixingStationViewModel.swift` | `previewingClipID`, `toggleClipPreview`, `stopPreview` |
| **Modify** `SonicMerge/Features/MixingStation/ClipCardView.swift` | Theme usage, play affordance, accessibility labels |
| **Modify** `SonicMerge/Features/MixingStation/GapRowView.swift` | Secondary visual treatment (“connector” between clips) |
| **Modify** `SonicMerge/Features/MixingStation/ExportFormatSheet.swift` | Local-first microcopy under export actions |
| **Modify** `SonicMerge/Features/Denoising/CleaningLabView.swift` | On-device AI hero copy; align intense purple accent from requirements |
| **Create** `SonicMergeTests/SonicMergeThemeTests.swift` | Token regression tests |
| **Create** `SonicMergeTests/ClipPreviewStateTests.swift` | Preview state machine tests with temp audio file |
| **Modify** `SonicMerge.xcodeproj/project.pbxproj` | Add new Swift files to app + test targets |

---

### Task 1: `SonicMergeTheme` tokens

**Files:**
- Create: `SonicMerge/DesignSystem/SonicMergeTheme.swift`
- Create: `SonicMergeTests/SonicMergeThemeTests.swift`
- Modify: `SonicMerge.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import UIKit
@testable import SonicMerge

struct SonicMergeThemeTests {

    @Test func canvasBackgroundRGBA_matchesUX01Background() {
        let c = SonicMergeTheme.ColorPalette.canvasBackground
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(c.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(Double(r) - 0.973) < 0.02)
        #expect(abs(Double(g) - 0.976) < 0.02)
        #expect(abs(Double(b) - 0.980) < 0.02)
    }

    @Test func aiAccentRGBA_matchesUX01AIAccent() {
        let c = SonicMergeTheme.ColorPalette.aiAccent
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(c.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(Double(r) - (88.0 / 255.0)) < 0.02)
        #expect(abs(Double(g) - (86.0 / 255.0)) < 0.02)
        #expect(abs(Double(b) - (214.0 / 255.0)) < 0.02)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd "/Users/datnnt/Desktop/DatNNT/App/SonicMerge"
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SonicMergeTests/SonicMergeThemeTests test
```

Expected: **build failure** — `SonicMergeTheme` / `ColorPalette` not found.

- [ ] **Step 3: Write minimal implementation**

```swift
import SwiftUI
import UIKit

enum SonicMergeTheme {

    enum ColorPalette {
        /// UX-01 canvas `#F8F9FA` (existing MixingStation background)
        static let canvasBackground = UIColor(red: 0.973, green: 0.976, blue: 0.980, alpha: 1)
        /// Primary accent `#007AFF`
        static let primaryAccent = UIColor(red: 0, green: 0.478, blue: 1, alpha: 1)
        /// UX-01 AI accent `#5856D6`
        static let aiAccent = UIColor(red: 88 / 255, green: 86 / 255, blue: 214 / 255, alpha: 1)
        static let primaryText = UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1)
        static let cardSurface = UIColor.white
    }

    enum Radius {
        static let card: CGFloat = 12
        static let chip: CGFloat = 8
    }
}
```

Add both new files to the Xcode targets (app + tests), same compile flags as peer files.

- [ ] **Step 4: Run test to verify it passes**

Run the same `xcodebuild` command as Step 2.

Expected: **PASS**.

- [ ] **Step 5: Commit**

```bash
cd "/Users/datnnt/Desktop/DatNNT/App/SonicMerge"
git add SonicMerge/DesignSystem/SonicMergeTheme.swift SonicMergeTests/SonicMergeThemeTests.swift SonicMerge.xcodeproj/project.pbxproj
git commit -m "feat(design-system): add SonicMergeTheme color tokens and tests"
```

---

### Task 2: Trust / AI signal components

**Files:**
- Create: `SonicMerge/DesignSystem/TrustSignalViews.swift`
- Create: `SonicMergeTests/TrustSignalCopyTests.swift`
- Modify: `SonicMerge.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import SonicMerge

struct TrustSignalCopyTests {

    @Test func localFirstStripTitle_isStableCopy() {
        #expect(TrustSignalCopy.localFirstTitle == "Private by design")
    }

    @Test func localFirstStripSubtitle_mentionsOnDevice() {
        #expect(TrustSignalCopy.localFirstSubtitle.contains("On-device"))
        #expect(TrustSignalCopy.localFirstSubtitle.lowercased().contains("cloud") == false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd "/Users/datnnt/Desktop/DatNNT/App/SonicMerge"
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SonicMergeTests/TrustSignalCopyTests test
```

Expected: **FAIL** — `TrustSignalCopy` missing.

- [ ] **Step 3: Write minimal implementation**

```swift
import SwiftUI

enum TrustSignalCopy {
    static let localFirstTitle = "Private by design"
    static let localFirstSubtitle = "Audio stays on your iPhone. Processing runs on-device — no upload, no account."
    static let aiDenoiseTitle = "On-device AI denoise"
    static let aiDenoiseSubtitle = "Core ML removes noise from your merge. Your files never leave this device."
}

struct LocalFirstTrustStrip: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title3)
                .foregroundStyle(Color(SonicMergeTheme.ColorPalette.aiAccent))
            VStack(alignment: .leading, spacing: 4) {
                Text(TrustSignalCopy.localFirstTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(SonicMergeTheme.ColorPalette.primaryText))
                Text(TrustSignalCopy.localFirstSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(SonicMergeTheme.ColorPalette.cardSurface))
        .clipShape(RoundedRectangle(cornerRadius: SonicMergeTheme.Radius.card, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SonicMergeTests/TrustSignalCopyTests test
```

Expected: **PASS**.

- [ ] **Step 5: Commit**

```bash
git add SonicMerge/DesignSystem/TrustSignalViews.swift SonicMergeTests/TrustSignalCopyTests.swift SonicMerge.xcodeproj/project.pbxproj
git commit -m "feat(ui): add local-first trust strip and stable marketing copy tests"
```

---

### Task 3: Mixing station — trust strip, swipe-to-delete (keep `ClipCardView` API until Task 5)

**Files:**
- Modify: `SonicMerge/Features/MixingStation/MixingStationView.swift:1-200`
- Modify: `SonicMergeTests/MixingStationViewModelTests.swift` (add one test for delete via index helper if needed — **skip if delete path unchanged**)

**Ordering note:** Implement **Task 5** before wiring preview buttons — or simply land Task 3 with `ClipCardView(clip: clip)` and update call sites in Task 5’s Step 3 when the initializer gains preview parameters.

**Behavior goals:**
- Show `LocalFirstTrustStrip` above the list when `clips` is non-empty.
- Add a compact summary line: total clips + approximate total duration (compute in-view from `viewModel.clips` for v1 to avoid VM churn).
- Remove reliance on destructive inline list chrome: **delete via swipeActions**; keep `onMove` for reorder. If iOS still shows delete circles while `onDelete` is attached, **remove `onDelete`** and perform deletes from `swipeActions` calling `viewModel.deleteClip(atOffsets:)`.

- [ ] **Step 1: Write the failing test** (pure index helper in extension file to keep view thin)

Create `SonicMerge/Features/MixingStation/MixingStationClipIndexResolver.swift`:

```swift
import Foundation

enum MixingStationClipIndexResolver {
    /// Maps a stable clip `id` to a list index for the current ordered `clips` array.
    static func index(for clipID: UUID, in clips: [AudioClip]) -> Int? {
        clips.firstIndex { $0.id == clipID }
    }
}
```

Create `SonicMergeTests/MixingStationClipIndexResolverTests.swift`:

```swift
import Foundation
import Testing
@testable import SonicMerge

struct MixingStationClipIndexResolverTests {

    @Test func findsIndex_byUUID() {
        let a = AudioClip(displayName: "A", fileURLRelativePath: "a.m4a", duration: 1)
        let b = AudioClip(displayName: "B", fileURLRelativePath: "b.m4a", duration: 2)
        let clips = [a, b]
        #expect(MixingStationClipIndexResolver.index(for: b.id, in: clips) == 1)
        #expect(MixingStationClipIndexResolver.index(for: UUID(), in: clips) == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SonicMergeTests/MixingStationClipIndexResolverTests test
```

Expected: **FAIL** until file is added to target.

- [ ] **Step 3: Write minimal implementation**

Add resolver file to app target. Then update `MixingStationView` `clipList`:

```swift
private var clipList: some View {
    List {
        Section {
            LocalFirstTrustStrip()
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }

        ForEach(Array(viewModel.clips.enumerated()), id: \.element.id) { index, clip in
            Section {
                ClipCardView(clip: clip)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        if let idx = MixingStationClipIndexResolver.index(for: clip.id, in: viewModel.clips) {
                            viewModel.deleteClip(atOffsets: IndexSet(integer: idx))
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

                if index < viewModel.clips.count - 1,
                   let transition = clip.gapTransition {
                    GapRowView(transition: transition) { gapDuration, isCrossfade in
                        viewModel.updateTransition(
                            transition,
                            gapDuration: gapDuration,
                            isCrossfade: isCrossfade
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .onMove { from, to in viewModel.moveClip(fromOffsets: from, toOffset: to) }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(Color(SonicMergeTheme.ColorPalette.canvasBackground))
    .environment(\.editMode, .constant(.active))
}
```

**Follow-up in Task 5:** replace `ClipCardView(clip: clip)` with the preview-enabled initializer once `MixingStationViewModel.previewingClipID` exists (Task 4).

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SonicMergeTests/MixingStationClipIndexResolverTests test
```

Expected: **PASS**.

- [ ] **Step 5: Commit**

```bash
git add SonicMerge/Features/MixingStation/MixingStationView.swift \
  SonicMerge/Features/MixingStation/MixingStationClipIndexResolver.swift \
  SonicMergeTests/MixingStationClipIndexResolverTests.swift \
  SonicMerge.xcodeproj/project.pbxproj
git commit -m "feat(mixing-station): add local-first strip, summary layout hooks, swipe delete"
```

---

### Task 4: `MixingStationViewModel` clip preview + tests

**Files:**
- Modify: `SonicMerge/Features/MixingStation/MixingStationViewModel.swift`
- Create: `SonicMergeTests/ClipPreviewStateTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import AVFoundation
import Foundation
import SwiftData
import Testing
@testable import SonicMerge

@MainActor
struct ClipPreviewStateTests {

    /// Does not touch disk: missing clip files must not enter the "playing" state.
    @Test func togglePreview_missingClipFile_doesNotSetPlayingID() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AudioClip.self, GapTransition.self, configurations: config)
        let context = ModelContext(container)
        let vm = MixingStationViewModel(modelContext: context)

        let clip = AudioClip(displayName: "Missing", fileURLRelativePath: "definitely-not-on-disk-\(UUID().uuidString).m4a", duration: 0.1)
        clip.sortOrder = 0
        context.insert(clip)
        try context.save()
        await vm.fetchAll()

        vm.toggleClipPreview(clip)
        #expect(vm.previewingClipID == nil)
        vm.stopClipPreview()
        #expect(vm.previewingClipID == nil)
    }

    /// Happy path writes into `AppConstants.clipsDirectory()` because `AudioClip.fileURL` resolves there.
    /// Prerequisite: unit tests run with the same capability setup as the main app (App Group resolves),
    /// which is already expected for clip-import-related integration behavior.
    @Test func togglePreview_existingClipFile_setsAndClearsPlayingID() async throws {
        let clipsDir = try AppConstants.clipsDirectory()
        let filename = "preview-\(UUID().uuidString).wav"
        let absolute = clipsDir.appending(path: filename)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 8000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        let file = try AVAudioFile(forWriting: absolute, settings: settings)
        let frames: AVAudioFrameCount = 800
        guard let format = AVAudioFormat(settings: settings),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            throw NSError(domain: "ClipPreviewStateTests", code: 1)
        }
        buffer.frameLength = frames
        try file.write(from: buffer)

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AudioClip.self, GapTransition.self, configurations: config)
        let context = ModelContext(container)
        let vm = MixingStationViewModel(modelContext: context)

        let clip = AudioClip(displayName: "P", fileURLRelativePath: filename, duration: 0.1)
        clip.sortOrder = 0
        context.insert(clip)
        try context.save()
        await vm.fetchAll()

        vm.toggleClipPreview(clip)
        #expect(vm.previewingClipID == clip.id)

        vm.toggleClipPreview(clip)
        #expect(vm.previewingClipID == nil)

        vm.toggleClipPreview(clip)
        vm.stopClipPreview()
        #expect(vm.previewingClipID == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SonicMergeTests/ClipPreviewStateTests test
```

Expected: **FAIL** — `previewingClipID` / methods missing.

- [ ] **Step 3: Write minimal implementation**

Add to `MixingStationViewModel` (imports include `AVFoundation`):

```swift
private(set) var previewingClipID: UUID?
private var previewPlayer: AVAudioPlayer?

func toggleClipPreview(_ clip: AudioClip) {
    if previewingClipID == clip.id {
        stopClipPreview()
        return
    }
    stopClipPreview()
    guard let url = try? clip.fileURL else { return }
    do {
        let player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
        guard player.play() else { return }
        previewPlayer = player
        previewingClipID = clip.id
    } catch {
        previewPlayer = nil
        previewingClipID = nil
    }
}

func stopClipPreview() {
    previewPlayer?.stop()
    previewPlayer = nil
    previewingClipID = nil
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SonicMergeTests/ClipPreviewStateTests test
```

Expected: **PASS** (Simulator audio session quirks should not break `AVAudioPlayer` for WAV file preview; if flaky, set `player.volume = 0` in implementation while still asserting state).

- [ ] **Step 5: Commit**

```bash
git add SonicMerge/Features/MixingStation/MixingStationViewModel.swift \
  SonicMergeTests/ClipPreviewStateTests.swift \
  SonicMerge.xcodeproj/project.pbxproj
git commit -m "feat(audio): add on-device clip preview with observable state"
```

---

### Task 5: `ClipCardView` — modern card + preview control

**Files:**
- Modify: `SonicMerge/Features/MixingStation/ClipCardView.swift:1-76`

- [ ] **Step 1: Write the failing test**

Extend `SonicMergeTests` with a small view-token test — **avoid snapshot**. Prefer testing duration formatter in isolation by making `formattedDuration(seconds:)` internal or `package` if modules require it. Simplest compliant approach: extract static formatter:

Create `SonicMerge/Features/MixingStation/ClipDurationFormatting.swift`:

```swift
import Foundation

enum ClipDurationFormatting {
    static func mmss(from seconds: TimeInterval) -> String {
        let s = max(0, seconds)
        let mins = Int(s) / 60
        let secs = Int(s) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
```

`SonicMergeTests/ClipDurationFormattingTests.swift`:

```swift
import Testing
@testable import SonicMerge

struct ClipDurationFormattingTests {

    @Test func formatsMMSS() {
        #expect(ClipDurationFormatting.mmss(from: 74) == "1:14")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SonicMergeTests/ClipDurationFormattingTests test
```

Expected: **FAIL** until enum exists.

- [ ] **Step 3: Write minimal implementation**

Update `MixingStationView` `clipList` clip row to pass preview state (after Task 4 lands the VM API):

```swift
ClipCardView(clip: clip, isPreviewing: viewModel.previewingClipID == clip.id) {
    viewModel.toggleClipPreview(clip)
}
```

Replace `ClipCardView` initializer and body:

```swift
struct ClipCardView: View {
    let clip: AudioClip
    let isPreviewing: Bool
    let onPreviewTap: () -> Void

    @State private var peaks: [Float] = Array(repeating: 0, count: 50)

    var body: some View {
        HStack(spacing: 12) {
            WaveformThumbnailView(peaks: peaks)
                .frame(width: 60, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(clip.displayName)
                    .font(.system(.body, design: .default, weight: .medium))
                    .foregroundStyle(Color(SonicMergeTheme.ColorPalette.primaryText))
                    .lineLimit(1)
                Text(ClipDurationFormatting.mmss(from: clip.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(action: onPreviewTap) {
                Image(systemName: isPreviewing ? "stop.fill" : "play.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(SonicMergeTheme.ColorPalette.primaryAccent))
                    .padding(10)
                    .background(Color(SonicMergeTheme.ColorPalette.primaryAccent).withAlphaComponent(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPreviewing ? "Stop preview" : "Preview clip")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(SonicMergeTheme.ColorPalette.cardSurface))
        .clipShape(RoundedRectangle(cornerRadius: SonicMergeTheme.Radius.card, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        .task { loadPeaks() }
    }

    private func loadPeaks() {
        guard let url = clip.waveformSidecarURL,
              let data = try? Data(contentsOf: url),
              data.count == 50 * MemoryLayout<Float>.size else { return }
        peaks = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
}
```

**Note:** If `Color(UIColor).withAlphaComponent` is awkward in SwiftUI, use `Color(SonicMergeTheme.ColorPalette.primaryAccent).opacity(0.12)`.

- [ ] **Step 4: Run tests**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Expected: full suite **PASS**.

- [ ] **Step 5: Commit**

```bash
git add SonicMerge/Features/MixingStation/ClipCardView.swift \
  SonicMerge/Features/MixingStation/ClipDurationFormatting.swift \
  SonicMergeTests/ClipDurationFormattingTests.swift \
  SonicMerge.xcodeproj/project.pbxproj
git commit -m "feat(ui): refresh clip cards with preview control and duration helper"
```

---

### Task 6: Transition row visual downgrade + Cleaning Lab / Export copy

**Files:**
- Modify: `SonicMerge/Features/MixingStation/GapRowView.swift`
- Modify: `SonicMerge/Features/MixingStation/ExportFormatSheet.swift`
- Modify: `SonicMerge/Features/Denoising/CleaningLabView.swift`

- [ ] **Step 1: Write the failing test**

Add `SonicMergeTests/GapRowLabelsTests.swift`:

```swift
import Testing
@testable import SonicMerge

struct GapRowLabelsTests {

    @Test func pickerAccessibilityLabel_isStable() {
        #expect(GapRowAccessibility.label == "Transition between clips")
    }
}
```

Add to `GapRowView.swift`:

```swift
enum GapRowAccessibility {
    static let label = "Transition between clips"
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SonicMergeTests/GapRowLabelsTests test
```

Expected: **FAIL** until enum exists in target.

- [ ] **Step 3: Write minimal implementation**

`GapRowView.body` append:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel(GapRowAccessibility.label)
.padding(.vertical, 6)
.padding(.horizontal, 12)
.background(Color(SonicMergeTheme.ColorPalette.cardSurface).opacity(0.55))
.clipShape(RoundedRectangle(cornerRadius: SonicMergeTheme.Radius.chip, style: .continuous))
```

`ExportFormatSheet` under title add:

```swift
Text("Files are rendered locally on your device.")
    .font(.caption)
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 24)
```

`CleaningLabView` insert below navigation title area (top of `ScrollView`):

```swift
HStack(alignment: .top, spacing: 10) {
    Image(systemName: "cpu")
        .foregroundStyle(Color(SonicMergeTheme.ColorPalette.aiAccent))
    VStack(alignment: .leading, spacing: 4) {
        Text(TrustSignalCopy.aiDenoiseTitle)
            .font(.subheadline.weight(.semibold))
        Text(TrustSignalCopy.aiDenoiseSubtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    Spacer(minLength: 0)
}
.padding(12)
.background(Color(SonicMergeTheme.ColorPalette.cardSurface))
.clipShape(RoundedRectangle(cornerRadius: SonicMergeTheme.Radius.card, style: .continuous))
.shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SonicMergeTests/GapRowLabelsTests test
```

Expected: **PASS**.

- [ ] **Step 5: Commit**

```bash
git add SonicMerge/Features/MixingStation/GapRowView.swift \
  SonicMerge/Features/MixingStation/ExportFormatSheet.swift \
  SonicMerge/Features/Denoising/CleaningLabView.swift \
  SonicMergeTests/GapRowLabelsTests.swift \
  SonicMerge.xcodeproj/project.pbxproj
git commit -m "feat(ui): soften transition rows and surface on-device AI/export copy"
```

---

## Self-review checklist (completed by plan author)

1. **Spec coverage:** Modern layout, AI + local-first messaging, reduced fragmentation between screens, preview affordance — mapped to Tasks 2–6.
2. **Placeholder scan:** No `TBD` / `TODO` / vague “handle edge cases” steps.
3. **Type consistency:** `ClipCardView(clip:isPreviewing:onPreviewTap:)` matches Task 3 usage; `TrustSignalCopy` shared between views.

---

## Execution handoff

**Plan complete and saved to** `docs/superpowers/plans/2026-04-06-modern-ui-local-first-ai.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — dispatch a fresh subagent per task, review between tasks, fast iteration (**REQUIRED SUB-SKILL:** `superpowers:subagent-driven-development`).

2. **Inline Execution** — run tasks in one session with checkpoints (**REQUIRED SUB-SKILL:** `superpowers:executing-plans`).

**Which approach do you want?**
