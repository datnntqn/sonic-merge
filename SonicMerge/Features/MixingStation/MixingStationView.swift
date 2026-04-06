// MixingStationView.swift
// SonicMerge
//
// Root view of SonicMerge. Displays the Mixing Station: a vertical list of
// clip cards interleaved with gap rows, with toolbar Export and Import buttons.
//
// Replaces ImportView as the app's entry point (SonicMergeApp.swift routes here).

import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Root view of SonicMerge. Displays the Mixing Station: a vertical list of
/// clip cards interleaved with gap rows, with toolbar Export and Import buttons.
///
/// Replaces ImportView as the app's entry point (SonicMergeApp.swift routes here).
struct MixingStationView: View {
    @Environment(MixingStationViewModel.self) private var viewModel
    @State private var showDocumentPicker = false
    @State private var showExportSheet = false
    @State private var showCleaningLab = false
    @State private var mergedFileURLForCleaning: URL?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: SonicMergeTheme.ColorPalette.canvasBackground)
                    .ignoresSafeArea()

                if viewModel.clips.isEmpty {
                    emptyState
                } else {
                    clipList
                }
            }
            .navigationTitle("SonicMerge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .navigationDestination(isPresented: $showCleaningLab) {
                if let url = mergedFileURLForCleaning {
                    CleaningLabView(mergedFileURL: url)
                }
            }
            // Export format picker (bottom sheet)
            .sheet(isPresented: $showExportSheet) {
                ExportFormatSheet(isPresented: $showExportSheet) { options in
                    viewModel.exportMerged(options: options)
                }
            }
            // Export progress (non-dismissible)
            .sheet(isPresented: Binding(
                get: { viewModel.isExporting },
                set: { _ in }
            )) {
                ExportProgressSheet(
                    isNormalizing: viewModel.isNormalizingExport,
                    progress: viewModel.exportProgress,
                    onCancel: { viewModel.cancelExport() }
                )
            }
            // Share sheet after successful export
            .sheet(isPresented: Binding(
                get: { viewModel.showShareSheet },
                set: { if !$0 { viewModel.dismissShareSheet() } }
            )) {
                if let url = viewModel.exportedFileURL {
                    ActivityViewController(
                        activityItems: [url],
                        onDismiss: { viewModel.dismissShareSheet() }
                    )
                }
            }
            // Document picker for import
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: UTType.audioImportTypes,
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls): viewModel.importFiles(urls)
                case .failure: break
                }
            }
        }
        .task {
            await viewModel.fetchAll()
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundStyle(Color(uiColor: SonicMergeTheme.ColorPalette.primaryAccent))
            Text("No clips yet")
                .font(.system(.title3, design: .default, weight: .semibold))
                .foregroundStyle(Color(uiColor: SonicMergeTheme.ColorPalette.primaryText))
            Text("Tap Import to add audio files")
                .font(.system(.body))
                .foregroundStyle(.secondary)
            Button(action: { showDocumentPicker = true }) {
                Label("Import Audio", systemImage: "plus.circle.fill")
                    .font(.system(.body, design: .default, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(uiColor: SonicMergeTheme.ColorPalette.primaryAccent))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var clipList: some View {
        List {
            Section {
                LocalFirstTrustStrip()
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sequence")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(uiColor: SonicMergeTheme.ColorPalette.primaryText))
                        Text(summarySubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            ForEach(Array(viewModel.clips.enumerated()), id: \.element.id) { index, clip in
                Section {
                    ClipCardView(
                        clip: clip,
                        isPreviewing: viewModel.previewingClipID == clip.id,
                        onPreviewTap: { viewModel.toggleClipPreview(clip) }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            if let idx = MixingStationClipIndexResolver.index(for: clip.id, in: viewModel.clips) {
                                viewModel.deleteClip(atOffsets: IndexSet(integer: idx))
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }

                    if index < viewModel.clips.count - 1,
                       let transition = clip.gapTransition {
                        GapRowView(transition: transition) { gapDuration, isCrossfade in
                            viewModel.updateTransition(
                                transition,
                                gapDuration: gapDuration,
                                isCrossfade: isCrossfade
                            )
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .onMove { from, to in viewModel.moveClip(fromOffsets: from, toOffset: to) }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: SonicMergeTheme.ColorPalette.canvasBackground))
        .environment(\.editMode, .constant(.active))
    }

    private var summarySubtitle: String {
        let n = viewModel.clips.count
        let total = viewModel.clips.reduce(0.0) { $0 + $1.duration }
        let dur = ClipDurationFormatting.mmss(from: total)
        return "\(n) clip\(n == 1 ? "" : "s") · ~\(dur)"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: { showDocumentPicker = true }) {
                Label("Import", systemImage: "plus")
            }
            .disabled(viewModel.isImporting || viewModel.isExporting)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: { showExportSheet = true }) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel.clips.isEmpty || viewModel.isExporting)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                navigateToCleaningLab()
            } label: {
                Label("Denoise", systemImage: "wand.and.sparkles")
            }
            .disabled(viewModel.clips.isEmpty)
        }
    }

    // MARK: - Cleaning Lab Navigation

    /// Produces a temp merged file from the current clips, then pushes CleaningLabView.
    ///
    /// Uses AudioMergerService to build a merged .wav file matching the current clip
    /// arrangement. The URL is passed into CleaningLabView as the source for denoising.
    private func navigateToCleaningLab() {
        viewModel.stopClipPreview()
        let destURL = FileManager.default.temporaryDirectory
            .appending(path: "SonicMerge-CleaningLab-\(UUID().uuidString).wav")

        Task {
            let mergerService = AudioMergerService()
            let stream = await mergerService.export(
                clips: viewModel.clips.sorted(by: { $0.sortOrder < $1.sortOrder }),
                transitions: viewModel.transitions,
                format: .wav,
                destinationURL: destURL
            )
            // Consume the stream to completion (wait for merge to finish)
            for await _ in stream {}
            if FileManager.default.fileExists(atPath: destURL.path) {
                mergedFileURLForCleaning = destURL
                showCleaningLab = true
            }
        }
    }
}
