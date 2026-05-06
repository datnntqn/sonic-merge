// MixingStationView.swift
// SonicMerge
//
// Root view: Mixing Station with conveyor timeline, toolbar, sheets.

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MixingStationView: View {
    @Environment(MixingStationViewModel.self) private var viewModel
    @Environment(\.sonicMergeSemantic) private var semantic

    /// Phase 10 (D-06): persists across launches once the user has ever imported a clip.
    /// Gates the LocalFirstTrustStrip render in MergeTimelineView.
    @AppStorage("sonicMerge.hasImportedFirstClip") private var hasImportedFirstClip: Bool = false

    @State private var showDocumentPicker = false
    @State private var showExportSheet = false

    // POL-01: one trigger @State per toolbar button — prevents cross-firing
    @State private var exportHaptic = false

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                if viewModel.clips.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            Spacer()
                            CircularImportButton(size: .pinned) { showDocumentPicker = true }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                        MergeTimelineView(onExportTap: { showExportSheet = true })
                    }
                }
            }
            .navigationTitle("Merge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
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
        .onChange(of: viewModel.clips.count) { _, newCount in
            // Phase 10 D-06: flip the first-launch trust-banner flag the first
            // time the user has any clips. Persists across launches via @AppStorage.
            if newCount > 0 && !hasImportedFirstClip {
                hasImportedFirstClip = true
            }
        }
        .task {
            await viewModel.fetchAll()
        }
        .onAppear {
            let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
            guard let filename = defaults?.string(forKey: "pendingImportFilename") else { return }
            defaults?.removeObject(forKey: "pendingImportFilename")
            guard let clipsDir = try? AppConstants.clipsDirectory() else { return }
            let fileURL = clipsDir.appending(path: filename)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            viewModel.importFiles([fileURL])
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: SonicMergeTheme.Spacing.md) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(Color(uiColor: semantic.accentAction))
                .frame(width: 76, height: 76)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(uiColor: semantic.accentAction).opacity(0.14))
                )
                .accessibilityHidden(true)
            Text("No clips yet")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
            Text("Tap below to add audio files,\nor drop them here.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
                .padding(.horizontal, 32)
            CircularImportButton(size: .hero) { showDocumentPicker = true }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                exportHaptic.toggle()
                showExportSheet = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel.clips.isEmpty || viewModel.isExporting)
            .sensoryFeedback(.impact(weight: .light), trigger: exportHaptic)
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 8) {
                SettingsToolbarButton()
                ThemeToggleButton()
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
