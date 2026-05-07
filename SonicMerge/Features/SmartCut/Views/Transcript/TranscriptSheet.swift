import SwiftUI

/// Quick-peek transcript surface presented as `.sheet` from the toolbar
/// icon. B-layout: paragraphed text with periodic timestamp markers.
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
