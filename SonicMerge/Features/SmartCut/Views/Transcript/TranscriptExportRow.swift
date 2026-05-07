import SwiftUI
import UIKit

/// Horizontal row of action chips for the transcript surfaces. Used by
/// `TranscriptSheet` (in header) and `TranscriptCanvas` (bottom-sticky).
///
/// Actions: Copy (UIPasteboard) + .txt + .srt + .vtt (UIActivityViewController).
struct TranscriptExportRow: View {

    let segments: [TranscriptionState.RecognizedSegment]
    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        HStack(spacing: 8) {
            actionChip(icon: "doc.on.clipboard", label: "Copy", action: copy)
            actionChip(icon: "doc.text", label: ".txt", action: { exportFile(.txt) })
            actionChip(icon: "captions.bubble", label: ".srt", action: { exportFile(.srt) })
            actionChip(icon: "film", label: ".vtt", action: { exportFile(.vtt) })
        }
    }

    private func actionChip(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption.weight(.bold))
                Text(label).font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color(uiColor: semantic.accentAction))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color(uiColor: semantic.accentAction).opacity(0.10)))
        }
        .buttonStyle(.plain)
        .disabled(segments.isEmpty)
        .opacity(segments.isEmpty ? 0.4 : 1.0)
    }

    private func copy() {
        UIPasteboard.general.string = TranscriptExporter.plainText(from: segments)
    }

    private enum FileFormat {
        case txt, srt, vtt
        var ext: String {
            switch self {
            case .txt: return "txt"
            case .srt: return "srt"
            case .vtt: return "vtt"
            }
        }
    }

    private func exportFile(_ format: FileFormat) {
        let content: String
        switch format {
        case .txt: content = TranscriptExporter.plainText(from: segments)
        case .srt: content = TranscriptExporter.srt(from: segments)
        case .vtt: content = TranscriptExporter.vtt(from: segments)
        }
        guard let url = try? TranscriptExporter.writeTempFile(content: content, ext: format.ext) else { return }
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController?.topMostPresenter() else { return }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = root.view
        root.present(activity, animated: true)
    }
}

private extension UIViewController {
    func topMostPresenter() -> UIViewController {
        var top: UIViewController = self
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
