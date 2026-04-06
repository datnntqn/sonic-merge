// GapRowView.swift
// SonicMerge

import SwiftUI
import UIKit

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
        Picker("Gap", selection: $selection) {
            ForEach(GapOption.allCases, id: \.self) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(GapRowAccessibility.label)
        .background(Color(uiColor: SonicMergeTheme.ColorPalette.cardSurface).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: SonicMergeTheme.Radius.chip, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .onChange(of: selection) { _, newValue in
            onUpdate(newValue.gapDuration, newValue.isCrossfade)
        }
    }
}
