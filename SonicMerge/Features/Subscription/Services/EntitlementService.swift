import Foundation
import Observation

/// Single source of truth for the user's Pro entitlement state. Other
/// code in the app talks to this — never to StoreKit directly. That
/// decoupling means swapping StoreKit for any other IAP backend
/// (RevenueCat, Adapty) only changes `StoreKitClient.swift`.
@MainActor
@Observable
final class EntitlementService {

    /// **Do not use in app code.** Kept for legacy callsites only — app code must
    /// read the `@Environment(EntitlementService.self)` instance owned by
    /// `RootTabView`. Calling `.shared.gate(...)` constructs a fresh
    /// `DailyUsageTracker()` whose counter state will diverge from any
    /// test-injected tracker on the @Environment instance.
    static let shared = EntitlementService()

    /// Free-tier caps. Moved to `AppConstants.FreeCap` so the Share Extension
    /// target can read the same values (extensions are separate processes and
    /// cannot import this type). The typealias keeps existing call sites
    /// (`FreeCap.smartCutMaxSeconds`, etc.) source-compatible.
    typealias FreeCap = AppConstants.FreeCap

    private(set) var currentEntitlement: Entitlement = .free

    var isPro: Bool { currentEntitlement.isPro }

    /// App Group `UserDefaults` key the Share Extension reads to decide
    /// whether to gate over-cap imports. Mirrored on every state transition.
    static let isProMirrorKey = "EntitlementService.isPro"

    private let usageTracker: DailyUsageTracker
    private let sharedDefaults: UserDefaults?

    init(usageTracker: DailyUsageTracker = DailyUsageTracker(),
         sharedDefaults: UserDefaults? = nil) {
        self.usageTracker = usageTracker
        // Default to the real App Group suite; tests can inject a private suite
        // so they don't pollute the shared one.
        self.sharedDefaults = sharedDefaults ?? UserDefaults(suiteName: AppConstants.appGroupID)
    }

    /// Called by `StoreKitClient` when `Transaction.currentEntitlements`
    /// resolves or when `Transaction.updates` emits a new state.
    /// Public so tests can inject states without StoreKit.
    ///
    /// Mirrors the Pro flag to App Group defaults on every transition (both
    /// Pro→Free and Free→Pro) so the Share Extension — a separate process
    /// that can't import this type — can read the current Pro state
    /// synchronously when deciding whether to admit an over-cap import.
    func setEntitlement(_ entitlement: Entitlement) {
        currentEntitlement = entitlement
        sharedDefaults?.set(entitlement.isPro, forKey: Self.isProMirrorKey)
    }

    /// Read-only access to the daily-usage counter. Exposed so views (e.g.
    /// `FreeCapCaption`) can render "N of 3 today" without taking a
    /// dependency on the private `DailyUsageTracker` instance.
    func dailyCount(for feature: DailyUsageTracker.Feature) -> Int {
        usageTracker.count(for: feature)
    }

    /// Maps a `ProFeature` to a `GateResult`. Pro users always pass; Free
    /// users compare against `FreeCap` and `usageTracker`.
    func gate(_ feature: ProFeature) -> GateResult {
        if isPro { return .allowed }
        return gateFree(feature)
    }

    /// Mirrors `gate(_:)` but always evaluates the Free-tier path. Used by
    /// debug tooling that wants to preview "what the Free user would see"
    /// while testing on a Pro account.
    private func gateFree(_ feature: ProFeature) -> GateResult {
        switch feature {
        case .smartCutSession:
            return usageTracker.count(for: .smartCut) >= FreeCap.smartCutSessionsPerDay
                ? .requiresPro(reason: .hitDailyCap)
                : .allowed

        case .smartCutLength(let seconds):
            return seconds > FreeCap.smartCutMaxSeconds
                ? .requiresPro(reason: .hitLengthCap)
                : .allowed

        case .denoiseSession:
            return usageTracker.count(for: .denoise) >= FreeCap.denoiseSessionsPerDay
                ? .requiresPro(reason: .hitDailyCap)
                : .allowed

        case .denoiseLength(let seconds):
            return seconds > FreeCap.denoiseMaxSeconds
                ? .requiresPro(reason: .hitLengthCap)
                : .allowed

        // .mergeClipCount intentionally shares .hitLengthCap until Sub-project 3
        // adds a dedicated .hitClipCountCap to PaywallReason. Headline copy reads
        // identically for both gates.
        case .mergeClipCount(let count):
            return count > FreeCap.mergeMaxClips
                ? .requiresPro(reason: .hitLengthCap)
                : .allowed

        case .exportFormat(let format):
            return format == .wav
                ? .allowed
                : .requiresPro(reason: .watermarkExport)

        case .removeWatermark:
            return .requiresPro(reason: .watermarkExport)

        case .customFillerLibrary, .backgroundProcessing:
            return .requiresPro(reason: .settingsUpgrade)
        }
    }

    /// Helpers for incrementing usage. Called by SmartCut/Denoise call
    /// sites at the moment a session is committed (not at apply-cuts —
    /// session creation is the chargeable action).
    func recordSmartCutSession() { usageTracker.increment(.smartCut) }
    func recordDenoiseSession() { usageTracker.increment(.denoise) }
}

// EntitlementService is @Observable — inject via @Environment(EntitlementService.self)
// (Swift 5.9+ Observation framework). No EnvironmentKey needed.
