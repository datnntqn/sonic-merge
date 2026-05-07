// SmartCutSessionView.swift
// SonicMerge
//
// Push destination from SmartCutHomeView. Resolves a SmartCutSession by ID,
// owns a per-session SmartCutViewModel, and renders SmartCutStudioContainer
// as its body. Persists edit-list state back to the session on disappear.

import SwiftUI
import SwiftData
import StoreKit

struct SmartCutSessionView: View {
    let sessionId: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fillerLibrary) private var libraryStore
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(EntitlementService.self) private var entitlements
    @Environment(ReviewPromptCoordinator.self) private var reviewCoordinator

    @State private var viewModel: SmartCutViewModel?
    @State private var session: SmartCutSession?
    @State private var showDeleteConfirm = false

    @State private var showExportSheet = false
    @State private var showExportProgressSheet = false
    @State private var exportProgress: Float = 0.0
    @State private var exportTask: Task<Void, Never>?
    @State private var showShareSheet = false
    @State private var exportedFileURL: URL? = nil
    @State private var isNormalizingExport = false
    @State private var showMoodCheckSheet = false
    @State private var showTranscriptSheet = false
    @State private var paywallReason: PaywallReason?

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let viewModel, let session {
                    ScrollView {
                        SmartCutStudioContainer(vm: viewModel, library: libraryStore.binding)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 96)
                    }
                    .navigationTitle(session.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { toolbarContent }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            if let viewModel, shouldShowFloatingBar(for: viewModel) {
                FloatingActionBar { applyCutsButton(for: viewModel) }
            }
        }
        .task { await load() }
        .onDisappear {
            if let vm = viewModel, let session {
                vm.cancelAnalyze()
                vm.persist(to: session)
                try? modelContext.save()
            }
        }
        .confirmationDialog(
            "Delete this Smart Cut session?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The source audio and any saved edits will be removed.")
        }
        .sheet(isPresented: $showExportSheet) {
            ExportFormatSheet(isPresented: $showExportSheet, paywallReason: $paywallReason) { options in
                startExport(options: options)
            }
        }
        .paywall(reason: $paywallReason)
        .moodCheckSheet(isPresented: $showMoodCheckSheet) { mood in
            handleMood(mood)
        }
        .sheet(isPresented: $showTranscriptSheet) {
            TranscriptSheet(segments: viewModel?.cachedSegments ?? [])
        }
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
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showTranscriptSheet = true
            } label: {
                Label("Transcript", systemImage: "doc.text")
            }
            .disabled(viewModel?.cachedSegments.isEmpty ?? true)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showExportSheet = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel?.outputURL == nil)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete session", systemImage: "trash")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }

    private func shouldShowFloatingBar(for vm: SmartCutViewModel) -> Bool {
        switch vm.state {
        case .results: return true
        case .applied: return vm.hasDirtyEditsSinceApply
        case .idle, .analyzing, .stale, .error: return false
        }
    }

    @ViewBuilder
    private func applyCutsButton(for vm: SmartCutViewModel) -> some View {
        switch vm.state {
        case .results:
            Button { Task { await vm.apply() } } label: {
                HStack(spacing: 6) {
                    SmartCutMark(size: .toolbar, monochromeTint: .white)
                        .frame(width: 22, height: 22)
                    Text("Apply Cuts")
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(LinearGradient(
                    colors: semantic.accentAIGradientStops.map { Color(uiColor: $0) },
                    startPoint: .leading,
                    endPoint: .trailing
                )))
            }
            .accessibilityLabel("Apply Cuts")
        case .applied:
            if vm.hasDirtyEditsSinceApply {
                Button { Task { await vm.apply() } } label: {
                    Label("Re-apply", systemImage: "arrow.clockwise")
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
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

    private func load() async {
        let id = sessionId
        let descriptor = FetchDescriptor<SmartCutSession>(
            predicate: #Predicate { $0.id == id }
        )
        guard let fetched = try? modelContext.fetch(descriptor).first else {
            dismiss()
            return
        }
        fetched.lastOpenedAt = .now
        try? modelContext.save()

        let coordinator = PlaybackCoordinator()
        let vm = SmartCutViewModel(
            session: fetched,
            library: libraryStore.library,
            coordinator: coordinator,
            entitlements: entitlements,
            modelContext: modelContext
        )
        self.session = fetched
        self.viewModel = vm
    }

    private func performDelete() {
        guard let session else { return }
        if let dir = try? AppConstants.smartCutSessionDirectory(for: session.id) {
            try? FileManager.default.removeItem(at: dir)
        }
        modelContext.delete(session)
        try? modelContext.save()
        dismiss()
    }

    private func startExport(options: ExportOptions) {
        guard let viewModel, let sourceURL = viewModel.outputURL else { return }

        let ext = options.format == .m4a ? "m4a" : "wav"
        let destinationURL = FileManager.default.temporaryDirectory
            .appending(path: "CleanCut-SmartCutExport-\(UUID().uuidString).\(ext)")

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
                    reviewCoordinator.recordExport()
                    if reviewCoordinator.shouldPromptNow() {
                        reviewCoordinator.markPrompted()
                        showMoodCheckSheet = true
                    }
                }
            }
        }
    }

    private func handleMood(_ mood: MoodCheckSheet.Mood) {
        guard mood == .happy else { return }
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
