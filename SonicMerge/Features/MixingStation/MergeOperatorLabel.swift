// MergeOperatorLabel.swift
// SonicMerge

import SwiftUI
import UIKit

enum MergeOperatorKind {
    case plus
    case equals
}

/// Large centered operator between timeline slots (+ / =).
struct MergeOperatorLabel: View {
    let kind: MergeOperatorKind
    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        HStack {
            Spacer()
            Image(systemName: symbolName)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(uiColor: semantic.accentAction).opacity(0.9))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color(uiColor: semantic.surfaceBase)) // opaque — spine threads through
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color(uiColor: semantic.accentGlow).opacity(0.35), lineWidth: 1)
                )
            Spacer()
        }
        .padding(.vertical, 6)
        .accessibilityLabel(kind == .plus ? "Plus, add next clip" : "Equals, merged output")
    }

    private var symbolName: String {
        switch kind {
        case .plus: return "plus"
        case .equals: return "equal"
        }
    }
}
