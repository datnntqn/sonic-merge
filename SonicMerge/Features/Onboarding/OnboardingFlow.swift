// OnboardingFlow.swift
// SonicMerge
//
// First-launch onboarding. 5 steps: brand opener → trust primer →
// speech recognition permission → hands-on Smart Cut on bundled
// sample → result + Denoise reveal. Gated by @AppStorage flag in
// RootTabView. Spec: docs/superpowers/specs/2026-05-03-cleancut-onboarding-design.md

import SwiftUI

struct OnboardingFlow: View {
    enum Step: Int { case brand = 0, trust, permission, sample, result }

    @AppStorage("sonicMerge.hasOnboarded") private var hasOnboarded: Bool = false
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var step: Step = .brand

    var body: some View {
        ZStack {
            PremiumBackground()
            VStack(spacing: 0) {
                StepProgressIndicator(step: step)
                    .padding(.top, 16)

                Group {
                    switch step {
                    case .brand:
                        BrandOpenerStep(
                            semantic: semantic,
                            reduceMotion: reduceMotion,
                            onContinue: { advance(to: .trust) },
                            onSkip: { advance(to: .trust) }   // skip → trust per spec §5 step 1
                        )
                    case .trust:
                        TrustPrimerStep(
                            semantic: semantic,
                            reduceTransparency: reduceTransparency,
                            onContinue: { advance(to: .permission) }
                        )
                    case .permission, .sample, .result:
                        // TODO Chunks 4–5: replace
                        VStack {
                            Text("Step \(step.rawValue + 1) — not yet implemented")
                            Button("Done · Open Smart Cut") { hasOnboarded = true }
                                .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func advance(to next: Step) {
        if reduceMotion {
            step = next
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { step = next }
        }
    }
}

// MARK: - Step progress indicator

private struct StepProgressIndicator: View {
    let step: OnboardingFlow.Step

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { index in
                let isActive = index == step.rawValue
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isActive ? Color(uiColor: .systemIndigo) : Color(uiColor: .systemGray3))
                    .frame(width: isActive ? 24 : 14, height: 4)
                    .animation(.easeInOut(duration: 0.2), value: step)
            }
        }
        .accessibilityHidden(true)  // per-step .accessibilityLabel covers position
    }
}

// MARK: - Step 1: Brand opener

private struct BrandOpenerStep: View {
    let semantic: SonicMergeSemantic
    let reduceMotion: Bool
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onSkip)
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
            }
            .padding(.top, 8)

            Spacer(minLength: 0)

            // Hero badge — gradient at 20% alpha, sparkles inside
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            Color(uiColor: semantic.accentAI).opacity(0.20),
                            Color(uiColor: semantic.accentAction).opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
            }
            .frame(width: 80, height: 80)
            .accessibilityHidden(true)
            .padding(.bottom, 20)

            Text("Cut. Clean. Merge.")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            Text("Your audio toolkit, all on this device.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .padding(.bottom, 24)

            VStack(spacing: 10) {
                FeaturePill(icon: "sparkles", iconBg: Color(uiColor: semantic.accentAI),
                            title: "Smart Cut", subtitle: "remove fillers", semantic: semantic)
                FeaturePill(icon: "waveform.badge.minus", iconBg: Color(uiColor: semantic.accentAI),
                            title: "Denoise", subtitle: "clean noisy clips", semantic: semantic)
                FeaturePill(icon: "rectangle.stack", iconBg: Color(uiColor: semantic.accentAction),
                            title: "Merge", subtitle: "combine audio", semantic: semantic)
            }

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color(uiColor: semantic.accentAction)))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step 1 of 5: Cut. Clean. Merge. Your audio toolkit, all on this device.")
    }
}

private struct FeaturePill: View {
    let icon: String
    let iconBg: Color
    let title: String
    let subtitle: String
    let semantic: SonicMergeSemantic

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(iconBg)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
                Text(subtitle).font(.caption)
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: semantic.surfaceCard))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(uiColor: .systemGray5), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Step 2: Trust primer

private struct TrustPrimerStep: View {
    let semantic: SonicMergeSemantic
    let reduceTransparency: Bool
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 32)  // matches step 1's skip-row height
            Spacer(minLength: 0)

            // Hero badge — indigo at 14% alpha, lock.shield.fill inside
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(uiColor: semantic.accentAction).opacity(0.14))
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Color(uiColor: semantic.accentAction))
            }
            .frame(width: 80, height: 80)
            .accessibilityHidden(true)
            .padding(.bottom, 20)

            Text("Your audio\nnever leaves\nthis device.")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            Text("No upload. No cloud. No account.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)

            VStack(spacing: 10) {
                TrustRow(text: "Apple's on-device AI handles every cut",
                         semantic: semantic,
                         reduceTransparency: reduceTransparency)
                TrustRow(text: "Files stay in CleanCut's private folder",
                         semantic: semantic,
                         reduceTransparency: reduceTransparency)
            }

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color(uiColor: semantic.accentAction)))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step 2 of 5: Your audio never leaves this device. No upload. No cloud. No account.")
    }
}

private struct TrustRow: View {
    let text: String
    let semantic: SonicMergeSemantic
    let reduceTransparency: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(Color(uiColor: semantic.accentAction))
                .font(.system(size: 16, weight: .semibold))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var background: some View {
        if reduceTransparency {
            Color(uiColor: semantic.surfaceCard)
        } else {
            ZStack {
                Color(uiColor: semantic.accentGlow).opacity(0.06)
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }
}
