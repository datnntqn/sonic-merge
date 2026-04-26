// JunctionView.swift
// SonicMerge
//
// Phase 10 — Smart Junction capsule between clip cards. Replaces GapRowView's
// horizontal pill-row layout (4 chips taking ~120pt vertical) with a single
// 28pt capsule that opens a native iOS Menu on tap. See
// docs/superpowers/specs/2026-04-24-main-screen-continuous-stream-design.md
// for the full design contract (D-02 / D-04 / D-05).
//
// Wave 8 (D-05): "Insert clip here" is rendered when an onInsertClip callback
// is supplied. The async orchestration (R-03) lives in the parent view via a
// pendingInsert gate.

import SwiftUI
import UIKit

struct JunctionView: View {
    let transition: GapTransition
    let onTransitionChange: (_ gapDuration: Double?, _ isCrossfade: Bool?) -> Void
    /// Optional Wave-8 (D-05): if non-nil, the Menu shows an "Insert clip here"
    /// action. When tapped, the parent owns the file-importer + reorder dance.
    let onInsertClip: (() -> Void)?

    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var picked: Choice

    enum Choice: Hashable {
        case gap(Double)
        case crossfade

        /// True when this choice represents the empty / "tap to add" state.
        /// Used by the capsule to render as an Add affordance rather than a
        /// state readout.
        var isEmpty: Bool {
            if case .gap(let d) = self, d == 0 { return true }
            return false
        }

        var capsuleLabel: String {
            switch self {
            case .gap(let d):
                if d == 0 { return "Add" }
                if d == 0.5 { return "0.5s" }
                if d == 1.0 { return "1.0s" }
                return "2.0s"
            case .crossfade:
                return "Cross"
            }
        }

        var capsuleSymbol: String {
            switch self {
            case .gap(let d): return d == 0 ? "plus" : "clock"
            case .crossfade: return "arrow.triangle.merge"
            }
        }

        var voiceOverLabel: String {
            switch self {
            case .gap(let d):
                return d == 0
                    ? "no gap, tap to add a gap or crossfade"
                    : "\(d) second gap"
            case .crossfade:
                return "Crossfade"
            }
        }
    }

    init(
        transition: GapTransition,
        onTransitionChange: @escaping (Double?, Bool?) -> Void,
        onInsertClip: (() -> Void)? = nil
    ) {
        self.transition = transition
        self.onTransitionChange = onTransitionChange
        self.onInsertClip = onInsertClip
        let initial: Choice = transition.isCrossfade
            ? .crossfade
            : .gap(transition.gapDuration)
        _picked = State(initialValue: initial)
    }

    var body: some View {
        Menu {
            Picker("Transition", selection: $picked) {
                Label("No gap", systemImage: "minus").tag(Choice.gap(0))
                Label("0.5 seconds", systemImage: "clock").tag(Choice.gap(0.5))
                Label("1.0 seconds", systemImage: "clock").tag(Choice.gap(1.0))
                Label("2.0 seconds", systemImage: "clock").tag(Choice.gap(2.0))
            }
            Divider()
            Button {
                // Phase 11: medium-weight haptic precedes the state flip so
                // the impact lands at the moment of choice, not after the
                // menu dismiss animation completes.
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                picked = .crossfade
            } label: {
                Label("Crossfade", systemImage: "arrow.triangle.merge")
            }
            if let onInsertClip {
                Divider()
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onInsertClip()
                } label: {
                    Label("Insert clip here", systemImage: "plus")
                }
            }
        } label: {
            capsule
        }
        .onChange(of: picked) { _, newValue in
            // Phase 11 distinct haptics: light for any gap change (incl.
            // "No gap"), medium for crossfade. Picker selections route
            // through this single observer; the explicit Crossfade and
            // Insert buttons fire their own generator before mutating
            // state so the haptic precedes the menu dismiss.
            let style: UIImpactFeedbackGenerator.FeedbackStyle = {
                switch newValue {
                case .gap:       return .light
                case .crossfade: return .medium
                }
            }()
            UIImpactFeedbackGenerator(style: style).impactOccurred()

            switch newValue {
            case .gap(let d):
                onTransitionChange(d, false)
            case .crossfade:
                onTransitionChange(nil, true)
            }
        }
        .accessibilityLabel("Transition: \(picked.voiceOverLabel). Double-tap to change.")
        .accessibilityAddTraits(.isButton)
    }

    private var capsule: some View {
        HStack(spacing: 6) {
            Image(systemName: picked.capsuleSymbol)
            Text(picked.capsuleLabel)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        // Empty/Add state is dimmed so it reads as an affordance, not a
        // current-state badge. Set states render at full accentAction.
        .foregroundStyle(
            Color(uiColor: semantic.accentAction)
                .opacity(picked.isEmpty ? 0.55 : 1.0)
        )
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(
            Capsule().fill(Color(uiColor: semantic.surfaceCard))
        )
        .overlay(
            Capsule().stroke(
                Color(uiColor: semantic.accentGlow).opacity(picked.isEmpty ? strokeOpacity * 0.6 : strokeOpacity),
                style: StrokeStyle(lineWidth: 1, dash: picked.isEmpty ? [3, 3] : [])
            )
        )
        .frame(minWidth: 72, minHeight: 44)
        .contentShape(Rectangle())
    }

    private var strokeOpacity: Double {
        // reduceTransparency raises the stroke from 0.35 → 0.55 for stronger contrast.
        reduceTransparency ? 0.55 : 0.35
    }

    /// Value-typed key that re-evaluates whenever the bound transition's mutable
    /// properties change. Used to drive `.sensoryFeedback`, since GapTransition
    /// is a SwiftData @Model class (Equatable as reference identity, not value).
    private var triggerKey: Int {
        var hasher = Hasher()
        hasher.combine(transition.gapDuration)
        hasher.combine(transition.isCrossfade)
        return hasher.finalize()
    }
}
