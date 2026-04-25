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
        ScrollView {
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

                // 3. AI Orb hero (always visible — renders idle/processing/success internally)
                SquircleCard(glassEnabled: false, glowEnabled: false) {
                    AIOrbView(viewModel: viewModel)
                        .padding(.vertical, SonicMergeTheme.Spacing.sm)
                }

                // 4. Waveform display — hidden in pure idle state so the slider
                //    + primary CTA reach above the fold sooner.
                if shouldShowWaveformSection {
                    waveformSection
                }

                // 5. Intensity slider (always visible, dimmed during processing)
                intensitySlider

                // 6. A/B comparison button (shown when denoised result available)
                if viewModel.hasDenoisedResult {
                    abComparisonButton
                }

                // 7. Denoise / Re-process action button (shown when NOT processing)
                if !viewModel.isProcessing {
                    denoiseActionButton
                }
            }
            .padding(.horizontal, SonicMergeTheme.Spacing.md)
            .padding(.vertical, SonicMergeTheme.Spacing.lg)
        }
        .background(Color(uiColor: semantic.surfaceBase))
        .navigationTitle("Cleaning Lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
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
                        WaveformCanvasView(peaks: viewModel.waveformPeaks)
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

    /// Intensity slider — LimeGreenSlider with Noise Reduction label
    private var intensitySlider: some View {
        SquircleCard(glassEnabled: false, glowEnabled: false) {
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

    /// Denoise / Re-process primary CTA — Lime Green filled pill
    private var denoiseActionButton: some View {
        Button {
            viewModel.startDenoising(mergedFileURL: mergedFileURL)
        } label: {
            Text(viewModel.hasDenoisedResult ? "Re-process" : "Denoise Audio")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
        .sensoryFeedback(.success, trigger: viewModel.isProcessing)
        .accessibilityHint("Starts on-device AI noise reduction")
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
            .disabled(!viewModel.hasDenoisedResult || viewModel.isProcessing)
        }
    }

    // MARK: - Export Logic

    /// Export the intensity-blended denoised audio using AudioMergerService.
    ///
    /// Guards that denoisedTempURL is non-nil (written by CleaningLabViewModel).
    /// Calls AudioMergerService.exportFile(inputURL:format:destinationURL:) which
    /// handles format conversion (m4a via AVAssetExportSession, wav via AVAssetReader+Writer).
    private func startExport(options: ExportOptions) {
        guard let sourceURL = viewModel.denoisedTempURL else { return }

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

// MARK: - WaveformCanvasView

/// Full-width symmetrical waveform drawn from 50 Float peaks.
/// Mirrors the ClipCardView waveform pattern at full width.
private struct WaveformCanvasView: View {
    let peaks: [Float]

    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        Canvas { context, size in
            guard !peaks.isEmpty else { return }

            let barWidth = (size.width / CGFloat(peaks.count)) * 0.7
            let gap = (size.width / CGFloat(peaks.count)) * 0.3
            let centerY = size.height / 2

            for (index, peak) in peaks.enumerated() {
                let normalizedPeak = CGFloat(max(0.01, min(1.0, peak)))
                let halfHeight = normalizedPeak * centerY * 0.9

                let x = CGFloat(index) * (barWidth + gap) + gap / 2
                let rect = CGRect(
                    x: x,
                    y: centerY - halfHeight,
                    width: barWidth,
                    height: halfHeight * 2
                )

                let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
                context.fill(path, with: .color(Color(uiColor: semantic.accentWaveform).opacity(0.88)))
            }

            // Scrub line (center) — textPrimary@0.3 for visibility in both light and dark mode
            var scrubPath = Path()
            scrubPath.move(to: CGPoint(x: size.width / 2, y: 4))
            scrubPath.addLine(to: CGPoint(x: size.width / 2, y: size.height - 4))
            context.stroke(
                scrubPath,
                with: .color(Color(uiColor: semantic.textPrimary).opacity(0.3)),
                lineWidth: 1.5
            )
        }
    }
}
