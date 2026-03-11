// MixingStationView.swift
// SonicMerge
//
// Root view of SonicMerge. Displays the Mixing Station: a vertical list of
// clip cards interleaved with gap rows, with toolbar Export and Import buttons.
//
// Replaces ImportView as the app's entry point (SonicMergeApp.swift routes here).

import SwiftUI
import UniformTypeIdentifiers

/// Root view of SonicMerge. Displays the Mixing Station: a vertical list of
/// clip cards interleaved with gap rows, with toolbar Export and Import buttons.
///
/// Replaces ImportView as the app's entry point (SonicMergeApp.swift routes here).
struct MixingStationView: View {
    @Environment(MixingStationViewModel.self) private var viewModel
    @State private var showDocumentPicker = false
    @State private var showExportSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.973, green: 0.976, blue: 0.980)
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
            // Export format picker (bottom sheet)
            .sheet(isPresented: $showExportSheet) {
                ExportFormatSheet(isPresented: $showExportSheet) { format in
                    viewModel.exportMerged(format: format)
                }
            }
            // Export progress (non-dismissible)
            .sheet(isPresented: Binding(
                get: { viewModel.isExporting },
                set: { _ in }
            )) {
                ExportProgressSheet(
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
                .foregroundStyle(Color(red: 0, green: 0.478, blue: 1.0))
            Text("No clips yet")
                .font(.system(.title3, design: .default, weight: .semibold))
                .foregroundStyle(Color(red: 0.110, green: 0.110, blue: 0.118))
            Text("Tap Import to add audio files")
                .font(.system(.body))
                .foregroundStyle(.secondary)
            Button(action: { showDocumentPicker = true }) {
                Label("Import Audio", systemImage: "plus.circle.fill")
                    .font(.system(.body, design: .default, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(red: 0, green: 0.478, blue: 1.0))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var clipList: some View {
        List {
            // Interleave clip cards and gap rows
            ForEach(Array(viewModel.clips.enumerated()), id: \.element.id) { index, clip in
                Section {
                    ClipCardView(clip: clip)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    // Gap row after every clip except the last
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
            .onDelete { offsets in viewModel.deleteClip(atOffsets: offsets) }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.973, green: 0.976, blue: 0.980))
        .environment(\.editMode, .constant(.active))  // Always show drag handles (MRG-01)
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
    }
}
