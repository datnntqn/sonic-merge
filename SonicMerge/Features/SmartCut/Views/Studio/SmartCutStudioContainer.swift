// SmartCutStudioContainer.swift
// SonicMerge
//
// Phase 12 (Smart Cut Studio Refactor): top-level container view that
// replaces SmartCutCardView at the CleaningLabView call-site. Owns the
// state-machine switch and renders the new studio layout in .results /
// .applied / .stale states. Idle, analyzing, and error states preserve
// the prior SmartCutCardView affordances (estimated-minutes label,
// "Run in BG" button, "Reads from: denoised audio" footer, error icon
// + Try-again-via-invalidate, applied-state green checkmark, stale-state
// re-analyze warning) — those are user-visible features in the shipped
// product, not stylistic choices, so they port across rather than
// simplify out.
//
// Init signature mirrors the existing SmartCutCardView (vm:, library:);
// CleaningLabView's call-site is a one-line swap.

import SwiftUI

struct SmartCutStudioContainer: View {
    @Bindable var vm: SmartCutViewModel
    @Binding var library: FillerLibrary

    @Environment(\.sonicMergeSemantic) private var semantic
    @State private var openCategory: String?
    @State private var showEditFillerList: Bool = false
    @State private var studioMode: StudioMode = .edit

    enum StudioMode: String, CaseIterable, Identifiable {
        case edit = "Edit"
        case transcript = "Transcript"
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            switch vm.state {
            case .idle:
                idleScaffold
            case .analyzing(let progress):
                analyzingScaffold(progress: progress)
            case .results:
                studioLayout(headerBanner: nil)
            case .applied(let saved):
                studioLayout(headerBanner: AnyView(appliedBanner(saved: saved)))
            case .stale:
                staleScaffold
            case .error(let message):
                errorScaffold(message: message)
            }
        }
        .sheet(isPresented: $showEditFillerList) {
            EditFillerListStudioSheet(library: $library)
        }
    }

    // MARK: - Studio layout (.results / .applied)

    private func studioLayout(headerBanner: AnyView?) -> some View {
        VStack(spacing: 12) {
            Picker("Mode", selection: $studioMode) {
                ForEach(StudioMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 4)

            switch studioMode {
            case .edit: editStudioBody(headerBanner: headerBanner)
            case .transcript:
                TranscriptCanvas(
                    segments: vm.cachedSegments,
                    enabledCutRanges: vm.editList.enabledCutRanges
                )
                .frame(minHeight: 360)
            }
        }
    }

    private func editStudioBody(headerBanner: AnyView?) -> some View {
        VStack(spacing: 12) {
            StudioSummaryCard(
                fillerCount: vm.editList.fillers.count,
                pauseCount: vm.editList.pauses.count,
                savings: vm.editList.enabledSavings,
                onReset: { vm.invalidate() }
            )

            if let headerBanner { headerBanner }

            Text("Tap a card to review occurrences. Toggle ✓ to skip a word.")
                .font(.caption)
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.top, 4)

            VStack(spacing: 12) {
                ForEach(vm.editList.categories, id: \.self) { category in
                    let edits = vm.editList.fillers.filter { $0.matchedText == category }
                    let categorySavings = edits.filter(\.isEnabled).reduce(0) {
                        $0 + ($1.timeRange.upperBound - $1.timeRange.lowerBound)
                    }
                    let state = vm.editList.categoryState(for: category)
                    FillerCategoryRow(
                        category: category,
                        occurrenceCount: edits.count,
                        savings: categorySavings,
                        isEnabled: state != .off,
                        onToggleGroup: { vm.setCategory(category, enabled: state == .off) },
                        onOpenSheet: { openCategory = category }
                    )
                }
                if !vm.editList.pauses.isEmpty {
                    PauseControlRow(viewModel: vm)
                }
            }

            Button {
                showEditFillerList = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Edit filler list")
                }
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: semantic.accentAction).opacity(0.5))
            }
            .padding(.top, 4)
        }
        .sheet(item: Binding<SheetCategory?>(
            get: { openCategory.map { SheetCategory(rawValue: $0) } },
            set: { openCategory = $0?.rawValue }
        )) { sheetCategory in
            let edits = vm.editList.fillers.filter { $0.matchedText == sheetCategory.rawValue }
            FillerOccurrenceSheet(
                category: sheetCategory.rawValue,
                edits: edits,
                inputURL: vm.inputURL,
                onToggleEdit: { id, enabled in vm.setEdit(id: id, enabled: enabled) },
                onToggleCategory: { enabled in vm.setCategory(sheetCategory.rawValue, enabled: enabled) }
            )
        }
    }

    private func appliedBanner(saved: TimeInterval) -> some View {
        // Preserves the prior .applied-state "Applied · Xs saved" affordance
        // (SmartCutCardView.swift:115-116) so users still get a visible
        // confirmation that the cuts landed.
        Label("Applied · \(formatDuration(saved)) saved", systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.green)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    // MARK: - Non-results scaffolds (preserve all prior SmartCutCardView features)

    private var idleScaffold: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Remove fillers and trim long silences")
                    .foregroundStyle(.secondary)

                smartCutOrb(active: false)
                    .tint(.green)
                    // Shrink the existing 80pt orb to ~56pt visually + reserve
                    // a 56×56 layout slot. `.scaleEffect` defaults to `.center`
                    // anchor, which keeps the orb visually centered inside its frame.
                    .scaleEffect(56.0 / 80.0, anchor: .center)
                    .frame(width: 56, height: 56)

                IdleSettingsCards(
                    viewModel: vm,
                    library: $library,
                    onEditFillerList: { showEditFillerList = true }
                )

                Button {
                    vm.analyze()
                } label: {
                    let label = vm.estimatedAnalysisMinutes > 0
                        ? "Analyze ~\(vm.estimatedAnalysisMinutes) min"
                        : "Analyze"
                    HStack(spacing: 6) {
                        SmartCutMark(size: .toolbar, monochromeTint: .white)
                            .frame(width: 22, height: 22)
                        Text(label)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
            }
            .padding()
        }
    }

    private func analyzingScaffold(progress: Double) -> some View {
        // Mirrors SmartCutCardView.analyzingContent (lines 83-96): orb +
        // progress + Cancel + Run in BG buttons.
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
        .padding()
    }

    private var staleScaffold: some View {
        // Mirrors SmartCutCardView.staleContent (lines 122-132): orange
        // warning + Re-analyze button. Studio layout NOT shown here since
        // the editList is stale and shouldn't be acted on until re-analyze.
        VStack(alignment: .leading, spacing: 12) {
            Label("Denoise was re-applied", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Smart Cut analysis is stale.")
                .foregroundStyle(.secondary)
            Button("Re-analyze") {
                vm.requestReanalyze()
                vm.analyze()
            }
            .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
        }
        .padding()
    }

    private func errorScaffold(message: String) -> some View {
        // Mirrors SmartCutCardView.errorContent (lines 134-140): octagon
        // icon + Try-again-via-invalidate (NOT analyze, per prior behavior).
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.octagon.fill")
                .foregroundStyle(.red)
            Button("Try again") { vm.invalidate() }
        }
        .padding()
    }

    private func smartCutOrb(active: Bool) -> some View {
        Group {
            if active {
                SmartCutMark(size: .hero)
                    .frame(width: 80, height: 80)
                    .phaseAnimator([1.0, 1.05]) { content, phase in
                        content.scaleEffect(phase)
                    } animation: { _ in
                        .easeInOut(duration: 0.9)
                    }
            } else {
                SmartCutMark(size: .hero)
                    .frame(width: 80, height: 80)
            }
        }
    }

    private func formatDuration(_ s: TimeInterval) -> String {
        let m = Int(s) / 60
        let sec = Int(s) % 60
        return m > 0 ? "\(m)m \(sec)s" : "\(sec)s"
    }
}

/// Wraps a category String in an Identifiable so .sheet(item:) accepts it.
private struct SheetCategory: Identifiable, Hashable {
    let rawValue: String
    var id: String { rawValue }
}
