// SonicMerge/Features/SmartCut/SmartCutCardView.swift
import SwiftUI

struct SmartCutCardView: View {
    @Bindable var vm: SmartCutViewModel
    @Binding var library: FillerLibrary
    @State private var showsEditFillerSheet = false

    var body: some View {
        SquircleCard(glassEnabled: false, glowEnabled: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                content
            }
        }
        .sheet(isPresented: $showsEditFillerSheet) {
            EditFillerListSheet(library: $library)
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Label("Smart Cut", systemImage: "sparkles")
                .font(.headline)
            Spacer()
            switch vm.state {
            case .results, .applied, .stale, .error:
                resetButton
            case .idle, .analyzing:
                EmptyView()
            }
        }
    }

    private var resetButton: some View {
        Button("Reset") { vm.invalidate() }
            .buttonStyle(.borderless)
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .idle: idleContent
        case .analyzing(let progress): analyzingContent(progress: progress)
        case .results: resultsContent
        case .applied(let saved): appliedContent(saved: saved)
        case .stale: staleContent
        case .error(let message): errorContent(message: message)
        }
    }

    private func smartCutOrb(active: Bool) -> some View {
        Image(systemName: "sparkles")
            .font(.system(size: 56, weight: .bold))
            .foregroundStyle(.tint)
            .symbolEffect(.pulse, options: active ? .repeating : .nonRepeating)
            .frame(width: 80, height: 80)
    }

    private var idleContent: some View {
        VStack(spacing: 12) {
            Text("Remove fillers and trim long silences")
                .foregroundStyle(.secondary)
            smartCutOrb(active: false)
                .tint(.green)
            Button {
                vm.analyze()
            } label: {
                let label = vm.estimatedAnalysisMinutes > 0
                    ? "Analyze ~\(vm.estimatedAnalysisMinutes) min"
                    : "Analyze"
                Label(label, systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
            Text("Reads from: denoised audio")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func analyzingContent(progress: Double) -> some View {
        VStack(spacing: 12) {
            smartCutOrb(active: true)
                .tint(.green)
            Text("Transcribing \(Int(progress * 100))%")
            ProgressView(value: progress)
            HStack {
                Button("Cancel") { vm.cancelAnalyze() }
                    .buttonStyle(PillButtonStyle(variant: .outline, size: .regular, tint: .accent))
                Button("Run in BG") { vm.scheduleBackgroundTranscription() }
                    .buttonStyle(PillButtonStyle(variant: .outline, size: .regular, tint: .ai))
            }
        }
    }

    private var resultsContent: some View {
        // clt-t5: inline "Apply Cuts" CTA removed; the Cleaning Lab's
        // FloatingActionBar now owns the apply action.
        VStack(alignment: .leading, spacing: 12) {
            statsLine
            abPill
            fillerPanel(dimmed: false)
            Button("+ Edit filler list") { showsEditFillerSheet = true }
                .buttonStyle(.borderless)
        }
    }

    private func appliedContent(saved: TimeInterval) -> some View {
        // clt-t5: inline "Re-apply" CTA removed; the Cleaning Lab's
        // FloatingActionBar now owns the re-apply action when dirty.
        VStack(alignment: .leading, spacing: 12) {
            statsLine
            Label("Applied · \(formatDuration(saved)) saved", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            abPill
            fillerPanel(dimmed: false)
        }
    }

    private var staleContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Denoise was re-applied", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Smart Cut analysis is stale.")
                .foregroundStyle(.secondary)
            Button("Re-analyze") { vm.requestReanalyze(); vm.analyze() }
                .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
            fillerPanel(dimmed: true)
        }
    }

    private func errorContent(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.octagon.fill")
                .foregroundStyle(.red)
            Button("Try again") { vm.invalidate() }
        }
    }

    private func fillerPanel(dimmed: Bool) -> some View {
        FillerListPanel(
            editList: vm.editList,
            inputURL: vm.inputURL,
            onCategoryToggle: vm.setCategory,
            onIndividualToggle: vm.setEdit,
            onPauseToggle: vm.setEdit,
            onThresholdChange: { vm.pauseThreshold = $0 },
            pauseThreshold: $vm.pauseThreshold
        )
        .opacity(dimmed ? 0.4 : 1.0)
        .disabled(dimmed)
    }

    private var statsLine: some View {
        let fillerCount = vm.editList.fillers.count
        let pauseCount = vm.editList.pauses.count
        return VStack(alignment: .leading, spacing: 8) {
            Text("Found \(fillerCount) fillers + \(pauseCount) long pauses")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                SavesBadge(savings: vm.editList.enabledSavings)
                Spacer()
            }
        }
    }

    /// Lime-green capsule with a soft glow, dimming to grey when savings == 0
    /// (preserves layout stability as the user toggles rows).
    private struct SavesBadge: View {
        let savings: TimeInterval
        @Environment(\.sonicMergeSemantic) private var semantic

        var body: some View {
            let isActive = savings > 0
            let accent = Color(uiColor: semantic.accentAI)
            Text("saves ~\(formatDuration(savings))")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isActive ? accent : Color.secondary.opacity(0.15))
                )
                .foregroundStyle(isActive ? Color(uiColor: semantic.textPrimary) : .secondary)
                .shadow(color: accent.opacity(isActive ? 0.4 : 0), radius: 8)
        }

        private func formatDuration(_ s: TimeInterval) -> String {
            let m = Int(s) / 60
            let sec = Int(s) % 60
            return m > 0 ? "\(m)m \(sec)s" : "\(sec)s"
        }
    }

    private var abPill: some View {
        HStack(spacing: 0) {
            Button("Original") { vm.isPlayingCleaned = false; vm.toggleCleaned() }
                .buttonStyle(PillButtonStyle(
                    variant: vm.isPlayingCleaned ? .outline : .filled,
                    size: .compact, tint: .accent))
            Button("Cleaned") { vm.isPlayingCleaned = true; vm.toggleCleaned() }
                .buttonStyle(PillButtonStyle(
                    variant: vm.isPlayingCleaned ? .filled : .outline,
                    size: .compact, tint: .accent))
        }
    }

    private func formatDuration(_ s: TimeInterval) -> String {
        let m = Int(s) / 60
        let sec = Int(s) % 60
        return m > 0 ? "\(m)m \(sec)s" : "\(sec)s"
    }
}
