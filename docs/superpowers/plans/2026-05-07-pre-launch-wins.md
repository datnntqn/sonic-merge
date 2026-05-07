# Pre-Launch Wins Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship transcription as a top-level feature (sheet + studio toggle + export) and add the privacy moat as a paywall hero claim. Both pulled from the competitive audit's "ship before launch" bucket.

**Architecture:** Pure helper for format conversion (`TranscriptExporter`), two SwiftUI surfaces (`TranscriptSheet` for quick peeks, `TranscriptCanvas` for the cuts-marked studio view), shared export-row component, and a one-line addition to `PaywallView.hero`.

**Tech Stack:** Swift 6, SwiftUI, Foundation, UIKit (UIPasteboard + UIActivityViewController), Swift Testing.

**Spec source:** `docs/superpowers/specs/2026-05-07-pre-launch-wins-design.md`.

**Estimated scope:** ~350 LOC new + ~40 modified, ~80 LOC tests. 3 chunks, 6-8 hours focused work.

---

## Pre-flight

- [ ] **Step 1: Confirm baseline + spec exists**

```bash
git log --oneline | head -5
```

You should see `e78cf77 docs(spec): pre-launch wins — transcript surface + privacy hero copy`. If not, abort.

- [ ] **Step 2: Confirm FAIL=5 baseline**

```bash
rm -rf /Users/datnnt/Library/Developer/Xcode/DerivedData/SonicMerge-ffrtspafwgzstsgbvhypcerpzcpx/Logs/Test 2>/dev/null
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5` with canonical names. Anything else → fix before proceeding.

---

## Chunk 1: `TranscriptExporter` + tests (pure helper)

**Why first:** Pure logic, no UI dependencies. TDD-ideal. Both UI surfaces depend on it; ship the API before any consumer code.

### Task 1.1: Create the exporter

**Files:**
- Create: `SonicMerge/Features/SmartCut/Services/TranscriptExporter.swift`

- [ ] **Step 1: Write the file**

```swift
import Foundation

/// Pure helper that converts `TranscriptionState.RecognizedSegment` arrays
/// into shareable text formats (.txt / .srt / .vtt) plus simple paragraph
/// rendering for SwiftUI views.
///
/// Stateless. All methods are static. No async. No service dependencies.
enum TranscriptExporter {

    /// Gap (seconds) between two consecutive segments that triggers a paragraph break.
    static let paragraphBreakThreshold: TimeInterval = 1.5

    // MARK: - Plain text

    /// Concatenated transcript with paragraph breaks at long pauses or sentence-end.
    static func plainText(from segments: [TranscriptionState.RecognizedSegment]) -> String {
        guard !segments.isEmpty else { return "" }
        var output = ""
        for (index, seg) in segments.enumerated() {
            let text = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { continue }
            if index > 0 {
                let prev = segments[index - 1]
                let gap = seg.startTime - prev.endTime
                if gap >= paragraphBreakThreshold {
                    output += "\n\n"
                } else if let lastChar = output.last, !lastChar.isWhitespace {
                    output += " "
                }
            }
            output += text
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - SRT (SubRip)

    /// Each segment becomes one cue. Standard SubRip format with comma millisecond
    /// delimiter (`00:00:01,500`). Cues numbered sequentially from 1.
    static func srt(from segments: [TranscriptionState.RecognizedSegment]) -> String {
        guard !segments.isEmpty else { return "" }
        var output = ""
        for (index, seg) in segments.enumerated() {
            let text = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { continue }
            output += "\(index + 1)\n"
            output += "\(srtTimestamp(seg.startTime)) --> \(srtTimestamp(seg.endTime))\n"
            output += "\(text)\n\n"
        }
        return output
    }

    private static func srtTimestamp(_ seconds: TimeInterval) -> String {
        let total = max(0, seconds)
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        let secs = Int(total) % 60
        let millis = Int((total - floor(total)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, secs, millis)
    }

    // MARK: - VTT (WebVTT)

    /// WebVTT format with dot millisecond delimiter (`00:00:01.500`).
    /// Required `WEBVTT` header. No cue numbers (allowed but optional).
    static func vtt(from segments: [TranscriptionState.RecognizedSegment]) -> String {
        guard !segments.isEmpty else { return "WEBVTT\n\n" }
        var output = "WEBVTT\n\n"
        for seg in segments {
            let text = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { continue }
            output += "\(vttTimestamp(seg.startTime)) --> \(vttTimestamp(seg.endTime))\n"
            output += "\(text)\n\n"
        }
        return output
    }

    private static func vttTimestamp(_ seconds: TimeInterval) -> String {
        let total = max(0, seconds)
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        let secs = Int(total) % 60
        let millis = Int((total - floor(total)) * 1000)
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, secs, millis)
    }

    // MARK: - File writing helper

    /// Writes a transcript string to a temp file with the given extension and
    /// returns the URL for `UIActivityViewController` consumption. Caller is
    /// responsible for cleanup; iOS purges temp dir periodically.
    static func writeTempFile(content: String, ext: String, basename: String = "transcript") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(basename).\(ext)")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
```

- [ ] **Step 2: Build to confirm**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | grep -E "error:|BUILD" | head -5
```

Expected: `BUILD SUCCEEDED`.

### Task 1.2: Tests

**Files:**
- Create: `SonicMergeTests/Features/SmartCut/TranscriptExporterTests.swift`

- [ ] **Step 1: Write the tests**

```swift
import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct TranscriptExporterTests {

    private func segment(text: String, start: TimeInterval, end: TimeInterval) -> TranscriptionState.RecognizedSegment {
        TranscriptionState.RecognizedSegment(text: text, startTime: start, endTime: end, confidence: 1.0)
    }

    // MARK: - Plain text

    @Test func plainTextEmpty() {
        #expect(TranscriptExporter.plainText(from: []) == "")
    }

    @Test func plainTextConcatenatesWithSpaces() {
        let segs = [
            segment(text: "Hello", start: 0, end: 0.5),
            segment(text: "world", start: 0.6, end: 1.0)
        ]
        #expect(TranscriptExporter.plainText(from: segs) == "Hello world")
    }

    @Test func plainTextInsertsParagraphOnLongPause() {
        let segs = [
            segment(text: "First sentence.", start: 0, end: 1.0),
            segment(text: "Second sentence.", start: 3.0, end: 4.0)  // 2s gap > 1.5
        ]
        let out = TranscriptExporter.plainText(from: segs)
        #expect(out.contains("\n\n"))
    }

    @Test func plainTextDoesNotInsertParagraphOnShortPause() {
        let segs = [
            segment(text: "First", start: 0, end: 1.0),
            segment(text: "second", start: 1.2, end: 2.0)  // 0.2s gap < 1.5
        ]
        let out = TranscriptExporter.plainText(from: segs)
        #expect(!out.contains("\n\n"))
    }

    @Test func plainTextStripsWhitespace() {
        let segs = [segment(text: "  padded  ", start: 0, end: 1)]
        #expect(TranscriptExporter.plainText(from: segs) == "padded")
    }

    @Test func plainTextSkipsEmptySegments() {
        let segs = [
            segment(text: "Hello", start: 0, end: 0.5),
            segment(text: "", start: 0.6, end: 0.7),
            segment(text: "world", start: 0.8, end: 1.0)
        ]
        #expect(TranscriptExporter.plainText(from: segs) == "Hello world")
    }

    // MARK: - SRT

    @Test func srtEmptyReturnsEmptyString() {
        #expect(TranscriptExporter.srt(from: []) == "")
    }

    @Test func srtFormatsCueWithCommaMillis() {
        let segs = [segment(text: "Hello", start: 0, end: 1.5)]
        let out = TranscriptExporter.srt(from: segs)
        #expect(out.contains("00:00:00,000 --> 00:00:01,500"))
        #expect(out.contains("Hello"))
        #expect(out.hasPrefix("1\n"))
    }

    @Test func srtNumbersCuesSequentially() {
        let segs = [
            segment(text: "One", start: 0, end: 1),
            segment(text: "Two", start: 1, end: 2),
            segment(text: "Three", start: 2, end: 3)
        ]
        let out = TranscriptExporter.srt(from: segs)
        #expect(out.contains("1\n"))
        #expect(out.contains("2\n"))
        #expect(out.contains("3\n"))
    }

    @Test func srtHandlesMultiHourTimestamp() {
        let segs = [segment(text: "Late", start: 3725.5, end: 3726.0)]  // 1:02:05.500
        let out = TranscriptExporter.srt(from: segs)
        #expect(out.contains("01:02:05,500"))
    }

    // MARK: - VTT

    @Test func vttEmptyReturnsHeaderOnly() {
        #expect(TranscriptExporter.vtt(from: []) == "WEBVTT\n\n")
    }

    @Test func vttFormatsCueWithDotMillis() {
        let segs = [segment(text: "Hello", start: 0, end: 1.5)]
        let out = TranscriptExporter.vtt(from: segs)
        #expect(out.hasPrefix("WEBVTT\n\n"))
        #expect(out.contains("00:00:00.000 --> 00:00:01.500"))
        #expect(out.contains("Hello"))
    }

    @Test func vttHandlesMultiHourTimestamp() {
        let segs = [segment(text: "Late", start: 3725.5, end: 3726.0)]
        let out = TranscriptExporter.vtt(from: segs)
        #expect(out.contains("01:02:05.500"))
    }

    // MARK: - File writing

    @Test func writeTempFileCreatesReadableFile() throws {
        let url = try TranscriptExporter.writeTempFile(content: "test content", ext: "txt", basename: "exporter-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)
        #expect(String(data: data, encoding: .utf8) == "test content")
    }
}
```

- [ ] **Step 2: Run tests**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SonicMergeTests/TranscriptExporterTests test 2>&1 | grep -E "passed|failed" | head -20
```

Expected: ~13 tests pass.

- [ ] **Step 3: Run full suite + commit Chunk 1**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`.

```bash
git add SonicMerge/Features/SmartCut/Services/TranscriptExporter.swift \
        SonicMergeTests/Features/SmartCut/TranscriptExporterTests.swift
git commit -m "feat(transcript): TranscriptExporter — .txt/.srt/.vtt + plain text rendering"
```

---

## Chunk 2: TranscriptSheet + TranscriptExportRow + new toolbar icon

**Why second:** Builds the lightweight quick-peek surface and the shared export-row component. After this chunk lands, users can already tap the toolbar icon and get a full transcript experience — independent of the studio integration.

### Task 2.1: TranscriptExportRow shared component

**Files:**
- Create: `SonicMerge/Features/SmartCut/Views/Transcript/TranscriptExportRow.swift`

- [ ] **Step 1: Write the file**

```swift
import SwiftUI
import UIKit

/// Horizontal row of action chips for the transcript surfaces. Used by
/// `TranscriptSheet` (in header) and `TranscriptCanvas` (bottom-sticky).
///
/// Actions: Copy (UIPasteboard) + .txt + .srt + .vtt (UIActivityViewController).
struct TranscriptExportRow: View {

    let segments: [TranscriptionState.RecognizedSegment]
    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        HStack(spacing: 8) {
            actionChip(icon: "doc.on.clipboard", label: "Copy", action: copy)
            actionChip(icon: "doc.text", label: ".txt", action: { exportFile(.txt) })
            actionChip(icon: "captions.bubble", label: ".srt", action: { exportFile(.srt) })
            actionChip(icon: "film", label: ".vtt", action: { exportFile(.vtt) })
        }
    }

    private func actionChip(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption.weight(.bold))
                Text(label).font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color(uiColor: semantic.accentAction))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color(uiColor: semantic.accentAction).opacity(0.10)))
        }
        .buttonStyle(.plain)
        .disabled(segments.isEmpty)
        .opacity(segments.isEmpty ? 0.4 : 1.0)
    }

    private func copy() {
        UIPasteboard.general.string = TranscriptExporter.plainText(from: segments)
    }

    private enum FileFormat {
        case txt, srt, vtt
        var ext: String { switch self { case .txt: "txt"; case .srt: "srt"; case .vtt: "vtt" } }
    }

    private func exportFile(_ format: FileFormat) {
        let content: String
        switch format {
        case .txt: content = TranscriptExporter.plainText(from: segments)
        case .srt: content = TranscriptExporter.srt(from: segments)
        case .vtt: content = TranscriptExporter.vtt(from: segments)
        }
        guard let url = try? TranscriptExporter.writeTempFile(content: content, ext: format.ext) else { return }
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController?.topMostPresenter() else { return }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = root.view
        root.present(activity, animated: true)
    }
}

private extension UIViewController {
    func topMostPresenter() -> UIViewController {
        var top: UIViewController = self
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | grep -E "error:|BUILD" | head -5
```

Expected: `BUILD SUCCEEDED`.

### Task 2.2: TranscriptSheet (B-layout)

**Files:**
- Create: `SonicMerge/Features/SmartCut/Views/Transcript/TranscriptSheet.swift`

- [ ] **Step 1: Write the file**

```swift
import SwiftUI

/// Quick-peek transcript surface presented as `.sheet` from the toolbar
/// icon. B-layout: paragraphed text with periodic timestamp markers.
///
/// Empty state: when `segments.isEmpty`, shows an actionable hint to
/// run Analyze first.
struct TranscriptSheet: View {

    let segments: [TranscriptionState.RecognizedSegment]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        NavigationStack {
            Group {
                if segments.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(paragraphs.indices, id: \.self) { i in
                                paragraphView(paragraphs[i])
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .background(Color(uiColor: semantic.surfaceBase))
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(uiColor: semantic.accentAction))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    TranscriptExportRow(segments: segments)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble")
                .font(.system(size: 48))
                .foregroundStyle(Color(uiColor: semantic.textSecondary).opacity(0.5))
            Text("No transcript yet")
                .font(.headline)
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
            Text("Run Analyze first to generate the transcript.")
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Paragraph grouping

    private struct Paragraph: Identifiable {
        let id = UUID()
        let startTime: TimeInterval
        let text: String
    }

    private var paragraphs: [Paragraph] {
        var result: [Paragraph] = []
        var currentText = ""
        var currentStart: TimeInterval = 0
        for (i, seg) in segments.enumerated() {
            let cleaned = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty { continue }
            if currentText.isEmpty {
                currentStart = seg.startTime
                currentText = cleaned
            } else {
                let prev = segments[i - 1]
                let gap = seg.startTime - prev.endTime
                if gap >= TranscriptExporter.paragraphBreakThreshold {
                    result.append(Paragraph(startTime: currentStart, text: currentText))
                    currentStart = seg.startTime
                    currentText = cleaned
                } else {
                    currentText += " " + cleaned
                }
            }
        }
        if !currentText.isEmpty {
            result.append(Paragraph(startTime: currentStart, text: currentText))
        }
        return result
    }

    private func paragraphView(_ p: Paragraph) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(timestamp(p.startTime))
                .font(.caption2.weight(.heavy))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                .tracking(0.5)
            Text(p.text)
                .font(.body)
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
                .lineSpacing(4)
        }
        .padding(.bottom, 16)
    }

    private func timestamp(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | grep -E "error:|BUILD" | head -5
```

Expected: `BUILD SUCCEEDED`.

### Task 2.3: Wire toolbar icon on SmartCutSessionView

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Home/SmartCutSessionView.swift`

- [ ] **Step 1: Add state for sheet presentation**

In the `@State` block at the top of the struct (alongside `showExportSheet`, etc.), add:

```swift
    @State private var showTranscriptSheet = false
```

- [ ] **Step 2: Add the toolbar icon BEFORE the existing Export item**

Find the existing `private var toolbarContent: some ToolbarContent {` block. Add a new `ToolbarItem` BEFORE the existing Export item:

```swift
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showTranscriptSheet = true
            } label: {
                Label("Transcript", systemImage: "doc.text")
            }
            .disabled(viewModel?.cachedSegments.isEmpty ?? true)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showExportSheet = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel?.outputURL == nil)
        }
        // ... existing More menu unchanged ...
    }
```

- [ ] **Step 3: Present the sheet**

On the body, alongside the existing `.paywall(reason:)` and `.moodCheckSheet(...)` modifiers, add:

```swift
        .sheet(isPresented: $showTranscriptSheet) {
            TranscriptSheet(segments: viewModel?.cachedSegments ?? [])
        }
```

- [ ] **Step 4: Build**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | grep -E "error:|BUILD" | head -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Run full suite + commit Chunk 2**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`.

```bash
git add SonicMerge/Features/SmartCut/Views/Transcript/TranscriptExportRow.swift \
        SonicMerge/Features/SmartCut/Views/Transcript/TranscriptSheet.swift \
        SonicMerge/Features/SmartCut/Views/Home/SmartCutSessionView.swift
git commit -m "feat(transcript): TranscriptSheet (B-layout) + toolbar icon + export row"
```

---

## Chunk 3: Studio segmented control + TranscriptCanvas + privacy hero copy

**Why last:** Builds on Chunks 1 & 2 (exporter + export row are reused). Adds the richer cuts-marked view inside Smart Cut studio + the paywall copy change.

### Task 3.1: TranscriptCanvas (C-layout)

**Files:**
- Create: `SonicMerge/Features/SmartCut/Views/Transcript/TranscriptCanvas.swift`

- [ ] **Step 1: Write the file**

```swift
import SwiftUI

/// Full-screen transcript view with cut markers. Shown inside Smart Cut
/// studio when the segmented control is on "Transcript" tab.
///
/// Reads `segments` and `enabledCutRanges` from the view model — words whose
/// startTime falls inside any cut range render with strikethrough + pink
/// overlay. Long-pause cuts render as inline duration chips.
///
/// Bottom-sticky `TranscriptExportRow` stays visible while user scrolls.
struct TranscriptCanvas: View {

    let segments: [TranscriptionState.RecognizedSegment]
    let enabledCutRanges: [ClosedRange<TimeInterval>]

    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        VStack(spacing: 0) {
            if segments.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(paragraphs.indices, id: \.self) { i in
                            paragraphView(paragraphs[i])
                        }
                        Color.clear.frame(height: 80)  // export-row sticky spacer
                    }
                    .padding(20)
                }
            }
            HStack {
                Spacer()
                TranscriptExportRow(segments: segments)
                Spacer()
            }
            .padding(.vertical, 12)
            .background(Color(uiColor: semantic.surfaceBase).opacity(0.95))
            .overlay(Rectangle().fill(Color(uiColor: semantic.textSecondary).opacity(0.08)).frame(height: 1), alignment: .top)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.bubble").font(.system(size: 36))
                .foregroundStyle(Color(uiColor: semantic.textSecondary).opacity(0.4))
            Text("Run Analyze first to see the transcript.")
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Paragraphs (same grouping as TranscriptSheet)

    private struct Paragraph: Identifiable {
        let id = UUID()
        let startTime: TimeInterval
        let segments: [TranscriptionState.RecognizedSegment]
    }

    private var paragraphs: [Paragraph] {
        var result: [Paragraph] = []
        var currentSegs: [TranscriptionState.RecognizedSegment] = []
        for (i, seg) in segments.enumerated() {
            if currentSegs.isEmpty {
                currentSegs = [seg]
            } else {
                let prev = segments[i - 1]
                let gap = seg.startTime - prev.endTime
                if gap >= TranscriptExporter.paragraphBreakThreshold {
                    result.append(Paragraph(startTime: currentSegs.first!.startTime, segments: currentSegs))
                    currentSegs = [seg]
                } else {
                    currentSegs.append(seg)
                }
            }
        }
        if !currentSegs.isEmpty {
            result.append(Paragraph(startTime: currentSegs.first!.startTime, segments: currentSegs))
        }
        return result
    }

    private func paragraphView(_ p: Paragraph) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(timestamp(p.startTime))
                .font(.caption2.weight(.heavy))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                .tracking(0.5)
            wordsLine(p.segments)
        }
    }

    private func wordsLine(_ segs: [TranscriptionState.RecognizedSegment]) -> some View {
        var attributed = AttributedString()
        for (i, seg) in segs.enumerated() {
            let cleaned = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty { continue }
            var chunk = AttributedString(cleaned)
            if isCut(seg) {
                chunk.strikethroughStyle = .single
                chunk.backgroundColor = Color.red.opacity(0.18)
                chunk.foregroundColor = Color(uiColor: semantic.textSecondary)
            } else {
                chunk.foregroundColor = Color(uiColor: semantic.textPrimary)
            }
            attributed += chunk
            if i < segs.count - 1 { attributed += AttributedString(" ") }
        }
        return Text(attributed)
            .font(.body)
            .lineSpacing(5)
    }

    private func isCut(_ seg: TranscriptionState.RecognizedSegment) -> Bool {
        enabledCutRanges.contains { $0.contains(seg.startTime) }
    }

    private func timestamp(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | grep -E "error:|BUILD" | head -5
```

Expected: `BUILD SUCCEEDED`.

### Task 3.2: Studio segmented control

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift`

- [ ] **Step 1: Find the studio body root and add segmented state**

Open the file. Add `@State` near the top of the struct:

```swift
    @State private var studioMode: StudioMode = .edit

    enum StudioMode: String, CaseIterable, Identifiable {
        case edit = "Edit"
        case transcript = "Transcript"
        var id: String { rawValue }
    }
```

- [ ] **Step 2: Wrap the existing scrollable body in a Group + Picker**

Find the outermost `ScrollView` or `VStack` that wraps the studio's idle/results cards. Wrap it:

```swift
    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $studioMode) {
                ForEach(StudioMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            switch studioMode {
            case .edit:
                existingStudioBody  // ← whatever the current body content is
            case .transcript:
                TranscriptCanvas(
                    segments: viewModel.cachedSegments,
                    enabledCutRanges: viewModel.editList.enabledCutRanges
                )
            }
        }
    }
```

(Adjust `existingStudioBody` reference to whatever the actual current body looks like — extract it into a computed property if it isn't already.)

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | grep -E "error:|BUILD" | head -5
```

Expected: `BUILD SUCCEEDED`. If body extraction is messy, the picker may need to wrap in a different position — adapt to the actual file layout.

### Task 3.3: Privacy hero copy on PaywallView

**Files:**
- Modify: `SonicMerge/Features/Subscription/Views/PaywallView.swift`

- [ ] **Step 1: Add the privacy line above "CleanCut Pro" headline**

In the `hero` computed property, find the existing `Text("CleanCut Pro")` line. Insert a new Text directly above it:

```swift
            Text("Your audio never leaves your phone.")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            Text("CleanCut Pro")
                // ... existing modifiers unchanged
```

The line shows on every paywall presentation regardless of `reason`. The existing celebratory `🎉 You're all set` badge (Sub-project 3) sits ABOVE this line for `.endOfOnboarding`; the privacy line is between celebratory badge and "CleanCut Pro".

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | grep -E "error:|BUILD" | head -5
```

Expected: `BUILD SUCCEEDED`.

### Task 3.4: Run full suite + commit Chunk 3

- [ ] **Step 1: Run tests**

```bash
rm -rf /Users/datnnt/Library/Developer/Xcode/DerivedData/SonicMerge-ffrtspafwgzstsgbvhypcerpzcpx/Logs/Test 2>/dev/null
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`.

- [ ] **Step 2: Commit**

```bash
git add SonicMerge/Features/SmartCut/Views/Transcript/TranscriptCanvas.swift \
        SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift \
        SonicMerge/Features/Subscription/Views/PaywallView.swift
git commit -m "feat(transcript): studio Edit/Transcript toggle + cuts canvas + privacy hero"
```

---

## Final ship-readiness check

- [ ] **Step 1: Run full suite one last time**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5` (baseline preserved). 13 new tests added (`TranscriptExporterTests`).

- [ ] **Step 2: Manual smoke checklist (per spec Testing section)**

1. Open a Smart Cut session. Run Analyze. Tap toolbar 📄 icon. Sheet rises with paragraphed transcript + timestamps. Copy works (paste into Notes app). Each export chip presents UIActivityViewController — save .txt / .srt / .vtt to Files and inspect.
2. Same session → segmented control on "Transcript" tab. Studio body swaps to TranscriptCanvas. Filler words show strikethrough + pink. Pause durations OR cuts show. Switching back to "Edit" returns the existing cards.
3. Open a session BEFORE running Analyze. Toolbar 📄 icon is disabled. Studio "Transcript" tab shows empty state.
4. Trigger any paywall reason. Privacy line "Your audio never leaves your phone." appears above the gradient "CleanCut Pro" headline.

- [ ] **Step 3: Push to origin/main**

```bash
git push origin main
```

---

## Notes for the implementer

- **`UIActivityViewController` from a SwiftUI button** uses the `UIWindowScene.windows.first` pattern (same as Sub-project 4's `SKStoreReviewController`). Single-scene assumption per Info.plist.
- **`AttributedString` strikethrough rendering** in SwiftUI: the strikethrough on inline text only works correctly when the entire AttributedString is rendered through a single `Text` view — multi-line wrapping respects per-character formatting. This is why TranscriptCanvas builds one AttributedString per paragraph rather than concatenating multiple `Text` views.
- **Paragraph-grouping logic is duplicated** between TranscriptSheet and TranscriptCanvas (rule-of-two — not yet refactor-pressing per Karpathy guidelines). If a third consumer ever needs paragraphs, lift to TranscriptExporter.
- **Toolbar icon disabled state** uses `viewModel?.cachedSegments.isEmpty ?? true` — handles the (rare) case where the view model isn't loaded yet on initial appear.
- **Studio body extraction**: if `SmartCutStudioContainer` doesn't currently expose its body as a computed property, you'll need to extract the existing scroll content into one (e.g., `private var editBody: some View`). Keep the diff minimal — just the wrapping, not a refactor of the contents.
- **The privacy line is intentionally short.** Avoid adding qualifiers ("...even when you upgrade") — they dilute the claim. The whole point is brevity + assertion.
- **Dark mode**: all colors are bound to `semantic.*` tokens. The line will render in `textPrimary` (white in dark mode, near-black in light) automatically. Strikethrough on TranscriptCanvas uses `Color.red.opacity(0.18)` — adapts naturally to both modes.
