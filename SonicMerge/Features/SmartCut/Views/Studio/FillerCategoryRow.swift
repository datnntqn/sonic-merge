// FillerCategoryRow.swift
// SonicMerge
//
// Phase 12 (Smart Cut Studio Refactor): content of one filler-category
// bento card. Leading column shows the count eyebrow + word label;
// trailing column shows the saves chip + group toggle. Tapping the body
// (anywhere outside the toggle) opens the detail sheet via the parent's
// onOpenSheet callback.

import SwiftUI

struct FillerCategoryRow: View {
    let category: String
    let occurrenceCount: Int
    let savings: TimeInterval
    let isEnabled: Bool      // true = some occurrences will be cut (group .on or .mixed)
    let onToggleGroup: () -> Void
    let onOpenSheet: () -> Void

    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        StudioBentoCard(
            isDisabled: !isEnabled,
            onTap: onOpenSheet,
            leading: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(occurrenceCount) OCCURRENCE\(occurrenceCount == 1 ? "" : "S")")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                    Text(category)
                        .font(.title3.weight(isEnabled ? .semibold : .bold))
                        .foregroundStyle(isEnabled
                            ? Color(uiColor: semantic.textPrimary)
                            : Color(uiColor: semantic.accentAction))
                        .strikethrough(!isEnabled)
                }
            },
            trailing: {
                HStack(spacing: 12) {
                    SavesChip(seconds: savings)
                    Button(action: onToggleGroup) {
                        Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isEnabled
                                ? Color(uiColor: semantic.accentAI)
                                : Color(uiColor: semantic.accentAction).opacity(0.5))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isEnabled ? "Disable \(category)" : "Enable \(category)")
                }
            }
        )
    }
}

/// Small lime/dim chip used by the bento cards' trailing edge.
struct SavesChip: View {
    let seconds: TimeInterval
    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        Text(seconds > 0 ? "saves \(SmartCutFormatting.formatTimestamp(seconds))" : "saves —")
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(seconds > 0
                ? Color(uiColor: semantic.accentAI)
                : Color(uiColor: semantic.textSecondary))
    }
}
