//
//  ImportView.swift
//  SonicMerge
//
//  Minimal Phase 1 UI for the import pipeline.
//  Hosts the .fileImporter document picker and displays the imported clip list.
//  Phase 2 replaces this with the full Mixing Station UI.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(ImportViewModel.self) private var viewModel
    @State private var isPickerPresented = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.clips.isEmpty && !viewModel.isImporting {
                    ContentUnavailableView(
                        "No Audio Clips",
                        systemImage: "waveform.badge.plus",
                        description: Text("Tap Import Audio to add files")
                    )
                } else {
                    List(viewModel.clips, id: \.id) { clip in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(clip.displayName)
                                .font(.headline)
                            Text(String(format: "%.1fs \u{00B7} 48kHz \u{00B7} Stereo", clip.duration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("SonicMerge")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPickerPresented = true
                    } label: {
                        Label("Import Audio", systemImage: "plus")
                    }
                    .disabled(viewModel.isImporting)
                }
            }
            .overlay {
                if viewModel.isImporting {
                    ProgressView("Normalizing...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .alert("Import Errors", isPresented: .constant(!viewModel.importErrors.isEmpty)) {
                Button("OK") { }
            } message: {
                Text(viewModel.importErrors.joined(separator: "\n"))
            }
            .fileImporter(
                isPresented: $isPickerPresented,
                allowedContentTypes: [UTType].audioImportTypes,
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    Task { await viewModel.importFiles(urls) }
                case .failure(let error):
                    viewModel.handlePickerError(error)
                }
            }
        }
    }
}

// Convenience to use [UTType].audioImportTypes in .fileImporter
private extension Array where Element == UTType {
    static var audioImportTypes: [UTType] { UTType.audioImportTypes }
}
