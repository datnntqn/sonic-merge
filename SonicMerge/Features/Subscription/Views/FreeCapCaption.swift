import SwiftUI

/// Single-line caption surfaced under each home screen's import button so
/// Free users see the cap before they tap. Hidden entirely for Pro users.
/// Tap opens the paywall via `.settingsUpgrade` (bypasses throttle — user
/// is explicitly asking).
///
/// Reads `EntitlementService.isPro` and `EntitlementService.dailyCount(for:)`,
/// both `@Observable`, so the caption live-updates as the user consumes
/// quota.
struct FreeCapCaption: View {

    enum Feature {
        case smartCut
        case denoise
        case merge
    }

    let feature: Feature
    @Binding var paywallReason: PaywallReason?

    @Environment(EntitlementService.self) private var entitlements
    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        let count = dailyCount()
        if let text = Self.captionString(for: feature, isPro: entitlements.isPro, count: count) {
            Button {
                paywallReason = .settingsUpgrade
            } label: {
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("FreeCapCaption")
        }
    }

    private func dailyCount() -> Int {
        switch feature {
        case .smartCut: return entitlements.dailyCount(for: .smartCut)
        case .denoise: return entitlements.dailyCount(for: .denoise)
        case .merge: return 0  // Merge has no daily cap; `count` is unused.
        }
    }

    /// Pure-function test seam. Returns the caption string for a given state.
    /// `count` is consumed only for `.smartCut` and `.denoise`; ignored for
    /// `.merge`. Returns `nil` when the user is Pro (caller renders nothing).
    static func captionString(for feature: Feature, isPro: Bool, count: Int) -> String? {
        guard !isPro else { return nil }
        switch feature {
        case .smartCut:
            return "Free: up to 5 min · \(count) of 3 today"
        case .denoise:
            return "Free: up to 3 min · \(count) of 3 today"
        case .merge:
            return "Free: up to 3 clips"
        }
    }
}
