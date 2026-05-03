// OnboardingFlow.swift
// SonicMerge
//
// First-launch onboarding. 5 steps: brand opener → trust primer →
// speech recognition permission → hands-on Smart Cut on bundled
// sample → result + Denoise reveal. Gated by @AppStorage flag in
// RootTabView. Spec: docs/superpowers/specs/2026-05-03-cleancut-onboarding-design.md

import SwiftUI

struct OnboardingFlow: View {
    /// Set true on Done; the @AppStorage in RootTabView observes the same
    /// key and dismisses the .fullScreenCover.
    @AppStorage("sonicMerge.hasOnboarded") private var hasOnboarded: Bool = false

    var body: some View {
        // TODO Chunk 3+: replace with actual step views.
        ZStack {
            Color.black.opacity(0.001)  // tappable placeholder for tests
            VStack(spacing: 16) {
                Text("Onboarding placeholder")
                    .font(.headline)
                Button("Done · Open Smart Cut") {
                    hasOnboarded = true
                }
            }
        }
    }
}
