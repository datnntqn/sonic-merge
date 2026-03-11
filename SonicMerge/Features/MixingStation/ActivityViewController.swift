// ActivityViewController.swift
// SonicMerge

import SwiftUI
import UIKit

/// UIActivityViewController wrapper for sharing files from the App Group container.
/// Use instead of ShareLink — ShareLink has a known iOS 17 bug with "Save to Files"
/// for internal App Group URLs (silent failure, no file saved).
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onDismiss: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    final class Coordinator: NSObject {
        let onDismiss: (() -> Void)?
        init(onDismiss: (() -> Void)?) { self.onDismiss = onDismiss }
    }
}
