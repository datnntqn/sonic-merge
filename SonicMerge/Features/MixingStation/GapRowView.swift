// GapRowView.swift
// SonicMerge

import SwiftUI

enum GapRowAccessibility {
    static let label = "Transition between clips"
}

/// Inline row between two clip cards allowing the user to select a gap duration or crossfade.
/// The segmented control options are: 0.5s | 1.0s | 2.0s | Crossfade.
/// Selecting any option takes effect immediately (no confirm step).
struct GapRowView: View {
    let transition: GapTransition
    let onUpdate: (_ gapDuration: Double?, _ isCrossfade: Bool?) -> Void

    @State private var selection: GapOption

    enum GapOption: String, CaseIterable, Hashable {
        case half = "0.5s"
        case one  = "1.0s"
        case two  = "2.0s"
        case crossfade = "Crossfade"

        var gapDuration: Double? {
            switch self {
            case .half: return 0.5
            case .one: return 1.0
            case .two: return 2.0
            case .crossfade: return nil
            }
        }
        var isCrossfade: Bool { self == .crossfade }
    }

    init(transition: GapTransition, onUpdate: @escaping (Double?, Bool?) -> Void) {
        self.transition = transition
        self.onUpdate = onUpdate
        let initial: GapOption = transition.isCrossfade ? .crossfade :
            (transition.gapDuration == 1.0 ? .one : transition.gapDuration == 2.0 ? .two : .half)
        _selection = State(initialValue: initial)
    }

    var body: some View {
        HStack(spacing: SonicMergeTheme.Spacing.sm) {
            ForEach(GapOption.allCases, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    Text(option.rawValue)
                }
                .buttonStyle(
                    selection == option
                        ? PillButtonStyle(variant: .filled,  size: .compact)
                        : PillButtonStyle(variant: .outline, size: .compact)
                )
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SonicMergeTheme.Spacing.md)
        .padding(.vertical, SonicMergeTheme.Spacing.sm)
        .background(Color.clear) // Phase 7: transparent so the timeline spine shows through
        .accessibilityElement(children: .combine)
        .accessibilityLabel(GapRowAccessibility.label)
        .onChange(of: selection) { _, newValue in
            onUpdate(newValue.gapDuration, newValue.isCrossfade)
        }
    }
}
