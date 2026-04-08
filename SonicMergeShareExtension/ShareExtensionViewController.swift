//
//  ShareExtensionViewController.swift
//  SonicMergeShareExtension
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers

@objc(ShareExtensionViewController)
final class ShareExtensionViewController: UIViewController {

    private let hudModel = ShareHUDModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        let hudView = ShareHUDView(model: hudModel) { [weak self] in
            self?.extensionContext?.cancelRequest(withError: NSError(
                domain: "com.dtech.SonicMerge.ShareExtension",
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
            let filename = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { tempURL, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let tempURL else {
                        continuation.resume(throwing: NSError(
                            domain: "com.dtech.SonicMerge.ShareExtension",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "No temp URL provided"]
                        ))
                        return
                    }

                    // CRITICAL: tempURL is invalidated when this handler returns.
                    // All file operations must complete synchronously here.
                    do {
                        let clipsDir = try AppConstants.clipsDirectory()
                        let originalFilename = tempURL.lastPathComponent
                        let dest = clipsDir.appending(path: originalFilename)

                        // Overwrite if exists (dedup by displayName happens in main app per D-10)
                        if FileManager.default.fileExists(atPath: dest.path) {
                            try FileManager.default.removeItem(at: dest)
                        }
                        try FileManager.default.copyItem(at: tempURL, to: dest)

                        continuation.resume(returning: originalFilename)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            // Update HUD with filename
            await MainActor.run {
                hudModel.filename = URL(fileURLWithPath: filename)
                    .deletingPathExtension().lastPathComponent
            }

            // Write pending-file key so main app picks up on next scenePhase .active
            let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
            defaults?.set(filename, forKey: "pendingImportFilename")
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
