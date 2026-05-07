import SwiftUI

/// Full-screen transcript view with cut markers. Shown inside Smart Cut
/// studio when the segmented control is on "Transcript" tab.
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
                        Color.clear.frame(height: 64)
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

    private func wordsLine(_ segs: [TranscriptionState.RecognizedSegment]) -> Text {
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
