// CleaningLabView.swift
// SonicMerge
//
// Full Cleaning Lab screen (Plan 03-04).
//
// Pure rendering layer over CleaningLabViewModel.
// All business logic (pipeline, A/B playback, blending, haptics) lives in the ViewModel.
//
// Sections:
// 1. Stale result banner
// 2. Waveform display
// 3. Intensity slider
// 4. A/B comparison button
// 5. Denoise / Re-process action button
// 6. Export toolbar button (presents ExportFormatSheet → ExportProgressSheet)
// 7. Progress modal (non-dismissible, reuses ExportProgressSheet)
// + Error alert

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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                onDeviceAIHero

                // 1. Stale result banner
                if viewModel.showsStaleResultBanner && viewModel.hasDenoisedResult {
                    staleBanner
                }

                // 2. Waveform display
                waveformSection

                // 3. Intensity slider (always visible, dimmed before processing)
                intensitySlider

                // 4. A/B comparison button (shown when denoised result available)
                if viewModel.hasDenoisedResult {
                    abComparisonButton
                }

                // 5. Denoise / Re-process action button (shown when NOT processing)
                if !viewModel.isProcessing {
                    denoiseActionButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("Cleaning Lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        // 6. Export format picker
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
        // Share sheet after successful export (replaces imperative shareExportedFile helper)
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
        // 7. Progress modal (non-dismissible) — reuses ExportProgressSheet
        .sheet(isPresented: .constant(viewModel.isProcessing)) {
            ExportProgressSheet(
                progress: viewModel.progress,
                onCancel: { viewModel.cancelDenoising() }
            )
            .interactiveDismissDisabled(true)
        }
        // Error alert
        .alert("Denoising Failed", isPresented: errorAlertBinding) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Subviews

    private var onDeviceAIHero: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "cpu")
                .foregroundStyle(Color(uiColor: SonicMergeTheme.ColorPalette.aiAccent))
            VStack(alignment: .leading, spacing: 4) {
                Text(TrustSignalCopy.aiDenoiseTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(uiColor: SonicMergeTheme.ColorPalette.primaryText))
                Text(TrustSignalCopy.aiDenoiseSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(uiColor: SonicMergeTheme.ColorPalette.cardSurface))
        .clipShape(RoundedRectangle(cornerRadius: SonicMergeTheme.Radius.card, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // 1. Stale result banner
    private var staleBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(red: 0.8, green: 0.4, blue: 0.0))

            VStack(alignment: .leading, spacing: 2) {
                Text("Clips have changed.")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Color(red: 0.5, green: 0.25, blue: 0.0))
                Text("Re-process to update the denoised audio.")
                    .font(.system(.caption))
                    .foregroundStyle(Color(red: 0.5, green: 0.25, blue: 0.0))
            }

            Spacer()

            Button("Re-process") {
                viewModel.startDenoising(mergedFileURL: mergedFileURL)
            }
            .font(.system(.caption, weight: .semibold))
            .foregroundStyle(Color(red: 0.7, green: 0.35, blue: 0.0))
        }
        .padding(12)
        .background(Color(red: 1.0, green: 0.88, blue: 0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // 2. Waveform display
    private var waveformSection: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.11, green: 0.11, blue: 0.12))

                if viewModel.isProcessing && viewModel.waveformPeaks.isEmpty {
                    Text("Processing...")
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                } else if !viewModel.waveformPeaks.isEmpty {
                    WaveformCanvasView(peaks: viewModel.waveformPeaks)
                        .padding(.horizontal, 8)
                } else if !viewModel.hasDenoisedResult {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("Tap \"Denoise Audio\" to begin")
                            .font(.system(.caption))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(height: 120)
    }

    // 3. Intensity slider
    private var intensitySlider: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Noise Reduction")
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(Color(red: 0.11, green: 0.11, blue: 0.12))
                Spacer()
                Text("\(Int(viewModel.intensity * 100))%")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Color(red: 0, green: 0.478, blue: 1.0))
                    .monospacedDigit()
                    .frame(minWidth: 40, alignment: .trailing)
            }

            Slider(
                value: Binding(
                    get: { viewModel.intensity },
                    set: { viewModel.onIntensityChanged($0) }
                ),
                in: 0...1
            )
            .tint(Color(red: 0, green: 0.478, blue: 1.0))
            .disabled(viewModel.isProcessing)
            .opacity(viewModel.isProcessing ? 0.5 : 1.0)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // 4. A/B comparison button
    private var abComparisonButton: some View {
        VStack(spacing: 6) {
            // Long-press gesture for hold-to-hear-original
            Button {} label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isHoldingOriginal ? "headphones" : "waveform.and.magnifyingglass")
                    Text(viewModel.isHoldingOriginal ? "Original" : "Denoised")
                        .font(.system(.body, weight: .semibold))
                }
                .foregroundStyle(viewModel.isHoldingOriginal ? .white : Color(red: 0, green: 0.478, blue: 1.0))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    viewModel.isHoldingOriginal
                        ? Color(red: 0, green: 0.478, blue: 1.0)
                        : Color(red: 0, green: 0.478, blue: 1.0).opacity(0.1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0, green: 0.478, blue: 1.0), lineWidth: 1.5)
                )
            }
            .onLongPressGesture(
                minimumDuration: 0,
                pressing: { isPressing in
                    if isPressing {
                        viewModel.holdBegan()
                    } else {
                        viewModel.holdEnded()
                    }
                },
                perform: {}
            )

            Text("Hold to compare with original")
                .font(.system(.caption))
                .foregroundStyle(.secondary)
        }
    }

    // 5. Denoise / Re-process action button
    private var denoiseActionButton: some View {
        Button {
            viewModel.startDenoising(mergedFileURL: mergedFileURL)
        } label: {
            Text(viewModel.hasDenoisedResult ? "Re-process" : "Denoise Audio")
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    viewModel.hasDenoisedResult
                        ? Color(red: 0.3, green: 0.3, blue: 0.35)
                        : Color(red: 0, green: 0.478, blue: 1.0)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // 6. Export toolbar button
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
                lufsNormalize: options.lufsNormalize   // NEW — threads LUFS flag
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
                context.fill(path, with: .color(Color(red: 0, green: 0.478, blue: 1.0).opacity(0.85)))
            }

            // Scrub line (center)
            var scrubPath = Path()
            scrubPath.move(to: CGPoint(x: size.width / 2, y: 4))
            scrubPath.addLine(to: CGPoint(x: size.width / 2, y: size.height - 4))
            context.stroke(
                scrubPath,
                with: .color(.white.opacity(0.6)),
                lineWidth: 1.5
            )
        }
    }
}
