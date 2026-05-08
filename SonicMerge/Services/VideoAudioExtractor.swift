// SonicMerge/Services/VideoAudioExtractor.swift
//
// Extract the audio track from a video file and export it as a standalone
// .m4a. Used by the Photos & Videos import source.
//

import AVFoundation
import Foundation

enum VideoAudioExtractor {

    enum ExtractError: Error, Equatable {
        case noAudioTrack
        case exportFailed(String)  // wraps the underlying error description
        case unsupportedFile
    }

    /// Extracts the audio track from `videoURL` and writes it to a temp .m4a.
    /// The caller owns the returned URL and is responsible for moving or
    /// deleting it once consumed.
    static func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else { throw ExtractError.noAudioTrack }

        guard let session = AVAssetExportSession(asset: asset,
                                                 presetName: AVAssetExportPresetAppleM4A) else {
            throw ExtractError.unsupportedFile
        }

        let outURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("extracted-\(UUID().uuidString).m4a")

        session.outputURL = outURL
        session.outputFileType = .m4a

        // iOS 17 compatible: bare `export()` async overload is iOS 18+.
        // Mirror the pattern in AudioMergerService.swift:418-428.
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                switch session.status {
                case .completed:
                    cont.resume()
                case .failed, .cancelled:
                    cont.resume(throwing: ExtractError.exportFailed(
                        session.error?.localizedDescription ?? "unknown"))
                default:
                    cont.resume(throwing: ExtractError.exportFailed(
                        "unexpected status: \(session.status.rawValue)"))
                }
            }
        }
        return outURL
    }
}
