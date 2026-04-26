// SonicMerge/Features/SmartCut/Views/FillerListPanel.swift
import SwiftUI
import AVFoundation

struct FillerListPanel: View {
    let editList: EditList
    let inputURL: URL?
    let onCategoryToggle: (_ category: String, _ enabled: Bool) -> Void
    let onIndividualToggle: (_ id: String, _ enabled: Bool) -> Void
    let onPauseToggle: (_ id: String, _ enabled: Bool) -> Void
    let onThresholdChange: (TimeInterval) -> Void
    @State private var expandedCategories: Set<String> = []
    @State private var previewPlayer: AVAudioPlayer?
    @Binding var pauseThreshold: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(editList.categories, id: \.self) { category in
                categoryRow(category: category)
                if expandedCategories.contains(category) {
                    ForEach(editList.fillers.filter { $0.matchedText == category }) { edit in
                        occurrenceRow(edit: edit)
                    }
                }
            }
            if !editList.pauses.isEmpty {
                Divider()
                pauseRow
            }
        }
    }

    private func categoryRow(category: String) -> some View {
        let state = editList.categoryState(for: category)
        let count = editList.fillers.filter { $0.matchedText == category }.count
        return HStack {
            Image(systemName: checkboxName(for: state))
                .onTapGesture {
                    onCategoryToggle(category, state != .on)
                }
            Text(category)
            Text("(\(count))").foregroundStyle(.secondary)
            Spacer()
            Image(systemName: expandedCategories.contains(category) ? "chevron.down" : "chevron.right")
                .onTapGesture {
                    if expandedCategories.contains(category) {
                        expandedCategories.remove(category)
                    } else {
                        expandedCategories.insert(category)
                    }
                }
        }
    }

    private func occurrenceRow(edit: FillerEdit) -> some View {
        HStack {
            Button {
                playWindow(around: edit.timeRange)
            } label: {
                Image(systemName: "play.fill")
            }
            Text(edit.contextExcerpt).lineLimit(1)
            Spacer()
            Text(formatTimestamp(edit.timeRange.lowerBound)).foregroundStyle(.secondary)
            Image(systemName: edit.isEnabled ? "checkmark.square.fill" : "square")
                .onTapGesture {
                    onIndividualToggle(edit.id, !edit.isEnabled)
                }
        }
        .padding(.leading, 24)
    }

    private var pauseRow: some View {
        let count = editList.pauses.count
        let savings = editList.pauses.filter(\.isEnabled).reduce(0.0) { $0 + $1.duration }
        let allEnabled = editList.pauses.allSatisfy(\.isEnabled)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: allEnabled ? "checkmark.square.fill" : "square")
                    .onTapGesture {
                        for p in editList.pauses { onPauseToggle(p.id, !allEnabled) }
                    }
                Text("Trim \(count) long pauses (>\(formatThreshold(pauseThreshold)))")
                Spacer()
                Text("saves \(formatTimestamp(savings))").foregroundStyle(.secondary)
            }
            HStack {
                Text("Threshold: \(formatThreshold(pauseThreshold))").foregroundStyle(.secondary)
                Stepper("", value: Binding(
                    get: { pauseThreshold },
                    set: { onThresholdChange($0); pauseThreshold = $0 }
                ), in: 1.0...3.0, step: 0.5)
                .labelsHidden()
            }
        }
    }

    private func checkboxName(for state: EditList.CategoryState) -> String {
        switch state {
        case .on: return "checkmark.square.fill"
        case .off: return "square"
        case .mixed: return "minus.square.fill"
        }
    }

    private func formatTimestamp(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatThreshold(_ seconds: TimeInterval) -> String {
        String(format: "%.1fs", seconds)
    }

    private func playWindow(around range: ClosedRange<TimeInterval>) {
        guard let inputURL else { return }
        let centerSeconds = range.lowerBound
        let windowStart = max(0, centerSeconds - 2)
        do {
            let player = try AVAudioPlayer(contentsOf: inputURL)
            player.currentTime = windowStart
            player.play()
            previewPlayer = player
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                if previewPlayer === player { player.stop() }
            }
        } catch {
            // Surface via a non-crash channel; UI shows nothing — the play button is silent on failure.
        }
    }
}
