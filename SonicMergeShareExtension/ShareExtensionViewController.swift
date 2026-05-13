//
//  ShareExtensionViewController.swift
//  SonicMergeShareExtension
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

/// Key the main app writes whenever `EntitlementService.setEntitlement(_:)`
/// runs. Hardcoded here because the Share Extension is a separate target and
/// cannot import the main app's `EntitlementService`. Keep in sync with
/// `EntitlementService.isProMirrorKey`.
private let isProMirrorKey = "EntitlementService.isPro"

private struct ShareImportPayload {
    let filename: String
    let sessionId: UUID
    let originalBasename: String
}

@objc(ShareExtensionViewController)
final class ShareExtensionViewController: UIViewController {

    private let hudModel = ShareHUDModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        let hudView = ShareHUDView(model: hudModel) { [weak self] in
            self?.extensionContext?.cancelRequest(withError: NSError(
                domain: "com.dtech.cleancut.ShareExtension",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "User dismissed"]
            ))
        }
        let hosting = UIHostingController(rootView: hudView)
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hosting.didMove(toParent: self)

        Task { await loadAndCopyFile() }
    }

    private func loadAndCopyFile() async {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            hudModel.state = .error
            return
        }

        // Use loadFileRepresentation (streams to temp file, never loads full file into memory)
        // This satisfies the 120 MB extension memory ceiling for 30 MB+ files
        let typeIdentifier = UTType.audio.identifier

        guard itemProvider.hasItemConformingToTypeIdentifier(typeIdentifier) else {
            hudModel.state = .error
            return
        }

        // Bridge callback-based API to async/await
        do {
            let payload = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ShareImportPayload, Error>) in
                itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { tempURL, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let tempURL else {
                        continuation.resume(throwing: NSError(
                            domain: "com.dtech.cleancut.ShareExtension",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "No temp URL provided"]
                        ))
                        return
                    }

                    // CRITICAL: tempURL is invalidated when this handler returns.
                    // All file operations must complete synchronously here.
                    do {
                        let sessionId = UUID()
                        let dir = try AppConstants.smartCutSessionDirectory(for: sessionId)
                        let ext = tempURL.pathExtension.isEmpty ? "m4a" : tempURL.pathExtension.lowercased()
                        let dest = dir.appending(path: "source.\(ext)")
                        if FileManager.default.fileExists(atPath: dest.path) {
                            try FileManager.default.removeItem(at: dest)
                        }
                        try FileManager.default.copyItem(at: tempURL, to: dest)

                        continuation.resume(returning: ShareImportPayload(
                            filename: "source.\(ext)",
                            sessionId: sessionId,
                            originalBasename: tempURL.deletingPathExtension().lastPathComponent
                        ))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            // Update HUD with the user-friendly basename.
            await MainActor.run {
                hudModel.filename = payload.originalBasename
            }

            // Free-tier length gate. The Share Extension is a separate process
            // and cannot reach `EntitlementService` directly, so it reads the
            // mirrored `isPro` flag that the main app writes on every state
            // transition. The cap used here is `smartCutMaxSeconds` (the more
            // permissive of Smart Cut and Denoise) because the extension
            // doesn't know which workspace the user will route to — if they
            // pick the stricter workspace inside the app, the in-app gate
            // catches it on open.
            let sharedDefaults = UserDefaults(suiteName: AppConstants.appGroupID)
            let isPro = sharedDefaults?.bool(forKey: isProMirrorKey) ?? false
            if !isPro {
                // Probe the file we just copied. If `load(.duration)` throws
                // (corrupt file, unsupported codec), treat as 0 and let the
                // import through — the in-app validation would catch it.
                let dir = try AppConstants.smartCutSessionDirectory(for: payload.sessionId)
                let dest = dir.appending(path: payload.filename)
                let asset = AVURLAsset(url: dest)
                var duration: TimeInterval = 0
                do {
                    duration = try await asset.load(.duration).seconds
                } catch {
                    duration = 0
                }
                if duration > AppConstants.FreeCap.smartCutMaxSeconds {
                    try? FileManager.default.removeItem(at: dir)
                    await MainActor.run {
                        hudModel.state = .freeLimitReached(durationSeconds: duration)
                    }
                    return
                }
            }

            // Write routing keys so the main app picks up on next scenePhase .active.
            let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
            defaults?.set(payload.filename, forKey: "pendingImportFilename")
            defaults?.set(payload.sessionId.uuidString, forKey: "pendingImportSessionId")
            defaults?.set("smart-cut", forKey: "pendingImportDestination")
            defaults?.set(payload.originalBasename, forKey: "pendingImportBasename")
            defaults?.synchronize() // flush before extension process suspends

            // Show success briefly, then auto-dismiss
            await MainActor.run { hudModel.state = .success }
            try? await Task.sleep(for: .milliseconds(300))

            extensionContext?.completeRequest(returningItems: nil)

        } catch {
            await MainActor.run { hudModel.state = .error }
        }
    }
}
