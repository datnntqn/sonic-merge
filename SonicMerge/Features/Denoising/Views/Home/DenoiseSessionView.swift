// DenoiseSessionView.swift
// SonicMerge
//
// Push destination from DenoiseHomeView. Resolves a DenoiseSession by ID,
// owns a per-session DenoiseSessionViewModel, and renders the denoise UI
// (orb + intensity + A/B + waveform + floating Apply CTA).

import SwiftUI
import SwiftData
import AVFoundation

struct DenoiseSessionView: View {
    let sessionId: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(EntitlementService.self) private var entitlements

    @State private var viewModel: DenoiseSessionViewModel?
    @State private var session: DenoiseSession?
    @State private var showDeleteConfirm = false

    @State private var showExportSheet = false
    @State private var showExportProgressSheet = false
    @State private var exportProgress: Float = 0.0
    @State private var exportTask: Task<Void, Never>?
    @State private var showShareSheet = false
    @State private var exportedFileURL: URL? = nil
    @State private var isNormalizingExport = false
    @State private var paywallReason: PaywallReason?

    @AppStorage("sonicMerge.hasImportedFirstClip") private var hasImportedFirstClip: Bool = false

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.errorMessage != nil },
            set: { if !$0 { viewModel?.errorMessage = nil } }
        )
    }

    private var shouldShowWaveformSection: Bool {
        guard let viewModel else { return false }
        return !viewModel.waveformPeaks.isEmpty || viewModel.isProcessing
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let viewModel, let session {
                    ScrollView {
                        DenoiseStudioBody(
                            viewModel: viewModel,
                            shouldShowWaveformSection: shouldShowWaveformSection,
                            hasImportedFirstClip: hasImportedFirstClip,
                            reduceMotion: reduceMotion,
                            colorScheme: colorScheme,
                            semantic: semantic
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 96)
                    }
                    .navigationTitle(session.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { toolbarContent }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            if let viewModel {
                FloatingActionBar {
                    Button {
                        guard let url = viewModel.mergedFileURL else { return }
                        viewModel.startDenoising(mergedFileURL: url)
                    } label: {
                        Label(viewModel.hasDenoisedResult ? "Re-denoise" : "Denoise Audio",
                              systemImage: "wand.and.stars")
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
                    .disabled(viewModel.isProcessing || viewModel.mergedFileURL == nil)
                }
            }
        }
        .background { PremiumBackground() }
        .task { await load() }
        .onDisappear {
            if let vm = viewModel, let session {
                vm.persist(to: session)
                try? modelContext.save()
            }
        }
        .confirmationDialog(
            "Delete this Denoise session?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showExportSheet) {
            ExportFormatSheet(isPresented: $showExportSheet, paywallReason: $paywallReason) { options in
                startExport(options: options)
            }
        }
        .paywall(reason: $paywallReason)
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
        .alert("Denoising Failed", isPresented: errorAlertBinding) {
            Button("Got It") {}
        } message: {
            Text(viewModel?.errorMessage ?? "")
        }
        .sensoryFeedback(.success, trigger: viewModel?.hasDenoisedResult ?? false)
        .sensoryFeedback(.error, trigger: viewModel?.errorMessage != nil)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showExportSheet = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel?.exportSource == nil || (viewModel?.isProcessing ?? false))
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("Delete session", systemImage: "trash")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }

    private func load() async {
        let id = sessionId
        let descriptor = FetchDescriptor<DenoiseSession>(
            predicate: #Predicate { $0.id == id }
        )
        guard let fetched = try? modelContext.fetch(descriptor).first else {
            dismiss()
            return
        }
        fetched.lastOpenedAt = .now
        try? modelContext.save()
        self.session = fetched
        self.viewModel = DenoiseSessionViewModel(session: fetched, modelContext: modelContext)
    }

    private func performDelete() {
        guard let session else { return }
        if let dir = try? AppConstants.denoiseSessionDirectory(for: session.id) {
            try? FileManager.default.removeItem(at: dir)
        }
        modelContext.delete(session)
        try? modelContext.save()
        dismiss()
    }

    private func startExport(options: ExportOptions) {
        guard let viewModel, let sourceURL = viewModel.exportSource else { return }

        let ext = options.format == .m4a ? "m4a" : "wav"
        let destinationURL = FileManager.default.temporaryDirectory
            .appending(path: "CleanCut-DenoisedExport-\(UUID().uuidString).\(ext)")

        showExportProgressSheet = true
        exportProgress = 0.0
        isNormalizingExport = options.lufsNormalize

        let mergerService = AudioMergerService()
        let applyWatermark = !entitlements.isPro
        exportTask = Task {
            let stream = await mergerService.exportFile(
                inputURL: sourceURL,
                format: options.format,
                destinationURL: destinationURL,
                lufsNormalize: options.lufsNormalize,
                applyWatermark: applyWatermark
            )
            for await p in stream {
                guard !Task.isCancelled else { break }
                exportProgress = p
            }
            if !Task.isCancelled {
                exportProgress = 1.0
                try? await Task.sleep(nanoseconds: 300_000_000)
                showExportProgressSheet = false
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    exportedFileURL = destinationURL
                    showShareSheet = true
                }
            }
        }
    }
}

// MARK: - DenoiseStudioBody

private struct DenoiseStudioBody: View {
    @Bindable var viewModel: DenoiseSessionViewModel
    let shouldShowWaveformSection: Bool
    let hasImportedFirstClip: Bool
    let reduceMotion: Bool
    let colorScheme: ColorScheme
    let semantic: SonicMergeSemantic

    var body: some View {
        VStack(spacing: SonicMergeTheme.Spacing.md) {
            if !hasImportedFirstClip {
                onDeviceAIHero
            }
            if viewModel.showsStaleResultBanner && viewModel.hasDenoisedResult {
                staleBanner
            }
            aiWorkstation
            if shouldShowWaveformSection {
                waveformSection
            }
        }
    }

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

    private var staleBanner: some View {
        SquircleCard(glassEnabled: false, glowEnabled: false) {
            HStack(spacing: SonicMergeTheme.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Source has changed.")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(uiColor: semantic.textPrimary))
                    Text("Re-process to update the denoised audio.")
                        .font(.caption)
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                }
                Spacer()
                Button("Re-process Audio") {
                    if let url = viewModel.mergedFileURL {
                        viewModel.startDenoising(mergedFileURL: url)
                    }
                }
                .buttonStyle(PillButtonStyle(variant: .filled, size: .compact, tint: .ai))
            }
        }
        .transition(reduceMotion ? .identity : .opacity)
    }

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

    private var aiWorkstation: some View {
        SquircleCard(glassEnabled: false, glowEnabled: false) {
            VStack(spacing: SonicMergeTheme.Spacing.lg) {
                AIOrbView(viewModel: viewModel)
                    .padding(.vertical, SonicMergeTheme.Spacing.sm)
                Divider().accessibilityHidden(true)
                intensityRow
                if viewModel.hasDenoisedResult {
                    abComparisonButton
                }
            }
        }
    }

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
    }

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
    }
}
