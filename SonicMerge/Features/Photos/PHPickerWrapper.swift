// SonicMerge/Features/Photos/PHPickerWrapper.swift
//
// SwiftUI bridge over PHPickerViewController for the Photos & Videos
// import source. Filter is video-only, single-selection. The picked
// asset is loaded as a file representation and handed back as a URL.
//
// PHPickerViewController is Apple-mediated and runs out-of-process, so
// no NSPhotoLibraryUsageDescription is required.
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct PHPickerWrapper: UIViewControllerRepresentable {

    enum PickError: LocalizedError, Equatable {
        case loadFailed(String)
        case missingFile

        var errorDescription: String? {
            switch self {
            case .loadFailed(let msg):
                return "Couldn't load this video. \(msg)"
            case .missingFile:
                return "Couldn't read the picked video."
            }
        }
    }

    let onPickResult: (Result<URL, Error>) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: PHPickerViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPickResult: onPickResult, onCancel: onCancel)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPickResult: (Result<URL, Error>) -> Void
        let onCancel: () -> Void

        init(onPickResult: @escaping (Result<URL, Error>) -> Void,
             onCancel: @escaping () -> Void) {
            self.onPickResult = onPickResult
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController,
                    didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let result = results.first else {
                onCancel()
                return
            }

            let provider = result.itemProvider
            // Prefer the most specific UTI the asset advertises; fall back to
            // generic movie. PHPicker exposes whatever the asset has.
            let typeId = provider.registeredTypeIdentifiers.first(where: {
                UTType($0)?.conforms(to: .movie) == true
            }) ?? UTType.movie.identifier

            provider.loadFileRepresentation(forTypeIdentifier: typeId) { [weak self] tempURL, error in
                guard let self else { return }
                if let error {
                    DispatchQueue.main.async {
                        self.onPickResult(.failure(PickError.loadFailed(error.localizedDescription)))
                    }
                    return
                }
                guard let tempURL else {
                    DispatchQueue.main.async {
                        self.onPickResult(.failure(PickError.missingFile))
                    }
                    return
                }
                // Defensive copy: tempURL is invalidated when this closure
                // returns. Mirror the pattern in ShareExtensionViewController.
                let copyURL = FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent("phpicker-\(UUID().uuidString).\(tempURL.pathExtension)")
                do {
                    try FileManager.default.copyItem(at: tempURL, to: copyURL)
                    DispatchQueue.main.async {
                        self.onPickResult(.success(copyURL))
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.onPickResult(.failure(PickError.loadFailed(error.localizedDescription)))
                    }
                }
            }
        }
    }
}
