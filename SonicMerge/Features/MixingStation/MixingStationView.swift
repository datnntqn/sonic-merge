// MixingStationView.swift
// SonicMerge
//
// Root view: Mixing Station with conveyor timeline, toolbar, sheets.

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MixingStationView: View {
    @Environment(MixingStationViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("sonicMergeThemePreference") private var themePreferenceRaw: String = ThemePreference.system.rawValue

    @State private var showDocumentPicker = false
    @State private var showExportSheet = false
    @State private var showCleaningLab = false
    @State private var mergedFileURLForCleaning: URL?

    private var themePreference: ThemePreference {
        ThemePreference(rawValue: themePreferenceRaw) ?? .system
    }

    private var semantic: SonicMergeSemantic {
        SonicMergeSemantic.resolved(colorScheme: colorScheme, preference: themePreference)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: semantic.surfaceBase)
                    .ignoresSafeArea()

                if viewModel.clips.isEmpty {
                    emptyState
                } else {
                    MergeTimelineView(onExportTap: { showExportSheet = true })
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
            .sheet(isPresented: $showExportSheet) {
                ExportFormatSheet(isPresented: $showExportSheet) { options in
                    viewModel.exportMerged(options: options)
                }
            }
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
            .onDrop(of: UTType.audioDropTypes, isTargeted: nil) { providers in
                guard !providers.isEmpty else { return false }
                Task {
                    let urls = await AudioDropImport.urls(from: providers)
                    guard !urls.isEmpty else { return }
                    await MainActor.run {
                        viewModel.importFiles(urls)
                    }
                }
                return true
            }
        }
        .environment(\.sonicMergeSemantic, semantic)
        .onChange(of: showCleaningLab) { _, isShowing in
            if !isShowing, let url = mergedFileURLForCleaning {
                try? FileManager.default.removeItem(at: url)
                mergedFileURLForCleaning = nil
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
                .foregroundStyle(Color(uiColor: semantic.accentAction))
            Text("No clips yet")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
            Text("Tap Import to add audio files")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
            Button(action: { showDocumentPicker = true }) {
                Label("Import Audio", systemImage: "plus.circle.fill")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color(uiColor: semantic.surfaceBase))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(uiColor: semantic.accentAction))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
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
            Menu {
                Picker("Appearance", selection: $themePreferenceRaw) {
                    Text("System").tag(ThemePreference.system.rawValue)
                    Text("Light").tag(ThemePreference.light.rawValue)
                    Text("Dark conveyor").tag(ThemePreference.dark.rawValue)
                }
            } label: {
                Label("Appearance", systemImage: "paintpalette")
            }
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
            for await _ in stream {}
            if FileManager.default.fileExists(atPath: destURL.path) {
                mergedFileURLForCleaning = destURL
                showCleaningLab = true
            }
        }
    }
}

// MARK: - Drag & drop

private enum AudioDropImport {
    static func urls(from providers: [NSItemProvider]) async -> [URL] {
        await withTaskGroup(of: URL?.self) { group in
            for provider in providers {
                group.addTask { await url(from: provider) }
            }
            var result: [URL] = []
            for await url in group {
                if let url {
                    result.append(url)
                }
            }
            return result
        }
    }

    private static func url(from provider: NSItemProvider) async -> URL? {
        if provider.canLoadObject(ofClass: URL.self) {
            return await withCheckedContinuation { continuation in
                _ = provider.loadObject(ofClass: URL.self) { object, _ in
                    continuation.resume(returning: object)
                }
            }
        }
        for ut in UTType.audioDropTypes where provider.hasItemConformingToTypeIdentifier(ut.identifier) {
            return await withCheckedContinuation { continuation in
                provider.loadFileRepresentation(forTypeIdentifier: ut.identifier) { tempURL, error in
                    guard let tempURL, error == nil else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let dest = FileManager.default.temporaryDirectory
                        .appending(path: "SonicMerge-drop-\(UUID().uuidString)-\(tempURL.lastPathComponent)")
                    do {
                        try FileManager.default.copyItem(at: tempURL, to: dest)
                        continuation.resume(returning: dest)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
        return nil
    }
}
