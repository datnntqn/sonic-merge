// SmartCutSessionView.swift
// SonicMerge
//
// Push destination from SmartCutHomeView. Resolves a SmartCutSession by ID,
// owns a per-session SmartCutViewModel, and renders SmartCutStudioContainer
// as its body. Persists edit-list state back to the session on disappear.

import SwiftUI
import SwiftData

struct SmartCutSessionView: View {
    let sessionId: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fillerLibrary) private var libraryStore

    @State private var viewModel: SmartCutViewModel?
    @State private var session: SmartCutSession?
    @State private var showDeleteConfirm = false

    var body: some View {
        Group {
            if let viewModel, let session {
                SmartCutStudioContainer(vm: viewModel, library: libraryStore.binding)
                    .navigationTitle(session.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { toolbarContent }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
            modelContext: modelContext
        )
        self.session = fetched
        self.viewModel = vm
    }

    private func performDelete() {
        guard let session else { return }
        // Best-effort filesystem cleanup; SwiftData delete is the source of truth.
        if let dir = try? AppConstants.smartCutSessionDirectory(for: session.id) {
            try? FileManager.default.removeItem(at: dir)
        }
        modelContext.delete(session)
        try? modelContext.save()
        dismiss()
    }
}
