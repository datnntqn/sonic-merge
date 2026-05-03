// ThemeToggleButton.swift
// SonicMerge
//
// Binary Light ↔ Dark toggle. Self-contained: reads/writes its own
// @AppStorage("sonicMergeThemePreference"). Caller invokes as
// `ThemeToggleButton()` with no args.

import SwiftUI

struct ThemeToggleButton: View {
    @Environment(\.sonicMergeSemantic) private var semantic

    @AppStorage("sonicMergeThemePreference") private var themePreferenceRaw: String = ThemePreference.light.rawValue

    private var current: ThemePreference {
        // Legacy-value tolerance (spec §7): unrecognized raw → render as .light.
        // The §10 .onAppear migration normalizes storage on first launch.
        ThemePreference(rawValue: themePreferenceRaw) ?? .light
    }

    var body: some View {
        Button {
            themePreferenceRaw = ThemePreference.next(after: current).rawValue
        } label: {
            Image(systemName: current == .light ? "sun.max.fill" : "moon.fill")
                .font(.system(size: 17, weight: .semibold))
                .symbolEffect(.bounce, value: themePreferenceRaw)
        }
        .tint(Color(uiColor: semantic.accentAction))
        .sensoryFeedback(.impact(weight: .light), trigger: themePreferenceRaw)
        .accessibilityLabel(current == .light ? "Theme: Light" : "Theme: Dark")
        .accessibilityHint(current == .light ? "Tap to switch to Dark theme" : "Tap to switch to Light theme")
    }
}
