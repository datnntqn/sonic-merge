// DenoiseHomeView.swift
// SonicMerge
//
// Denoise tab root. Recents list + Upload Audio CTA. Push-on-tap is
// implemented via the `onSelect` closure passed in by RootTabView.

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AVFoundation

struct DenoiseHomeView: View {
    let onSelect: (UUID) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(EntitlementService.self) private var entitlements

    @Query(sort: \DenoiseSession.lastOpenedAt, order: .reverse, animation: .default)
    private var sessions: [DenoiseSession]

    @State private var showFileImporter = false
    @State private var showSourceSheet = false
    @State private var pendingAction: ImportSourceAction?
    @State private var showRecorder = false
    @State private var showPhotoPicker = false
    @State private var photoExtractError: String?
    @State private var photoLoading = false
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
        .navigationTitle("Denoise")
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
                    showPhotoPicker = true
                }
            }
        ) {
            ImportSourceSheet(pendingAction: $pendingAction)
        }
        .sheet(isPresented: $showRecorder) {
            RecorderSheet { url in
                Task {
                    await createSession(from: url)
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PHPickerWrapper(
                onPickResult: { result in
                    showPhotoPicker = false
                    Task { await handlePhotoPickResult(result) }
                },
                onCancel: { showPhotoPicker = false }
            )
        }
        .alert(
            "Couldn't import this video",
            isPresented: Binding(
                get: { photoExtractError != nil },
                set: { if !$0 { photoExtractError = nil } }
            )
        ) {
            Button("OK") {}
        } message: {
            Text(photoExtractError ?? "")
        }
        .overlay {
            if photoLoading {
                VStack(spacing: 12) {
                    ProgressView().controlSize(.large)
                    Text("Loading video…")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                }
                .padding(28)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: UTType.audioImportTypes,
            allowsMultipleSelection: false
        ) { result in
            Task { await handleImport(result: result) }
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

    private var emptyState: some View {
        VStack(spacing: SonicMergeTheme.Spacing.md) {
            Image(systemName: "waveform.badge.minus")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(Color(uiColor: semantic.accentAI))
                .frame(width: 76, height: 76)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(uiColor: semantic.accentAI).opacity(0.18))
                )
                .accessibilityHidden(true)
            Text("Clean noisy recordings")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
            Text("Upload audio and remove background noise on-device.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
                .padding(.horizontal, 32)
            CircularImportButton(size: .hero) { showSourceSheet = true }
        }
    }

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
                    DenoiseRecentRow(session: session)
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
        let ext = pickedURL.pathExtension.isEmpty ? "wav" : pickedURL.pathExtension.lowercased()
        let basename = pickedURL.deletingPathExtension().lastPathComponent

        let dir: URL
        do {
            dir = try AppConstants.denoiseSessionDirectory(for: sessionId)
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

        // Sub-project 2 gate: refuse if Free user exceeds 3-min length cap
        // or has hit today's 3-session quota. Cleanup the temp file we just
        // copied so we don't leak storage on rejected imports.
        if let reason = ImportDecision.gate(durationSeconds: duration, entitlements: entitlements) {
            try? FileManager.default.removeItem(at: dir)
            paywallReason = reason
            return
        }

        let session = DenoiseSession(
            id: sessionId,
            name: basename,
            sourceFilename: "source.\(ext)",
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
        entitlements.recordDenoiseSession()

        onSelect(sessionId)
    }

    private func handlePhotoPickResult(_ result: Result<URL, Error>) async {
        let overlayTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled { photoLoading = true }
        }
        defer {
            overlayTask.cancel()
            photoLoading = false
        }

        switch result {
        case .success(let videoURL):
            defer { try? FileManager.default.removeItem(at: videoURL) }
            do {
                let audioURL = try await VideoAudioExtractor.extractAudio(from: videoURL)
                await createSession(from: audioURL)
                try? FileManager.default.removeItem(at: audioURL)
            } catch VideoAudioExtractor.ExtractError.noAudioTrack {
                photoExtractError = "This video has no audio to import."
            } catch {
                photoExtractError = "Couldn't extract audio. \(error.localizedDescription)"
            }
        case .failure(let error):
            photoExtractError = error.localizedDescription
        }
    }

    private func delete(_ session: DenoiseSession) {
        if let dir = try? AppConstants.denoiseSessionDirectory(for: session.id) {
            try? FileManager.default.removeItem(at: dir)
        }
        modelContext.delete(session)
        try? modelContext.save()
    }
}

// MARK: - ImportDecision

extension DenoiseHomeView {
    /// Pure decision: should we import this audio? Lifted out of `createSession`
    /// so tests can verify gate routing without touching the file system.
    struct ImportDecision {
        static func gate(
            durationSeconds: TimeInterval,
            entitlements: EntitlementService
        ) -> PaywallReason? {
            if case .requiresPro(let reason) = entitlements.gate(.denoiseLength(seconds: durationSeconds)) {
                return reason
            }
            if case .requiresPro(let reason) = entitlements.gate(.denoiseSession) {
                return reason
            }
            return nil
        }
    }
}

private struct DenoiseRecentRow: View {
    let session: DenoiseSession
    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(uiColor: semantic.accentAI), Color(uiColor: semantic.accentAction)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "waveform")
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

    private func formatSubtitle(_ session: DenoiseSession) -> String {
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
