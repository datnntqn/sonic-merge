//
//  SmartCutAppDelegate.swift
//  SonicMerge
//
//  Created by DATNNT on 4/26/26.
//

import UIKit
import BackgroundTasks
import UserNotifications

/// Minimal AppDelegate adaptor introduced for Smart Cut. Owns:
/// - BGTaskScheduler registration for background transcription
/// - UNUserNotificationCenter delegation for handling the completion-tap deep-link
final class SmartCutAppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTranscriptionTask.identifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            BackgroundTranscriptionTask.handle(processingTask)
        }

        UNUserNotificationCenter.current().delegate = SmartCutNotificationDelegate.shared
        return true
    }
}

/// Receives notification taps and bridges them to the in-app pending-open state
/// that SmartCutViewModel.onAppear consumes (spec §7.4).
final class SmartCutNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    static let shared = SmartCutNotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let hash = response.notification.request.content.userInfo["smartCutCompletedFor"] as? String {
            Task { @MainActor in
                PendingSmartCutOpen.shared.hash = hash
            }
        }
        completionHandler()
    }
}

/// Tiny shared mailbox for the notification → SmartCutViewModel handoff.
@MainActor
final class PendingSmartCutOpen {
    static let shared = PendingSmartCutOpen()
    var hash: String?
    private init() {}
}
