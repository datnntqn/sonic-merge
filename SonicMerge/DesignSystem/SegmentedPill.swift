// SegmentedPill.swift
// SonicMerge
//
// clt-t1: Generic pill segmented control matching the project's PillButtonStyle aesthetic.
// Sized for 2 options at iPhone widths; supports N>=2 via Option.allCases iteration.
//
// Usage:
//     enum Tab: Hashable, CaseIterable { case foo, bar }
//     @State private var tab: Tab = .foo
//     SegmentedPill(selection: $tab) { option in
//         option == .foo ? "Foo" : "Bar"
//     }
//
// The selected option uses (.filled, .compact, .ai); unselected uses (.outline, .compact, .accent).
// Tapping fires a light UIImpactFeedbackGenerator for tactile confirmation.

import SwiftUI
import UIKit

struct SegmentedPill<Option: Hashable & CaseIterable>: View
    where Option.AllCases: RandomAccessCollection
{
    @Binding var selection: Option
    let label: (Option) -> String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(Option.allCases), id: \.self) { option in
                let isSelected = (option == selection)
                Button {
                    if option != selection {
                        selection = option
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } label: {
                    Text(label(option))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle(
                    variant: isSelected ? .filled : .outline,
                    size: .compact,
                    tint: isSelected ? .ai : .accent
                ))
            }
        }
    }
}
