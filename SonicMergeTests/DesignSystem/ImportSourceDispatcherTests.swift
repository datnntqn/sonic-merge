// SonicMergeTests/DesignSystem/ImportSourceDispatcherTests.swift
import Testing
@testable import SonicMerge

@MainActor
struct ImportSourceDispatcherTests {

    @Test func filesActionInvokesOnlyFilesClosure() {
        var filesCount = 0
        var recordCount = 0
        var photosCount = 0
        let d = ImportSourceDispatcher(
            onFiles:  { filesCount  += 1 },
            onRecord: { recordCount += 1 },
            onPhotos: { photosCount += 1 }
        )
        d.dispatch(.files)
        #expect(filesCount  == 1)
        #expect(recordCount == 0)
        #expect(photosCount == 0)
    }

    @Test func recordActionInvokesOnlyRecordClosure() {
        var filesCount = 0
        var recordCount = 0
        var photosCount = 0
        let d = ImportSourceDispatcher(
            onFiles:  { filesCount  += 1 },
            onRecord: { recordCount += 1 },
            onPhotos: { photosCount += 1 }
        )
        d.dispatch(.record)
        #expect(filesCount  == 0)
        #expect(recordCount == 1)
        #expect(photosCount == 0)
    }

    @Test func photosActionInvokesOnlyPhotosClosure() {
        var filesCount = 0
        var recordCount = 0
        var photosCount = 0
        let d = ImportSourceDispatcher(
            onFiles:  { filesCount  += 1 },
            onRecord: { recordCount += 1 },
            onPhotos: { photosCount += 1 }
        )
        d.dispatch(.photos)
        #expect(filesCount  == 0)
        #expect(recordCount == 0)
        #expect(photosCount == 1)
    }

    @Test func dispatchIsIdempotentPerCall() {
        var filesCount = 0
        let d = ImportSourceDispatcher(
            onFiles:  { filesCount += 1 },
            onRecord: {},
            onPhotos: {}
        )
        d.dispatch(.files)
        d.dispatch(.files)
        d.dispatch(.files)
        #expect(filesCount == 3)  // each dispatch invokes once, no swallowing
    }
}
