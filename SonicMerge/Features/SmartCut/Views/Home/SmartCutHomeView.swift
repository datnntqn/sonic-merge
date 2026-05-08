// SmartCutHomeView.swift
// SonicMerge
//
// Smart Cut tab root. Recents list + Upload Audio CTA. Push-on-tap is
// implemented via the `onSelect` closure passed in by RootTabView (which
// owns the NavigationStack path binding for this tab).

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AVFoundation

struct SmartCutHomeView: View {
    /// Called with the freshly created (or tapped) session ID. RootTabView
    /// appends it onto the Smart Cut tab's NavigationStack path.
    let onSelect: (UUID) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(EntitlementService.self) private var entitlements

    @Query(sort: \SmartCutSession.lastOpenedAt, order: .reverse, animation: .default)
    private var sessions: [SmartCutSession]

    @State private var showFileImporter = false
    @State private var showSourceSheet = false
    @State private var showRecorder = false
    @State private var pendingAction: ImportSourceAction?
    @State private var importErrorMessage: String?
    @State private var paywallReason: PaywallReason?

    var body: some View {
        ZStack {
            PremiumBackground()
            if sessions.isEmpty {
                emptyState
            } else {
                loadedState
            }
        }
        .navigationTitle("Smart Cut")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    SettingsToolbarButton()
                    ThemeToggleButton()
                }
            }
        }
        .sheet(
            isPresented: $showSourceSheet,
            onDismiss: {
                guard let action = pendingAction else { return }
                pendingAction = nil
                switch action {
                case .files:
                    showFileImporter = true
                case .record:
                    showRecorder = true
                case .photos:
                    // Wired in Chunk 3.
                    print("[ImportSourceSheet] photos tapped — wiring lands in Chunk 3")
                }
            }
        ) {
            ImportSourceSheet(pendingAction: $pendingAction)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: UTType.audioImportTypes,
            allowsMultipleSelection: false
        ) { result in
            Task { await handleImport(result: result) }
        }
        .sheet(isPresented: $showRecorder) {
            RecorderSheet { url in
                Task {
                    await createSession(from: url)
                    // Recording is the only source where we own the URL outright,
                    // so we delete the /tmp file after createSession's copy. Files
                    // and Photos paths come from system pickers and are best left
                    // to the OS reaper.
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
        .paywall(reason: $paywallReason)
        .alert(
            "Couldn't import this file",
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )
        ) {
            Button("OK") {}
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: SonicMergeTheme.Spacing.md) {
            SmartCutMark(size: .splash)
                .frame(width: 76, height: 76)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LinearGradient(
                            colors: semantic.accentAIGradientStops.map { Color(uiColor: $0).opacity(0.18) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                )
                .accessibilityHidden(true)
            Text("Cut fillers in seconds")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
            Text("Upload a recording and we'll find every invalid word and long pause.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
                .padding(.horizontal, 32)
            CircularImportButton(size: .hero) { showSourceSheet = true }
        }
    }

    // MARK: - Loaded state

    private var loadedState: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                CircularImportButton(size: .pinned) { showSourceSheet = true }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            List {
                ForEach(sessions) { session in
                    SmartCutRecentRow(session: session)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(session.id) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                delete(session)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Upload flow

    private func handleImport(result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard let pickedURL = urls.first else { return }
            await createSession(from: pickedURL)
        case .failure(let error):
            importErrorMessage = error.localizedDescription
        }
    }

    private func createSession(from pickedURL: URL) async {
        let didStart = pickedURL.startAccessingSecurityScopedResource()
        defer { if didStart { pickedURL.stopAccessingSecurityScopedResource() } }

        let sessionId = UUID()
        let ext = pickedURL.pathExtension.isEmpty ? "m4a" : pickedURL.pathExtension.lowercased()
        let basename = pickedURL.deletingPathExtension().lastPathComponent

        let dir: URL
        do {
            dir = try AppConstants.smartCutSessionDirectory(for: sessionId)
        } catch {
            importErrorMessage = error.localizedDescription
            return
        }

        let destURL = dir.appending(path: "source.\(ext)")

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: pickedURL, to: destURL)
        } catch {
            try? FileManager.default.removeItem(at: dir)
            importErrorMessage = "Couldn't import this file. \(error.localizedDescription)"
            return
        }

        let duration: Double
        do {
            duration = try await AVURLAsset(url: destURL).load(.duration).seconds
        } catch {
            try? FileManager.default.removeItem(at: dir)
            importErrorMessage = "This file isn't a valid audio recording."
            return
        }

        // Sub-project 2 gate: refuse if Free user exceeds 5-min length cap
        // or has hit today's 3-session quota. Cleanup the temp file we just
        // copied so we don't leak storage on rejected imports.
        if let reason = ImportDecision.gate(durationSeconds: duration, entitlements: entitlements) {
            try? FileManager.default.removeItem(at: dir)
            paywallReason = reason
            return
        }

        let sourceHash: String
        do {
            sourceHash = try await SourceHasher.sha256Hex(of: destURL)
        } catch {
            try? FileManager.default.removeItem(at: dir)
            importErrorMessage = "Couldn't read this file."
            return
        }

        let session = SmartCutSession(
            id: sessionId,
            name: basename,
            sourceFilename: "source.\(ext)",
            sourceHashHex: sourceHash,
            durationSeconds: duration
        )
        modelContext.insert(session)
        do {
            try modelContext.save()
        } catch {
            try? FileManager.default.removeItem(at: dir)
            importErrorMessage = "Couldn't save the session. \(error.localizedDescription)"
            return
        }
        entitlements.recordSmartCutSession()

        onSelect(sessionId)
    }

    private func delete(_ session: SmartCutSession) {
        if let dir = try? AppConstants.smartCutSessionDirectory(for: session.id) {
            try? FileManager.default.removeItem(at: dir)
        }
        modelContext.delete(session)
        try? modelContext.save()
    }
}

// MARK: - ImportDecision

extension SmartCutHomeView {
    /// Pure decision: should we import this audio? Lifted out of `createSession`
    /// so tests can verify gate routing without touching the file system.
    struct ImportDecision {
        static func gate(
            durationSeconds: TimeInterval,
            entitlements: EntitlementService
        ) -> PaywallReason? {
            if case .requiresPro(let reason) = entitlements.gate(.smartCutLength(seconds: durationSeconds)) {
                return reason
            }
            if case .requiresPro(let reason) = entitlements.gate(.smartCutSession) {
                return reason
            }
            return nil
        }
    }
}

// MARK: - SmartCutRecentRow

private struct SmartCutRecentRow: View {
    let session: SmartCutSession
    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(
                    colors: semantic.accentAIGradientStops.map { Color(uiColor: $0) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
                Text(formatSubtitle(session))
                    .font(.caption)
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func formatSubtitle(_ session: SmartCutSession) -> String {
        let duration = formatDuration(session.durationSeconds)
        let relative = RelativeDateTimeFormatter().localizedString(
            for: session.lastOpenedAt, relativeTo: .now
        )
        return "\(duration) · \(relative)"
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return m > 0 ? "\(m) min" : "\(s) s"
    }
}
