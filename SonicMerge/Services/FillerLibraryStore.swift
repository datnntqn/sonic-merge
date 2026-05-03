import Foundation
import SwiftUI
import Observation

/// Process-wide owner of the user's FillerLibrary. Installed on RootTabView and
/// read by per-session SmartCutSessionView instances via the environment.
///
/// FillerLibrary is itself UserDefaults-backed (see FillerLibrary.swift), so
/// `library`'s mutations persist automatically; the store just provides one
/// SwiftUI-observable instance with a Binding for SmartCutStudioContainer.
@Observable
@MainActor
final class FillerLibraryStore {
    var library: FillerLibrary

    init(library: FillerLibrary = FillerLibrary()) {
        self.library = library
    }

    var binding: Binding<FillerLibrary> {
        Binding(
            get: { self.library },
            set: { self.library = $0 }
        )
    }
}

private struct FillerLibraryStoreKey: EnvironmentKey {
    @MainActor static let defaultValue: FillerLibraryStore = FillerLibraryStore()
}

extension EnvironmentValues {
    var fillerLibrary: FillerLibraryStore {
        get { self[FillerLibraryStoreKey.self] }
        set { self[FillerLibraryStoreKey.self] = newValue }
    }
}
