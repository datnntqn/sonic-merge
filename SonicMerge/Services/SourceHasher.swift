//
//  SourceHasher.swift
//  SonicMerge
//
//  Streams a file through SHA256 in 64KB chunks. Used as the resume key for
//  SmartCut transcription state (spec §7.5).
//

import Foundation
import CryptoKit

/// Streams a file through SHA256 in 64KB chunks. Used as the resume key for
/// SmartCut transcription state (spec §7.5).
enum SourceHasher {

    static func sha256Hex(of url: URL) async throws -> String {
        try await Task.detached(priority: .utility) {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }

            var hasher = SHA256()
            while true {
                let chunk = try handle.read(upToCount: 64 * 1024) ?? Data()
                if chunk.isEmpty { break }
                hasher.update(data: chunk)
            }
            let digest = hasher.finalize()
            return digest.map { String(format: "%02x", $0) }.joined()
        }.value
    }
}
