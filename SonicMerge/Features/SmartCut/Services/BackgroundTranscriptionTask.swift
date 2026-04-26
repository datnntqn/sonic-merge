import Foundation
import BackgroundTasks
import UserNotifications

/// BGProcessingTask handler for resuming transcription when iOS allows.
/// Identifier matches Info.plist BGTaskSchedulerPermittedIdentifiers.
enum BackgroundTranscriptionTask {

    static let identifier = "com.dtech.SonicMerge.smartcut.transcribe"

    static func makeRequest() -> BGProcessingTaskRequest {
        let req = BGProcessingTaskRequest(identifier: identifier)
        req.requiresExternalPower = false
        req.requiresNetworkConnectivity = false
        return req
    }

    static func schedule() throws {
        try BGTaskScheduler.shared.submit(makeRequest())
    }

    /// CRITICAL: `task.expirationHandler` MUST be assigned synchronously before any
    /// async work begins, or iOS may expire the task before we register the handler
    /// and the BG work is killed without a reschedule path.
    static func handle(_ task: BGProcessingTask) {
        let cancelBox = CancelBox()

        task.expirationHandler = {
            cancelBox.isCancelled = true
            try? schedule()
            task.setTaskCompleted(success: false)
        }

        Task {
            let cacheDir = FileManager.default
                .urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("SmartCut", isDirectory: true)

            func completeIfNotExpired(success: Bool) {
                guard !cancelBox.isCancelled else { return }
                task.setTaskCompleted(success: success)
            }

            guard let urls = try? FileManager.default
                .contentsOfDirectory(at: cacheDir,
                                     includingPropertiesForKeys: [.contentModificationDateKey]) else {
                completeIfNotExpired(success: true)
                return
            }
            guard let newestState = urls
                .compactMap({ url -> (URL, Date)? in
                    let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey])
                        .contentModificationDate) ?? .distantPast
                    return (url, date)
                })
                .max(by: { $0.1 < $1.1 })?
                .0 else {
                completeIfNotExpired(success: true)
                return
            }

            do {
                let data = try Data(contentsOf: newestState)
                var state = try JSONDecoder().decode(TranscriptionState.self, from: data)

                if state.isComplete {
                    await postCompletionNotification(state: state)
                    completeIfNotExpired(success: true)
                    return
                }

                guard let inputURL = SmartCutSourceLocator.lookupURL(forHash: state.sourceHash) else {
                    try? schedule()
                    completeIfNotExpired(success: true)
                    return
                }

                let service = TranscriptionService()
                for try await update in await service.transcribe(input: inputURL) {
                    state = update
                    if cancelBox.isCancelled { return }
                }

                if state.isComplete {
                    await postCompletionNotification(state: state)
                    completeIfNotExpired(success: true)
                } else {
                    try? schedule()
                    completeIfNotExpired(success: true)
                }
            } catch {
                completeIfNotExpired(success: false)
            }
        }
    }

    private final class CancelBox: @unchecked Sendable {
        var isCancelled = false
    }

    static func makeCompletionNotificationContent(sourceHash: String,
                                                  fillerCount: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Smart Cut finished"
        content.body = "Found \(fillerCount) fillers in your episode. Open to review."
        content.sound = .default
        content.userInfo = ["smartCutCompletedFor": sourceHash]
        return content
    }

    private static func postCompletionNotification(state: TranscriptionState) async {
        let content = makeCompletionNotificationContent(sourceHash: state.sourceHash,
                                                        fillerCount: state.recognizedSegments.count)
        let req = UNNotificationRequest(identifier: "smartcut-\(state.sourceHash)",
                                        content: content,
                                        trigger: nil)
        try? await UNUserNotificationCenter.current().add(req)
    }
}

/// Maps source-hash → URL for BG resume. Both read and write live here.
/// Storage is App Group UserDefaults so background processes can read it; callers
/// MUST pass URLs in `Caches/` or `Documents/` — `tmp/` may be purged before BG fires.
enum SmartCutSourceLocator {
    private static let key = "SmartCut.SourceHashToURL"

    static func lookupURL(forHash hash: String) -> URL? {
        guard let dict = UserDefaults(suiteName: AppConstants.appGroupID)?
            .dictionary(forKey: key) as? [String: String],
              let path = dict[hash] else { return nil }
        return URL(fileURLWithPath: path)
    }

    static func register(hash: String, url: URL) {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
        var dict = (defaults.dictionary(forKey: key) as? [String: String]) ?? [:]
        dict[hash] = url.path
        defaults.set(dict, forKey: key)
    }
}
