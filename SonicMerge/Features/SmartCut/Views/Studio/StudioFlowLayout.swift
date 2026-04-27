// StudioFlowLayout.swift
// SonicMerge
//
// Phase 12 (Smart Cut Studio Refactor): wrap-flow Layout for the unified
// tag-capsule pool in EditFillerListStudioSheet. Each row left-aligns
// (or right-aligns under RTL via the parent's layoutDirection environment)
// and wraps to a new row when the next item would exceed the proposed
// width. ~50 LoC; pure presentation, no behavior.

import SwiftUI

struct StudioFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var currentX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && !rows[rows.count - 1].isEmpty {
                rows.append([size])
                currentX = size.width + spacing
            } else {
                rows[rows.count - 1].append(size)
                currentX += size.width + spacing
            }
        }

        let totalHeight: CGFloat = rows.reduce(0) { acc, row in
            let rowHeight = row.map(\.height).max() ?? 0
            return acc + rowHeight + (acc > 0 ? spacing : 0)
        }
        let widestRow: CGFloat = rows.map { row in
            row.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(0, row.count - 1))
        }.max() ?? 0

        return CGSize(width: min(widestRow, width), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // RTL is handled by the SwiftUI parent applying
        // .environment(\.layoutDirection, .rightToLeft) — bounds.minX
        // becomes the visual leading edge and SwiftUI mirrors placement
        // automatically. No direct RTL handling needed here.
        var rowItems: [(index: Int, size: CGSize)] = []
        var rowY: CGFloat = bounds.minY
        var currentX: CGFloat = 0

        func placeRow() {
            let rowHeight = rowItems.map(\.size.height).max() ?? 0
            var x: CGFloat = bounds.minX
            for entry in rowItems {
                subviews[entry.index].place(
                    at: CGPoint(x: x, y: rowY + (rowHeight - entry.size.height) / 2),
                    proposal: ProposedViewSize(entry.size)
                )
                x += entry.size.width + spacing
            }
            rowY += rowHeight + spacing
            rowItems.removeAll()
            currentX = 0
        }

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.width && !rowItems.isEmpty {
                placeRow()
            }
            rowItems.append((index, size))
            currentX += size.width + spacing
        }
        if !rowItems.isEmpty { placeRow() }
    }
}
