import Foundation

/// Every gate-able capability in the app. Used by
/// `EntitlementService.gate(_ feature: ProFeature) -> GateResult`.
/// Sub-project 1 introduces the type; Sub-project 2 wires the gate
/// semantics at each callsite.
///
/// The `seconds:` and `count:` payloads let gates be context-aware
/// without hardcoding limits inside the service (e.g., `.smartCutLength(600)`
/// for "user is trying to import a 10-min clip" — service compares to the
/// 5-min free cap and returns .requiresPro if exceeded).
enum ProFeature: Equatable, Hashable, Sendable {
    case smartCutSession
    case smartCutLength(seconds: TimeInterval)
    case denoiseSession
    case denoiseLength(seconds: TimeInterval)
    case mergeClipCount(count: Int)
    case exportFormat(format: ExportFormat)
    case removeWatermark
    case customFillerLibrary
    case backgroundProcessing

    enum ExportFormat: Equatable, Hashable, Sendable {
        case wav
        case m4a
        case mp3
    }
}

/// Returned by `EntitlementService.gate(_:)`. Sub-project 1 only declares the
/// type; Sub-project 2 returns specific reasons at gate sites.
enum GateResult: Equatable, Sendable {
    case allowed
    case requiresPro(reason: String)
}
