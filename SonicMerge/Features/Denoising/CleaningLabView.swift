// CleaningLabView.swift
// SonicMerge
//
// Full Cleaning Lab screen — Phase 8 restyle (Plan 03).
//
// Pure rendering layer over CleaningLabViewModel.
// All business logic (pipeline, A/B playback, blending, haptics) lives in the ViewModel.
//
// Layout order (Phase 8):
// 1. onDeviceAIHero trust strip (SquircleCard)
// 2. staleBanner (conditional, SquircleCard)
// 3. AIOrbView hero (SquircleCard, always visible, renders idle/processing/success states)
// 4. waveformSection (SquircleCard)
// 5. intensitySlider with LimeGreenSlider (SquircleCard)
// 6. abComparisonButton (bare pill on surfaceBase, shown when hasDenoisedResult)
// 7. denoiseActionButton (bare pill on surfaceBase, shown when !isProcessing)
// + Export toolbar button → ExportFormatSheet → ExportProgressSheet → ActivityViewController
// + Error alert
// NOTE: Denoising progress modal sheet REMOVED — progress is shown inline via AIOrbView.

import SwiftUI
import UIKit
import AVFoundation

// MARK: - CleaningLabTab

/// Tabs for Cleaning Lab's dual AI suite. File-scope enum (not nested) so the generic
/// SegmentedPill<Tab: Hashable & CaseIterable> can reference it cleanly.
fileprivate enum CleaningLabTab: Hashable, CaseIterable {
    case denoise, smartCut
}

// MARK: - CleaningLabView

/// Full Cleaning Lab screen — push navigation destination from MixingStationView.
///
/// Receives the pre-merged file URL from the caller. Owns its CleaningLabViewModel.
/// All state is driven from viewModel properties; view is a pure rendering layer.
struct CleaningLabView: View {

    // MARK: - Properties

    let mergedFileURL: URL

    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Phase 10 D-06 reuse: once the user has ever imported a clip in Mixing
    /// Station this is true permanently. The Cleaning Lab is only reachable
    /// after at least one import, so in practice the on-device-AI banner shows
    /// only on edge-case re-installs / fresh DBs — keeping it bounded mirrors
    /// the Mixing Station trust-banner pattern and recovers ~90pt of vertical
    /// space so the primary CTA is above the fold.
    @AppStorage("sonicMerge.hasImportedFirstClip") private var hasImportedFirstClip: Bool = false

    @State private var viewModel = CleaningLabViewModel()
    @State private var selectedTab: CleaningLabTab = .denoise
    @State private var showExportSheet = false
    @State private var showExportProgressSheet = false
    @State private var exportProgress: Float = 0.0
    @State private var exportTask: Task<Void, Never>?
    @State private var showShareSheet = false
    @State private var exportedFileURL: URL? = nil
    @State private var isNormalizingExport = false

    // MARK: - Computed Bindings

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    // MARK: - Body

    /// Phase 10 hint: only render the waveform card when there's actual content
    /// to show OR a brief processing transition. In pure idle state the card is
    /// hidden entirely — the AI Orb's "Ready to denoise" label already conveys
    /// the state, and dropping the card recovers ~140pt of vertical space.
    private var shouldShowWaveformSection: Bool {
        !viewModel.waveformPeaks.isEmpty || viewModel.isProcessing
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                SegmentedPill(selection: $selectedTab) { option in
                    switch option {
                    case .denoise:  return "AI Denoise"
                    case .smartCut: return "Smart Cut"
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                ScrollView {
                    Group {
                        switch selectedTab {
                        case .denoise:  denoiseContent
                        case .smartCut: smartCutContent
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 96)
                }
            }

            if shouldShowFloatingBar {
                FloatingActionBar { floatingBarContent }
            }
        }
        .background { PremiumBackground() }
        .navigationTitle("Cleaning Lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        // sc-t19: hand the merged URL to the VM so Smart Cut has an input
        // even before the user runs Denoise. clt-t5: deep-link handler
        // moved here from SmartCutCardView so it fires regardless of which
        // tab is active on first entry.
        .onAppear {
            viewModel.setMergedFileURL(mergedFileURL)
            handlePendingSmartCutOpenIfNeeded()
        }
        // Export format picker
        .sheet(isPresented: $showExportSheet) {
            ExportFormatSheet(isPresented: $showExportSheet) { options in
                startExport(options: options)
            }
        }
        // Export progress sheet
        .sheet(isPresented: $showExportProgressSheet) {
            ExportProgressSheet(
                isNormalizing: isNormalizingExport,
                progress: exportProgress,
                onCancel: {
                    exportTask?.cancel()
                    exportTask = nil
                    showExportProgressSheet = false
                    exportProgress = 0
                    isNormalizingExport = false
                }
            )
            .interactiveDismissDisabled(true)
        }
        // Share sheet after successful export
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedFileURL {
                ActivityViewController(activityItems: [url], onDismiss: {
                    exportedFileURL = nil
                    exportProgress = 0
                    isNormalizingExport = false
                    showShareSheet = false
                })
            }
        }
        // Error alert
        .alert("Denoising Failed", isPresented: errorAlertBinding) {
            Button("Got It") {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        // Haptic triggers
        .sensoryFeedback(.success, trigger: viewModel.hasDenoisedResult)
        .sensoryFeedback(.error, trigger: viewModel.errorMessage != nil)
    }

    // MARK: - Tab Content

    /// AI Denoise tab — trust strip, stale banner, AI workstation card,
    /// optional waveform card. The primary "Denoise Audio" CTA lives in
    /// the floating action bar below (see `denoiseFloatingButton`).
    @ViewBuilder
    private var denoiseContent: some View {
        VStack(spacing: SonicMergeTheme.Spacing.md) {
            // 1. Trust strip — first-launch only, gated on the same
            //    @AppStorage flag as the Mixing Station banner (D-06).
            if !hasImportedFirstClip {
                onDeviceAIHero
            }

            // 2. Stale result banner (conditional)
            if viewModel.showsStaleResultBanner && viewModel.hasDenoisedResult {
                staleBanner
            }

            // 3. AI Workstation — orb + intensity + A/B compare. The primary
            //    CTA is no longer rendered inline (clt-t5); it now lives in
            //    the persistent FloatingActionBar.
            aiWorkstation

            // 4. Output waveform — only visible when there's content to
            //    render or while processing emits intermediate state.
            if shouldShowWaveformSection {
                waveformSection
            }
        }
    }

    /// Smart Cut tab — single SmartCutCardView. Deep-link auto-open is
    /// handled by the outer `.onAppear` on `body` (see
    /// `handlePendingSmartCutOpenIfNeeded`).
    @ViewBuilder
    private var smartCutContent: some View {
        SmartCutCardView(vm: viewModel.smartCutVM,
                         library: $viewModel.fillerLibrary)
    }

    // MARK: - Floating Action Bar

    /// Whether to show the persistent floating CTA. Denoise tab always shows
    /// the bar (the button itself is `.disabled` when not actionable). Smart
    /// Cut tab shows the bar only when an Apply or Re-apply action is valid.
    private var shouldShowFloatingBar: Bool {
        switch selectedTab {
        case .denoise:
            return true  // always-show; button itself is .disabled when not actionable
        case .smartCut:
            let s = viewModel.smartCutVM.state
            switch s {
            case .results: return true
            case .applied: return viewModel.smartCutVM.hasDirtyEditsSinceApply
            case .idle, .analyzing, .stale, .error: return false
            }
        }
    }

    @ViewBuilder
    private var floatingBarContent: some View {
        switch selectedTab {
        case .denoise:
            denoiseFloatingButton
        case .smartCut:
            smartCutFloatingButton
        }
    }

    @ViewBuilder
    private var denoiseFloatingButton: some View {
        Button {
            guard let url = viewModel.mergedFileURL else { return }
            viewModel.startDenoising(mergedFileURL: url)
        } label: {
            Label(viewModel.hasDenoisedResult ? "Re-denoise" : "Denoise Audio",
                  systemImage: "wand.and.stars")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
        .disabled(viewModel.isProcessing || viewModel.mergedFileURL == nil)
    }

    @ViewBuilder
    private var smartCutFloatingButton: some View {
        let vm: SmartCutViewModel = viewModel.smartCutVM
        switch vm.state {
        case .results:
            Button { Task { await vm.apply() } } label: {
                Label("Apply Cuts", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
        case .applied:
            if vm.hasDirtyEditsSinceApply {
                Button { Task { await vm.apply() } } label: {
                    Label("Re-apply", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
            } else {
                EmptyView()
            }
        case .idle, .analyzing, .stale, .error:
            EmptyView()
        }
    }

    // MARK: - Deep-link

    /// Deep-link handler — must live on the OUTER `.onAppear` so it fires
    /// regardless of which tab is active on first entry. Auto-switches to the
    /// Smart Cut tab when a pending hash matches the current input.
    private func handlePendingSmartCutOpenIfNeeded() {
        if let pending = PendingSmartCutOpen.shared.hash,
           let inputURL = viewModel.smartCutVM.inputURL {
            Task {
                let currentHash = try? await SourceHasher.sha256Hex(of: inputURL)
                if currentHash == pending {
                    await MainActor.run {
                        selectedTab = .smartCut
                        viewModel.smartCutVM.analyze()
                        PendingSmartCutOpen.shared.hash = nil
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    /// Trust strip — on-device AI indicator
    private var onDeviceAIHero: some View {
        SquircleCard(glassEnabled: false, glowEnabled: false) {
            HStack(alignment: .top, spacing: SonicMergeTheme.Spacing.sm) {
                Image(systemName: "cpu")
                    .foregroundStyle(Color(uiColor: semantic.trustIcon))
                VStack(alignment: .leading, spacing: 4) {
                    Text(TrustSignalCopy.aiDenoiseTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(uiColor: semantic.textPrimary))
                    Text(TrustSignalCopy.aiDenoiseSubtitle)
                        .font(.caption)
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// Stale result banner — shown when clips have changed after denoising
    private var staleBanner: some View {
        SquircleCard(glassEnabled: false, glowEnabled: false) {
            HStack(spacing: SonicMergeTheme.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Clips have changed.")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(uiColor: semantic.textPrimary))
                    Text("Re-process to update the denoised audio.")
                        .font(.caption)
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                }

                Spacer()

                Button("Re-process Audio") {
                    viewModel.startDenoising(mergedFileURL: mergedFileURL)
                }
                .buttonStyle(PillButtonStyle(variant: .filled, size: .compact, tint: .ai))
            }
        }
        .transition(reduceMotion ? .identity : .opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stale result warning. Clips have changed. Re-process to update the denoised audio.")
    }

    /// Waveform display — shows peaks or the brief processing transition state.
    /// Pure idle (no peaks, not processing) is handled at the call site by
    /// hiding this card entirely; the empty-state hint is no longer needed
    /// because the AI Orb's "Ready to denoise" label conveys it.
    private var waveformSection: some View {
        SquircleCard(glassEnabled: false, glowEnabled: false) {
            GeometryReader { _ in
                ZStack {
                    if !viewModel.waveformPeaks.isEmpty {
                        WaveformPathView(
                            peaks: viewModel.waveformPeaks,
                            verticalInset: 6,
                            shadowRadius: 8
                        )
                        .padding(.horizontal, SonicMergeTheme.Spacing.sm)
                    } else if viewModel.isProcessing {
                        Text("Processing\u{2026}")
                            .font(.caption)
                            .foregroundStyle(Color(uiColor: semantic.textSecondary))
                    }
                }
            }
            .padding(-SonicMergeTheme.Spacing.md)
            .padding(SonicMergeTheme.Spacing.sm)
        }
        .frame(height: 96)
    }

    /// AI Workstation — single cohesive card holding orb, intensity row,
    /// and A/B compare. The primary Denoise / Re-denoise CTA used to live
    /// inside this card; clt-t5 moved it to the persistent FloatingActionBar
    /// so the workstation stays focused on parameter tuning + monitoring.
    private var aiWorkstation: some View {
        SquircleCard(glassEnabled: false, glowEnabled: false) {
            VStack(spacing: SonicMergeTheme.Spacing.lg) {
                AIOrbView(viewModel: viewModel)
                    .padding(.vertical, SonicMergeTheme.Spacing.sm)

                Divider()
                    .accessibilityHidden(true)

                intensityRow

                if viewModel.hasDenoisedResult {
                    abComparisonButton
                }
            }
        }
    }

    /// Inline intensity row used inside the workstation card (no nested
    /// SquircleCard wrapper). Shape and behavior match the prior intensitySlider
    /// — only the surrounding card chrome is removed.
    private var intensityRow: some View {
        VStack(spacing: SonicMergeTheme.Spacing.sm) {
            HStack {
                Text("Noise Reduction")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
                Spacer()
                Text("\(Int(viewModel.intensity * 100))%")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color(uiColor: semantic.accentAI)
                            : Color(uiColor: semantic.accentAction)
                    )
                    .frame(minWidth: 40, alignment: .trailing)
            }

            LimeGreenSlider(
                value: Binding(
                    get: { Double(viewModel.intensity) },
                    set: { viewModel.onIntensityChanged(Float($0)) }
                ),
                in: 0...1
            )
        }
        .disabled(viewModel.isProcessing)
        .opacity(viewModel.isProcessing ? 0.5 : 1.0)
        .accessibilityElement(children: .contain)
    }

    /// A/B comparison button — hold-to-hear-original interaction
    private var abComparisonButton: some View {
        VStack(spacing: 6) {
            Button {} label: {
                HStack(spacing: SonicMergeTheme.Spacing.sm) {
                    Image(systemName: viewModel.isHoldingOriginal ? "headphones" : "waveform.badge.magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                    Text(viewModel.isHoldingOriginal ? "Original" : "Denoised")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(
                viewModel.isHoldingOriginal
                    ? PillButtonStyle(variant: .filled, size: .regular, tint: .accent)
                    : PillButtonStyle(variant: .outline, size: .regular, tint: .accent)
            )
            .onLongPressGesture(
                minimumDuration: 0,
                pressing: { isPressing in
                    if isPressing { viewModel.holdBegan() } else { viewModel.holdEnded() }
                },
                perform: {}
            )
            .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.isHoldingOriginal)

            Text("Hold to compare with original")
                .font(.caption)
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
        }
        .accessibilityLabel("Compare with original. Hold to listen to the original audio. Release to hear the denoised version.")
    }

    /// Export toolbar button
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showExportSheet = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            // sc-t19: export resolves to the best available source
            // (Smart Cut output > denoised blend > raw merged file).
            .disabled(viewModel.exportSource == nil || viewModel.isProcessing)
        }
    }

    // MARK: - Export Logic

    /// Export the best-available audio source via AudioMergerService.
    ///
    /// Source resolution (sc-t19): smartCutVM.outputURL > denoisedTempURL > mergedFileURL.
    /// Calls AudioMergerService.exportFile(inputURL:format:destinationURL:) which
    /// handles format conversion (m4a via AVAssetExportSession, wav via AVAssetReader+Writer).
    private func startExport(options: ExportOptions) {
        guard let sourceURL = viewModel.exportSource else { return }

        let ext = options.format == .m4a ? "m4a" : "wav"
        let destinationURL = FileManager.default.temporaryDirectory
            .appending(path: "SonicMerge-DenoisedExport-\(UUID().uuidString).\(ext)")

        showExportProgressSheet = true
        exportProgress = 0.0
        isNormalizingExport = options.lufsNormalize

        let mergerService = AudioMergerService()
        exportTask = Task {
            let stream = await mergerService.exportFile(
                inputURL: sourceURL,
                format: options.format,
                destinationURL: destinationURL,
                lufsNormalize: options.lufsNormalize   // threads LUFS flag
            )
            for await p in stream {
                guard !Task.isCancelled else { break }
                exportProgress = p
            }
            if !Task.isCancelled {
                exportProgress = 1.0
                // Brief delay so user sees 100% before sheet dismisses
                try? await Task.sleep(nanoseconds: 300_000_000)
                showExportProgressSheet = false
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    // Use sheet-based ActivityViewController instead of imperative present()
                    exportedFileURL = destinationURL
                    showShareSheet = true
                }
            }
        }
    }
}

